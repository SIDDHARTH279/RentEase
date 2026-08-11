from django.conf import settings
from django.db import models


class Expense(models.Model):
    class Category(models.TextChoices):
        MAINTENANCE = "maintenance", "Maintenance"
        PLUMBING = "plumbing", "Plumbing"
        PAINTING = "painting", "Painting"
        ELECTRICAL = "electrical", "Electrical"
        TAX = "tax", "Tax"
        INSURANCE = "insurance", "Insurance"
        UTILITIES = "utilities", "Utilities"
        OTHER = "other", "Other"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="expenses",
    )
    building = models.ForeignKey(
        "properties.Building",
        on_delete=models.CASCADE,
        related_name="expenses",
    )
    unit = models.ForeignKey(
        "properties.Unit",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="expenses",
    )
    category = models.CharField(max_length=20, choices=Category.choices)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    date = models.DateField()
    note = models.TextField(blank=True, default="")
    receipt = models.ImageField(upload_to="expenses/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.category} ₹{self.amount} ({self.date})"
