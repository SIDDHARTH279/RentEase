from rest_framework import serializers
from .models import Portfolio, Building, Unit, Lease, LeaseTenant


class PortfolioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Portfolio
        fields = ("id", "name", "description", "created_at")
        read_only_fields = ("id", "created_at")


class BuildingSerializer(serializers.ModelSerializer):
    portfolio = serializers.PrimaryKeyRelatedField(
        queryset=Portfolio.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Building
        fields = ("id", "portfolio", "name", "address", "city", "type", "created_at")
        read_only_fields = ("id", "created_at")

    def create(self, validated_data):
        request = self.context["request"]
        portfolio = validated_data.get("portfolio")
        if portfolio is None:
            name = (request.user.first_name or "My").strip() or "My"
            portfolio, _ = Portfolio.objects.get_or_create(
                owner=request.user,
                defaults={"name": f"{name}'s Portfolio"},
            )
            validated_data["portfolio"] = portfolio
        elif portfolio.owner_id != request.user.id:
            raise serializers.ValidationError(
                {"portfolio": "Portfolio not found or not owned by you."}
            )
        return super().create(validated_data)


class UnitSerializer(serializers.ModelSerializer):
    building_name = serializers.CharField(source="building.name", read_only=True)

    class Meta:
        model = Unit
        fields = (
            "id",
            "building",
            "building_name",
            "unit_number",
            "floor",
            "bedrooms",
            "base_rent",
            "deposit",
            "is_vacant",
            "created_at",
        )
        read_only_fields = ("id", "created_at", "building_name")

    def validate_building(self, building):
        request = self.context.get("request")
        if (
            request
            and building.portfolio.owner_id != request.user.id
        ):
            raise serializers.ValidationError("Not your building.")
        return building


class LeaseSerializer(serializers.ModelSerializer):
    unit_number = serializers.CharField(source="unit.unit_number", read_only=True)
    building_name = serializers.CharField(source="unit.building.name", read_only=True)

    class Meta:
        model = Lease
        fields = (
            "id",
            "unit",
            "unit_number",
            "building_name",
            "monthly_rent",
            "due_day",
            "start_date",
            "end_date",
            "status",
            "created_at",
        )
        read_only_fields = ("id", "unit_number", "building_name", "created_at")


class LeaseTenantSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaseTenant
        fields = ("id", "lease", "tenant", "rent_share_pct", "is_primary")
        read_only_fields = ("id",)
