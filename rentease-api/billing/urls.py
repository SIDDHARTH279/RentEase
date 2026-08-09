from django.urls import path
from .views import (
    OwnerInvoiceListView,
    OwnerGenerateInvoiceView,
    MyRentShareListView,
    MyCurrentRentShareView,
    InitiatePaymentView,
    OwnerAnalyticsView,
)

urlpatterns = [
    # Owner
    path("invoices/lease/<int:lease_id>/", OwnerInvoiceListView.as_view()),
    path("invoices/lease/<int:lease_id>/generate/", OwnerGenerateInvoiceView.as_view()),
    path("analytics/", OwnerAnalyticsView.as_view()),

    # Tenant
    path("my-shares/", MyRentShareListView.as_view()),
    path("my-shares/current/", MyCurrentRentShareView.as_view()),
    path("pay/<int:share_id>/", InitiatePaymentView.as_view()),
]
