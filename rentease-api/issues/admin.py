from django.contrib import admin
from .models import Issue

@admin.register(Issue)
class IssueAdmin(admin.ModelAdmin):
    list_display = ('title', 'unit', 'reported_by', 'category', 'status', 'created_at')
    list_filter = ('status', 'category')
    search_fields = ('title', 'reported_by__email')
