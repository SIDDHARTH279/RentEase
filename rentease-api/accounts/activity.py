from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from billing.models import RentShare
from issues.models import Issue
from messaging.models import ChatMessage


class ActivityFeedView(APIView):
    """
    Lightweight in-app activity inbox built from existing data
    (overdue rent, open issues, unread chat) — no separate Notification table.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        items = []

        if user.role == User.Role.OWNER:
            overdue = (
                RentShare.objects.filter(
                    invoice__lease__unit__building__portfolio__owner=user,
                    status=RentShare.ShareStatus.OVERDUE,
                )
                .select_related(
                    "lease_tenant__tenant",
                    "invoice__lease__unit",
                )
                .order_by("-invoice__due_date")[:15]
            )
            for share in overdue:
                tenant = share.lease_tenant.tenant
                name = f"{tenant.first_name} {tenant.last_name}".strip() or tenant.email
                unit = share.invoice.lease.unit.unit_number
                items.append(
                    {
                        "id": f"overdue-{share.id}",
                        "type": "overdue_rent",
                        "title": f"Overdue rent · Unit {unit}",
                        "body": f"{name} — ₹{share.amount}",
                        "created_at": share.invoice.due_date.isoformat(),
                        "unread": True,
                    }
                )

            open_issues = (
                Issue.objects.filter(
                    unit__building__portfolio__owner=user,
                    status__in=["open", "in_progress"],
                )
                .select_related("unit", "reported_by")
                .order_by("-created_at")[:15]
            )
            for issue in open_issues:
                reporter = issue.reported_by
                who = (
                    f"{reporter.first_name} {reporter.last_name}".strip()
                    or reporter.email
                )
                items.append(
                    {
                        "id": f"issue-{issue.id}",
                        "type": "issue",
                        "title": f"Issue · Unit {issue.unit.unit_number}",
                        "body": f"{issue.title}" + (f" — {who}" if who else ""),
                        "created_at": issue.created_at.isoformat(),
                        "unread": issue.status == "open",
                    }
                )

            unread_msgs = (
                ChatMessage.objects.filter(
                    conversation__owner=user,
                    is_read=False,
                )
                .exclude(sender=user)
                .select_related("sender", "conversation__tenant")
                .order_by("-created_at")[:15]
            )
            for msg in unread_msgs:
                name = (
                    f"{msg.sender.first_name} {msg.sender.last_name}".strip()
                    or msg.sender.email
                )
                preview = msg.text or ("Photo" if msg.message_type == "image" else "")
                items.append(
                    {
                        "id": f"chat-{msg.id}",
                        "type": "chat",
                        "title": f"Message from {name}",
                        "body": preview[:120],
                        "created_at": msg.created_at.isoformat(),
                        "unread": True,
                        "conversation_id": msg.conversation_id,
                    }
                )
        else:
            pending = (
                RentShare.objects.filter(
                    lease_tenant__tenant=user,
                    status__in=[
                        RentShare.ShareStatus.PENDING,
                        RentShare.ShareStatus.OVERDUE,
                    ],
                )
                .select_related("invoice__lease__unit")
                .order_by("invoice__due_date")[:10]
            )
            for share in pending:
                unit = share.invoice.lease.unit.unit_number
                items.append(
                    {
                        "id": f"rent-{share.id}",
                        "type": "rent_due",
                        "title": (
                            "Rent overdue"
                            if share.status == RentShare.ShareStatus.OVERDUE
                            else "Rent due"
                        ),
                        "body": f"Unit {unit} — ₹{share.amount}",
                        "created_at": share.invoice.due_date.isoformat(),
                        "unread": True,
                    }
                )

            unread_msgs = (
                ChatMessage.objects.filter(
                    conversation__tenant=user,
                    is_read=False,
                )
                .exclude(sender=user)
                .select_related("sender")
                .order_by("-created_at")[:15]
            )
            for msg in unread_msgs:
                name = (
                    f"{msg.sender.first_name} {msg.sender.last_name}".strip()
                    or msg.sender.email
                )
                preview = msg.text or ("Photo" if msg.message_type == "image" else "")
                items.append(
                    {
                        "id": f"chat-{msg.id}",
                        "type": "chat",
                        "title": f"Message from {name}",
                        "body": preview[:120],
                        "created_at": msg.created_at.isoformat(),
                        "unread": True,
                        "conversation_id": msg.conversation_id,
                    }
                )

        def sort_key(item):
            return item.get("created_at") or ""

        items.sort(key=sort_key, reverse=True)
        return Response({"count": len(items), "results": items[:40]})
