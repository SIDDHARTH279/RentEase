from django.urls import path

from .views import ExpenseDetailView, ExpenseListCreateView

urlpatterns = [
    path("", ExpenseListCreateView.as_view()),
    path("<int:pk>/", ExpenseDetailView.as_view()),
]
