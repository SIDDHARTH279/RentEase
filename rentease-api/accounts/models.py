from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager



# This code creates a custom user manager for a Django
# custom user model where users log in using email instead of username.
class UserManager(BaseUserManager):
    """Custom manager so create_user / create_superuser use email."""

    def create_user(self, email, password=None, **extra_fields):

        if not email:
            raise ValueError('Email is required')

        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', User.Role.OWNER)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('superuser must have is_staff=true')

        if extra_fields.get('is_superuser') is not True:
            raise ValueError('superuser must have is_superuser=true')

        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):

    class Role(models.TextChoices):
        OWNER = "owner", "Owner"
        TENANT = "tenant", "Tenant"


    # remove default username - we use email
    username = None
    email = models.EmailField(unique=True)
    role = models.CharField(
        max_length=10,
        choices = Role.choices,
        default= Role.TENANT
    )

    phone = models.CharField(max_length=15, blank=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email