from django.contrib import admin

from .models import ChecklistItem, Document


class ChecklistItemInline(admin.TabularInline):
    model = ChecklistItem
    extra = 0


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ("title", "doc_type", "unit", "uploaded_by", "created_at")
    list_filter = ("doc_type",)
    search_fields = ("title", "unit__unit_number")
    inlines = [ChecklistItemInline]


@admin.register(ChecklistItem)
class ChecklistItemAdmin(admin.ModelAdmin):
    list_display = ("room", "condition", "document")
