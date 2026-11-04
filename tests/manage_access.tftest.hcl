# manage_access: false creates the resources and identities but grants nothing (no Azure role assignments,
# Graph permissions, sign-in consent or app roles) and lists every grant in access_request; the default grants
# all of it. Mock providers: no Azure sign-in, nothing is created. Run with: terraform init && terraform test

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
  name                   = "cwtest"
  location               = "norwayeast"
  resource_group_name    = "rg-cwtest"
  continuous_deployment  = true
  shared_spn_access      = [{ scope = "/subscriptions/11111111-1111-4111-8111-111111111111" }]
  admin_principal_ids    = ["22222222-2222-4222-8222-222222222222"]
  secret_vault_admin_ids = ["33333333-3333-4333-8333-333333333333"]
}

run "manual" {
  command = apply
  variables { manage_access = false }
  assert {
    condition     = length(azurerm_role_assignment.scan) == 0 && length(azurerm_role_assignment.history_app) == 0 && length(azurerm_role_assignment.secrets_app) == 0 && length(azurerm_role_assignment.secrets_admins) == 0 && length(azurerm_role_assignment.deploy) == 0 && length(azurerm_role_definition.deploy) == 0
    error_message = "Azure role assignments made"
  }
  assert {
    condition     = length(azuread_app_role_assignment.graph) == 0 && length(azuread_service_principal_delegated_permission_grant.sso) == 0 && length(azuread_app_role_assignment.role_groups) == 0 && length(azuread_app_role_assignment.admins) == 0 && length(data.azuread_service_principal.msgraph) == 0
    error_message = "Entra grants made"
  }
  assert {
    condition     = strcontains(output.access_request, "Reader on /subscriptions/11111111") && strcontains(output.access_request, "User.Read.All")
    error_message = output.access_request
  }
}

run "managed" {
  command = plan
  assert {
    condition     = length(azurerm_role_assignment.scan) == 3 && length(azurerm_role_assignment.history_app) == 1 && length(azurerm_role_assignment.secrets_admins) == 1 && length(azurerm_role_assignment.deploy) == 1 && length(azuread_service_principal_delegated_permission_grant.sso) == 1 && length(azuread_app_role_assignment.role_groups) > 0 && output.access_request == "Not needed: Terraform granted the access."
    error_message = "default should grant everything"
  }
}
