# crm_project/urls.py
from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

urlpatterns = [
    path('admin513/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),
    path('', include('core.urls')), # Use empty path '' for homepage
    path('crm/', include('crm_entities.urls')), 
    # Activities
    path('activities/', include('activities.urls')),
    # Sales Pipeline
    path('pipeline/', include('sales_pipeline.urls')),
    # Users
    path('users/', include('users.urls')),
    # Health check
    path('health/', lambda request: HttpResponse('OK')),
]