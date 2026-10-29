# The dashboard without Terraform touching Entra ID: no app registration, no
# groups, no app role assignments and no Graph permission grants. Those are
# made by whoever owns Entra (often through a request process); this
# configuration builds only the Azure side and prints what to ask them for:
#   terraform output -raw sso_app_request     the sign-in app and its roles
#   terraform output -raw graph_request       the scan identity's Graph permissions
#
# To use the module from another configuration:
#   source = "github.com/Gooseankles/terraform-azurerm-ops-dashboard?ref=v1.5.4"
module "dashboard" {
  source = "../.."

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # Azure RBAC for the scan identity (not Entra). Needs Owner, User Access
  # Administrator or Role Based Access Control Administrator on the scopes.
  shared_spn_access = var.shared_spn_access

  # --- Nothing in Entra ---
  create_sso_app          = false # the Entra team makes the sign-in app
  create_role_groups      = false # the Entra team makes the groups and assigns them to the app roles
  grant_graph_permissions = false # the Entra team grants the Graph permissions

  # The app the Entra team sends back. Blank on the first apply: SSO is off
  # and only the local admin login works until it is set.
  sso_app_client_id = var.sso_app_client_id
  sso_client_secret = var.sso_client_secret # blank = secretless (federated credential)
  admin_password    = var.admin_password

  # Customers and area roles here only name the app roles listed in
  # sso_app_request; Terraform creates no roles or groups for them.
  customers  = var.customers
  area_roles = var.area_roles

  tags = var.tags
}
