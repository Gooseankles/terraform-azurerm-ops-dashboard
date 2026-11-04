output "url" {
  description = "Dashboard address."
  value       = local.site_url
}

output "resource_group_name" {
  description = "Resource group the dashboard lives in."
  value       = azurerm_resource_group.this.name
}

output "stable_deployment" {
  description = "With continuous_deployment: this web app's entry for the dashboard repo's STABLE_DEPLOYMENTS variable (a JSON list of these), so Promote to stable restarts it. IDs and names only, no secret. null otherwise."
  value = var.continuous_deployment ? {
    clientId       = azurerm_user_assigned_identity.deploy[0].client_id
    tenantId       = azurerm_user_assigned_identity.deploy[0].tenant_id
    subscriptionId = element(split("/", azurerm_linux_web_app.this.id), 2)
    resourceGroup  = azurerm_resource_group.this.name
    name           = azurerm_linux_web_app.this.name
  } : null
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
        value "Admin"  - everything: every tenant, plus Settings
        value "User"   - every tenant: read and run%{for k, c in var.customers}
        value "Admin-${k}"  - ${c.name}: read and run its scans
        value "User-${k}"   - ${c.name}: read and run its scans%{endfor}%{for role, r in local.area_role_defs}
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
  description = "What to ask an Entra admin for when grant_graph_permissions or manage_access = false: the scan identity's Graph application permissions."
  value       = var.grant_graph_permissions && var.manage_access ? "Not needed: Terraform granted the Graph permissions." : <<-EOT
    Microsoft Graph application permissions for Cirrus Watch (${var.name}) scan identity
    - Service principal (managed identity) object ID: ${azurerm_linux_web_app.this.identity[0].principal_id}
    - Application permissions, with admin consent (Privileged Role Administrator or Global Administrator):
    %{for p in local.all_graph_permissions}    ${p}
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
      ], length(c.extra_graph_checks) == 0 ? [
      "   The dashboard's extra Graph checks are on by default: turn them off in Settings > ${k} tab > Extra Graph checks (none).",
      ] : [
      "   Extra checks (${join(", ", c.extra_graph_checks)}): also ${join(", ", distinct(flatten([for x in c.extra_graph_checks : local.extra_graph_permission_map[x]])))}, with admin consent.",
      "   They run by default; Settings > ${k} tab > Extra Graph checks lists fewer, or none.",
      ], [
      "4. Read roles for it, per subscription (or on a management group):",
      ], [
      for pair in setproduct(length(c.subscription_ids) > 0 ? c.subscription_ids : ["<subscription-id>"], local.scan_roles) :
      "     az role assignment create --assignee ${c.client_id != "" ? c.client_id : "<client-id>"} --role \"${pair[1]}\" --scope /subscriptions/${pair[0]}"
    ]))
  }
}

output "private_network" {
  description = "VNet integration subnet, how storage and the vault are reached, their private endpoints and the web app's own private endpoint (null when private_network = false)."
  value = var.private_network ? {
    app_subnet_id         = local.app_subnet_id
    private_access        = var.private_access
    private_endpoint_id   = local.history_private ? azurerm_private_endpoint.history_blob[0].id : null
    vault_endpoint_id     = local.vault_private ? azurerm_private_endpoint.secret_vault[0].id : null
    storage_public_access = !var.create_history_storage ? null : local.history_public_off ? "Disabled" : (local.history_private ? "Enabled, private endpoint only (firewall denies all networks)" : "Enabled, integration subnet only")
    app_endpoint_id       = local.app_private ? azurerm_private_endpoint.app[0].id : null
    app_private_ip        = local.app_private ? azurerm_private_endpoint.app[0].private_service_connection[0].private_ip_address : null
    app_public_access     = local.app_public_off ? "Disabled" : local.app_private ? (length(local.allowed_ip_ranges) + length(var.allowed_subnet_ids) > 0 ? "Enabled, private endpoint and allowed IPs/subnets only" : "Enabled, private endpoint only (access restrictions deny all networks)") : "Enabled"
  } : null
}

# Every grant Terraform leaves out with manage_access = false, one line each.
locals {
  app_principal = azurerm_linux_web_app.this.identity[0].principal_id
  manual_azure_roles = concat(
    [for k, a in local.scan_role_assignments : "${a.role} on ${a.scope} -> web app identity ${local.app_principal}"],
    var.create_history_storage ? ["Storage Blob Data Contributor on ${azurerm_storage_account.history[0].id} -> web app identity ${local.app_principal}"] : [],
    var.create_secret_vault ? concat(
      ["Key Vault Secrets Officer on ${azurerm_key_vault.secrets[0].id} -> web app identity ${local.app_principal}"],
      [for id in var.secret_vault_admin_ids : "Key Vault Secrets Officer on ${azurerm_key_vault.secrets[0].id} -> ${id} (break-glass)"]
    ) : [],
    var.continuous_deployment ? ["A custom role with only Microsoft.Web/sites/read and Microsoft.Web/sites/restart/action, assignable at ${azurerm_resource_group.this.id} (not Website Contributor: it can read the app settings), on ${azurerm_linux_web_app.this.id} -> deploy identity ${azurerm_user_assigned_identity.deploy[0].principal_id}"] : [],
  )
  manual_sign_in = !var.create_sso_app ? [] : concat(
    ["Grant admin consent for openid and profile on Enterprise application ${azuread_service_principal.dashboard[0].object_id} (Permissions page)"],
    var.create_role_groups
    ? [for role, r in local.dashboard_roles : "App role ${role} -> group ${azuread_group.role[role].object_id}"]
    : [for k, m in local.role_members : "App role ${m.role} -> ${m.member}"],
  )
}

output "access_request" {
  description = "With manage_access = false: every grant Terraform left out (Azure roles, Graph permissions, sign-in consent and app roles), with scopes and object IDs, for an admin to add by hand."
  value       = var.manage_access ? "Not needed: Terraform granted the access." : <<-EOT
    Access for Cirrus Watch (${var.name}), all to be added by an admin. The app reports what is missing until then.

    Azure role assignments (Owner or User Access Administrator on the scope):
    %{for l in local.manual_azure_roles}  - ${l}
    %{endfor}%{if length(local.manual_azure_roles) == 0}  - none
    %{endif}
    Microsoft Graph application permissions with admin consent (Privileged Role Administrator or Global
    Administrator) for web app identity ${local.app_principal}:
    %{for p in local.all_graph_permissions}  - ${p}
    %{endfor}%{if length(local.all_graph_permissions) == 0}  - none
    %{endif}
    Sign-in app (Application Administrator, or an owner of the Enterprise application for the app roles):
    %{for l in local.manual_sign_in}  - ${l}
    %{endfor}%{if length(local.manual_sign_in) == 0}  - none (create_sso_app = false: see sso_app_request)
    %{endif}
  EOT
}
