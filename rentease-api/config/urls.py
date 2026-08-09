from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenRefreshView
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/auth/", include("accounts.urls")),
    path("api/v1/auth/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("api/v1/properties/", include("properties.urls")),
    path("api/v1/billing/", include("billing.urls")),
    path('api/v1/issues/', include('issues.urls')),
] + static(settings.MEDIA_URL, document_root = settings.MEDIA_ROOT)
