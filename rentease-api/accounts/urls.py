from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    GoogleLoginView,
    InviteTenantView,
    AcceptInviteView,
    SaveFCMTokenView,
    ProfileView,
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("google/", GoogleLoginView.as_view(), name="google-login"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("invite-tenant/", InviteTenantView.as_view(), name="invite-tenant"),
    path("accept-invite/", AcceptInviteView.as_view(), name="accept-invite"),
    path("fcm-token/", SaveFCMTokenView.as_view(), name="fcm-token"),
]
