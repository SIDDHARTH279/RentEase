from rest_framework import generics, serializers, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsOwner, IsTenant
from properties.models import Unit

from .models import ChecklistItem, Document
from .serializers import ChecklistItemSerializer, DocumentSerializer


def _owner_units(user):
    return Unit.objects.filter(building__portfolio__owner=user)


def _tenant_units(user):
    return Unit.objects.filter(
        leases__tenants__tenant=user,
        leases__status="active",
    ).distinct()


class OwnerDocumentListCreateView(generics.ListCreateAPIView):
    serializer_class = DocumentSerializer
    permission_classes = [IsOwner]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        qs = Document.objects.filter(
            unit__building__portfolio__owner=self.request.user
        ).select_related("unit", "uploaded_by")
        unit_id = self.request.query_params.get("unit_id")
        if unit_id:
            qs = qs.filter(unit_id=unit_id)
        return qs

    def perform_create(self, serializer):
        unit = serializer.validated_data["unit"]
        if unit.building.portfolio.owner_id != self.request.user.id:
            raise serializers.ValidationError({"unit": "Not your unit."})
        serializer.save(uploaded_by=self.request.user)


class TenantDocumentListCreateView(generics.ListCreateAPIView):
    serializer_class = DocumentSerializer
    permission_classes = [IsTenant]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        units = _tenant_units(self.request.user)
        qs = Document.objects.filter(unit__in=units).select_related(
            "unit", "uploaded_by"
        )
        unit_id = self.request.query_params.get("unit_id")
        if unit_id:
            qs = qs.filter(unit_id=unit_id)
        return qs

    def perform_create(self, serializer):
        unit = serializer.validated_data["unit"]
        if not _tenant_units(self.request.user).filter(pk=unit.pk).exists():
            raise serializers.ValidationError({"unit": "Not your unit."})
        serializer.save(
            uploaded_by=self.request.user,
            tenant=self.request.user,
        )


class DocumentDetailView(APIView):
    def get_object(self, request, pk):
        try:
            doc = Document.objects.select_related(
                "unit__building__portfolio"
            ).get(pk=pk)
        except Document.DoesNotExist:
            return None
        user = request.user
        if user.role == "owner" and doc.unit.building.portfolio.owner_id == user.id:
            return doc
        if user.role == "tenant" and doc.unit in _tenant_units(user):
            return doc
        return None

    def get(self, request, pk):
        doc = self.get_object(request, pk)
        if not doc:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(DocumentSerializer(doc, context={"request": request}).data)

    def delete(self, request, pk):
        doc = self.get_object(request, pk)
        if not doc:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        if request.user.role != "owner" and doc.uploaded_by_id != request.user.id:
            return Response({"detail": "Forbidden."}, status=status.HTTP_403_FORBIDDEN)
        doc.file.delete(save=False)
        doc.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChecklistItemListCreateView(generics.ListCreateAPIView):
    serializer_class = ChecklistItemSerializer
    permission_classes = [IsOwner]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        return ChecklistItem.objects.filter(
            document_id=self.kwargs["document_id"],
            document__unit__building__portfolio__owner=self.request.user,
        )

    def perform_create(self, serializer):
        doc = Document.objects.get(
            pk=self.kwargs["document_id"],
            unit__building__portfolio__owner=self.request.user,
        )
        serializer.save(document=doc)
