# --- Continuous deployment: GitHub Actions restarts the web app, no publishing password ---
#
# With continuous_deployment the dashboard repo's "Promote to stable" workflow signs in to Azure as this identity
# through GitHub's OIDC token (a federated credential, so there is no secret anywhere) and restarts the web app. A
# restart makes App Service pull the image again, so it picks up the moved :stable tag. The identity may only read and
# restart this one web app.

resource "azurerm_user_assigned_identity" "deploy" {
  count               = var.continuous_deployment ? 1 : 0
  name                = "id-${var.name}-deploy"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# Trusts tokens GitHub issues to workflow runs whose subject matches exactly (default: the dashboard repo's
# "stable" environment, which the Promote to stable workflow's deploy job uses).
resource "azurerm_federated_identity_credential" "deploy_github" {
  count                     = var.continuous_deployment ? 1 : 0
  name                      = "github-deploy"
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy[0].id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = var.deploy_github_subject
}

# Tighter than Website Contributor, which could also change app settings and read the publishing credentials.
resource "azurerm_role_definition" "deploy" {
  count             = var.continuous_deployment ? 1 : 0
  name              = "Cirrus Watch deploy (${var.name})"
  scope             = azurerm_resource_group.this.id
  description       = "Read and restart the Cirrus Watch web app ${var.name} so it pulls its image again."
  assignable_scopes = [azurerm_resource_group.this.id]

  permissions {
    actions = [
      "Microsoft.Web/sites/read",
      "Microsoft.Web/sites/restart/action",
    ]
  }
}

resource "azurerm_role_assignment" "deploy" {
  count              = var.continuous_deployment ? 1 : 0
  scope              = azurerm_linux_web_app.this.id
  role_definition_id = azurerm_role_definition.deploy[0].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.deploy[0].principal_id
  principal_type     = "ServicePrincipal"
}
