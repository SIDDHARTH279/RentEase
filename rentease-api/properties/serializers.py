from rest_framework import serializers
from .models import Portfolio, Building, Unit, Lease, LeaseTenant


class PortfolioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Portfolio
        fields = ("id", "name", "description", "created_at")
        read_only_fields = ("id", "created_at")


class BuildingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Building
        fields = ("id", "portfolio", "name", "address", "city", "type", "created_at")
        read_only_fields = ("id", "created_at")


class UnitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Unit
        fields = (
            "id",
            "building",
            "unit_number",
            "floor",
            "bedrooms",
            "base_rent",
            "deposit",
            "is_vacant",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class LeaseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lease
        fields = (
            "id",
            "unit",
            "monthly_rent",
            "due_day",
            "start_date",
            "end_date",
            "status",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class LeaseTenantSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaseTenant
        fields = ("id", "lease", "tenant", "rent_share_pct", "is_primary")
        read_only_fields = ("id",)
