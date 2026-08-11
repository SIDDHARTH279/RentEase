from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsOwner

from .models import Expense
from .serializers import ExpenseSerializer


class ExpenseListCreateView(APIView):
    permission_classes = [IsOwner]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        qs = (
            Expense.objects.filter(owner=request.user)
            .select_related("building", "unit")
            .all()
        )
        building_id = request.query_params.get("building_id")
        if building_id:
            qs = qs.filter(building_id=building_id)
        return Response(
            ExpenseSerializer(qs, many=True, context={"request": request}).data
        )

    def post(self, request):
        serializer = ExpenseSerializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        expense = serializer.save()
        return Response(
            ExpenseSerializer(expense, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class ExpenseDetailView(APIView):
    permission_classes = [IsOwner]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def _get(self, request, pk):
        try:
            return Expense.objects.select_related("building", "unit").get(
                id=pk, owner=request.user
            )
        except Expense.DoesNotExist:
            return None

    def get(self, request, pk):
        expense = self._get(request, pk)
        if not expense:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            ExpenseSerializer(expense, context={"request": request}).data
        )

    def patch(self, request, pk):
        expense = self._get(request, pk)
        if not expense:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = ExpenseSerializer(
            expense,
            data=request.data,
            partial=True,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        expense = serializer.save()
        return Response(
            ExpenseSerializer(expense, context={"request": request}).data
        )

    def delete(self, request, pk):
        expense = self._get(request, pk)
        if not expense:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        expense.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
