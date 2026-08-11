from django.contrib import admin

from .models import Conversation, ChatMessage


class ChatMessageInline(admin.TabularInline):
    model = ChatMessage
    extra = 0
    readonly_fields = (
        "sender",
        "message_type",
        "text",
        "image",
        "reply_to",
        "is_read",
        "created_at",
    )


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ("id", "owner", "tenant", "updated_at")
    search_fields = ("owner__email", "tenant__email")
    inlines = [ChatMessageInline]


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "conversation",
        "sender",
        "message_type",
        "text",
        "is_read",
        "created_at",
    )
    list_filter = ("is_read", "message_type")
    search_fields = ("text", "sender__email")
