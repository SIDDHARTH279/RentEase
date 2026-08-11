from rest_framework import serializers

from .models import Expense


class ExpenseSerializer(serializers.ModelSerializer):
    building_name = serializers.CharField(source="building.name", read_only=True)
    unit_number = serializers.CharField(
        source="unit.unit_number", read_only=True, allow_null=True
    )
    receipt_url = serializers.SerializerMethodField()

    class Meta:
        model = Expense
        fields = (
            "id",
            "building",
            "building_name",
            "unit",
            "unit_number",
            "category",
            "amount",
            "date",
            "note",
            "receipt",
            "receipt_url",
            "created_at",
        )
        read_only_fields = ("id", "created_at", "receipt_url", "building_name", "unit_number")
        extra_kwargs = {"receipt": {"write_only": True, "required": False}}

    def get_receipt_url(self, obj):
        if not obj.receipt:
            return None
        request = self.context.get("request")
        url = obj.receipt.url
        if request:
            return request.build_absolute_uri(url)
        return url

    def validate(self, attrs):
        request = self.context["request"]
        building = attrs.get("building") or getattr(self.instance, "building", None)
        unit = attrs.get("unit", serializers.empty)
        if unit is serializers.empty:
            unit = getattr(self.instance, "unit", None)

        if building and building.portfolio.owner_id != request.user.id:
            raise serializers.ValidationError({"building": "Not your building."})

        if unit is not None and building is not None:
            if unit.building_id != building.id:
                raise serializers.ValidationError(
                    {"unit": "Unit must belong to the selected building."}
                )
        return attrs

    def create(self, validated_data):
        validated_data["owner"] = self.context["request"].user
        return super().create(validated_data)
