from django.shortcuts import render
from .models import Issue
from .serializers import IssueSerializer
from accounts.permissions import IsOwner, IsTenant

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework import generics

# TENANT VIEWS
class MyIssueListCreateView(generics.ListCreateAPIView):
    serializer_class = IssueSerializer
    permission_classes = [IsTenant]

    def get_queryset(self):
        return Issue.objects.filter(
            reported_by = self.request.user
        ).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(reported_by = self.request.user)


# OWNER VIEWS
class OwnerIssueListView(generics.ListAPIView):
    serializer_class = IssueSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return Issue.objects.filter(
            unit__building__portfolio__owner = self.request.user
        ).order_by('-created_at')


class OwnerIssueUpdateView(APIView):
    permission_classes = [IsOwner]
    def patch(self, request, pk):
        try:
            issue = Issue.objects.get(
                pk=pk,
                unit__building__portfolio__owner=request.user
            )
        except Issue.DoesNotExist:
            return Response(
                {'detail': 'Issue not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        new_status = request.data.get('status')
        if new_status not in dict(Issue.STATUS):
            return Response(
                {'detail': 'Invalid status.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        issue.status = new_status
        issue.save()
        return Response(IssueSerializer(issue).data)