# Access restrictions: allowed_ip_ranges and the named allowed_ips become ip_restriction rules on the web app.
# Mock providers, nothing is created. Run with: terraform init && terraform test



mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest" } }
  mock_resource "azurerm_storage_account" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.Storage/storageAccounts/stcwtest" } }
  mock_resource "azurerm_key_vault" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.KeyVault/vaults/kvcwtest", vault_uri = "https://kvcwtest.vault.azure.net/" } }
  mock_resource "azurerm_service_plan" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.Web/serverFarms/plan" } }
  mock_resource "azurerm_linux_web_app" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.Web/sites/cwtest", identity = { principal_id = "44444444-4444-4444-8444-444444444444", tenant_id = "00000000-0000-4000-8000-0000000000bb" } } }
  mock_resource "azurerm_user_assigned_identity" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id", principal_id = "55555555-5555-4555-8555-555555555555", client_id = "66666666-6666-4666-8666-666666666666" } }
  mock_resource "azurerm_log_analytics_workspace" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.OperationalInsights/workspaces/law" } }
  mock_resource "azurerm_application_insights" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.Insights/components/ai" } }
  mock_resource "azurerm_monitor_action_group" { defaults = { id = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-cwtest/providers/Microsoft.Insights/actionGroups/ag" } }
  mock_resource "azurerm_storage_container" { defaults = { id = "https://stcwtest.blob.core.windows.net/dashboard" } }
}
mock_provider "random" {
  mock_resource "random_uuid" { defaults = { result = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" } }
}
mock_provider "azuread" {
  mock_resource "azuread_group" { defaults = { object_id = "77777777-7777-4777-8777-777777777777", id = "/groups/77777777-7777-4777-8777-777777777777" } }
  mock_resource "azuread_application" { defaults = { id = "/applications/88888888-8888-4888-8888-888888888888", client_id = "99999999-9999-4999-8999-999999999999", object_id = "88888888-8888-4888-8888-888888888888" } }
  mock_resource "azuread_service_principal" { defaults = { object_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", id = "/servicePrincipals/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" } }
  mock_data "azuread_client_config" {
    defaults = { object_id = "00000000-0000-4000-8000-0000000000aa", tenant_id = "00000000-0000-4000-8000-0000000000bb" }
  }
  mock_data "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-4000-8000-0000000000cc", app_role_ids = { "User.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "GroupMember.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "Application.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "EntitlementManagement.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "RoleManagement.Read.Directory" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "AuditLog.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "Policy.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "DelegatedPermissionGrant.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "LicenseAssignment.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "PrivilegedEligibilitySchedule.Read.AzureADGroup" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "PrivilegedAssignmentSchedule.Read.AzureADGroup" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "IdentityRiskyUser.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "SecurityEvents.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "AdministrativeUnit.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "Organization.Read.All" = "cccccccc-cccc-4ccc-8ccc-cccccccccccc" } }
  }
}

variables {
  name                = "cwtest"
  location            = "norwayeast"
  resource_group_name = "rg-cwtest"
  shared_spn_access   = [{ scope = "/subscriptions/11111111-1111-4111-8111-111111111111" }]
  admin_principal_ids = ["22222222-2222-4222-8222-222222222222"]
}

run "no_rules_by_default" {
  command = plan
  assert {
    condition     = !local.restricted && length(azurerm_linux_web_app.this.site_config[0].ip_restriction) == 0
    error_message = "with no IPs or subnets the site should stay open"
  }
}

run "named_and_unnamed_together" {
  command = plan
  variables {
    allowed_ip_ranges = ["192.0.2.1"]
    allowed_ips       = { "vpn" = "198.51.100.0/24", "office-oslo" = "203.0.113.10", "home-v6" = "2001:db8::1" }
  }
  assert {
    condition     = local.restricted && length(azurerm_linux_web_app.this.site_config[0].ip_restriction) == 4
    error_message = "one unnamed and three named rules expected"
  }
  assert {
    condition = [for r in azurerm_linux_web_app.this.site_config[0].ip_restriction : "${r.name}=${r.ip_address}@${r.priority}"] == [
      "allow-ip-1=192.0.2.1/32@100",
      "home-v6=2001:db8::1/128@300",
      "office-oslo=203.0.113.10/32@301",
      "vpn=198.51.100.0/24@302",
    ]
    error_message = "named rules should use the map key as name, in key order, with bare addresses widened to /32 or /128"
  }
}

run "bad_name_refused" {
  command = plan
  variables { allowed_ips = { "office oslo" = "203.0.113.10" } }
  expect_failures = [var.allowed_ips]
}

run "too_long_name_refused" {
  command = plan
  variables { allowed_ips = { "a-name-that-is-longer-than-32-chars" = "203.0.113.10" } }
  expect_failures = [var.allowed_ips]
}

run "bad_address_refused" {
  command = plan
  variables { allowed_ips = { "office" = "203.0.113.300" } }
  expect_failures = [var.allowed_ips]
}
