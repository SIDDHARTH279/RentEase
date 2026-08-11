from celery import shared_task
from datetime import date, timedelta

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
    from accounts.notifications import create_notification

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
        "lease_tenant__tenant",
        "invoice__lease__unit",
        "invoice__lease__unit__building__portfolio__owner",
    )

    share_count = 0
    for share in overdue_shares:
        share.status = RentShare.ShareStatus.OVERDUE
        share.save(update_fields=["status"])
        unit_number = share.invoice.lease.unit.unit_number
        try:
            send_overdue_reminder_email(
                email=share.lease_tenant.tenant.email,
                amount=float(share.amount),
                due_date=str(share.invoice.due_date),
                unit_number=unit_number,
            )
        except Exception:
            pass
        try:
            create_notification(
                share.lease_tenant.tenant,
                title="Rent overdue",
                body=f"₹{share.amount} for unit {unit_number} was due on {share.invoice.due_date}.",
                type="rent_overdue",
                data={
                    "type": "rent_overdue",
                    "invoice_id": str(share.invoice_id),
                    "share_id": str(share.id),
                },
            )
            owner = share.invoice.lease.unit.building.portfolio.owner
            create_notification(
                owner,
                title="Overdue rent",
                body=f"Unit {unit_number}: ₹{share.amount} overdue.",
                type="rent_overdue",
                data={
                    "type": "rent_overdue",
                    "invoice_id": str(share.invoice_id),
                    "share_id": str(share.id),
                },
            )
        except Exception:
            pass
        share_count += 1

    return f"Overdue: {invoice_count} invoices, {share_count} shares."


@shared_task
def send_rent_due_reminders():
    """
    Daily task: remind tenants (and owners) about rent due today or tomorrow.
    """
    from .models import RentShare
    from accounts.notifications import create_notification

    today = date.today()
    tomorrow = today + timedelta(days=1)
    shares = RentShare.objects.filter(
        status=RentShare.ShareStatus.PENDING,
        invoice__due_date__in=[today, tomorrow],
    ).select_related(
        "lease_tenant__tenant",
        "invoice__lease__unit",
        "invoice__lease__unit__building__portfolio__owner",
    )

    count = 0
    for share in shares:
        due = share.invoice.due_date
        unit = share.invoice.lease.unit.unit_number
        when = "today" if due == today else "tomorrow"
        try:
            create_notification(
                share.lease_tenant.tenant,
                title=f"Rent due {when}",
                body=f"₹{share.amount} for unit {unit} is due {when} ({due}).",
                type="rent_due",
                data={
                    "type": "rent_due",
                    "invoice_id": str(share.invoice_id),
                    "share_id": str(share.id),
                },
            )
            owner = share.invoice.lease.unit.building.portfolio.owner
            create_notification(
                owner,
                title=f"Rent due {when}",
                body=f"Unit {unit}: ₹{share.amount} due {when}.",
                type="rent_due",
                data={
                    "type": "rent_due",
                    "invoice_id": str(share.invoice_id),
                    "share_id": str(share.id),
                },
            )
            count += 1
        except Exception:
            pass

    return f"Reminders sent for {count} shares."


@shared_task
def send_lease_renewal_reminders():
    """
    Daily task: notify owner + tenants 30 and 7 days before lease end_date.
    """
    from accounts.notifications import create_notification

    today = date.today()
    targets = {today + timedelta(days=7), today + timedelta(days=30)}
    leases = Lease.objects.filter(
        status=Lease.LeaseStatus.ACTIVE,
        end_date__in=targets,
    ).select_related("unit__building__portfolio__owner").prefetch_related(
        "tenants__tenant"
    )

    count = 0
    for lease in leases:
        days_left = (lease.end_date - today).days
        unit = lease.unit.unit_number
        body = f"Lease for unit {unit} ends in {days_left} days ({lease.end_date})."
        try:
            create_notification(
                lease.unit.building.portfolio.owner,
                title="Lease renewal reminder",
                body=body,
                type="lease_renewal",
                data={"type": "lease_renewal", "lease_id": str(lease.id)},
            )
            for lt in lease.tenants.all():
                create_notification(
                    lt.tenant,
                    title="Lease renewal reminder",
                    body=body,
                    type="lease_renewal",
                    data={"type": "lease_renewal", "lease_id": str(lease.id)},
                )
            count += 1
        except Exception:
            pass

    return f"Lease renewal reminders for {count} leases."
