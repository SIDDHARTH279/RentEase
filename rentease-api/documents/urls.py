from django.urls import path

from .views import (
    ChecklistItemListCreateView,
    DocumentDetailView,
    OwnerDocumentListCreateView,
    TenantDocumentListCreateView,
)

urlpatterns = [
    path("owner/", OwnerDocumentListCreateView.as_view()),
    path("my/", TenantDocumentListCreateView.as_view()),
    path("<int:pk>/", DocumentDetailView.as_view()),
    path(
        "<int:document_id>/checklist-items/",
        ChecklistItemListCreateView.as_view(),
    ),
]
