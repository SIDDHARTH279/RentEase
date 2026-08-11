"""Notify the other participant when a chat message is created."""


def notify_peer_of_message(conversation, sender, message):
    """Create in-app + FCM notification for the peer (owner or tenant)."""
    peer = conversation.tenant if sender.id == conversation.owner_id else conversation.owner
    name = f"{sender.first_name} {sender.last_name}".strip() or sender.email
    if message.message_type == message.MessageType.IMAGE:
        preview = "📷 Photo"
        if message.text:
            preview = f"📷 {message.text[:80]}"
    else:
        preview = (message.text or "")[:120] or "New message"

    try:
        from accounts.notifications import create_notification

        create_notification(
            peer,
            title=name,
            body=preview,
            type="chat",
            data={
                "type": "chat",
                "conversation_id": str(conversation.id),
                "message_id": str(message.id),
            },
            push=True,
        )
    except Exception:
        pass
