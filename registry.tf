# --- Registry token in an existing key vault (registry_key_vault_id) ---
#
# With registry_password_secret_name the web app's app setting is a Key Vault reference, which App Service resolves with
# the web app's system-assigned identity. In the module's own vault that identity already has Key Vault Secrets
# Officer. In a vault you bring, it gets Key Vault Secrets User on the one secret only (not the whole vault). The
# secret itself is never written by Terraform, so the token stays out of the state. Without manage_access the grant
# is yours to make: the identity is the web app's principal (output web_app_principal_id).

resource "azurerm_role_assignment" "registry_secret" {
  count                = var.registry_password_secret_name != "" && var.registry_key_vault_id != "" && var.manage_access ? 1 : 0
  scope                = "${var.registry_key_vault_id}/secrets/${var.registry_password_secret_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
