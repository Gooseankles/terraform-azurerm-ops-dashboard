output "url" {
  description = "Dashboard address."
  value       = module.dashboard.url
}

output "sso_app_request" {
  description = "Send to the Entra team: the sign-in app registration, its app roles and the federated credential."
  value       = module.dashboard.sso_app_request
}

output "graph_request" {
  description = "Send to the Entra team: the Graph application permissions the scan identity needs (admin consent)."
  value       = module.dashboard.graph_request
}

output "web_app_principal_id" {
  description = "Object ID of the scan identity (the web app's system-assigned identity)."
  value       = module.dashboard.web_app_principal_id
}
