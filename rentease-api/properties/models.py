from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator


class Portfolio(models.Model):
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='portfolios')
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Building(models.Model):

    class BuildingType(models.TextChoices):
        HOUSE = 'house', 'House'
        APARTMENT = 'apartment', 'Apartment'
        COMMERCIAL = 'commercial', 'Commercial'

    portfolio = models.ForeignKey(Portfolio, on_delete=models.CASCADE, related_name='buildings')
    name = models.CharField(max_length=100)
    address = models.TextField()
    city= models.CharField(max_length=100)
    type = models.CharField(
        max_length=20,
        choices=BuildingType.choices
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Unit(models.Model):
    building = models.ForeignKey(Building, on_delete=models.CASCADE, related_name='units')
    unit_number = models.CharField(max_length=50)
    floor = models.PositiveIntegerField()
    bedrooms = models.PositiveIntegerField(default=0)
    base_rent = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    deposit = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    is_vacant = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.unit_number

class Lease(models.Model):

    class LeaseStatus(models.TextChoices):
        ACTIVE = "active", "Active"
        ENDED = "ended", "Ended"


    unit = models.ForeignKey(
        Unit,
        on_delete=models.CASCADE,
        related_name="leases"
    )

    monthly_rent = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    due_day = models.PositiveSmallIntegerField(
        validators=[
            MinValueValidator(1),
            MaxValueValidator(28)
        ]
    )

    start_date = models.DateField()

    end_date = models.DateField(
        null=True,
        blank=True
    )

    status = models.CharField(
        max_length=10,
        choices=LeaseStatus.choices,
        default=LeaseStatus.ACTIVE
    )

    created_at = models.DateTimeField(auto_now_add=True)


    def __str__(self):
        return f"{self.unit} Lease"



class LeaseTenant(models.Model):

    lease = models.ForeignKey(
        Lease,
        on_delete=models.CASCADE,
        related_name="tenants"
    )

    tenant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="leases"
    )

    rent_share_pct = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators=[
            MinValueValidator(0),
            MaxValueValidator(100)
        ]
    )

    is_primary = models.BooleanField(default=False)


    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["lease", "tenant"],
                name="unique_lease_tenant"
            )
        ]


    def __str__(self):
        return f"{self.tenant} - {self.lease}"