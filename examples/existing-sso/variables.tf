variable "subscription_id" {
  description = "Subscription the dashboard is deployed in."
  type        = string
}

variable "name" {
  description = "Short name used in resource names."
  type        = string
}

variable "location" {
  type    = string
  default = "norwayeast"
}

variable "resource_group_name" {
  description = "Blank = rg-<name>."
  type        = string
  default     = ""
}

variable "shared_spn_access" {
  description = "Scopes where the scan identity gets Azure roles (default Reader and Cost Management Reader)."
  type = list(object({
    scope = string
    roles = optional(list(string), ["Reader", "Cost Management Reader"])
  }))
  default = []
}

variable "sso_app_client_id" {
  description = "Client ID of the sign-in app the Entra team made. Blank until they send it."
  type        = string
  default     = ""
}

variable "sso_client_secret" {
  description = "Only if the Entra team gives a client secret instead of the federated credential."
  type        = string
  default     = ""
  sensitive   = true
}

variable "admin_password" {
  description = "Local admin login (username admin) until SSO works. Blank = off."
  type        = string
  default     = ""
  sensitive   = true
}

variable "customers" {
  description = "Customer tenants; see the module's variables.tf. Here only name, tenant_id and area_roles matter for Entra (role names)."
  type = map(object({
    name             = string
    tenant_id        = string
    subscription_ids = optional(list(string), [])
    client_id        = optional(string, "")
    enabled          = optional(bool, true)
    area_roles = optional(map(object({
      read_members = optional(list(string), [])
      run_members  = optional(list(string), [])
    })), {})
  }))
  default = {}
}

variable "area_roles" {
  description = "Areas (identity, platform, security, cost) whose <Area>.Read / <Area>.Run roles to ask the Entra team for."
  type = map(object({
    read_members = optional(list(string), [])
    run_members  = optional(list(string), [])
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
