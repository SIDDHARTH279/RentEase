from django.contrib import admin

from .models import Expense


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ("id", "owner", "building", "category", "amount", "date")
    list_filter = ("category", "date")
    search_fields = ("note", "owner__email", "building__name")
