from django.urls import path

from .views import (
    ConversationListCreateView,
    MessageListCreateView,
    OwnerTenantContactsView,
)

urlpatterns = [
    path("conversations/", ConversationListCreateView.as_view()),
    path("contacts/", OwnerTenantContactsView.as_view()),
    path("conversations/<int:conversation_id>/messages/", MessageListCreateView.as_view()),
]
