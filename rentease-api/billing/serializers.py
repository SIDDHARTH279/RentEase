from rest_framework import serializers

from .crypto import encrypt_secret
from .models import PaymentGatewayConfig, RentInvoice, RentShare, Payment


class PaymentGatewayConfigSerializer(serializers.Serializer):
    razorpay_key_id = serializers.CharField(
        max_length=100, required=False, allow_blank=True
    )
    razorpay_key_secret = serializers.CharField(
        max_length=200, required=False, allow_blank=True, write_only=True
    )
    is_enabled = serializers.BooleanField(required=False)

    upi_id = serializers.CharField(max_length=100, required=False, allow_blank=True)
    account_holder_name = serializers.CharField(
        max_length=150, required=False, allow_blank=True
    )
    bank_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    account_number = serializers.CharField(
        max_length=40, required=False, allow_blank=True
    )
    ifsc_code = serializers.CharField(max_length=20, required=False, allow_blank=True)
    payment_notes = serializers.CharField(
        max_length=300, required=False, allow_blank=True
    )
    show_manual_details = serializers.BooleanField(required=False)
    clear_qr_code = serializers.BooleanField(required=False, write_only=True)

    is_configured = serializers.BooleanField(read_only=True)
    has_manual_details = serializers.BooleanField(read_only=True)
    key_secret_masked = serializers.CharField(read_only=True)
    qr_code_url = serializers.SerializerMethodField()
    updated_at = serializers.DateTimeField(read_only=True)

    def get_qr_code_url(self, instance):
        if not instance.qr_code:
            return ""
        request = self.context.get("request")
        url = instance.qr_code.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def to_representation(self, instance: PaymentGatewayConfig):
        secret = instance.razorpay_key_secret_encrypted
        masked = ""
        if secret:
            masked = "••••••••" + (
                instance.razorpay_key_id[-4:] if instance.razorpay_key_id else ""
            )
        return {
            "razorpay_key_id": instance.razorpay_key_id,
            "is_enabled": instance.is_enabled,
            "is_configured": instance.is_configured,
            "has_manual_details": instance.has_manual_details,
            "key_secret_masked": masked if instance.is_configured else "",
            "upi_id": instance.upi_id,
            "account_holder_name": instance.account_holder_name,
            "bank_name": instance.bank_name,
            "account_number": instance.account_number,
            "ifsc_code": instance.ifsc_code,
            "payment_notes": instance.payment_notes,
            "show_manual_details": instance.show_manual_details,
            "qr_code_url": self.get_qr_code_url(instance),
            "updated_at": instance.updated_at,
        }

    def update(self, instance, validated_data):
        if "razorpay_key_id" in validated_data:
            instance.razorpay_key_id = validated_data["razorpay_key_id"].strip()
        if "is_enabled" in validated_data:
            instance.is_enabled = validated_data["is_enabled"]
        secret = validated_data.get("razorpay_key_secret", "").strip()
        if secret:
            instance.razorpay_key_secret_encrypted = encrypt_secret(secret)

        for field in (
            "upi_id",
            "account_holder_name",
            "bank_name",
            "account_number",
            "ifsc_code",
            "payment_notes",
        ):
            if field in validated_data:
                setattr(instance, field, (validated_data[field] or "").strip())

        if "show_manual_details" in validated_data:
            instance.show_manual_details = validated_data["show_manual_details"]

        if validated_data.get("clear_qr_code"):
            if instance.qr_code:
                instance.qr_code.delete(save=False)
            instance.qr_code = None

        qr = self.context.get("qr_file")
        if qr is not None:
            instance.qr_code = qr

        instance.save()
        return instance

    def create(self, validated_data):
        owner = self.context["request"].user
        instance, _ = PaymentGatewayConfig.objects.get_or_create(owner=owner)
        return self.update(instance, validated_data)


class TenantOwnerPaymentInfoSerializer(serializers.Serializer):
    """Public-to-tenant view of owner's offline payment instructions."""

    upi_id = serializers.CharField()
    account_holder_name = serializers.CharField()
    bank_name = serializers.CharField()
    account_number = serializers.CharField()
    ifsc_code = serializers.CharField()
    payment_notes = serializers.CharField()
    qr_code_url = serializers.CharField(allow_blank=True)
    razorpay_available = serializers.BooleanField()
    has_manual_details = serializers.BooleanField()


class RentShareSerializer(serializers.ModelSerializer):
    tenant_email = serializers.CharField(
        source="lease_tenant.tenant.email",
        read_only=True,
    )
    tenant_name = serializers.SerializerMethodField()
    rent_share_pct = serializers.DecimalField(
        source="lease_tenant.rent_share_pct",
        max_digits=5,
        decimal_places=2,
        read_only=True,
    )
    payment_method = serializers.SerializerMethodField()
    paid_at = serializers.SerializerMethodField()

    class Meta:
        model = RentShare
        fields = (
            "id",
            "lease_tenant",
            "tenant_email",
            "tenant_name",
            "rent_share_pct",
            "amount",
            "status",
            "payment_method",
            "paid_at",
        )
        read_only_fields = ("id", "amount", "status")

    def get_tenant_name(self, obj):
        t = obj.lease_tenant.tenant
        name = f"{t.first_name} {t.last_name}".strip()
        return name or t.email

    def get_payment_method(self, obj):
        payment = getattr(obj, "payment", None)
        return payment.method if payment else ""

    def get_paid_at(self, obj):
        payment = getattr(obj, "payment", None)
        return payment.paid_at if payment else None


class RentInvoiceSerializer(serializers.ModelSerializer):
    shares = RentShareSerializer(many=True, read_only=True)
    unit_number = serializers.CharField(
        source="lease.unit.unit_number",
        read_only=True,
    )

    class Meta:
        model = RentInvoice
        fields = (
            "id",
            "lease",
            "unit_number",
            "period_start",
            "period_end",
            "total_amount",
            "due_date",
            "status",
            "created_at",
            "shares",
        )
        read_only_fields = ("id", "created_at")


class MyRentShareSerializer(serializers.ModelSerializer):
    period_start = serializers.DateField(source="invoice.period_start", read_only=True)
    period_end = serializers.DateField(source="invoice.period_end", read_only=True)
    due_date = serializers.DateField(source="invoice.due_date", read_only=True)
    invoice_status = serializers.CharField(source="invoice.status", read_only=True)
    invoice_total = serializers.DecimalField(
        source="invoice.total_amount",
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )
    rent_share_pct = serializers.DecimalField(
        source="lease_tenant.rent_share_pct",
        max_digits=5,
        decimal_places=2,
        read_only=True,
    )
    unit_number = serializers.CharField(
        source="invoice.lease.unit.unit_number",
        read_only=True,
    )
    co_tenants_pending = serializers.SerializerMethodField()

    class Meta:
        model = RentShare
        fields = (
            "id",
            "amount",
            "status",
            "period_start",
            "period_end",
            "due_date",
            "invoice_status",
            "invoice_total",
            "rent_share_pct",
            "unit_number",
            "co_tenants_pending",
        )
        read_only_fields = fields

    def get_co_tenants_pending(self, obj):
        siblings = obj.invoice.shares.exclude(id=obj.id)
        pending = siblings.exclude(status=RentShare.ShareStatus.PAID).count()
        total_others = siblings.count()
        return {"pending": pending, "total_others": total_others}


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = (
            "id",
            "rent_share",
            "gateway_order_id",
            "gateway_payment_id",
            "amount",
            "method",
            "notes",
            "status",
            "paid_at",
            "created_at",
        )
        read_only_fields = ("id", "created_at")
