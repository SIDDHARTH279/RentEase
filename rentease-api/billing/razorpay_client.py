import razorpay
from django.conf import settings

from .crypto import decrypt_secret


class RazorpayNotConfigured(Exception):
    pass


def resolve_razorpay_credentials(owner=None) -> tuple[str, str]:
    """
    Prefer owner-saved keys from PaymentGatewayConfig.
    Fall back to .env keys for local/dev convenience.
    """
    if owner is not None:
        config = getattr(owner, "payment_gateway", None)
        if config is None:
            from .models import PaymentGatewayConfig

            config = PaymentGatewayConfig.objects.filter(owner=owner).first()
        if config and config.is_configured:
            if not config.is_enabled:
                raise RazorpayNotConfigured(
                    "Online payments are currently disabled by the owner."
                )
            return config.razorpay_key_id, decrypt_secret(
                config.razorpay_key_secret_encrypted
            )

    # Dev fallback only when owner has not saved app settings yet
    key_id = settings.RAZORPAY_KEY_ID or ""
    key_secret = settings.RAZORPAY_KEY_SECRET or ""
    if key_id and key_secret:
        return key_id, key_secret

    raise RazorpayNotConfigured(
        "Razorpay is not set up. Owner must add Key ID and Secret under "
        "Profile menu → Razorpay settings."
    )


def get_razorpay_client(owner=None):
    key_id, key_secret = resolve_razorpay_credentials(owner)
    return razorpay.Client(auth=(key_id, key_secret)), key_id


def create_order(
    *,
    amount_rupees,
    receipt: str,
    notes: dict | None = None,
    owner=None,
):
    client, _key_id = get_razorpay_client(owner)
    amount_paise = int(round(float(amount_rupees) * 100))
    if amount_paise < 100:
        raise ValueError("Amount must be at least ₹1.00")

    payload = {
        "amount": amount_paise,
        "currency": "INR",
        "receipt": receipt[:40],
        "payment_capture": 1,
        "notes": notes or {},
    }
    order = client.order.create(data=payload)
    return order, _key_id


def verify_payment_signature(
    *,
    order_id: str,
    payment_id: str,
    signature: str,
    owner=None,
) -> bool:
    client, _ = get_razorpay_client(owner)
    try:
        client.utility.verify_payment_signature(
            {
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": signature,
            }
        )
        return True
    except razorpay.errors.SignatureVerificationError:
        return False


def verify_webhook_signature(body: bytes, signature: str, owner=None) -> bool:
    secret = settings.RAZORPAY_WEBHOOK_SECRET
    if not secret:
        return False
    client, _ = get_razorpay_client(owner)
    try:
        client.utility.verify_webhook_signature(
            body.decode("utf-8"), signature, secret
        )
        return True
    except Exception:
        return False
