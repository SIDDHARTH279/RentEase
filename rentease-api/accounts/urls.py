from django.urls import path
from .activity import ActivityFeedView
from .notification_views import (
    NotificationDetailView,
    NotificationListView,
    NotificationMarkReadView,
)
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
    path("activity/", ActivityFeedView.as_view(), name="activity-feed"),
    path("notifications/", NotificationListView.as_view(), name="notifications"),
    path(
        "notifications/read/",
        NotificationMarkReadView.as_view(),
        name="notifications-read",
    ),
    path(
        "notifications/<int:pk>/",
        NotificationDetailView.as_view(),
        name="notification-detail",
    ),
]
