from django.urls import path
from .views import (
    OwnerInvoiceListView,
    OwnerGenerateInvoiceView,
    OwnerPaymentSettingsView,
    OwnerMarkSharePaidView,
    TenantOwnerPaymentInfoView,
    MyRentShareListView,
    MyCurrentRentShareView,
    CreateRazorpayOrderView,
    VerifyRazorpayPaymentView,
    RazorpayWebhookView,
    OwnerAnalyticsView,
)

urlpatterns = [
    # Owner
    path("invoices/lease/<int:lease_id>/", OwnerInvoiceListView.as_view()),
    path("invoices/lease/<int:lease_id>/generate/", OwnerGenerateInvoiceView.as_view()),
    path("analytics/", OwnerAnalyticsView.as_view()),
    path("payment-settings/", OwnerPaymentSettingsView.as_view()),
    path("shares/<int:share_id>/mark-paid/", OwnerMarkSharePaidView.as_view()),

    # Tenant payments
    path("my-shares/", MyRentShareListView.as_view()),
    path("my-shares/current/", MyCurrentRentShareView.as_view()),
    path("owner-payment-info/", TenantOwnerPaymentInfoView.as_view()),
    path("pay/<int:share_id>/create-order/", CreateRazorpayOrderView.as_view()),
    path("pay/verify/", VerifyRazorpayPaymentView.as_view()),
    path("webhooks/razorpay/", RazorpayWebhookView.as_view()),
]
