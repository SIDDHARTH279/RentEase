import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.db.models import Q

from .models import Conversation, ChatMessage
from .serializers import ChatMessageSerializer


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get("user")
        self.conversation_id = self.scope["url_route"]["kwargs"]["conversation_id"]
        self.room_group = f"chat_{self.conversation_id}"

        if self.user is None or self.user.is_anonymous:
            await self.close()
            return

        allowed = await self._user_in_conversation()
        if not allowed:
            await self.close()
            return

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room_group"):
            await self.channel_layer.group_discard(self.room_group, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            return

        text = (data.get("text") or "").strip()
        if not text:
            return

        reply_to_id = data.get("reply_to")
        message = await self._save_message(text, reply_to_id)
        if message is None:
            return

        await self.channel_layer.group_send(
            self.room_group,
            {
                "type": "chat.message",
                "message": message,
            },
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps(event["message"]))

    async def chat_read(self, event):
        await self.send(
            text_data=json.dumps(
                {
                    "event": "read",
                    "reader_id": event["reader_id"],
                    "message_ids": event["message_ids"],
                }
            )
        )

    @database_sync_to_async
    def _user_in_conversation(self):
        return Conversation.objects.filter(
            Q(id=self.conversation_id)
            & (Q(owner=self.user) | Q(tenant=self.user))
        ).exists()

    @database_sync_to_async
    def _save_message(self, text, reply_to_id=None):
        try:
            conv = Conversation.objects.get(
                Q(id=self.conversation_id)
                & (Q(owner=self.user) | Q(tenant=self.user))
            )
        except Conversation.DoesNotExist:
            return None

        reply_to = None
        if reply_to_id is not None:
            try:
                reply_to = ChatMessage.objects.select_related("sender").get(
                    id=int(reply_to_id), conversation=conv
                )
            except (ChatMessage.DoesNotExist, ValueError, TypeError):
                return None

        msg = ChatMessage.objects.create(
            conversation=conv,
            sender=self.user,
            message_type=ChatMessage.MessageType.TEXT,
            text=text,
            reply_to=reply_to,
        )
        conv.save(update_fields=["updated_at"])
        from .notify import notify_peer_of_message

        notify_peer_of_message(conv, self.user, msg)
        msg = ChatMessage.objects.select_related(
            "sender", "reply_to", "reply_to__sender"
        ).get(id=msg.id)
        return ChatMessageSerializer(msg).data
