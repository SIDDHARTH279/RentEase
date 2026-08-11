import json
from datetime import date

from dateutil.relativedelta import relativedelta
from django.conf import settings
from django.db.models import Sum
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from accounts.permissions import IsOwner, IsTenant
from properties.models import Lease, LeaseTenant
from .models import PaymentGatewayConfig, RentInvoice, RentShare, Payment
from .payments import mark_share_paid
from .razorpay_client import (
    RazorpayNotConfigured,
    create_order,
    verify_payment_signature,
    verify_webhook_signature,
)
from .serializers import (
    PaymentGatewayConfigSerializer,
    RentInvoiceSerializer,
    RentShareSerializer,
    MyRentShareSerializer,
    PaymentSerializer,
)
from .utils import generate_invoice_for_lease


def _owner_for_share(rent_share: RentShare):
    return rent_share.invoice.lease.unit.building.portfolio.owner


def _manual_payment_payload(config: PaymentGatewayConfig, request):
    qr_url = ""
    if config.qr_code:
        qr_url = request.build_absolute_uri(config.qr_code.url)
    return {
        "upi_id": config.upi_id,
        "account_holder_name": config.account_holder_name,
        "bank_name": config.bank_name,
        "account_number": config.account_number,
        "ifsc_code": config.ifsc_code,
        "payment_notes": config.payment_notes,
        "qr_code_url": qr_url,
        "razorpay_available": bool(
            config.is_configured and config.is_enabled
        ),
        "has_manual_details": bool(
            config.show_manual_details and config.has_manual_details
        ),
    }


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
        ).prefetch_related(
            "shares__lease_tenant__tenant",
            "shares__payment",
        ).order_by("-period_start")


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
            "lease_tenant",
        ).prefetch_related("invoice__shares").order_by("-invoice__period_start")


class MyCurrentRentShareView(RetrieveAPIView):
    """Tenant: get the single active (pending/overdue) rent share."""
    permission_classes = [IsTenant]
    serializer_class = MyRentShareSerializer

    def get_object(self):
        return RentShare.objects.filter(
            lease_tenant__tenant=self.request.user,
            status__in=[RentShare.ShareStatus.PENDING, RentShare.ShareStatus.OVERDUE],
        ).select_related(
            "invoice__lease__unit",
            "lease_tenant",
        ).prefetch_related("invoice__shares").order_by("-invoice__period_start").first()

    def retrieve(self, request, *args, **kwargs):
        obj = self.get_object()
        if obj is None:
            return Response({"detail": "No pending invoice."}, status=status.HTTP_404_NOT_FOUND)
        return Response(self.get_serializer(obj).data)


class OwnerPaymentSettingsView(APIView):
    """Owner: Razorpay keys and/or manual UPI/bank/QR payment details."""

    permission_classes = [IsOwner]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        config, _ = PaymentGatewayConfig.objects.get_or_create(owner=request.user)
        return Response(
            PaymentGatewayConfigSerializer(
                config, context={"request": request}
            ).data
        )

    def patch(self, request):
        config, _ = PaymentGatewayConfig.objects.get_or_create(owner=request.user)
        data = request.data.copy() if hasattr(request.data, "copy") else dict(request.data)

        # Normalize multipart boolean strings
        for bool_key in ("is_enabled", "show_manual_details", "clear_qr_code"):
            if bool_key in data:
                val = data.get(bool_key)
                if isinstance(val, str):
                    data[bool_key] = val.strip().lower() in ("1", "true", "yes", "on")

        qr_file = request.FILES.get("qr_code")
        serializer = PaymentGatewayConfigSerializer(
            config,
            data=data,
            partial=True,
            context={"request": request, "qr_file": qr_file},
        )
        serializer.is_valid(raise_exception=True)

        key_id = (serializer.validated_data.get("razorpay_key_id") or "").strip()
        secret = (serializer.validated_data.get("razorpay_key_secret") or "").strip()
        # Razorpay first-time setup needs both keys together (only when saving keys)
        setting_razorpay = bool(key_id or secret or "is_enabled" in serializer.validated_data)
        if setting_razorpay and not config.is_configured and (key_id or secret):
            if not (key_id and secret):
                return Response(
                    {
                        "detail": (
                            "Both razorpay_key_id and razorpay_key_secret "
                            "are required for first-time Razorpay setup."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        serializer.save()
        config.refresh_from_db()

        secret_submitted = bool(secret)
        if config.is_configured and config.is_enabled and secret_submitted:
            try:
                from .razorpay_client import get_razorpay_client

                client, _ = get_razorpay_client(owner=request.user)
                client.order.all({"count": 1})
            except Exception as exc:
                err = str(exc)
                if "Authentication failed" in err or "auth" in err.lower():
                    return Response(
                        {
                            "detail": (
                                "Keys saved, but Razorpay rejected them "
                                "(Authentication failed). Generate a fresh "
                                "Key ID + Secret pair in Razorpay Dashboard "
                                "and paste both again."
                            ),
                            "settings": PaymentGatewayConfigSerializer(
                                config, context={"request": request}
                            ).data,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

        return Response(
            PaymentGatewayConfigSerializer(
                config, context={"request": request}
            ).data
        )


class OwnerMarkSharePaidView(APIView):
    """Owner: mark a tenant rent share paid (cash / UPI / bank / other)."""

    permission_classes = [IsOwner]

    ALLOWED = {
        Payment.PaymentMethod.CASH,
        Payment.PaymentMethod.UPI,
        Payment.PaymentMethod.BANK_TRANSFER,
        Payment.PaymentMethod.OTHER,
    }

    def post(self, request, share_id):
        try:
            rent_share = RentShare.objects.select_related(
                "invoice__lease__unit__building__portfolio",
                "lease_tenant__tenant",
            ).get(
                id=share_id,
                invoice__lease__unit__building__portfolio__owner=request.user,
            )
        except RentShare.DoesNotExist:
            return Response(
                {"detail": "Rent share not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if rent_share.status == RentShare.ShareStatus.PAID:
            return Response(
                {"detail": "Already marked as paid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        method = (request.data.get("method") or Payment.PaymentMethod.CASH).strip()
        if method not in self.ALLOWED:
            return Response(
                {
                    "detail": (
                        "method must be one of: cash, upi, bank_transfer, other."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        notes = (request.data.get("notes") or "").strip()
        payment = mark_share_paid(
            rent_share=rent_share,
            method=method,
            notes=notes,
            notify_owner=False,
        )
        rent_share.refresh_from_db()
        # Re-fetch with payment for serializer fields
        rent_share = RentShare.objects.select_related(
            "lease_tenant__tenant", "payment"
        ).get(id=rent_share.id)

        return Response(
            {
                "share": RentShareSerializer(rent_share).data,
                "payment": PaymentSerializer(payment).data,
            }
        )


class TenantOwnerPaymentInfoView(APIView):
    """Tenant: owner's Razorpay availability + UPI/bank/QR for offline pay."""

    permission_classes = [IsTenant]

    def get(self, request):
        link = (
            LeaseTenant.objects.filter(
                tenant=request.user,
                lease__status=Lease.LeaseStatus.ACTIVE,
            )
            .select_related("lease__unit__building__portfolio__owner")
            .first()
        )
        if link is None:
            return Response(
                {"detail": "No active lease found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        owner = link.lease.unit.building.portfolio.owner
        config, _ = PaymentGatewayConfig.objects.get_or_create(owner=owner)
        payload = _manual_payment_payload(config, request)
        if not config.show_manual_details:
            payload.update(
                {
                    "upi_id": "",
                    "account_holder_name": "",
                    "bank_name": "",
                    "account_number": "",
                    "ifsc_code": "",
                    "payment_notes": "",
                    "qr_code_url": "",
                    "has_manual_details": False,
                }
            )
        return Response(payload)


class CreateRazorpayOrderView(APIView):
    """Tenant: create a Razorpay order for a rent share (does not mark paid)."""

    permission_classes = [IsTenant]

    def post(self, request, share_id):
        try:
            rent_share = RentShare.objects.select_related(
                "invoice__lease__unit__building__portfolio__owner",
                "lease_tenant__tenant",
            ).get(
                id=share_id,
                lease_tenant__tenant=request.user,
            )
        except RentShare.DoesNotExist:
            return Response(
                {"detail": "Rent share not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if rent_share.status == RentShare.ShareStatus.PAID:
            return Response(
                {"detail": "Already paid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        owner = _owner_for_share(rent_share)
        unit = rent_share.invoice.lease.unit.unit_number
        receipt = f"share_{rent_share.id}"
        try:
            order, key_id = create_order(
                amount_rupees=rent_share.amount,
                receipt=receipt,
                notes={
                    "rent_share_id": str(rent_share.id),
                    "invoice_id": str(rent_share.invoice_id),
                    "tenant_id": str(request.user.id),
                    "unit": str(unit),
                },
                owner=owner,
            )
        except RazorpayNotConfigured as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception as exc:
            err = str(exc)
            if "Authentication failed" in err or "auth" in err.lower():
                detail = (
                    "Razorpay authentication failed. Open owner menu → "
                    "Razorpay settings and paste the matching Key ID + "
                    "Key Secret from the same Razorpay mode (both Test or both Live)."
                )
            else:
                detail = f"Could not create Razorpay order: {err}"
            return Response(
                {"detail": detail},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        payment, _ = Payment.objects.get_or_create(
            rent_share=rent_share,
            defaults={
                "amount": rent_share.amount,
                "status": Payment.PaymentStatus.PENDING,
            },
        )
        if payment.status == Payment.PaymentStatus.CAPTURED:
            return Response(
                {"detail": "Already paid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        payment.gateway_order_id = order["id"]
        payment.amount = rent_share.amount
        payment.status = Payment.PaymentStatus.PENDING
        payment.save(
            update_fields=["gateway_order_id", "amount", "status"]
        )

        return Response(
            {
                "key_id": key_id,
                "order_id": order["id"],
                "amount": order["amount"],  # paise
                "currency": order.get("currency", "INR"),
                "rent_share_id": rent_share.id,
                "description": f"Rent — Unit {unit}",
                "prefill": {
                    "email": request.user.email,
                    "contact": request.user.phone or "",
                    "name": (
                        f"{request.user.first_name} {request.user.last_name}".strip()
                        or request.user.email
                    ),
                },
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyRazorpayPaymentView(APIView):
    """Tenant: verify checkout signature and mark share paid."""

    permission_classes = [IsTenant]

    def post(self, request):
        order_id = request.data.get("razorpay_order_id")
        payment_id = request.data.get("razorpay_payment_id")
        signature = request.data.get("razorpay_signature")
        share_id = request.data.get("rent_share_id")

        if not all([order_id, payment_id, signature, share_id]):
            return Response(
                {
                    "detail": (
                        "razorpay_order_id, razorpay_payment_id, "
                        "razorpay_signature, and rent_share_id are required."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            rent_share = RentShare.objects.select_related(
                "invoice__lease__unit__building__portfolio__owner"
            ).get(
                id=share_id,
                lease_tenant__tenant=request.user,
            )
        except RentShare.DoesNotExist:
            return Response(
                {"detail": "Rent share not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        payment = Payment.objects.filter(rent_share=rent_share).first()
        if payment and payment.gateway_order_id and payment.gateway_order_id != order_id:
            return Response(
                {"detail": "Order does not match this rent share."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        owner = _owner_for_share(rent_share)
        try:
            ok = verify_payment_signature(
                order_id=order_id,
                payment_id=payment_id,
                signature=signature,
                owner=owner,
            )
        except RazorpayNotConfigured as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        if not ok:
            return Response(
                {"detail": "Invalid payment signature."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        payment = mark_share_paid(
            rent_share=rent_share,
            order_id=order_id,
            payment_id=payment_id,
        )
        return Response(PaymentSerializer(payment).data, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name="dispatch")
class RazorpayWebhookView(APIView):
    """Razorpay webhook backup (payment.captured)."""

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        signature = request.META.get("HTTP_X_RAZORPAY_SIGNATURE", "")
        raw = request.body
        if settings.RAZORPAY_WEBHOOK_SECRET:
            if not verify_webhook_signature(raw, signature):
                return Response(
                    {"detail": "Invalid webhook signature."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return Response(
                {"detail": "Invalid JSON."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        event = payload.get("event")
        if event not in ("payment.captured", "order.paid"):
            return Response({"status": "ignored"})

        payment_entity = (
            payload.get("payload", {}).get("payment", {}).get("entity", {})
        )
        order_id = payment_entity.get("order_id")
        payment_id = payment_entity.get("id")
        if not order_id:
            return Response({"status": "ignored"})

        payment = Payment.objects.filter(gateway_order_id=order_id).select_related(
            "rent_share__invoice"
        ).first()
        if not payment:
            notes = payment_entity.get("notes") or {}
            share_id = notes.get("rent_share_id")
            if share_id:
                rent_share = RentShare.objects.filter(id=share_id).first()
                if rent_share:
                    mark_share_paid(
                        rent_share=rent_share,
                        order_id=order_id,
                        payment_id=payment_id or "",
                    )
            return Response({"status": "ok"})

        mark_share_paid(
            rent_share=payment.rent_share,
            order_id=order_id,
            payment_id=payment_id or "",
        )
        return Response({"status": "ok"})


# ─── Analytics ────────────────────────────────────────────────────────────────

class OwnerAnalyticsView(APIView):
    permission_classes = [IsOwner]

    def get(self, request):
        from issues.models import Issue

        owner = request.user
        today = date.today()

        from properties.models import Building, LeaseTenant

        active_leases = Lease.objects.filter(
            unit__building__portfolio__owner=owner,
            status=Lease.LeaseStatus.ACTIVE,
        )

        total_buildings = Building.objects.filter(portfolio__owner=owner).count()
        total_tenants = (
            LeaseTenant.objects.filter(
                lease__unit__building__portfolio__owner=owner,
                lease__status=Lease.LeaseStatus.ACTIVE,
            )
            .values("tenant_id")
            .distinct()
            .count()
        )

        owner_shares = RentShare.objects.filter(
            invoice__lease__unit__building__portfolio__owner=owner,
        )
        paid_shares = owner_shares.filter(status=RentShare.ShareStatus.PAID)
        pending_shares = owner_shares.filter(status=RentShare.ShareStatus.PENDING)
        overdue_shares = owner_shares.filter(status=RentShare.ShareStatus.OVERDUE)

        total_collected = Payment.objects.filter(
            rent_share__invoice__lease__unit__building__portfolio__owner=owner,
            status=Payment.PaymentStatus.CAPTURED,
        ).aggregate(total=Sum("amount"))["total"] or 0

        total_pending = pending_shares.aggregate(total=Sum("amount"))["total"] or 0
        total_overdue = overdue_shares.aggregate(total=Sum("amount"))["total"] or 0

        issues = Issue.objects.filter(unit__building__portfolio__owner=owner)

        from expenses.models import Expense

        expenses_qs = Expense.objects.filter(owner=owner)
        total_expenses = expenses_qs.aggregate(total=Sum("amount"))["total"] or 0
        month_start_now = today.replace(day=1)
        expenses_this_month = expenses_qs.filter(
            date__gte=month_start_now, date__lte=today
        ).aggregate(total=Sum("amount"))["total"] or 0

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
            spent = expenses_qs.filter(
                date__gte=month_start, date__lte=month_end
            ).aggregate(total=Sum("amount"))["total"] or 0

            monthly_trend.append({
                "month": month_start.strftime("%b %Y"),
                "collected": float(collected),
                "expenses": float(spent),
            })

        expense_by_category = {}
        for row in expenses_qs.values("category").annotate(total=Sum("amount")):
            expense_by_category[row["category"]] = float(row["total"] or 0)

        return Response({
            "summary": {
                "total_collected": float(total_collected),
                "total_pending": float(total_pending),
                "total_overdue": float(total_overdue),
                "total_expenses": float(total_expenses),
                "expenses_this_month": float(expenses_this_month),
                "net_income": float(total_collected) - float(total_expenses),
                "active_leases": active_leases.count(),
                "total_buildings": total_buildings,
                "total_tenants": total_tenants,
                "paid_shares_count": paid_shares.count(),
                "pending_shares_count": pending_shares.count(),
                "overdue_shares_count": overdue_shares.count(),
                "total_issues": issues.count(),
                "open_issues": issues.filter(status="open").count(),
            },
            "monthly_trend": monthly_trend,
            "payment_breakdown": {
                "paid": paid_shares.count(),
                "pending": pending_shares.count(),
                "overdue": overdue_shares.count(),
            },
            "expense_by_category": expense_by_category,
            "issue_breakdown": {
                "open": issues.filter(status="open").count(),
                "in_progress": issues.filter(status="in_progress").count(),
                "resolved": issues.filter(status="resolved").count(),
                "closed": issues.filter(status="closed").count(),
            },
        })
