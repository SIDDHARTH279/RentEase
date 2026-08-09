from django.urls import path
from .views import (
    PortfolioListCreateView,
    PortfolioDetailView,
    BuildingListCreateView,
    BuildingDetailView,
    UnitListCreateView,
    UnitDetailView,
    LeaseListCreateView,
    LeaseDetailView,
    LeaseTenantListCreateView,
    LeaseTenantDetailView,
    MyLeaseView,
    MyUnitView,
)

urlpatterns = [
    # Portfolio
    path("portfolios/", PortfolioListCreateView.as_view(), name="portfolio-list"),
    path("portfolios/<int:pk>/", PortfolioDetailView.as_view(), name="portfolio-detail"),

    # Building
    path("buildings/", BuildingListCreateView.as_view(), name="building-list"),
    path("buildings/<int:pk>/", BuildingDetailView.as_view(), name="building-detail"),

    # Unit
    path("units/", UnitListCreateView.as_view(), name="unit-list"),
    path("units/<int:pk>/", UnitDetailView.as_view(), name="unit-detail"),

    # Lease
    path("leases/", LeaseListCreateView.as_view(), name="lease-list"),
    path("leases/<int:pk>/", LeaseDetailView.as_view(), name="lease-detail"),

    # LeaseTenant
    path("lease-tenants/", LeaseTenantListCreateView.as_view(), name="lease-tenant-list"),
    path("lease-tenants/<int:pk>/", LeaseTenantDetailView.as_view(), name="lease-tenant-detail"),

    # Tenant-only
    path("my-lease/", MyLeaseView.as_view(), name="my-lease"),
    path("my-unit/", MyUnitView.as_view(), name="my-unit"),
]
