from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def broadcast_chat_message(conversation_id, message_data):
    """Push a serialized message to everyone in the conversation room."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    async_to_sync(channel_layer.group_send)(
        f"chat_{conversation_id}",
        {
            "type": "chat.message",
            "message": message_data,
        },
    )


def broadcast_messages_read(conversation_id, reader_id, message_ids):
    """Notify peers that messages were marked read (for live ticks)."""
    if not message_ids:
        return
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    async_to_sync(channel_layer.group_send)(
        f"chat_{conversation_id}",
        {
            "type": "chat.read",
            "reader_id": reader_id,
            "message_ids": list(message_ids),
        },
    )
