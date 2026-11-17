# The image input: the registry host is split from the image name for App Service, and registry credentials
# are passed through. Mock providers, nothing is created. Run with: terraform init && terraform test


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

run "default_is_vivicta_latest" {
  command = plan
  assert {
    condition     = local.registry_url == "https://containers.vivicta.ghe.com" && local.image_name == "vivicta-public-cloud/cirrus-ops-dashboard:latest"
    error_message = "the default should be :latest from containers.vivicta.ghe.com, with the host split off"
  }
}

run "digest_keeps_path" {
  command = plan
  variables { image = "containers.vivicta.ghe.com/vivicta-public-cloud/cirrus-ops-dashboard@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" }
  assert {
    condition     = local.image_name == "vivicta-public-cloud/cirrus-ops-dashboard@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    error_message = "a digest must stay on the image name"
  }
}

run "docker_hub_without_host" {
  command = plan
  variables { image = "trozity/azure-ops-dashboard:0.72.0.0" }
  assert {
    condition     = local.registry_url == "https://index.docker.io" && local.image_name == "trozity/azure-ops-dashboard:0.72.0.0"
    error_message = "an image without a host should come from Docker Hub"
  }
}

run "password_needs_username" {
  command = plan
  variables { registry_password = "token" }
  expect_failures = [var.registry_password]
}

run "token_secret_in_modules_vault" {
  command = apply
  variables {
    registry_username             = "someone"
    registry_password_secret_name = "ghe-pat"
  }
  assert {
    condition     = startswith(local.registry_password, "@Microsoft.KeyVault(SecretUri=") && strcontains(local.registry_password, "/secrets/ghe-pat/)")
    error_message = "the token should be a Key Vault reference to ghe-pat in the module's own vault"
  }
  assert {
    condition     = length(azurerm_role_assignment.registry_secret) == 0
    error_message = "the module's own vault already gives the app access; no extra grant"
  }
}

run "token_secret_in_existing_vault" {
  command = plan
  variables {
    registry_username             = "someone"
    registry_password_secret_name = "ghe-pat"
    registry_key_vault_id         = "/subscriptions/11111111-1111-4111-8111-111111111111/resourceGroups/rg-shared/providers/Microsoft.KeyVault/vaults/kv-shared"
  }
  assert {
    condition     = local.registry_password == "@Microsoft.KeyVault(SecretUri=https://kv-shared.vault.azure.net/secrets/ghe-pat/)"
    error_message = "the reference should point at the existing vault"
  }
  assert {
    condition     = length(azurerm_role_assignment.registry_secret) == 1
    error_message = "the app needs read access to the secret in the existing vault"
  }
}

run "secret_name_and_password_conflict" {
  command = plan
  variables {
    registry_username             = "someone"
    registry_password             = "token"
    registry_password_secret_name = "ghe-pat"
  }
  expect_failures = [var.registry_password_secret_name]
}

run "secret_needs_a_vault" {
  command = plan
  variables {
    registry_username             = "someone"
    registry_password_secret_name = "ghe-pat"
    create_secret_vault           = false
  }
  expect_failures = [azurerm_linux_web_app.this]
}
