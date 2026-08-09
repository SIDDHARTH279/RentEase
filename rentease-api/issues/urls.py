from django.urls import path
from .views import MyIssueListCreateView, OwnerIssueListView, OwnerIssueUpdateView

urlpatterns = [
    # tenant
    path('my-issues/', MyIssueListCreateView.as_view()),

    # Owner
    path('all/', OwnerIssueListView.as_view()),
    path('<int:pk>/status/', OwnerIssueUpdateView.as_view())
]
