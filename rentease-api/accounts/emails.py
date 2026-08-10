import logging
from django.core.mail import send_mail
from django.conf import settings

logger = logging.getLogger(__name__)


def _send(subject, message, recipient):
    try:
        send_mail(
            subject=subject,
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[recipient],
            fail_silently=False,
        )
        logger.info(f"Email sent to {recipient}: {subject}")
    except Exception as e:
        logger.error(f"Failed to send email to {recipient}: {e}")


def send_tenant_invite_email(email: str, invite_token: str, owner_name: str, invite_link: str):
    _send(
        subject="You've been invited to RentEase",
        message=(
            f"Hello,\n\n"
            f"{owner_name} has invited you to join RentEase as a tenant.\n\n"
            f"Tap this link on your phone (with RentEase installed):\n\n"
            f"{invite_link}\n\n"
            f"It opens the app login screen. Tap Continue with Google\n"
            f"using this invited email ({email}) to join as a tenant.\n\n"
            f"Backup invite token (manual accept):\n"
            f"{invite_token}\n\n"
            f"This invite expires in 7 days.\n\n"
            f"— RentEase Team"
        ),
        recipient=email,
    )


def send_welcome_email(email: str, first_name: str = ""):
    name = first_name or "there"
    _send(
        subject="Welcome to RentEase!",
        message=(
            f"Hi {name},\n\n"
            f"Your RentEase account is now active. You can log in to the app "
            f"to view your lease, pay rent, and raise issues.\n\n"
            f"— RentEase Team"
        ),
        recipient=email,
    )


def send_overdue_reminder_email(email: str, amount: float, due_date: str, unit_number: str):
    _send(
        subject="Rent Overdue — Action Required",
        message=(
            f"Hello,\n\n"
            f"Your rent payment of ₹{amount:.2f} for unit {unit_number} "
            f"was due on {due_date} and is now overdue.\n\n"
            f"Please log in to the RentEase app to make your payment as soon as possible "
            f"to avoid any penalties.\n\n"
            f"— RentEase Team"
        ),
        recipient=email,
    )
