# Resource logs to a Log Analytics workspace (log_analytics_workspace_id), as the App Service, Key Vault and Storage
# security baselines recommend. Off by default: nothing is made unless a workspace is given, because ingestion is
# billed per GB. Only logs are sent, no platform metrics: the alerts in monitoring.tf read metrics straight from
# Azure Monitor, which keeps them for 93 days at no cost. Diagnostic settings are made through Resource Manager and
# the logs leave through Azure Monitor, so the storage and vault firewalls (private_network) need nothing extra.
locals {
  diagnostics = var.log_analytics_workspace_id != null

  # The web app's categories, picked by hand instead of the "allLogs" group so the bill stays predictable (allLogs
  # also takes IP security, file change, antivirus and authentication logs). AppServiceAppLogs is left out: on a
  # Linux container it only carries Java apps' logs; the dashboard's own lines are in the console log. HTTP logs
  # (one row per request) are usually most of the volume.
  web_app_log_categories = [
    "AppServiceHTTPLogs",     # requests: who, which path, status, time taken
    "AppServiceConsoleLogs",  # the container's stdout and stderr, where the app writes its log lines
    "AppServiceAuditLogs",    # sign-ins to the publishing endpoints (FTP, Kudu)
    "AppServicePlatformLogs", # container starts, stops and health-check evictions
  ]
}

resource "azurerm_monitor_diagnostic_setting" "web_app" {
  count                      = local.diagnostics ? 1 : 0
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_linux_web_app.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = local.web_app_log_categories
    content {
      category = enabled_log.value
    }
  }
}

# Every data-plane request to the vault (AuditEvent): who read or changed which secret.
resource "azurerm_monitor_diagnostic_setting" "secret_vault" {
  count                      = local.diagnostics && var.create_secret_vault ? 1 : 0
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_key_vault.secrets[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}

# Blob writes and deletes on the history storage account. Reads, which the app makes on every page, are left out
# on purpose: the storage "audit" category group would take StorageRead too (every category that records a
# customer's interaction with the data), so the categories are named one by one.
resource "azurerm_monitor_diagnostic_setting" "history_blob" {
  count                      = local.diagnostics && var.create_history_storage ? 1 : 0
  name                       = "diag-${var.name}"
  target_resource_id         = "${azurerm_storage_account.history[0].id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}
