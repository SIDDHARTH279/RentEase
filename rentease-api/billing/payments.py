"""Shared helpers to mark rent shares paid after gateway confirmation."""

from django.db import transaction
from django.utils import timezone

from .models import Payment, RentShare
from .utils import update_invoice_status


@transaction.atomic
def mark_share_paid(
    *,
    rent_share: RentShare,
    order_id: str = "",
    payment_id: str = "",
    method: str = Payment.PaymentMethod.RAZORPAY,
    notes: str = "",
    notify_owner: bool = True,
) -> Payment:
    rent_share = RentShare.objects.select_for_update().select_related("invoice").get(
        id=rent_share.id
    )

    payment, _ = Payment.objects.select_for_update().get_or_create(
        rent_share=rent_share,
        defaults={
            "amount": rent_share.amount,
            "status": Payment.PaymentStatus.PENDING,
            "method": method or Payment.PaymentMethod.RAZORPAY,
        },
    )

    if (
        rent_share.status == RentShare.ShareStatus.PAID
        and payment.status == Payment.PaymentStatus.CAPTURED
    ):
        return payment

    if order_id:
        payment.gateway_order_id = order_id
    if payment_id:
        payment.gateway_payment_id = payment_id
    payment.amount = rent_share.amount
    payment.method = method or payment.method or Payment.PaymentMethod.RAZORPAY
    if notes:
        payment.notes = notes[:255]
    payment.status = Payment.PaymentStatus.CAPTURED
    payment.paid_at = timezone.now()
    payment.save()

    rent_share.status = RentShare.ShareStatus.PAID
    rent_share.save(update_fields=["status"])
    update_invoice_status(rent_share.invoice)

    try:
        from accounts.notifications import create_notification

        share = RentShare.objects.select_related(
            "lease_tenant__tenant",
            "invoice__lease__unit__building__portfolio__owner",
            "invoice__lease__unit",
        ).get(id=rent_share.id)
        tenant = share.lease_tenant.tenant
        owner = share.invoice.lease.unit.building.portfolio.owner
        unit = share.invoice.lease.unit.unit_number
        amount = share.amount
        method_label = dict(Payment.PaymentMethod.choices).get(
            payment.method, payment.method
        )
        create_notification(
            tenant,
            title="Payment recorded",
            body=f"₹{amount} marked paid ({method_label}) for unit {unit}.",
            type="payment_success",
            data={"type": "payment_success", "share_id": str(share.id)},
        )
        if notify_owner:
            create_notification(
                owner,
                title="Rent received",
                body=f"₹{amount} received for unit {unit} ({method_label}).",
                type="payment_success",
                data={"type": "payment_success", "share_id": str(share.id)},
            )
    except Exception:
        pass

    return payment
