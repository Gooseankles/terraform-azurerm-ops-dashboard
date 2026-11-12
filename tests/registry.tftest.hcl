# image and registry: the registry host is taken from the start of image (none = Docker Hub) and cut off the name
# App Service gets; registry_username and registry_password are passed on only when set, and only together.
# Mock providers: no Azure sign-in, nothing is created. Run with: terraform init && terraform test

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
}

run "docker_hub_default" {
  command = plan
  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_url == "https://index.docker.io" && azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "trozity/azure-ops-dashboard:stable"
    error_message = "the default image should come from Docker Hub, name unchanged"
  }
  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_username == null
    error_message = "no registry sign-in by default"
  }
}

run "private_registry_by_digest" {
  command = plan
  variables {
    image             = "ghcr.io/contoso/ops-dashboard@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    registry_username = "contoso-bot"
    registry_password = "not-a-real-token"
  }
  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_url == "https://ghcr.io" && azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "contoso/ops-dashboard@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    error_message = "the registry host should be split from the image name"
  }
  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_username == "contoso-bot"
    error_message = "the user name should reach App Service"
  }
}

run "registry_with_port_gets_latest" {
  command = plan
  variables { image = "registry.contoso.example:5000/ops/dashboard" }
  assert {
    condition     = azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_registry_url == "https://registry.contoso.example:5000" && azurerm_linux_web_app.this.site_config[0].application_stack[0].docker_image_name == "ops/dashboard:latest"
    error_message = "a registry port is not a tag"
  }
}

run "user_name_without_password" {
  command = plan
  variables {
    image             = "ghcr.io/contoso/ops-dashboard:1.0.0"
    registry_username = "contoso-bot"
  }
  expect_failures = [azurerm_linux_web_app.this]
}
