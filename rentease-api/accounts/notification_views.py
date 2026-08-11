from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AppNotification


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = AppNotification.objects.filter(user=request.user)[:50]
        unread = AppNotification.objects.filter(
            user=request.user, is_read=False
        ).count()
        results = [
            {
                "id": n.id,
                "type": n.type,
                "title": n.title,
                "body": n.body,
                "data": n.data,
                "is_read": n.is_read,
                "unread": not n.is_read,
                "created_at": n.created_at.isoformat(),
                "conversation_id": n.data.get("conversation_id"),
            }
            for n in qs
        ]
        return Response({"count": len(results), "unread_count": unread, "results": results})


class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ids = request.data.get("ids")
        mark_all = request.data.get("all") is True
        delete = request.data.get("delete") is True
        qs = AppNotification.objects.filter(user=request.user)
        if mark_all:
            if delete:
                deleted, _ = qs.delete()
                return Response({"deleted": deleted})
            updated = qs.filter(is_read=False).update(is_read=True)
            return Response({"updated": updated})
        if ids:
            targeted = qs.filter(id__in=ids)
            if delete:
                deleted, _ = targeted.delete()
                return Response({"deleted": deleted})
            updated = targeted.filter(is_read=False).update(is_read=True)
            return Response({"updated": updated})
        return Response(
            {"detail": "Provide ids or all=true."},
            status=status.HTTP_400_BAD_REQUEST,
        )


class NotificationDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        deleted, _ = AppNotification.objects.filter(
            id=pk, user=request.user
        ).delete()
        if not deleted:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)
