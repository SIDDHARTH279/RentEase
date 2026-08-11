from rest_framework import serializers

from .models import ChecklistItem, Document


class ChecklistItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChecklistItem
        fields = ("id", "document", "room", "condition", "note", "photo")
        read_only_fields = ("id",)


class DocumentSerializer(serializers.ModelSerializer):
    uploaded_by_email = serializers.EmailField(
        source="uploaded_by.email", read_only=True
    )
    unit_number = serializers.CharField(source="unit.unit_number", read_only=True)
    building_name = serializers.CharField(
        source="unit.building.name", read_only=True
    )
    file_url = serializers.SerializerMethodField()
    checklist_items = ChecklistItemSerializer(many=True, read_only=True)

    class Meta:
        model = Document
        fields = (
            "id",
            "unit",
            "unit_number",
            "building_name",
            "tenant",
            "doc_type",
            "title",
            "file",
            "file_url",
            "uploaded_by",
            "uploaded_by_email",
            "created_at",
            "checklist_items",
        )
        read_only_fields = (
            "id",
            "uploaded_by",
            "created_at",
            "checklist_items",
            "file_url",
            "unit_number",
            "building_name",
        )
        extra_kwargs = {"file": {"write_only": False, "required": True}}

    def get_file_url(self, obj):
        if not obj.file:
            return None
        request = self.context.get("request")
        url = obj.file.url
        if request:
            return request.build_absolute_uri(url)
        return url
