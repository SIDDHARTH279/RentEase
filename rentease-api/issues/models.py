from django.conf import settings
from django.db import models


class Issue(models.Model):
    CATEGORY = (
        ('plumbing', 'Plumbing'),
        ('electrical', 'Electrical'),
        ('carpentry', 'Carpentry'),
        ('cleaning', 'Cleaning'),
        ('other', 'Other'),
    )

    STATUS = (
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    )

    unit = models.ForeignKey(
        "properties.Unit",
        on_delete=models.CASCADE,
        related_name='issues'
    )
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='reported_issues'
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    photo = models.ImageField(upload_to='issues/', blank=True, null=True)
    category = models.CharField(max_length=20, choices=CATEGORY)
    status = models.CharField(max_length=20, choices=STATUS, default='open')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} — {self.unit}"