from django.conf import settings
from django.db import models


class Document(models.Model):
    class DocType(models.TextChoices):
        LEASE = "lease", "Lease agreement"
        ID_PROOF = "id_proof", "ID proof"
        MOVE_IN = "move_in", "Move-in checklist"
        MOVE_OUT = "move_out", "Move-out checklist"
        OTHER = "other", "Other"

    unit = models.ForeignKey(
        "properties.Unit",
        on_delete=models.CASCADE,
        related_name="documents",
    )
    tenant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="documents",
    )
    doc_type = models.CharField(max_length=20, choices=DocType.choices)
    title = models.CharField(max_length=200)
    file = models.FileField(upload_to="documents/")
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="uploaded_documents",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.title} ({self.doc_type})"


class ChecklistItem(models.Model):
    class Condition(models.TextChoices):
        GOOD = "good", "Good"
        FAIR = "fair", "Fair"
        POOR = "poor", "Poor"
        DAMAGED = "damaged", "Damaged"

    document = models.ForeignKey(
        Document,
        on_delete=models.CASCADE,
        related_name="checklist_items",
    )
    room = models.CharField(max_length=100)
    condition = models.CharField(
        max_length=20,
        choices=Condition.choices,
        default=Condition.GOOD,
    )
    note = models.TextField(blank=True, default="")
    photo = models.ImageField(upload_to="checklists/", blank=True, null=True)

    def __str__(self):
        return f"{self.room} — {self.condition}"
