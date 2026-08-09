from django.contrib import admin
from .models import RentInvoice, RentShare, Payment


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
    list_display = ("rent_share", "amount", "status", "paid_at", "gateway_payment_id")
    list_filter = ("status",)
