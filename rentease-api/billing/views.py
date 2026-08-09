from datetime import date
from dateutil.relativedelta import relativedelta

from django.db.models import Sum

from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.response import Response
from rest_framework import status

from accounts.permissions import IsOwner, IsTenant
from properties.models import Lease, LeaseTenant
from .models import RentInvoice, RentShare, Payment
from .serializers import (
    RentInvoiceSerializer,
    MyRentShareSerializer,
    PaymentSerializer,
)
from .utils import generate_invoice_for_lease, update_invoice_status


# ─── Owner views ──────────────────────────────────────────────────────────────

class OwnerInvoiceListView(ListAPIView):
    """List all invoices for a specific lease owned by the current owner."""
    permission_classes = [IsOwner]
    serializer_class = RentInvoiceSerializer

    def get_queryset(self):
        lease_id = self.kwargs["lease_id"]
        return RentInvoice.objects.filter(
            lease_id=lease_id,
            lease__unit__building__portfolio__owner=self.request.user,
        ).prefetch_related("shares__lease_tenant__tenant").order_by("-period_start")


class OwnerGenerateInvoiceView(APIView):
    """Manually trigger invoice generation for a lease (optional, for testing)."""
    permission_classes = [IsOwner]

    def post(self, request, lease_id):
        try:
            lease = Lease.objects.select_related(
                "unit__building__portfolio"
            ).get(
                id=lease_id,
                unit__building__portfolio__owner=request.user,
            )
        except Lease.DoesNotExist:
            return Response({"detail": "Lease not found."}, status=status.HTTP_404_NOT_FOUND)

        invoice, created = generate_invoice_for_lease(lease, date.today())
        serializer = RentInvoiceSerializer(invoice)
        return Response(
            {**serializer.data, "created": created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


# ─── Tenant views ─────────────────────────────────────────────────────────────

class MyRentShareListView(ListAPIView):
    """Tenant: list their own rent shares (current + history)."""
    permission_classes = [IsTenant]
    serializer_class = MyRentShareSerializer

    def get_queryset(self):
        return RentShare.objects.filter(
            lease_tenant__tenant=self.request.user,
        ).select_related(
            "invoice__lease__unit",
        ).order_by("-invoice__period_start")


class MyCurrentRentShareView(RetrieveAPIView):
    """Tenant: get the single active (pending/overdue) rent share."""
    permission_classes = [IsTenant]
    serializer_class = MyRentShareSerializer

    def get_object(self):
        return RentShare.objects.filter(
            lease_tenant__tenant=self.request.user,
            status__in=[RentShare.ShareStatus.PENDING, RentShare.ShareStatus.OVERDUE],
        ).select_related("invoice__lease__unit").order_by("-invoice__period_start").first()

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        if obj is None:
            return Response({"detail": "No pending invoice."}, status=status.HTTP_404_NOT_FOUND)
        return Response(self.get_serializer(obj).data)


class InitiatePaymentView(APIView):
    """
    Tenant: initiates a payment for a rent share.
    In production this would call Razorpay/Stripe to create an order.
    Here we simulate it by directly marking the share as paid.
    """
    permission_classes = [IsTenant]

    def post(self, request, share_id):
        try:
            rent_share = RentShare.objects.select_related("invoice").get(
                id=share_id,
                lease_tenant__tenant=request.user,
            )
        except RentShare.DoesNotExist:
            return Response({"detail": "Rent share not found."}, status=status.HTTP_404_NOT_FOUND)

        if rent_share.status == RentShare.ShareStatus.PAID:
            return Response({"detail": "Already paid."}, status=status.HTTP_400_BAD_REQUEST)

        gateway_payment_id = request.data.get("gateway_payment_id", f"manual_{share_id}")

        from django.utils import timezone

        payment = Payment.objects.create(
            rent_share=rent_share,
            gateway_payment_id=gateway_payment_id,
            amount=rent_share.amount,
            status=Payment.PaymentStatus.CAPTURED,
            paid_at=timezone.now(),
        )

        rent_share.status = RentShare.ShareStatus.PAID
        rent_share.save()

        update_invoice_status(rent_share.invoice)

        return Response(PaymentSerializer(payment).data, status=status.HTTP_201_CREATED)


# ─── Analytics ────────────────────────────────────────────────────────────────

class OwnerAnalyticsView(APIView):
    permission_classes = [IsOwner]

    def get(self, request):
        from issues.models import Issue

        owner = request.user
        today = date.today()

        active_leases = Lease.objects.filter(
            unit__building__portfolio__owner=owner,
            status=Lease.LeaseStatus.ACTIVE,
        )

        total_collected = Payment.objects.filter(
            rent_share__invoice__lease__unit__building__portfolio__owner=owner,
            status=Payment.PaymentStatus.CAPTURED,
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_pending = RentShare.objects.filter(
            invoice__lease__unit__building__portfolio__owner=owner,
            status=RentShare.ShareStatus.PENDING,
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_overdue = RentShare.objects.filter(
            invoice__lease__unit__building__portfolio__owner=owner,
            status=RentShare.ShareStatus.OVERDUE,
        ).aggregate(total=Sum("amount"))["total"] or 0

        issues = Issue.objects.filter(unit__building__portfolio__owner=owner)

        monthly_trend = []
        for i in range(5, -1, -1):
            month_start = (today - relativedelta(months=i)).replace(day=1)
            month_end = (month_start + relativedelta(months=1)) - relativedelta(days=1)
            collected = Payment.objects.filter(
                rent_share__invoice__lease__unit__building__portfolio__owner=owner,
                status=Payment.PaymentStatus.CAPTURED,
                paid_at__date__gte=month_start,
                paid_at__date__lte=month_end,
            ).aggregate(total=Sum("amount"))["total"] or 0

            monthly_trend.append({
                "month": month_start.strftime("%b %Y"),
                "collected": float(collected),
            })

        return Response({
            "summary": {
                "total_collected": float(total_collected),
                "total_pending": float(total_pending),
                "total_overdue": float(total_overdue),
                "active_leases": active_leases.count(),
                "total_issues": issues.count(),
                "open_issues": issues.filter(status="open").count(),
            },
            "monthly_trend": monthly_trend,
            "issue_breakdown": {
                "open": issues.filter(status="open").count(),
                "in_progress": issues.filter(status="in_progress").count(),
                "resolved": issues.filter(status="resolved").count(),
                "closed": issues.filter(status="closed").count(),
            },
        })
