from django.contrib import admin
from .models import PaymentGatewayConfig, RentInvoice, RentShare, Payment


@admin.register(PaymentGatewayConfig)
class PaymentGatewayConfigAdmin(admin.ModelAdmin):
    list_display = (
        "owner",
        "razorpay_key_id",
        "is_enabled",
        "upi_id",
        "show_manual_details",
        "updated_at",
    )
    search_fields = ("owner__email", "razorpay_key_id", "upi_id")
    readonly_fields = ("razorpay_key_secret_encrypted", "created_at", "updated_at")


class RentShareInline(admin.TabularInline):
    model = RentShare
    extra = 0
    readonly_fields = ("amount", "status")


@admin.register(RentInvoice)
class RentInvoiceAdmin(admin.ModelAdmin):
    list_display = ("lease", "period_start", "period_end", "total_amount", "status", "due_date")
    list_filter = ("status",)
    search_fields = ("lease__unit__unit_number",)
    inlines = [RentShareInline]


@admin.register(RentShare)
class RentShareAdmin(admin.ModelAdmin):
    list_display = ("invoice", "lease_tenant", "amount", "status")
    list_filter = ("status",)


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = (
        "rent_share",
        "amount",
        "method",
        "status",
        "paid_at",
        "gateway_order_id",
        "gateway_payment_id",
    )
    list_filter = ("status", "method")
    search_fields = ("gateway_order_id", "gateway_payment_id")
