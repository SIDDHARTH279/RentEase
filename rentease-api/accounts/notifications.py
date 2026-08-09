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

        cred_path = Path(__file__).resolve().parent.parent / "firebase-service-account.json"
        if not cred_path.exists():
            logger.warning("firebase-service-account.json not found — notifications disabled.")
            return False

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred)

        _firebase_initialized = True
        return True
    except Exception as e:
        logger.error(f"Firebase init failed: {e}")
        return False


def send_notification(user, title: str, body: str, data: dict = None):
    """
    Send a push notification to a single user.
    Silently skips if Firebase is not configured or user has no token.
    """
    if not _init_firebase():
        return

    try:
        from firebase_admin import messaging
        fcm = user.fcm_token
        if not fcm.token:
            return

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(priority="high"),
            token=fcm.token,
        )
        messaging.send(message)
        logger.info(f"Notification sent to {user.email}: {title}")
    except Exception as e:
        logger.warning(f"Notification failed for {getattr(user, 'email', '?')}: {e}")
