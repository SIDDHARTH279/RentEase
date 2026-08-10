from celery import shared_task
from datetime import date

from properties.models import Lease
from .utils import generate_invoice_for_lease


@shared_task
def generate_monthly_invoices():
    """
    Daily task: generate invoices for all active leases.
    Skips leases that already have an invoice for the current period.
    """
    today = date.today()
    active_leases = Lease.objects.filter(
        status=Lease.LeaseStatus.ACTIVE
    ).select_related("unit__building__portfolio")

    created_count = 0
    skipped_count = 0

    for lease in active_leases:
        _, created = generate_invoice_for_lease(lease, today)
        if created:
            created_count += 1
        else:
            skipped_count += 1

    return f"Done: {created_count} created, {skipped_count} skipped."


@shared_task
def mark_overdue_invoices():
    """
    Daily task: mark pending invoices/shares as overdue and email tenants.
    """
    from .models import RentInvoice, RentShare
    from accounts.emails import send_overdue_reminder_email

    today = date.today()

    overdue_invoices = RentInvoice.objects.filter(
        status=RentInvoice.InvoiceStatus.PENDING,
        due_date__lt=today,
    )
    invoice_count = overdue_invoices.update(status=RentInvoice.InvoiceStatus.OVERDUE)

    overdue_shares = RentShare.objects.filter(
        status=RentShare.ShareStatus.PENDING,
        invoice__due_date__lt=today,
    ).select_related(
        'lease_tenant__tenant',
        'invoice__lease__unit',
    )

    share_count = 0
    for share in overdue_shares:
        share.status = RentShare.ShareStatus.OVERDUE
        share.save(update_fields=['status'])
        try:
            send_overdue_reminder_email(
                email=share.lease_tenant.tenant.email,
                amount=float(share.amount),
                due_date=str(share.invoice.due_date),
                unit_number=share.invoice.lease.unit.unit_number,
            )
        except Exception:
            pass
        share_count += 1

    return f"Overdue: {invoice_count} invoices, {share_count} shares."
