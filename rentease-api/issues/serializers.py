from rest_framework import serializers
from .models import Issue

class IssueSerializer(serializers.ModelSerializer):
    reported_by_email = serializers.CharField(
        source = 'reported_by.email',
        read_only=True
    )
    unit_number = serializers.CharField(
        source = 'unit.unit_number',
        read_only=True
    )

    class Meta:
        model = Issue
        fields = (
            'id',
            'unit',
            'unit_number',
            'reported_by',
            'reported_by_email',
            'title',
            'description',
            'photo',
            'category',
            'status',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'reported_by', 'status', 'created_at', 'updated_at')