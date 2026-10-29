output "url" {
  description = "Dashboard address."
  value       = local.site_url
}

output "resource_group_name" {
  description = "Resource group the dashboard lives in."
  value       = azurerm_resource_group.this.name
}

output "deploy_webhook_url" {
  description = "With continuous_deployment: the URL that makes the app pull its image again. Holds the publishing password; put it in the dashboard repo's STABLE_DEPLOY_WEBHOOKS secret (one URL per line) so Promote to stable updates this app. null otherwise."
  sensitive   = true
  value = var.continuous_deployment ? format(
    "https://%s:%s@%s.scm.azurewebsites.net/api/registry/webhook",
    azurerm_linux_web_app.this.site_credential[0].name,
    azurerm_linux_web_app.this.site_credential[0].password,
    var.name,
  ) : null
}

output "web_app_id" {
  description = "Resource ID of the web app."
  value       = azurerm_linux_web_app.this.id
}

output "shared_spn_role_assignments" {
  description = "Roles the shared SPN got from shared_spn_access, as scope => roles."
  value = {
    for a in var.shared_spn_access : a.scope => a.roles...
  }
}

output "history_storage_url" {
  description = "Blob endpoint of the history storage account (null when create_history_storage = false)."
  value       = var.create_history_storage ? azurerm_storage_account.history[0].primary_blob_endpoint : null
}

output "secret_vault_uri" {
  description = "Address of the key vault holding the secrets entered in Settings (null when create_secret_vault = false)."
  value       = var.create_secret_vault ? azurerm_key_vault.secrets[0].vault_uri : null
}

output "web_app_principal_id" {
  description = "Object ID of the web app's system-assigned identity (the shared SPN). Extra roles can go in shared_spn_access or be granted elsewhere with this ID."
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}

output "sso_app_client_id" {
  description = "Client ID of the sign-in app registration."
  value       = local.sso_client_id
}

output "sso_app_request" {
  description = "What to ask the app-registration team for when create_sso_app = false."
  value       = var.create_sso_app ? "Not needed: Terraform created the app registration." : <<-EOT
    Sign-in app registration for Cirrus Watch (${var.name})
    - Single tenant (this organization only).
    - Platform Web, redirect URI: ${local.redirect_uri}
      Front-channel logout / home page: ${local.site_url}
    - No API permissions needed beyond the default sign-in (openid, profile).
    - App roles (allowed member types Users/Groups):
        value "Admin"  - everything: every tenant, Run now, Settings
        value "User"   - read-only, every tenant%{for k, c in var.customers}
        value "Admin-${k}"  - ${c.name}: read and run its scans
        value "User-${k}"   - ${c.name}: read-only%{endfor}%{for role, r in local.area_role_defs}
        value "${role}"  - ${r.description}%{endfor}
    - Enterprise application: "Assignment required" = Yes; assign groups (or people) to the roles.
    - Credential, preferred (no secret): Federated credential, scenario "Managed identity" / "Other issuer":
        issuer:   ${local.sso_fic_issuer}
        subject:  ${local.sso_fic_subject}   (object ID of managed identity id-${var.name}-sso)
        audience: api://AzureADTokenExchange
      Otherwise a client secret, set as sso_client_secret.
    Send back: the Application (client) ID -> sso_app_client_id.
  EOT
}

output "graph_request" {
  description = "What to ask an Entra admin for when grant_graph_permissions = false: the scan identity's Graph application permissions."
  value       = var.grant_graph_permissions ? "Not needed: Terraform granted the Graph permissions." : <<-EOT
    Microsoft Graph application permissions for Cirrus Watch (${var.name}) scan identity
    - Service principal (managed identity) object ID: ${azurerm_linux_web_app.this.identity[0].principal_id}
    - Application permissions, with admin consent (Privileged Role Administrator or Global Administrator):
    %{for p in var.graph_permissions}    ${p}
    %{endfor}- All read-only. No directory role is needed.
    - With PowerShell: New-MgServicePrincipalAppRoleAssignment for each, resource = Microsoft Graph
      (appId 00000003-0000-0000-c000-000000000000).
  EOT
}

output "sso_identity_client_id" {
  description = "Client ID of the user-assigned identity used for secretless SSO."
  value       = azurerm_user_assigned_identity.sso.client_id
}

output "role_groups" {
  description = "Entra security group per dashboard role (role => group object ID). Add people to these groups; one person can be in several customers' groups."
  value       = { for role, g in azuread_group.role : role => g.object_id }
}

output "customer_containers" {
  description = "History storage container per customer."
  value       = local.customer_containers
}

output "customer_onboarding" {
  description = "Per customer: the app registration to make in that tenant and the permissions to give it. Terraform does not touch customer tenants."
  value = {
    for k, c in var.customers : k => join("\n", concat([
      "${c.name} (tenant ${c.tenant_id})",
      "1. In that tenant, register an app (single tenant), e.g. \"Cirrus Watch\". ${c.client_id != "" ? "Set: ${c.client_id}." : "Then put its Application (client) ID in customers.${k}.client_id (or in Settings) and apply."}",
      "2. On the app: Certificates & secrets > Client secrets > New client secret. Paste its Value in the dashboard:",
      "     Settings > Customer tenants > ${k} > Edit > Client secret (never in Terraform). Note the expiry date.",
      "3. API permissions > Microsoft Graph > Application: ${join(", ", var.graph_permissions)}; then Grant admin consent.",
      "4. Read roles for it, per subscription (or on a management group):",
      ], [
      for pair in setproduct(length(c.subscription_ids) > 0 ? c.subscription_ids : ["<subscription-id>"], local.scan_roles) :
      "     az role assignment create --assignee ${c.client_id != "" ? c.client_id : "<client-id>"} --role \"${pair[1]}\" --scope /subscriptions/${pair[0]}"
    ]))
  }
}

output "private_network" {
  description = "VNet integration subnet, how storage and the vault are reached, and their private endpoints (null when private_network = false)."
  value = var.private_network ? {
    app_subnet_id         = local.app_subnet_id
    private_access        = var.private_access
    private_endpoint_id   = local.history_private ? azurerm_private_endpoint.history_blob[0].id : null
    vault_endpoint_id     = local.vault_private ? azurerm_private_endpoint.secret_vault[0].id : null
    storage_public_access = local.history_private ? "Disabled" : "Enabled, integration subnet only"
  } : null
}
