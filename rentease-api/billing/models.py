from django.conf import settings
from django.db import models


class PaymentGatewayConfig(models.Model):
    """Owner payment setup: Razorpay and/or manual (QR / bank / UPI)."""

    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="payment_gateway",
    )
    razorpay_key_id = models.CharField(max_length=100, blank=True, default="")
    razorpay_key_secret_encrypted = models.TextField(blank=True, default="")
    is_enabled = models.BooleanField(default=True)

    # Manual / offline collection (for owners without Razorpay)
    upi_id = models.CharField(max_length=100, blank=True, default="")
    account_holder_name = models.CharField(max_length=150, blank=True, default="")
    bank_name = models.CharField(max_length=100, blank=True, default="")
    account_number = models.CharField(max_length=40, blank=True, default="")
    ifsc_code = models.CharField(max_length=20, blank=True, default="")
    qr_code = models.ImageField(upload_to="payment_qr/", blank=True, null=True)
    payment_notes = models.CharField(max_length=300, blank=True, default="")
    show_manual_details = models.BooleanField(
        default=True,
        help_text="If true, tenants can see UPI/bank/QR for offline payment.",
    )

    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Payment config · {self.owner.email}"

    @property
    def is_configured(self) -> bool:
        return bool(self.razorpay_key_id and self.razorpay_key_secret_encrypted)

    @property
    def has_manual_details(self) -> bool:
        return bool(
            self.upi_id
            or self.account_number
            or self.qr_code
            or self.ifsc_code
        )


class RentInvoice(models.Model):

    class InvoiceStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"
        OVERDUE = "overdue", "Overdue"
        CANCELLED = "cancelled", "Cancelled"

    lease = models.ForeignKey(
        "properties.Lease",
        on_delete=models.CASCADE,
        related_name="invoices",
    )
    period_start = models.DateField()
    period_end = models.DateField()
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    due_date = models.DateField()
    status = models.CharField(
        max_length=10,
        choices=InvoiceStatus.choices,
        default=InvoiceStatus.PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["lease", "period_start"],
                name="unique_invoice_per_lease_per_period",
            )
        ]

    def __str__(self):
        return f"Invoice {self.lease} - {self.period_start}"


class RentShare(models.Model):

    class ShareStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"
        OVERDUE = "overdue", "Overdue"

    invoice = models.ForeignKey(
        RentInvoice,
        on_delete=models.CASCADE,
        related_name="shares",
    )
    lease_tenant = models.ForeignKey(
        "properties.LeaseTenant",
        on_delete=models.CASCADE,
        related_name="shares",
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(
        max_length=10,
        choices=ShareStatus.choices,
        default=ShareStatus.PENDING,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["invoice", "lease_tenant"],
                name="unique_share_per_invoice_per_tenant",
            )
        ]

    def __str__(self):
        return f"Share {self.lease_tenant} - {self.invoice}"


class Payment(models.Model):

    class PaymentStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        CAPTURED = "captured", "Captured"
        FAILED = "failed", "Failed"
        REFUNDED = "refunded", "Refunded"

    class PaymentMethod(models.TextChoices):
        RAZORPAY = "razorpay", "Razorpay"
        CASH = "cash", "Cash"
        UPI = "upi", "UPI / QR"
        BANK_TRANSFER = "bank_transfer", "Bank transfer"
        OTHER = "other", "Other"

    rent_share = models.OneToOneField(
        RentShare,
        on_delete=models.CASCADE,
        related_name="payment",
    )
    gateway_order_id = models.CharField(max_length=200, blank=True, db_index=True)
    gateway_payment_id = models.CharField(max_length=200, blank=True, db_index=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    method = models.CharField(
        max_length=20,
        choices=PaymentMethod.choices,
        default=PaymentMethod.RAZORPAY,
        blank=True,
    )
    notes = models.CharField(max_length=255, blank=True, default="")
    status = models.CharField(
        max_length=10,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Payment {self.rent_share} - {self.status}"
