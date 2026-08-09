import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
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
)

logger = logging.getLogger(__name__)
User = get_user_model()


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response(
                {
                    "message": "Owner registered successfully.",
                    "user": {
                        "id": user.id,
                        "email": user.email,
                        "role": user.role,
                    },
                },
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


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
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "role": user.role,
                },
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
        id_token = request.data.get("id_token")
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

        # Get existing user or create new owner
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
                {"detail": "Account is disabled."},
                status=status.HTTP_403_FORBIDDEN,
            )

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "role": user.role,
                },
                "created": created,
            },
            status=status.HTTP_200_OK,
        )


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

        send_mail(
            subject="You are invited to RentLedger",
            message=(
                f"Hello,\n\n"
                f"You have been invited to join RentLedger as a tenant.\n\n"
                f"Your invite token: {invite.token}\n\n"
                f"Use this token to accept your invite and set your password.\n\n"
                f"This invite expires in 7 days.\n\n"
                f"— RentLedger Team"
            ),
            from_email="noreply@rentledger.com",
            recipient_list=[invite.email],
            fail_silently=True,
        )

        return Response(
            {
                "message": "Invite sent successfully.",
                "invite_token": str(invite.token),
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

        refresh = RefreshToken.for_user(tenant_user)
        return Response(
            {
                "message": "Invite accepted. Welcome to RentLedger!",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": tenant_user.id,
                    "email": tenant_user.email,
                    "role": tenant_user.role,
                },
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
