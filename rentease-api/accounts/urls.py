from django.urls import path
from .views import RegisterView, LoginView, InviteTenantView, AcceptInviteView

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("invite-tenant/", InviteTenantView.as_view(), name="invite-tenant"),
    path("accept-invite/", AcceptInviteView.as_view(), name="accept-invite"),
]
