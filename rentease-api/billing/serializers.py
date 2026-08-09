from rest_framework import serializers
from .models import RentInvoice, RentShare, Payment


class RentShareSerializer(serializers.ModelSerializer):
    tenant_email = serializers.CharField(
        source="lease_tenant.tenant.email",
        read_only=True,
    )

    class Meta:
        model = RentShare
        fields = ("id", "lease_tenant", "tenant_email", "amount", "status")
        read_only_fields = ("id", "amount", "status")


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
    unit_number = serializers.CharField(
        source="invoice.lease.unit.unit_number",
        read_only=True,
    )

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
            "unit_number",
        )
        read_only_fields = fields


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = (
            "id",
            "rent_share",
            "gateway_payment_id",
            "amount",
            "status",
            "paid_at",
            "created_at",
        )
        read_only_fields = ("id", "created_at")
