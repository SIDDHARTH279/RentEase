from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from .models import User, TenantInvite


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
    )

    class Meta:
        model = User
        fields = ("email", "password", "first_name", "last_name")

    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data.get("first_name", ""),
            last_name=validated_data.get("last_name", ""),
            role=User.Role.OWNER,
        )
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, write_only=True)


class InviteTenantSerializer(serializers.Serializer):
    email = serializers.EmailField()
    lease_id = serializers.IntegerField()
    rent_share_pct = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=100.00,
        min_value=0,
        max_value=100,
    )

    def validate(self, attrs):
        from properties.models import Lease, LeaseTenant
        request = self.context["request"]

        try:
            lease = Lease.objects.get(
                id=attrs["lease_id"],
                unit__building__portfolio__owner=request.user,
            )
        except Lease.DoesNotExist:
            raise serializers.ValidationError("Lease not found or not owned by you.")

        if LeaseTenant.objects.filter(
            lease=lease, tenant__email=attrs["email"]
        ).exists():
            raise serializers.ValidationError("Tenant already linked to this lease.")

        if TenantInvite.objects.filter(
            lease=lease, email=attrs["email"], is_accepted=False,
            expires_at__gt=timezone.now()
        ).exists():
            raise serializers.ValidationError("An active invite already exists for this email.")

        attrs["lease"] = lease
        return attrs

    def create(self, validated_data):
        return TenantInvite.objects.create(
            email=validated_data["email"],
            lease=validated_data["lease"],
            rent_share_pct=validated_data["rent_share_pct"],
        )


class AcceptInviteSerializer(serializers.Serializer):
    token = serializers.UUIDField()
    password = serializers.CharField(write_only=True, validators=[validate_password])

    def validate(self, attrs):
        try:
            invite = TenantInvite.objects.get(token=attrs["token"])
        except TenantInvite.DoesNotExist:
            raise serializers.ValidationError("Invalid invite token.")

        if invite.is_accepted:
            raise serializers.ValidationError("Invite already accepted.")

        if invite.expires_at < timezone.now():
            raise serializers.ValidationError("Invite has expired.")

        attrs["invite"] = invite
        return attrs
