output "url" {
  description = "Dashboard address."
  value       = module.dashboard.url
}

output "web_app_principal_id" {
  description = "Object ID of the shared SPN (the web app's system-assigned identity)."
  value       = module.dashboard.web_app_principal_id
}

output "shared_spn_role_assignments" {
  description = "Roles the shared SPN got, as scope => roles."
  value       = module.dashboard.shared_spn_role_assignments
}

output "sso_app_client_id" {
  description = "Client ID of the sign-in app registration."
  value       = module.dashboard.sso_app_client_id
}

output "sso_app_request" {
  description = "What to ask the app-registration team for when create_sso_app = false."
  value       = module.dashboard.sso_app_request
}

output "sso_identity_client_id" {
  description = "Client ID of the user-assigned identity used for secretless SSO."
  value       = module.dashboard.sso_identity_client_id
}

output "history_storage_url" {
  description = "Blob endpoint of the history storage account."
  value       = module.dashboard.history_storage_url
}

output "role_groups" {
  description = "Entra security group per dashboard role (role => group object ID)."
  value       = module.dashboard.role_groups
}

output "customer_containers" {
  description = "History storage container per customer."
  value       = module.dashboard.customer_containers
}

output "customer_onboarding" {
  description = "Per customer: the consent link and role commands an admin in that tenant runs once."
  value       = module.dashboard.customer_onboarding
}

output "private_network" {
  description = "VNet integration subnet and storage private endpoint."
  value       = module.dashboard.private_network
}

output "secret_vault_uri" {
  description = "Address of the key vault holding the secrets entered in Settings."
  value       = module.dashboard.secret_vault_uri
}

output "resource_group_name" {
  description = "Resource group the dashboard lives in."
  value       = module.dashboard.resource_group_name
}

output "web_app_id" {
  description = "Resource ID of the web app."
  value       = module.dashboard.web_app_id
}

output "deploy_webhook_url" {
  description = "With continuous_deployment: the URL that makes the app pull its image again. Holds the publishing password; put it in the dashboard repo's STABLE_DEPLOY_WEBHOOKS secret (one URL per line) so Promote to stable updates this app. null otherwise."
  sensitive   = true
  value       = module.dashboard.deploy_webhook_url
}

output "graph_request" {
  description = "What to ask an Entra admin for when grant_graph_permissions = false: the scan identity's Graph application permissions."
  value       = module.dashboard.graph_request
}
