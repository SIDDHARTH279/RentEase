from django.db import models


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

    rent_share = models.OneToOneField(
        RentShare,
        on_delete=models.CASCADE,
        related_name="payment",
    )
    gateway_payment_id = models.CharField(max_length=200, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(
        max_length=10,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Payment {self.rent_share} - {self.status}"
