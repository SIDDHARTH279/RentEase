from django.core.management.base import BaseCommand
from billing.tasks import generate_monthly_invoices, mark_overdue_invoices


class Command(BaseCommand):
    help = "Manually run billing tasks (invoice generation + overdue marking)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--task",
            choices=["generate", "overdue", "all"],
            default="all",
            help="Which task to run (default: all)",
        )

    def handle(self, *args, **options):
        task = options["task"]

        if task in ("generate", "all"):
            self.stdout.write("Running: generate_monthly_invoices...")
            result = generate_monthly_invoices()
            self.stdout.write(self.style.SUCCESS(f"  Result: {result}"))

        if task in ("overdue", "all"):
            self.stdout.write("Running: mark_overdue_invoices...")
            result = mark_overdue_invoices()
            self.stdout.write(self.style.SUCCESS(f"  Result: {result}"))

        self.stdout.write(self.style.SUCCESS("Done."))
