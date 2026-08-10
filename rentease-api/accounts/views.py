import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from .emails import send_tenant_invite_email, send_welcome_email
from django_ratelimit.decorators import ratelimit
from django.utils.decorators import method_decorator
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

from accounts.permissions import IsOwner
from properties.models import LeaseTenant
from .models import TenantInvite, FCMToken
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    InviteTenantSerializer,
    AcceptInviteSerializer,
    ProfileSerializer,
)

logger = logging.getLogger(__name__)
User = get_user_model()


def _user_payload(user):
    return {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "phone": user.phone,
        "profile_complete": bool(user.first_name and user.phone),
    }


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response(
                {
                    "message": "Owner registered successfully.",
                    "user": _user_payload(user),
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(ProfileSerializer(request.user).data)

    def patch(self, request):
        serializer = ProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)


@method_decorator(ratelimit(key='ip', rate='5/m', method='POST', block=True), name='post')
class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data["email"]
        password = serializer.validated_data["password"]

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response(
                {"error": "Invalid credentials."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.check_password(password):
            return Response(
                {"error": "Invalid credentials."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {"error": "Account is disabled."},
                status=status.HTTP_403_FORBIDDEN,
            )

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": _user_payload(user),
            },
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return Response(
                {"detail": "Refresh token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response(
                {"detail": "Token is invalid or already blacklisted."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response({"detail": "Logged out successfully."}, status=status.HTTP_200_OK)


class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        from django.utils import timezone

        id_token = request.data.get("id_token")
        invite_token = request.data.get("invite_token")

        if not id_token:
            return Response(
                {"detail": "id_token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            from google.oauth2 import id_token as google_id_token
            from google.auth.transport import requests as google_requests

            client_id = settings.GOOGLE_CLIENT_ID
            id_info = google_id_token.verify_oauth2_token(
                id_token,
                google_requests.Request(),
                client_id,
            )
        except ValueError as e:
            logger.warning(f"Google token verification failed: {e}")
            return Response(
                {"detail": "Invalid Google token."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        email = id_info.get("email")
        first_name = id_info.get("given_name", "")
        last_name = id_info.get("family_name", "")

        if not email:
            return Response(
                {"detail": "Could not retrieve email from Google."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        def _jwt_response(user, *, created=False, invite_accepted=False):
            refresh = RefreshToken.for_user(user)
            payload = {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": _user_payload(user),
                "created": created,
            }
            if invite_accepted:
                payload["invite_accepted"] = True
            return Response(payload, status=status.HTTP_200_OK)

        def _accept_invite_as_tenant(invite, google_email, given, family):
            """Activate user as tenant and link to the invited lease."""
            if google_email.lower() != invite.email.lower():
                return None, Response(
                    {
                        "detail": (
                            f"Please sign in with the invited Google account "
                            f"({invite.email})."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Already joined earlier → just log them in
            if invite.is_accepted:
                try:
                    user = User.objects.get(email__iexact=invite.email)
                except User.DoesNotExist:
                    return None, Response(
                        {"detail": "Invite already used. Please contact the owner."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                if not user.is_active:
                    user.is_active = True
                    user.save(update_fields=["is_active"])
                return _jwt_response(user), None

            if invite.expires_at < timezone.now():
                return None, Response(
                    {"detail": "Invite has expired."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user, created = User.objects.get_or_create(
                email=invite.email,
                defaults={
                    "first_name": given,
                    "last_name": family,
                    "role": User.Role.TENANT,
                    "is_active": True,
                },
            )
            user.role = User.Role.TENANT
            user.is_active = True
            if given and not user.first_name:
                user.first_name = given
            if family and not user.last_name:
                user.last_name = family
            if not user.has_usable_password():
                user.set_unusable_password()
            user.save()

            LeaseTenant.objects.get_or_create(
                lease=invite.lease,
                tenant=user,
                defaults={
                    "rent_share_pct": invite.rent_share_pct,
                    "is_primary": True,
                },
            )
            invite.is_accepted = True
            invite.save(update_fields=["is_accepted"])

            try:
                send_welcome_email(email=user.email, first_name=user.first_name)
            except Exception:
                pass

            return _jwt_response(user, created=created, invite_accepted=True), None

        # ── Explicit invite token from deep link ──
        if invite_token:
            try:
                invite = TenantInvite.objects.select_related("lease").get(
                    token=invite_token
                )
            except TenantInvite.DoesNotExist:
                return Response(
                    {"detail": "Invalid invite token."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            result, err = _accept_invite_as_tenant(
                invite, email, first_name, last_name
            )
            return err if err is not None else result

        # ── No token: if this Gmail has a pending invite, accept it ──
        pending_invite = (
            TenantInvite.objects.select_related("lease")
            .filter(
                email__iexact=email,
                is_accepted=False,
                expires_at__gt=timezone.now(),
            )
            .order_by("-id")
            .first()
        )
        if pending_invite is not None:
            result, err = _accept_invite_as_tenant(
                pending_invite, email, first_name, last_name
            )
            return err if err is not None else result

        # ── Normal Google login (owner or returning tenant) ──
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "first_name": first_name,
                "last_name": last_name,
                "role": User.Role.OWNER,
                "is_active": True,
            },
        )

        if not user.is_active:
            return Response(
                {
                    "detail": (
                        "Account is disabled. If you were invited as a tenant, "
                        "ask the owner to send a new invite, then sign in with that Gmail."
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        return _jwt_response(user, created=created)


class InviteTenantView(APIView):
    permission_classes = [IsOwner]

    def post(self, request):
        serializer = InviteTenantSerializer(
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        invite = serializer.save()

        tenant_user, _ = User.objects.get_or_create(
            email=invite.email,
            defaults={
                "role": User.Role.TENANT,
                "is_active": False,
            },
        )

        owner_name = f"{request.user.first_name} {request.user.last_name}".strip() or request.user.email
        public_base = getattr(settings, "PUBLIC_BASE_URL", "").rstrip("/")
        invite_link = f"{public_base}/invite/{invite.token}/"
        send_tenant_invite_email(
            email=invite.email,
            invite_token=str(invite.token),
            owner_name=owner_name,
            invite_link=invite_link,
        )

        return Response(
            {
                "message": "Invite sent successfully.",
                "invite_token": str(invite.token),
                "invite_link": invite_link,
            },
            status=status.HTTP_201_CREATED,
        )


class AcceptInviteView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = AcceptInviteSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        invite = serializer.validated_data["invite"]
        password = serializer.validated_data["password"]

        tenant_user, _ = User.objects.get_or_create(
            email=invite.email,
            defaults={"role": User.Role.TENANT},
        )
        tenant_user.role = User.Role.TENANT
        tenant_user.is_active = True
        tenant_user.set_password(password)
        if serializer.validated_data.get("first_name"):
            tenant_user.first_name = serializer.validated_data["first_name"]
        if serializer.validated_data.get("last_name"):
            tenant_user.last_name = serializer.validated_data["last_name"]
        if serializer.validated_data.get("phone"):
            tenant_user.phone = serializer.validated_data["phone"]
        tenant_user.save()

        LeaseTenant.objects.get_or_create(
            lease=invite.lease,
            tenant=tenant_user,
            defaults={
                "rent_share_pct": invite.rent_share_pct,
                "is_primary": True,
            },
        )

        invite.is_accepted = True
        invite.save()

        send_welcome_email(
            email=tenant_user.email,
            first_name=tenant_user.first_name,
        )

        refresh = RefreshToken.for_user(tenant_user)
        return Response(
            {
                "message": "Invite accepted. Welcome to RentLedger!",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": _user_payload(tenant_user),
            },
            status=status.HTTP_200_OK,
        )


class SaveFCMTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get("token", "").strip()
        if not token:
            return Response({"detail": "Token is required."}, status=status.HTTP_400_BAD_REQUEST)
        FCMToken.objects.update_or_create(
            user=request.user,
            defaults={"token": token},
        )
        return Response({"detail": "Token saved."}, status=status.HTTP_200_OK)
