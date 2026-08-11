from django.db.models import Q
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from accounts.permissions import IsOwner
from properties.models import LeaseTenant

from .broadcast import broadcast_chat_message, broadcast_messages_read
from .models import Conversation, ChatMessage
from .serializers import ConversationSerializer, ChatMessageSerializer


class ConversationListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == User.Role.OWNER:
            qs = Conversation.objects.filter(owner=user).select_related(
                "owner", "tenant"
            )
        else:
            qs = Conversation.objects.filter(tenant=user).select_related(
                "owner", "tenant"
            )
        data = ConversationSerializer(qs, many=True, context={"request": request}).data
        return Response(data)

    def post(self, request):
        """
        Create or get a conversation.
        Owner body: { "tenant_id": <id> }
        Tenant: no body needed — finds their owner from lease.
        """
        user = request.user

        if user.role == User.Role.OWNER:
            tenant_id = request.data.get("tenant_id")
            if not tenant_id:
                return Response(
                    {"detail": "tenant_id is required."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                tenant = User.objects.get(id=tenant_id, role=User.Role.TENANT)
            except User.DoesNotExist:
                return Response(
                    {"detail": "Tenant not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            linked = LeaseTenant.objects.filter(
                tenant=tenant,
                lease__unit__building__portfolio__owner=user,
            ).exists()
            if not linked:
                return Response(
                    {"detail": "This tenant is not linked to your leases."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            conv, _ = Conversation.objects.get_or_create(owner=user, tenant=tenant)
        else:
            link = (
                LeaseTenant.objects.filter(tenant=user)
                .select_related("lease__unit__building__portfolio__owner")
                .first()
            )
            if not link:
                return Response(
                    {"detail": "No lease found for this tenant."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            owner = link.lease.unit.building.portfolio.owner
            conv, _ = Conversation.objects.get_or_create(owner=owner, tenant=user)

        return Response(
            ConversationSerializer(conv, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class OwnerTenantContactsView(APIView):
    """List tenants the owner can chat with (from leases)."""

    permission_classes = [IsOwner]

    def get(self, request):
        links = (
            LeaseTenant.objects.filter(
                lease__unit__building__portfolio__owner=request.user,
                lease__status="active",
            )
            .select_related(
                "tenant",
                "lease__unit__building",
            )
            .order_by("lease__unit__building__name", "lease__unit__unit_number")
        )
        by_tenant = {}
        for link in links:
            t = link.tenant
            unit = link.lease.unit
            building = unit.building
            entry = by_tenant.get(t.id)
            unit_info = {
                "unit_number": unit.unit_number,
                "building_name": building.name,
                "label": f"{unit.unit_number} · {building.name}",
            }
            if entry is None:
                name = f"{t.first_name} {t.last_name}".strip() or t.email
                by_tenant[t.id] = {
                    "id": t.id,
                    "email": t.email,
                    "name": name,
                    "phone": t.phone,
                    "units": [unit_info],
                }
            else:
                labels = {u["label"] for u in entry["units"]}
                if unit_info["label"] not in labels:
                    entry["units"].append(unit_info)

        contacts = []
        for entry in by_tenant.values():
            units = entry["units"]
            primary = units[0]
            entry["unit_number"] = primary["unit_number"]
            entry["building_name"] = primary["building_name"]
            entry["unit_label"] = (
                primary["label"]
                if len(units) == 1
                else ", ".join(u["label"] for u in units)
            )
            contacts.append(entry)

        contacts.sort(
            key=lambda c: (
                (c.get("building_name") or "").lower(),
                (c.get("unit_number") or "").lower(),
                (c.get("name") or "").lower(),
            )
        )
        return Response(contacts)


class MessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def _get_conversation(self, request, conversation_id):
        user = request.user
        try:
            return Conversation.objects.get(
                Q(id=conversation_id) & (Q(owner=user) | Q(tenant=user))
            )
        except Conversation.DoesNotExist:
            return None

    def get(self, request, conversation_id):
        conv = self._get_conversation(request, conversation_id)
        if not conv:
            return Response(
                {"detail": "Conversation not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        unread_ids = list(
            conv.messages.filter(is_read=False)
            .exclude(sender=request.user)
            .values_list("id", flat=True)
        )
        if unread_ids:
            conv.messages.filter(id__in=unread_ids).update(is_read=True)
            broadcast_messages_read(conv.id, request.user.id, unread_ids)

        messages = conv.messages.select_related(
            "sender", "reply_to", "reply_to__sender"
        ).all()

        q = (request.query_params.get("q") or "").strip()
        if q:
            messages = messages.filter(text__icontains=q)

        return Response(
            ChatMessageSerializer(
                messages, many=True, context={"request": request}
            ).data
        )

    def post(self, request, conversation_id):
        conv = self._get_conversation(request, conversation_id)
        if not conv:
            return Response(
                {"detail": "Conversation not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        text = (request.data.get("text") or "").strip()
        image = request.FILES.get("image")
        reply_to_id = request.data.get("reply_to")

        if not text and not image:
            return Response(
                {"detail": "text or image is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reply_to = None
        if reply_to_id not in (None, ""):
            try:
                reply_to = ChatMessage.objects.get(
                    id=int(reply_to_id), conversation=conv
                )
            except (ChatMessage.DoesNotExist, ValueError, TypeError):
                return Response(
                    {"detail": "reply_to message not found."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        msg = ChatMessage.objects.create(
            conversation=conv,
            sender=request.user,
            message_type=(
                ChatMessage.MessageType.IMAGE
                if image
                else ChatMessage.MessageType.TEXT
            ),
            text=text,
            image=image,
            reply_to=reply_to,
        )
        conv.save(update_fields=["updated_at"])

        from .notify import notify_peer_of_message

        notify_peer_of_message(conv, request.user, msg)

        data = ChatMessageSerializer(msg, context={"request": request}).data
        broadcast_chat_message(conv.id, data)
        return Response(data, status=status.HTTP_201_CREATED)
