from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.core.mail import send_mail

from accounts.permissions import IsOwner
from properties.models import LeaseTenant
from .models import TenantInvite, FCMToken
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    InviteTenantSerializer,
    AcceptInviteSerializer,
)

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

        # get or create tenant user (inactive until they accept)
        tenant_user, _ = User.objects.get_or_create(
            email=invite.email,
            defaults={
                "role": User.Role.TENANT,
                "is_active": False,
            },
        )

        # send invite email (prints to console in dev)
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

        # activate tenant user
        tenant_user, _ = User.objects.get_or_create(
            email=invite.email,
            defaults={"role": User.Role.TENANT},
        )
        tenant_user.role = User.Role.TENANT
        tenant_user.is_active = True
        tenant_user.set_password(password)
        tenant_user.save()

        # link tenant to lease
        LeaseTenant.objects.get_or_create(
            lease=invite.lease,
            tenant=tenant_user,
            defaults={
                "rent_share_pct": invite.rent_share_pct,
                "is_primary": True,
            },
        )

        # mark invite accepted
        invite.is_accepted = True
        invite.save()

        # issue JWT
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
