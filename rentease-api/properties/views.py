from rest_framework import generics
from rest_framework.response import Response
from rest_framework import status

from accounts.permissions import IsOwner
from .models import Portfolio, Building, Unit, Lease, LeaseTenant
from .serializers import (
    PortfolioSerializer,
    BuildingSerializer,
    UnitSerializer,
    LeaseSerializer,
    LeaseTenantSerializer,
)


# ─── Portfolio ────────────────────────────────────────────────────────────────

class PortfolioListCreateView(generics.ListCreateAPIView):
    serializer_class = PortfolioSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Portfolio.objects.filter(owner=self.request.user).order_by("-created_at")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class PortfolioDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PortfolioSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Portfolio.objects.filter(owner=self.request.user)


# ─── Building ─────────────────────────────────────────────────────────────────

class BuildingListCreateView(generics.ListCreateAPIView):
    serializer_class = BuildingSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Building.objects.filter(
            portfolio__owner=self.request.user
        ).order_by("-created_at")


class BuildingDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BuildingSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Building.objects.filter(portfolio__owner=self.request.user)


# ─── Unit ─────────────────────────────────────────────────────────────────────

class UnitListCreateView(generics.ListCreateAPIView):
    serializer_class = UnitSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Unit.objects.filter(
            building__portfolio__owner=self.request.user
        ).order_by("-created_at")


class UnitDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UnitSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Unit.objects.filter(building__portfolio__owner=self.request.user)


# ─── Lease ────────────────────────────────────────────────────────────────────

class LeaseListCreateView(generics.ListCreateAPIView):
    serializer_class = LeaseSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Lease.objects.filter(
            unit__building__portfolio__owner=self.request.user
        ).order_by("-created_at")


class LeaseDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = LeaseSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Lease.objects.filter(
            unit__building__portfolio__owner=self.request.user
        )


# ─── LeaseTenant ──────────────────────────────────────────────────────────────

class LeaseTenantListCreateView(generics.ListCreateAPIView):
    serializer_class = LeaseTenantSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return LeaseTenant.objects.filter(
            lease__unit__building__portfolio__owner=self.request.user
        )


class LeaseTenantDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = LeaseTenantSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return LeaseTenant.objects.filter(
            lease__unit__building__portfolio__owner=self.request.user
        )
