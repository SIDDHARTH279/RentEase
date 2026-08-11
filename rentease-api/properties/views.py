from datetime import date

from rest_framework import generics
from rest_framework.response import Response
from rest_framework import status
from rest_framework.views import APIView

from accounts.permissions import IsOwner, IsTenant
from .models import Portfolio, Building, Unit, Lease, LeaseTenant
from .serializers import (
    PortfolioSerializer,
    BuildingSerializer,
    UnitSerializer,
    LeaseSerializer,
    LeaseTenantSerializer,
)


# ─── Portfolio ────────────────────────────────────────────────────────────────

class PortfolioListCreateView(generics.ListCreateAPIView):
    serializer_class = PortfolioSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Portfolio.objects.filter(owner=self.request.user).order_by("-created_at")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class PortfolioDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PortfolioSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Portfolio.objects.filter(owner=self.request.user)


# ─── Building ─────────────────────────────────────────────────────────────────

class BuildingListCreateView(generics.ListCreateAPIView):
    serializer_class = BuildingSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Building.objects.filter(
            portfolio__owner=self.request.user
        ).order_by("-created_at")


class BuildingDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BuildingSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Building.objects.filter(portfolio__owner=self.request.user)


# ─── Unit ─────────────────────────────────────────────────────────────────────

class UnitListCreateView(generics.ListCreateAPIView):
    serializer_class = UnitSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        qs = Unit.objects.filter(
            building__portfolio__owner=self.request.user
        ).order_by("-created_at")
        building_id = self.request.query_params.get("building_id")
        if building_id:
            qs = qs.filter(building_id=building_id)
        return qs


class UnitDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UnitSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Unit.objects.filter(building__portfolio__owner=self.request.user)


# ─── Lease ────────────────────────────────────────────────────────────────────

class LeaseListCreateView(generics.ListCreateAPIView):
    serializer_class = LeaseSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Lease.objects.filter(
            unit__building__portfolio__owner=self.request.user
        ).order_by("-created_at")


class LeaseDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = LeaseSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Lease.objects.filter(
            unit__building__portfolio__owner=self.request.user
        )


class EndLeaseView(APIView):
    """Owner ends a tenancy: lease → ended, unit → vacant if no other active lease."""

    permission_classes = [IsOwner]

    def _get_lease(self, request, pk):
        try:
            return Lease.objects.select_related("unit").get(
                id=pk,
                unit__building__portfolio__owner=request.user,
            )
        except Lease.DoesNotExist:
            return None

    def _unpaid_summary(self, lease):
        from django.db.models import Sum

        from billing.models import RentShare

        unpaid = RentShare.objects.filter(
            invoice__lease=lease,
            status__in=[
                RentShare.ShareStatus.PENDING,
                RentShare.ShareStatus.OVERDUE,
            ],
        )
        pending = unpaid.filter(status=RentShare.ShareStatus.PENDING).aggregate(
            total=Sum("amount")
        )["total"] or 0
        overdue = unpaid.filter(status=RentShare.ShareStatus.OVERDUE).aggregate(
            total=Sum("amount")
        )["total"] or 0
        return {
            "pending_amount": float(pending),
            "overdue_amount": float(overdue),
            "unpaid_amount": float(pending) + float(overdue),
            "unpaid_count": unpaid.count(),
            "has_unpaid": unpaid.exists(),
        }

    def _clear_unpaid_rent(self, lease):
        """Remove pending/overdue shares so they leave analytics; keep paid history."""
        from billing.models import Payment, RentInvoice, RentShare
        from billing.utils import update_invoice_status

        unpaid_shares = RentShare.objects.filter(
            invoice__lease=lease,
            status__in=[
                RentShare.ShareStatus.PENDING,
                RentShare.ShareStatus.OVERDUE,
            ],
        )
        invoice_ids = list(unpaid_shares.values_list("invoice_id", flat=True).distinct())
        Payment.objects.filter(
            rent_share__in=unpaid_shares,
            status=Payment.PaymentStatus.PENDING,
        ).delete()
        deleted = unpaid_shares.delete()[0]

        for invoice in RentInvoice.objects.filter(id__in=invoice_ids):
            remaining = invoice.shares.all()
            if not remaining.exists():
                invoice.status = RentInvoice.InvoiceStatus.CANCELLED
                invoice.save(update_fields=["status"])
            else:
                update_invoice_status(invoice)
                # If still pending/overdue but no unpaid shares left, mark paid
                if invoice.status in (
                    RentInvoice.InvoiceStatus.PENDING,
                    RentInvoice.InvoiceStatus.OVERDUE,
                ) and not remaining.exclude(
                    status=RentShare.ShareStatus.PAID
                ).exists():
                    invoice.status = RentInvoice.InvoiceStatus.PAID
                    invoice.save(update_fields=["status"])
        return deleted

    def get(self, request, pk):
        lease = self._get_lease(request, pk)
        if not lease:
            return Response(
                {"detail": "Lease not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        summary = self._unpaid_summary(lease)
        summary.update(
            {
                "lease_id": lease.id,
                "unit_number": lease.unit.unit_number,
                "status": lease.status,
            }
        )
        return Response(summary)

    def post(self, request, pk):
        lease = self._get_lease(request, pk)
        if not lease:
            return Response(
                {"detail": "Lease not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if lease.status == Lease.LeaseStatus.ENDED:
            return Response(
                {"detail": "This lease is already ended."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        unpaid = self._unpaid_summary(lease)
        clear_pending = request.data.get("clear_pending") is True
        if unpaid["has_unpaid"] and not clear_pending:
            return Response(
                {
                    "detail": (
                        "This lease still has unpaid rent. "
                        "Confirm with clear_pending=true to end tenancy "
                        "and remove pending rent from analytics."
                    ),
                    **unpaid,
                },
                status=status.HTTP_409_CONFLICT,
            )

        end_date_raw = request.data.get("end_date")
        if end_date_raw:
            try:
                ended_on = date.fromisoformat(str(end_date_raw))
            except ValueError:
                return Response(
                    {"detail": "end_date must be YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        else:
            ended_on = date.today()

        cleared = 0
        if clear_pending and unpaid["has_unpaid"]:
            cleared = self._clear_unpaid_rent(lease)

        lease.status = Lease.LeaseStatus.ENDED
        lease.end_date = ended_on
        lease.save(update_fields=["status", "end_date"])

        unit = lease.unit
        has_other_active = Lease.objects.filter(
            unit=unit,
            status=Lease.LeaseStatus.ACTIVE,
        ).exclude(id=lease.id).exists()
        if not has_other_active and not unit.is_vacant:
            unit.is_vacant = True
            unit.save(update_fields=["is_vacant"])

        # Expire unused invites for this lease
        from django.utils import timezone
        from accounts.models import TenantInvite

        TenantInvite.objects.filter(
            lease=lease, is_accepted=False
        ).update(expires_at=timezone.now())

        # Notify linked tenants
        try:
            from accounts.notifications import create_notification

            for link in LeaseTenant.objects.filter(lease=lease).select_related(
                "tenant"
            ):
                create_notification(
                    link.tenant,
                    title="Tenancy ended",
                    body=(
                        f"Your lease for unit {unit.unit_number} "
                        f"ended on {ended_on}."
                    ),
                    type="general",
                    data={
                        "type": "general",
                        "lease_id": str(lease.id),
                        "unit_id": str(unit.id),
                    },
                )
        except Exception:
            pass

        data = LeaseSerializer(lease).data
        data["cleared_unpaid_shares"] = cleared
        data["unpaid_cleared_amount"] = unpaid["unpaid_amount"] if clear_pending else 0
        return Response(data)


# ─── LeaseTenant ──────────────────────────────────────────────────────────────

class LeaseTenantListCreateView(generics.ListCreateAPIView):
    serializer_class = LeaseTenantSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return LeaseTenant.objects.filter(
            lease__unit__building__portfolio__owner=self.request.user
        )


class LeaseTenantDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = LeaseTenantSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return LeaseTenant.objects.filter(
            lease__unit__building__portfolio__owner=self.request.user
        )


# ─── Tenant-only views ────────────────────────────────────────────────────────

class MyLeaseView(generics.GenericAPIView):
    permission_classes = [IsTenant]
    serializer_class = LeaseSerializer

    def get(self, request):
        lease_tenant = LeaseTenant.objects.filter(
            tenant=request.user,
            lease__status=Lease.LeaseStatus.ACTIVE,
        ).select_related("lease").first()

        if not lease_tenant:
            return Response(
                {"detail": "No active lease found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = self.get_serializer(lease_tenant.lease)
        return Response(serializer.data)


class MyUnitView(generics.GenericAPIView):
    permission_classes = [IsTenant]
    serializer_class = UnitSerializer

    def get(self, request):
        lease_tenant = LeaseTenant.objects.filter(
            tenant=request.user,
            lease__status=Lease.LeaseStatus.ACTIVE,
        ).select_related("lease__unit").first()

        if not lease_tenant:
            return Response(
                {"detail": "No active lease found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = self.get_serializer(lease_tenant.lease.unit)
        return Response(serializer.data)