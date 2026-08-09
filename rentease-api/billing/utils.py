from datetime import date
from dateutil.relativedelta import relativedelta
from decimal import Decimal, ROUND_HALF_UP

from properties.models import Lease, LeaseTenant
from .models import RentInvoice, RentShare


def get_period_dates(lease: Lease, reference_date: date):
    """Return (period_start, period_end, due_date) for a given month."""
    period_start = reference_date.replace(day=1)
    period_end = (period_start + relativedelta(months=1)) - relativedelta(days=1)
    due_date = reference_date.replace(day=lease.due_day)
    if due_date < reference_date:
        due_date = (due_date + relativedelta(months=1))
    return period_start, period_end, due_date


def generate_invoice_for_lease(lease: Lease, reference_date: date = None):
    """
    Generate a RentInvoice + RentShare rows for a lease.
    Skips if invoice already exists for the period.
    Returns (invoice, created) tuple.
    """
    if reference_date is None:
        reference_date = date.today()

    period_start, period_end, due_date = get_period_dates(lease, reference_date)

    invoice, created = RentInvoice.objects.get_or_create(
        lease=lease,
        period_start=period_start,
        defaults={
            "period_end": period_end,
            "total_amount": lease.monthly_rent,
            "due_date": due_date,
            "status": RentInvoice.InvoiceStatus.PENDING,
        },
    )

    if not created:
        return invoice, False

    tenants = LeaseTenant.objects.filter(lease=lease)

    for lease_tenant in tenants:
        share_amount = (
            Decimal(str(lease.monthly_rent))
            * (Decimal(str(lease_tenant.rent_share_pct)) / Decimal("100"))
        ).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

        RentShare.objects.get_or_create(
            invoice=invoice,
            lease_tenant=lease_tenant,
            defaults={
                "amount": share_amount,
                "status": RentShare.ShareStatus.PENDING,
            },
        )

        # Notify tenant
        try:
            from accounts.notifications import send_notification
            send_notification(
                user=lease_tenant.tenant,
                title="Rent Due",
                body=f"Your rent of \u20b9{share_amount} is due on {invoice.due_date}.",
                data={"type": "invoice", "invoice_id": str(invoice.id)},
            )
        except Exception:
            pass

    return invoice, True


def update_invoice_status(invoice: RentInvoice):
    """
    Check all RentShare statuses and update invoice status.
    Called after a payment is confirmed.
    """
    shares = invoice.shares.all()
    if not shares.exists():
        return

    if all(s.status == RentShare.ShareStatus.PAID for s in shares):
        invoice.status = RentInvoice.InvoiceStatus.PAID
        invoice.save()
