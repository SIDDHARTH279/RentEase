import logging
from pathlib import Path

logger = logging.getLogger(__name__)

_firebase_initialized = False


def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred_path = (
            Path(__file__).resolve().parent.parent / "firebase-service-account.json"
        )
        if not cred_path.exists():
            logger.warning(
                "firebase-service-account.json not found — push notifications disabled."
            )
            return False

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred)

        _firebase_initialized = True
        return True
    except Exception as e:
        logger.error(f"Firebase init failed: {e}")
        return False


_TYPE_ALIASES = {
    "invoice": "rent_due",
    "overdue_rent": "rent_overdue",
    "overdue": "rent_overdue",
    "payment": "payment_success",
}


def _normalize_type(type_value: str | None) -> str:
    from .models import AppNotification

    raw = (type_value or "general").strip().lower()
    raw = _TYPE_ALIASES.get(raw, raw)
    valid = {c.value for c in AppNotification.NotifType}
    return raw if raw in valid else AppNotification.NotifType.GENERAL


def create_notification(
    user,
    *,
    title: str,
    body: str = "",
    type: str = "general",
    data: dict | None = None,
    push: bool = True,
):
    """Persist in-app notification and optionally send FCM push."""
    from .models import AppNotification

    payload = dict(data or {})
    notif_type = _normalize_type(type or payload.get("type"))
    payload.setdefault("type", notif_type)

    notif = AppNotification.objects.create(
        user=user,
        type=notif_type,
        title=title,
        body=body,
        data=payload,
    )
    if push:
        send_push(user, title=title, body=body, data=payload)
    return notif


def send_notification(user, title: str, body: str, data: dict = None):
    """Backward-compatible: create in-app row + push."""
    payload = data or {}
    return create_notification(
        user,
        title=title,
        body=body or "",
        type=payload.get("type", "general"),
        data=payload,
        push=True,
    )


def send_push(user, title: str, body: str, data: dict = None):
    """Send FCM only (no DB row)."""
    if not _init_firebase():
        return

    try:
        from firebase_admin import messaging
        from .models import FCMToken

        try:
            fcm = user.fcm_token
        except FCMToken.DoesNotExist:
            return
        if not fcm.token:
            return

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(priority="high"),
            token=fcm.token,
        )
        messaging.send(message)
        logger.info(f"Push sent to {user.email}: {title}")
    except Exception as e:
        logger.warning(f"Push failed for {getattr(user, 'email', '?')}: {e}")
