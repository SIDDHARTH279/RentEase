import re
from django.core.exceptions import ValidationError


class StrongPasswordValidator:
    """
    Requires at least one digit and one special character.
    """

    def validate(self, password, user=None):
        if not re.search(r'\d', password):
            raise ValidationError(
                "Password must contain at least one number.",
                code='password_no_number',
            )
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~;\'']', password):
            raise ValidationError(
                "Password must contain at least one special character (!@#$%^&* etc.).",
                code='password_no_special',
            )

    def get_help_text(self):
        return "Your password must contain at least one number and one special character."
