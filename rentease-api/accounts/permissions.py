from rest_framework.permissions import BasePermission


class IsOwner(BasePermission):
    """Allow access only to users with role = owner."""

    message = "Access restricted to property owners only."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role == "owner"
        )


class IsTenant(BasePermission):
    """Allow access only to users with role = tenant."""

    message = "Access restricted to tenants only."

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role == "tenant"
        )
