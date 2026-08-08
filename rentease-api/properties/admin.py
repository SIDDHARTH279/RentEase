from django.contrib import admin
from .models import Portfolio, Building, Unit, Lease, LeaseTenant

admin.site.register(Portfolio)
admin.site.register(Building)
admin.site.register(Unit)
admin.site.register(Lease)
admin.site.register(LeaseTenant)