from rest_framework import serializers

from .models import Conversation, ChatMessage


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_email = serializers.EmailField(source="sender.email", read_only=True)
    sender_name = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    reply_preview = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = (
            "id",
            "conversation",
            "sender",
            "sender_email",
            "sender_name",
            "message_type",
            "text",
            "image",
            "reply_to",
            "reply_preview",
            "is_read",
            "created_at",
        )
        read_only_fields = (
            "id",
            "sender",
            "is_read",
            "created_at",
            "conversation",
            "message_type",
            "image",
            "reply_preview",
        )

    def get_sender_name(self, obj):
        name = f"{obj.sender.first_name} {obj.sender.last_name}".strip()
        return name or obj.sender.email

    def get_image(self, obj):
        if not obj.image:
            return None
        request = self.context.get("request")
        url = obj.image.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    def get_reply_preview(self, obj):
        reply = obj.reply_to
        if reply is None:
            return None
        name = f"{reply.sender.first_name} {reply.sender.last_name}".strip()
        return {
            "id": reply.id,
            "text": reply.text or ("Photo" if reply.message_type == ChatMessage.MessageType.IMAGE else ""),
            "sender_name": name or reply.sender.email,
            "message_type": reply.message_type,
        }


class ConversationSerializer(serializers.ModelSerializer):
    owner_email = serializers.EmailField(source="owner.email", read_only=True)
    tenant_email = serializers.EmailField(source="tenant.email", read_only=True)
    owner_name = serializers.SerializerMethodField()
    tenant_name = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = (
            "id",
            "owner",
            "tenant",
            "owner_email",
            "tenant_email",
            "owner_name",
            "tenant_name",
            "last_message",
            "unread_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = fields

    def get_owner_name(self, obj):
        name = f"{obj.owner.first_name} {obj.owner.last_name}".strip()
        return name or obj.owner.email

    def get_tenant_name(self, obj):
        name = f"{obj.tenant.first_name} {obj.tenant.last_name}".strip()
        return name or obj.tenant.email

    def get_last_message(self, obj):
        msg = obj.messages.select_related("sender", "reply_to__sender").order_by(
            "-created_at"
        ).first()
        if not msg:
            return None
        return ChatMessageSerializer(msg, context=self.context).data

    def get_unread_count(self, obj):
        request = self.context.get("request")
        if not request:
            return 0
        return obj.messages.filter(is_read=False).exclude(sender=request.user).count()
