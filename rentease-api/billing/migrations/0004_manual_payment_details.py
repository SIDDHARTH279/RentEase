from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("billing", "0003_paymentgatewayconfig"),
    ]

    operations = [
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="upi_id",
            field=models.CharField(blank=True, default="", max_length=100),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="account_holder_name",
            field=models.CharField(blank=True, default="", max_length=150),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="bank_name",
            field=models.CharField(blank=True, default="", max_length=100),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="account_number",
            field=models.CharField(blank=True, default="", max_length=40),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="ifsc_code",
            field=models.CharField(blank=True, default="", max_length=20),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="qr_code",
            field=models.ImageField(
                blank=True, null=True, upload_to="payment_qr/"
            ),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="payment_notes",
            field=models.CharField(blank=True, default="", max_length=300),
        ),
        migrations.AddField(
            model_name="paymentgatewayconfig",
            name="show_manual_details",
            field=models.BooleanField(
                default=True,
                help_text="If true, tenants can see UPI/bank/QR for offline payment.",
            ),
        ),
        migrations.AddField(
            model_name="payment",
            name="method",
            field=models.CharField(
                blank=True,
                choices=[
                    ("razorpay", "Razorpay"),
                    ("cash", "Cash"),
                    ("upi", "UPI / QR"),
                    ("bank_transfer", "Bank transfer"),
                    ("other", "Other"),
                ],
                default="razorpay",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="payment",
            name="notes",
            field=models.CharField(blank=True, default="", max_length=255),
        ),
    ]
