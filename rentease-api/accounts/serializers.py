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
    first_name = serializers.CharField(required=True, max_length=150)
    last_name = serializers.CharField(required=False, allow_blank=True, max_length=150)
    phone = serializers.CharField(required=False, allow_blank=True, max_length=10)

    class Meta:
        model = User
        fields = ("email", "password", "first_name", "last_name", "phone")

    def validate_phone(self, value):
        value = (value or "").strip()
        digits = "".join(ch for ch in value if ch.isdigit())
        if digits and len(digits) != 10:
            raise serializers.ValidationError("Phone number must be exactly 10 digits.")
        return digits

    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data.get("first_name", ""),
            last_name=validated_data.get("last_name", ""),
            phone=validated_data.get("phone", ""),
            role=User.Role.OWNER,
        )
        from properties.models import Portfolio

        name = (user.first_name or "My").strip() or "My"
        Portfolio.objects.get_or_create(
            owner=user,
            defaults={"name": f"{name}'s Portfolio"},
        )
        return user


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "first_name",
            "last_name",
            "phone",
            "role",
        )
        read_only_fields = ("id", "email", "role")

    def validate_phone(self, value):
        value = (value or "").strip()
        digits = "".join(ch for ch in value if ch.isdigit())
        if value and not digits:
            raise serializers.ValidationError("Enter a valid phone number.")
        if digits and len(digits) != 10:
            raise serializers.ValidationError("Phone number must be exactly 10 digits.")
        return digits


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, write_only=True)


class InviteTenantSerializer(serializers.Serializer):
    email = serializers.EmailField()
    lease_id = serializers.IntegerField(required=False)
    unit_id = serializers.IntegerField(required=False)
    rent_share_pct = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=100.00,
        min_value=0,
        max_value=100,
    )
    due_day = serializers.IntegerField(required=False, min_value=1, max_value=28, default=5)

    def validate(self, attrs):
        from datetime import date

        from properties.models import Lease, LeaseTenant, Unit

        request = self.context["request"]
        lease_id = attrs.get("lease_id")
        unit_id = attrs.get("unit_id")

        if not lease_id and not unit_id:
            raise serializers.ValidationError("Provide unit_id or lease_id.")

        lease = None
        if lease_id:
            try:
                lease = Lease.objects.get(
                    id=lease_id,
                    unit__building__portfolio__owner=request.user,
                )
            except Lease.DoesNotExist:
                raise serializers.ValidationError("Lease not found or not owned by you.")
        else:
            try:
                unit = Unit.objects.select_related("building__portfolio").get(
                    id=unit_id,
                    building__portfolio__owner=request.user,
                )
            except Unit.DoesNotExist:
                raise serializers.ValidationError("Unit not found or not owned by you.")

            lease = (
                Lease.objects.filter(unit=unit, status=Lease.LeaseStatus.ACTIVE)
                .order_by("-created_at")
                .first()
            )
            if lease is None:
                lease = Lease.objects.create(
                    unit=unit,
                    monthly_rent=unit.base_rent,
                    due_day=attrs.get("due_day") or 5,
                    start_date=date.today(),
                    status=Lease.LeaseStatus.ACTIVE,
                )
                if unit.is_vacant:
                    unit.is_vacant = False
                    unit.save(update_fields=["is_vacant"])

        if LeaseTenant.objects.filter(
            lease=lease, tenant__email=attrs["email"]
        ).exists():
            raise serializers.ValidationError("Tenant already linked to this lease.")

        if TenantInvite.objects.filter(
            lease=lease,
            email=attrs["email"],
            is_accepted=False,
            expires_at__gt=timezone.now(),
        ).exists():
            raise serializers.ValidationError(
                "An active invite already exists for this email."
            )

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
    first_name = serializers.CharField(required=False, allow_blank=True, max_length=150)
    last_name = serializers.CharField(required=False, allow_blank=True, max_length=150)
    phone = serializers.CharField(required=False, allow_blank=True, max_length=10)

    def validate_phone(self, value):
        value = (value or "").strip()
        digits = "".join(ch for ch in value if ch.isdigit())
        if digits and len(digits) != 10:
            raise serializers.ValidationError("Phone number must be exactly 10 digits.")
        return digits

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
