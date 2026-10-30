# Cirrus Watch: Terraform module

Deploys [Cirrus Watch](https://hub.docker.com/r/trozity/azure-ops-dashboard) (a self-hosted dashboard of
read-only Azure and Entra ID tenant checks) to Azure App Service. The module is the root of this repo;
[examples/default](examples/default) is a ready-made root configuration that calls it, or call it from your own
configuration (see [Use the module](#use-the-module)).
It needs Terraform 1.6 or newer and azurerm 5.x (azuread 3.x, random 3.x).

How the pieces are wired and what happens at start-up, sign-in and a scan is in the dashboard's
[setup low-level design](https://github.com/Gooseankles/cirrus-watch/blob/main/docs/lld-setup.md); day-to-day running in its [operations guide](https://github.com/Gooseankles/cirrus-watch/blob/main/docs/operations.md).

One `apply` creates:

- Resource group, Linux App Service plan (B1) and the web app running `trozity/azure-ops-dashboard:stable`
  (port 7070, `/home/data` storage, Always On, HTTPS only, random session secret).
- **Shared SPN**: the web app's system-assigned identity, used by every tool that has no SPN override in Settings.
  `shared_spn_access` says where it gets access and with which roles (default Reader and Cost Management Reader,
  which is all the scans need), plus the Microsoft Graph application permissions the tools use.
- **Secretless SSO**: an Entra app registration with the Admin and User roles, "assignment required" on, a
  user-assigned identity attached to the web app, and a federated credential so no client secret exists.
- Role assignments for the users or groups in `admin_principal_ids` and `user_principal_ids`.
- **History storage** (`create_history_storage`, on by default): a storage account with account keys off, a private
  `dashboard` container, and Storage Blob Data Contributor for the web app's identity. Every scan run is kept there
  (`history_retention_days`, default 730), so the dashboard shows trends and what was new or resolved in each run.
  Off = results stay on the app's own disk (`/home/data`, 365 days by default).
- **Secret vault** (`create_secret_vault`, on by default): a key vault (RBAC, soft delete 90 days) for the client
  secrets entered in Settings (SPN overrides, customer tenants). The web app gets Key Vault Secrets Officer on it and
  reads and writes it with its managed identity; Terraform never writes a secret, so none reach the state. Add
  object IDs to `secret_vault_admin_ids` for people who may see the secrets in the portal. Purge protection is off
  by default (`secret_vault_purge_protection`), so a deleted deployment can reuse the name.

Every identity's permissions, including the app registration each customer makes in their own tenant, are listed in
[docs/permissions.md](docs/permissions.md).

## Shared SPN access

Each entry is a scope and, optionally, its roles:

```hcl
shared_spn_access = [
  # Whole tenant (the tenant root management group's ID is the tenant ID), default roles.
  { scope = "/providers/Microsoft.Management/managementGroups/<tenant-id>" },
  # One subscription only, without Key Vault item checks.
  { scope = "/subscriptions/<id>", roles = ["Reader", "Cost Management Reader"] },
]

# Optional: scan only these subscriptions (blank = every subscription the shared SPN can see).
scan_subscription_ids = ["<id>"]
```

The `shared_spn_role_assignments` output lists what was granted. The old `scan_scopes` list still works (each
entry becomes a scope with the default roles) but is deprecated; move it to `shared_spn_access`.

## Access restrictions

To let only some networks reach the site (the portal's "Enabled from selected virtual networks and IP addresses"):

```hcl
allowed_ip_ranges  = ["203.0.113.10", "198.51.100.0/24"]  # office / VPN egress IPs; a bare IP = that one address
allowed_subnet_ids = []                                   # optional: subnets with the Microsoft.Web service endpoint
```

Any entry turns the default action to Deny, so every other address gets a 403 from App Service before it reaches
the app. The Kudu (scm) site follows the same rules. Sign-in keeps working because the Entra redirect goes through
the user's own browser. Empty lists (the default) leave the site open to the internet, with sign-in still required.

## Customer tenants

Leave `customers` out to watch only your own tenant: no customer containers, roles or groups are made, and
customers can be added later without rebuilding anything ([single tenant or several](https://github.com/Gooseankles/cirrus-watch/blob/main/docs/hld.md#single-tenant-or-several)).

```hcl
customers = {
  acme = {
    name             = "Acme AS"
    tenant_id        = "00000000-0000-0000-0000-000000000000"
    client_id        = ""                   # the app registration made in Acme's tenant (set it once it exists)
    subscription_ids = []                   # empty = every subscription that app can see there
    admin_members    = ["<user object id>"] # Admin-acme: see and run Acme's scans
    user_members     = ["<user object id>"] # User-acme: the same (kept for older setups)
    area_roles = {                          # optional: Security.Read-acme
      security = { read_members = ["<user object id>"] }
    }
  }
}
```

Each key (lowercase letters, digits, - or _) names the app roles `Admin-<key>` and `User-<key>`, the role groups
and the storage container `dashboard-<key>`. With at least one customer, Terraform adds:

- a storage container per customer.

In each customer tenant, by hand: register an app, give it a client secret, the Graph application permissions with
admin consent and Reader and Cost Management Reader ([details](docs/permissions.md#customer-tenant-app-other-tenants)).
Set its `client_id` and apply again (or enter it in Settings), and paste the secret in the dashboard's Settings →
Customer tenants → Edit. The secret goes to the secret vault and is never a Terraform value, so it stays out of
the state. `terraform output customer_onboarding` prints the steps and
the `az role assignment create` commands per customer. So the first apply can run before the app registrations
exist.

A customer's own app cannot trust the dashboard's managed identity instead of a secret: Entra refuses a managed
identity of another tenant in a federated credential (AADSTS700236).

**Upgrading from 0.11.0.x / 0.11.1.0:** the shared multi-tenant scan app (0.11.0.0) and the managed identity
`id-<name>-customers` (0.11.0.1) are gone; the next apply deletes them. Federated credentials added to customer
apps for that identity can be deleted; give each app a client secret instead.

**Upgrading to 1.3.0:** the default names of the sign-in app and the role groups changed from "Azure tools
dashboard (&lt;name&gt;)" to "Cirrus Watch (&lt;name&gt;)". The next apply renames them in place (same objects, IDs,
members and assignments). Set `role_group_prefix = "Azure tools dashboard (<name>)"` to keep the old group names.

## Area roles

So each team sees only its own scans, `area_roles` creates an `<Area>.Read` app role over every tenant, and a
customer's `area_roles` creates `<Area>.Read-<key>` for that tenant. Areas are `identity`, `platform`, `security` and
`cost`; which scans each holds is in the dashboard's
[sign-in and roles guide](https://github.com/Gooseankles/cirrus-watch/blob/main/docs/guides/sign-in-and-roles.md#roles). Whoever may see a scan may also run it and accept its
findings, so there are no Run roles (since v1.5.0; `run_members` still works and joins the Read role, and the old
`.Run` roles and their groups are removed at the next apply). An area only gets a role (and group) when listed;
members may be empty and added to the group later.

```hcl
area_roles = {
  identity = { read_members = ["<object id>"] }                 # Identity.Read
  security = { read_members = [] }
  platform = {}
}
```

Needs dashboard image 0.53.0.0 or newer.

## Role groups

With `create_role_groups = true` (the default), every role (Admin, User, Admin-&lt;key&gt;, User-&lt;key&gt;, the area roles) gets an
Entra security group assigned to that app role; `admin_principal_ids`, `user_principal_ids` and each customer's
`admin_members` / `user_members` become members. Later, add people to the groups (`role_groups` output) in Entra;
one person can be in several customers' groups. Assigning groups to app roles needs Entra ID P1 or P2. Set it to
`false` to assign people to the roles directly, as before 0.11.

**Upgrading:** with groups on, the direct Admin/User assignments of an earlier deployment are replaced by the
groups (same people). Whoever runs Terraform then also needs to create groups (Groups Administrator, or
`Group.ReadWrite.All`).

## Private network

```hcl
private_network    = true
vnet_address_space = ["10.90.0.0/24"]  # a VNet is created: /26 for the app, /27 for private endpoints
```

The web app gets outbound VNet integration and reaches the history storage account and the secret vault through
private endpoints (with `privatelink.blob.core.windows.net` and `privatelink.vaultcore.azure.net` private DNS zones
linked to the VNet). Their public network access stays on but is restricted: the firewalls deny every network
(default action Deny, trusted Azure services allowed), so only the private endpoints get through. To use an existing network instead, set
`vnet_integration_subnet_id` (delegated to `Microsoft.Web/serverFarms`), `private_endpoint_subnet_id` and, if the
DNS zones live in a hub, `blob_private_dns_zone_id` and `vault_private_dns_zone_id`. `vnet_route_all = true` sends all outbound traffic through the VNet (it then needs a
NAT gateway or firewall for internet access). The App Service plan must support VNet integration (Basic or higher).

Without private endpoints:

```hcl
private_network            = true
private_access             = "service_endpoint"
vnet_integration_subnet_id = "/subscriptions/.../virtualNetworks/vnet-spoke/subnets/snet-dashboard"
```

The storage account and the secret vault keep their public endpoints, but their firewalls deny everything except
the integration subnet (through the `Microsoft.Storage` and `Microsoft.KeyVault` service endpoints). No private
endpoints, private DNS zones or second subnet. An existing subnet needs both service endpoints turned on before the
apply (a created one gets them). The app's traffic to them goes through the VNet even with `vnet_route_all = false`.
The storage account must be in the VNet's region or its paired region. Trusted Azure services stay allowed, as with
private endpoints; they still need a role to read anything.
Terraform creates the containers through the storage data plane, so run it from a network that can reach the
private endpoint, or apply once with `private_network = false` first so the containers exist.

### The web app behind a private endpoint

```hcl
private_network      = true
app_private_endpoint = true
```

The web app (and its scm site) gets an inbound private endpoint in the private endpoint subnet and its public
network access is turned off: `https://<name>.azurewebsites.net` then answers only on the endpoint's private IP
(`private_network.app_private_ip` output). Users need a network path to the VNet (VPN, ExpressRoute or a peered
VNet) and DNS that resolves `privatelink.azurewebsites.net`: the zone is created and linked to the VNet, or set
`app_private_dns_zone_id` to a hub zone; on-premises DNS must forward `azurewebsites.net` to Azure DNS (for example
through a Private DNS Resolver). Sign-in still works: the redirect goes through the user's browser, which is on that
network. It works with either `private_access`; with `"service_endpoint"` and an existing VNet set
`private_endpoint_subnet_id` too. `allowed_ip_ranges`, `allowed_subnet_ids` and `continuous_deployment` are refused
with it (the public address they act on is off). Basic plans or higher support it.

`allowed_subnet_ids` is a different thing: it keeps the public address and lets in traffic from subnets with the
`Microsoft.Web` service endpoint turned on; it creates no private endpoint.

**Subnet sizes.** The integration subnet needs one address per app instance, and twice that for a short while
during a scale operation or platform upgrade; Azure keeps 5 addresses in every subnet. A /28 (11 usable) is
enough for this app on one or a few instances; Microsoft recommends /26 when a plan may scale out a lot or the
subnet is shared by several plans. The private endpoint subnet needs one address per endpoint (up to three
here), so a /28 is plenty there too.

## Load alarms

```hcl
alert_emails = ["ops@contoso.com"]
```

Azure Monitor emails these addresses when the App Service plan's average CPU (`alert_cpu_pct`, default 85) or
memory (`alert_memory_pct`, default 85) stays above the limit for 15 minutes, or when the app answers with more than
`alert_5xx_count` (10) server errors in 15 minutes. These come from Azure, so they also arrive when the dashboard
itself is down. Three alert rules and an action group, about 0.30 USD a month; nothing is created while the list is
empty. Which scans caused the load is on the dashboard's Server load page (Admin).

## Who can run it

(All in one table in [docs/permissions.md](docs/permissions.md#whoever-runs-terraform).)

- `Contributor` on the subscription for the app itself.
- `Owner`, `User Access Administrator` or `Role Based Access Control Administrator` on each `shared_spn_access` scope,
  and on the dashboard's resource group (the storage account and secret vault role assignments).
- Entra: `Application Administrator` (app registration), and `Privileged Role Administrator` or Global
  Administrator for the Graph permissions. Set `grant_graph_permissions = false` if you do not have that role
  and ask an admin to grant them later. With `create_role_groups` (the default) also `Groups Administrator`.
  `grant_sso_consent` (default true) grants admin consent for sign-in (openid, profile). A pipeline service
  principal needs the Microsoft Graph application permission `DelegatedPermissionGrant.ReadWrite.All` (admin
  consented) for it; a person needs Application Administrator or Global Administrator. With `false`, an admin clicks
  "Grant admin consent" under Enterprise applications → the app → Permissions, or users in tenants that block
  user consent see "Need admin approval".
- `Network Contributor` (on the subscription, or on the existing VNet) when `private_network = true`.
- azurerm 5 registers no resource providers by itself. The root provider block registers `Microsoft.Web`,
  `Microsoft.Storage`, `Microsoft.ManagedIdentity` and `Microsoft.KeyVault`, which needs rights on the subscription; if they are already
  registered and you lack those rights, remove `resource_providers_to_register` from `versions.tf`.

## Where to find what Terraform made in Entra

| What | Where in the portal |
| --- | --- |
| Sign-in app (roles, redirect URI, federated credential) | App registrations → **Cirrus Watch (&lt;name&gt;)** |
| Scan identity (the shared SPN) and its Graph permissions | Enterprise applications → set **Application type = Managed Identities** → **&lt;name&gt;** (the web app's name) → Permissions |
| Sign-in identity (trusted by the sign-in app, no permissions) | Enterprise applications → Managed Identities → **id-&lt;name&gt;-sso** |

The scan identity is the web app's system-assigned managed identity. A managed identity has no app registration,
so it is only under Enterprise applications, and the default filter there (Enterprise Applications) hides it. Its
object ID is the `web_app_principal_id` output; its Azure roles are on each `shared_spn_access` scope under Access
control (IAM).

## When you may not create app registrations

Some tenants hand out app registrations only through a request process. Then:

1. Set `create_sso_app = false` (and an `admin_password` so you can get in meanwhile) and apply. This builds the
   web app and the user-assigned identity, with SSO off.
2. Run `terraform output -raw sso_app_request` and send that text to the team. It lists the redirect URI, the
   app roles (Admin, User, a pair per customer and the area roles in `area_roles`), "assignment required", and the federated credential (issuer, subject = the identity's object ID,
   audience), so no secret is needed.
3. Put the client ID they send back in `sso_app_client_id` (and `sso_client_secret` only if they gave a secret
   instead of the federated credential) and apply again. The team assigns people to Admin/User.

A full configuration for this, with no app registration and no groups made by Terraform, is in
[examples/existing-sso](examples/existing-sso).

Granting the Graph permissions to the shared SPN is a separate Entra admin action (Privileged Role
Administrator); if that is also done by request, set `grant_graph_permissions = false` and ask for
`User.Read.All`, `GroupMember.Read.All`, `Application.Read.All`, `EntitlementManagement.Read.All`,
`RoleManagement.Read.Directory`, `AuditLog.Read.All`, `Policy.Read.All`, `DelegatedPermissionGrant.Read.All`,
`LicenseAssignment.Read.All`, `PrivilegedEligibilitySchedule.Read.AzureADGroup` and
`PrivilegedAssignmentSchedule.Read.AzureADGroup` as
application permissions for the `web_app_principal_id` output.

## Run

```bat
cd examples/default
copy terraform.tfvars.example terraform.tfvars   # then fill it in
az login
terraform init
terraform plan
terraform apply
```

Open the `url` output and sign in. State is local by default; for a team, add an `azurerm` backend
(storage account) to `examples/default/versions.tf`.

**Upgrading an existing deployment** (from before the module): run `terraform init -upgrade`, then `plan`. The
`moved` blocks in `examples/default/main.tf` carry the resources over to `module.dashboard`, so the plan should show moves and
no replacements.

**Upgrading to 0.12:** the apply adds the secret vault and its role assignment (register `Microsoft.KeyVault` if
your runner cannot). On its first start the app moves the client secrets it finds in `settings.json` and
`tenants.json` into the vault and removes them from the files; nothing has to be re-entered.

## Use the module

The module has no provider blocks; pass your own. The azurerm provider needs `storage_use_azuread = true` when
`create_history_storage` is on.

```hcl
provider "azurerm" {
  features {}
  subscription_id     = "<id>"
  storage_use_azuread = true
}

module "dashboard" {
  source = "github.com/Gooseankles/terraform-azurerm-ops-dashboard?ref=v1.6.1"

  name     = "contoso-azure-tools"
  location = "norwayeast"

  shared_spn_access = [
    { scope = "/providers/Microsoft.Management/managementGroups/<tenant-id>" },
  ]
  admin_principal_ids = ["<group object id>"]
}

output "url" {
  value = module.dashboard.url
}
```

`?ref=` picks the module version. Every release has a git tag `v<major>.<minor>.<patch>` (see the repo's tags), so
pin one and raise it when you choose to upgrade; `?ref=main` follows every push. The tag pins the infrastructure only: the app
image is the `image` input (default `trozity/azure-ops-dashboard:stable`, promoted by hand once a build has proven
itself); set it to `:latest` for every push, or to a version such as `:0.55.0.0` to pin the app. Every input and
output is listed under [Reference](#reference); what changed between versions is in [CHANGELOG.md](CHANGELOG.md).

## Continuous deployment

With `continuous_deployment = true` the app pulls its image again as soon as the deploy webhook is called, instead
of at the next restart. To have **Promote to stable** in the dashboard repo do that:

1. `terraform apply`, then `terraform output -raw deploy_webhook_url`.
2. Put the URL in the dashboard repo's Actions secret `STABLE_DEPLOY_WEBHOOKS` (one URL per line for several
   apps). The URL holds the site's publishing password: treat it as a secret.

It turns on basic authentication for the Kudu (scm) site, which the webhook needs (FTP stays off). With
`allowed_ip_ranges` or `allowed_subnet_ids` set, the scm site follows the same rules, so GitHub's runners are refused;
then call the webhook from an allowed address, or leave it off and restart the app after promoting.

## Policy check

Needs nothing beyond Reader on the shared SPN's scopes: it reads assignments, definitions, compliance states,
exemptions, remediation tasks and the policy identities' role assignments, and its probes call
`checkPolicyRestrictions` (a read operation; no resource is created). Choose the probes in Settings, Policy check.

## Key Vault

The vault settings, access and logging checks need only Reader. The dashboard's optional item check
(`KEYVAULT_ITEM_CHECK`, off by default) lists secrets, keys and certificates with their expiry dates; it needs
Key Vault Reader (no longer in the default roles; add it to a `shared_spn_access` entry's `roles`) on RBAC vaults,
and never reads a secret's value. Vaults still on access policies need a policy for `web_app_principal_id` with
**list** on secrets, keys and certificates. A vault whose firewall does not let the App Service in shows up as
"Items not checked".

**Upgrading to 1.2.0:** Key Vault Reader left the default roles, so the next apply removes it from scopes that use
the default. Keep it by listing the roles explicitly.

## Not covered

- Key Vault access policies on access-policy vaults (see above).
- A web app you already built by hand is not adopted; either `terraform import` it or let Terraform create a
  new one with another `name`.

## Reference

Written by [terraform-docs](https://terraform-docs.io) from `variables.tf`, `outputs.tf` and `versions.tf`
(`.terraform-docs.yml`); do not edit by hand.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.0, < 4.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 5.0, < 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6, < 4.0 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | >= 3.0, < 4.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 5.0, < 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6, < 4.0 |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Web app name; must be globally unique. The site becomes `https://<name>.azurewebsites.net`. | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Break-glass local login (username admin). Blank = disabled (recommended once SSO works). | `string` | `""` | no |
| <a name="input_admin_principal_ids"></a> [admin\_principal\_ids](#input\_admin\_principal\_ids) | Object IDs of users or groups that get the Admin role on the dashboard (only with create\_sso\_app = true; otherwise the app team assigns them). | `list(string)` | `[]` | no |
| <a name="input_alert_5xx_count"></a> [alert\_5xx\_count](#input\_alert\_5xx\_count) | Alarm when the app answers with more server errors (5xx) than this in 15 minutes. | `number` | `10` | no |
| <a name="input_alert_cpu_pct"></a> [alert\_cpu\_pct](#input\_alert\_cpu\_pct) | Alarm when the plan's average CPU stays above this percentage for 15 minutes. | `number` | `85` | no |
| <a name="input_alert_emails"></a> [alert\_emails](#input\_alert\_emails) | Email addresses for alarms on the dashboard's own App Service (CPU, memory, server errors), sent by Azure Monitor. Empty = no alerts are created. Each alert rule costs about 0.10 USD a month. | `list(string)` | `[]` | no |
| <a name="input_alert_memory_pct"></a> [alert\_memory\_pct](#input\_alert\_memory\_pct) | Alarm when the plan's average memory stays above this percentage for 15 minutes. | `number` | `85` | no |
| <a name="input_allowed_ip_ranges"></a> [allowed\_ip\_ranges](#input\_allowed\_ip\_ranges) | Public IPs or CIDR ranges that may reach the web app ("Enabled from selected virtual networks and IP<br/>addresses"), e.g. ["203.0.113.10", "198.51.100.0/24"]. A bare address means that one address. Empty, together<br/>with an empty allowed\_subnet\_ids, = open to the internet (sign-in still required). | `list(string)` | `[]` | no |
| <a name="input_allowed_subnet_ids"></a> [allowed\_subnet\_ids](#input\_allowed\_subnet\_ids) | Subnet resource IDs whose traffic may reach the web app (the subnet needs the Microsoft.Web service endpoint). Used together with allowed\_ip\_ranges. | `list(string)` | `[]` | no |
| <a name="input_app_private_dns_zone_id"></a> [app\_private\_dns\_zone\_id](#input\_app\_private\_dns\_zone\_id) | Existing privatelink.azurewebsites.net private DNS zone (e.g. in a hub), already linked to the VNets that must resolve the app. Blank = create one and link it to the VNet. | `string` | `""` | no |
| <a name="input_app_private_endpoint"></a> [app\_private\_endpoint](#input\_app\_private\_endpoint) | Give the web app itself an inbound private endpoint in the VNet and turn its public network access off (also<br/>for the scm site). Needs private\_network = true. People then need a network path to the VNet (VPN, ExpressRoute,<br/>peering) and DNS that resolves privatelink.azurewebsites.net (the zone is created and linked to the VNet unless<br/>app\_private\_dns\_zone\_id is set). Not together with allowed\_ip\_ranges, allowed\_subnet\_ids or continuous\_deployment. | `bool` | `false` | no |
| <a name="input_area_roles"></a> [area\_roles](#input\_area\_roles) | Area roles over every tenant, keyed by area: identity, platform, security or cost. Each listed area creates<br/>the app role `<Area>.Read` (see, run and accept findings of that area's scans), for example Security.Read;<br/>read\_members get it (object IDs, as group members with create\_role\_groups). run\_members is deprecated: there<br/>are no Run roles any more (whoever may see a scan may run it) and its members join read\_members. Per-customer area roles are in customers.area\_roles. Which scans each area holds is in the<br/>dashboard's docs/guides/sign-in-and-roles.md. | <pre>map(object({<br/>    read_members = optional(list(string), [])<br/>    run_members  = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_blob_private_dns_zone_id"></a> [blob\_private\_dns\_zone\_id](#input\_blob\_private\_dns\_zone\_id) | Existing privatelink.blob.core.windows.net private DNS zone (e.g. in a hub), already linked to the VNet. Blank = create one and link it to the VNet. | `string` | `""` | no |
| <a name="input_continuous_deployment"></a> [continuous\_deployment](#input\_continuous\_deployment) | Let the app pull a new image when Docker Hub's tag moves: turns on App Service continuous deployment (DOCKER\_ENABLE\_CI) and the deploy webhook (output deploy\_webhook\_url), which needs basic authentication on the Kudu (scm) site. false = the app pulls only on restart or image change. | `bool` | `false` | no |
| <a name="input_create_history_storage"></a> [create\_history\_storage](#input\_create\_history\_storage) | Create a storage account for scan results and run history (reached with the web app's managed identity, no keys). false = keep them on the app's own disk. | `bool` | `true` | no |
| <a name="input_create_role_groups"></a> [create\_role\_groups](#input\_create\_role\_groups) | Create an Entra security group per dashboard role (Admin, User, `Admin-<key>`, `User-<key>`, area roles) and assign it to that<br/>app role, so people get access by group membership and can be in several customers' groups. admin\_principal\_ids,<br/>user\_principal\_ids and each customer's admin\_members / user\_members become group members. Assigning groups to app<br/>roles needs Microsoft Entra ID P1 or P2, and members must be users (nested groups do not count). false = assign<br/>the people to the roles directly. | `bool` | `true` | no |
| <a name="input_create_secret_vault"></a> [create\_secret\_vault](#input\_create\_secret\_vault) | Create a key vault for the client secrets entered in Settings (SPN overrides, customer tenants); the web app reads and writes it with its managed identity. false = those secrets stay in files on the app's own disk. | `bool` | `true` | no |
| <a name="input_create_sso_app"></a> [create\_sso\_app](#input\_create\_sso\_app) | true = Terraform creates the sign-in app registration. false = the app registration comes from your own<br/>request process: set sso\_app\_client\_id (and sso\_client\_secret if the team hands out a secret instead of adding<br/>the federated credential); the output sso\_app\_request lists everything to ask them for. | `bool` | `true` | no |
| <a name="input_customers"></a> [customers](#input\_customers) | Customer tenants the dashboard scans besides its own, keyed by a short customer key (lowercase letters, digits,<br/>- or \_; it names the app roles `Admin-<key>`, `User-<key>` and `<Area>.Read-<key>`, the Entra<br/>groups and the storage container).<br/>  name             shown in the tenant tabs<br/>  tenant\_id        the customer's Entra tenant ID<br/>  client\_id        the app registration made in that tenant (see the customer\_onboarding output). Empty until<br/>                   it exists; it can also be set in the app's Settings. Its client secret is entered only in<br/>                   the app's Settings, so it never lands in the Terraform state.<br/>  subscription\_ids limit the scans to these subscriptions (empty = every one the app can see there)<br/>  enabled          false = keep the customer but stop scanning it<br/>  admin\_members    object IDs of users who get `Admin-<key>` (this customer, every area)<br/>  user\_members     object IDs of users who get `User-<key>` (this customer, every area; same access as `Admin-<key>`)<br/>  area\_roles       per area (identity, platform, security, cost): creates `<Area>.Read-<key>` for this<br/>                   customer (read, run and accept findings); read\_members get it (run\_members is<br/>                   deprecated and joins read\_members)<br/>Terraform never touches a customer tenant: the app registration and its permissions are made there by hand. | <pre>map(object({<br/>    name             = string<br/>    tenant_id        = string<br/>    subscription_ids = optional(list(string), [])<br/>    client_id        = optional(string, "")<br/>    enabled          = optional(bool, true)<br/>    admin_members    = optional(list(string), [])<br/>    user_members     = optional(list(string), [])<br/>    area_roles = optional(map(object({<br/>      read_members = optional(list(string), [])<br/>      run_members  = optional(list(string), [])<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_extra_app_settings"></a> [extra\_app\_settings](#input\_extra\_app\_settings) | Extra app settings, e.g. AZURE\_REQUIRED\_TAGS. | `map(string)` | `{}` | no |
| <a name="input_grant_graph_permissions"></a> [grant\_graph\_permissions](#input\_grant\_graph\_permissions) | Give the system-assigned identity the Microsoft Graph application permissions the tools use (user and group<br/>names, group members, app registration secrets, access packages). Needs a Privileged Role Administrator or<br/>Global Administrator running terraform. | `bool` | `true` | no |
| <a name="input_grant_sso_consent"></a> [grant\_sso\_consent](#input\_grant\_sso\_consent) | Grant tenant-wide admin consent for the sign-in app's delegated permissions (openid, profile), so tenants that<br/>do not let users consent themselves do not show "Need admin approval" at sign-in. Only with create\_sso\_app =<br/>true. A service principal running terraform (a pipeline) needs the Microsoft Graph application permission<br/>DelegatedPermissionGrant.ReadWrite.All; a person needs Application Administrator or Global Administrator.<br/>false = an admin clicks "Grant admin consent" on the Enterprise app's Permissions page instead. | `bool` | `true` | no |
| <a name="input_graph_permissions"></a> [graph\_permissions](#input\_graph\_permissions) | Microsoft Graph application permissions for the system-assigned identity. | `list(string)` | <pre>[<br/>  "User.Read.All",<br/>  "GroupMember.Read.All",<br/>  "Application.Read.All",<br/>  "EntitlementManagement.Read.All",<br/>  "RoleManagement.Read.Directory",<br/>  "AuditLog.Read.All",<br/>  "Policy.Read.All",<br/>  "DelegatedPermissionGrant.Read.All",<br/>  "LicenseAssignment.Read.All",<br/>  "PrivilegedEligibilitySchedule.Read.AzureADGroup",<br/>  "PrivilegedAssignmentSchedule.Read.AzureADGroup"<br/>]</pre> | no |
| <a name="input_history_retention_days"></a> [history\_retention\_days](#input\_history\_retention\_days) | How many days of run history the dashboard keeps. | `number` | `730` | no |
| <a name="input_image"></a> [image](#input\_image) | Docker Hub image and tag. :stable is promoted by hand once a build has proven itself; :latest is every push to main; a version (e.g. :0.55.0.0) pins the app. | `string` | `"trozity/azure-ops-dashboard:stable"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | `"norwayeast"` | no |
| <a name="input_private_access"></a> [private\_access](#input\_private\_access) | How the web app reaches the history storage account and the secret vault when private\_network = true.<br/>"private\_endpoint": private endpoints and private DNS zones; both firewalls deny all other networks (public<br/>network access stays on, restricted to selected networks).<br/>"service\_endpoint": no private endpoints or DNS zones; the integration subnet gets the Microsoft.Storage and<br/>Microsoft.KeyVault service endpoints and both firewalls let in that subnet only (an existing subnet needs both<br/>service endpoints turned on first). Cheaper and simpler; the storage account must be in the VNet's region or<br/>its paired region. | `string` | `"private_endpoint"` | no |
| <a name="input_private_endpoint_subnet_id"></a> [private\_endpoint\_subnet\_id](#input\_private\_endpoint\_subnet\_id) | Existing subnet for the private endpoints (storage, secret vault, and the web app with app\_private\_endpoint). Set together with vnet\_integration\_subnet\_id; with private\_access = "service\_endpoint" only needed for app\_private\_endpoint. | `string` | `""` | no |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Join the web app to a virtual network (VNet integration) and reach the history storage account and the secret<br/>vault through private endpoints; their firewalls deny all other networks (public network access stays on,<br/>restricted to selected networks). Without existing subnets a small<br/>VNet is created (vnet\_address\_space). Costs a little extra (private endpoint and DNS zone). | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group to create. Blank = `rg-<name>`. | `string` | `""` | no |
| <a name="input_role_group_prefix"></a> [role\_group\_prefix](#input\_role\_group\_prefix) | Display name prefix of the role groups. Blank = `Cirrus Watch (<name>)`. | `string` | `""` | no |
| <a name="input_scan_subscription_ids"></a> [scan\_subscription\_ids](#input\_scan\_subscription\_ids) | Limit the scans to these subscription IDs (AZURE\_SUBSCRIPTION\_IDS). Empty = every subscription the shared SPN can see, so new subscriptions under shared\_spn\_access are picked up automatically. | `list(string)` | `[]` | no |
| <a name="input_secret_vault_admin_ids"></a> [secret\_vault\_admin\_ids](#input\_secret\_vault\_admin\_ids) | Object IDs of users or groups who may see and change the stored secrets in the portal (Key Vault Secrets Officer). Empty = only the web app. | `list(string)` | `[]` | no |
| <a name="input_secret_vault_name"></a> [secret\_vault\_name](#input\_secret\_vault\_name) | Key vault name (3-24 letters, digits and dashes, globally unique). Blank = kv<name without dashes> plus a random suffix. | `string` | `""` | no |
| <a name="input_secret_vault_purge_protection"></a> [secret\_vault\_purge\_protection](#input\_secret\_vault\_purge\_protection) | Turn on purge protection for the secret vault. Cannot be turned off again, and a deleted vault then keeps its name for 90 days. | `bool` | `false` | no |
| <a name="input_shared_spn_access"></a> [shared\_spn\_access](#input\_shared\_spn\_access) | Where the shared SPN (the web app's system-assigned identity, used by every tool without its own SPN<br/>override) gets access, and with which Azure roles. Each entry is a scope: a management group<br/>(`/providers/Microsoft.Management/managementGroups/<id>`; the tenant root group's ID is the tenant ID), a<br/>subscription (`/subscriptions/<id>`), a resource group or a single resource such as a Key Vault. roles<br/>defaults to Reader and Cost Management Reader, which is what the scans need (add "Key Vault Reader" only for the<br/>dashboard's optional Key Vault item check). Empty list = no role assignments (grant them yourself). | <pre>list(object({<br/>    scope = string<br/>    roles = optional(list(string), ["Reader", "Cost Management Reader"])<br/>  }))</pre> | `[]` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | App Service plan size. B1 is enough; Always On needs Basic or higher. | `string` | `"B1"` | no |
| <a name="input_sso_app_client_id"></a> [sso\_app\_client\_id](#input\_sso\_app\_client\_id) | Client ID of an existing sign-in app registration (only with create\_sso\_app = false). Blank on the first apply: SSO stays off (use admin\_password) until the team sends it. | `string` | `""` | no |
| <a name="input_sso_client_secret"></a> [sso\_client\_secret](#input\_sso\_client\_secret) | Client secret of the existing app registration, if the team will not add the federated credential. Blank = secretless. | `string` | `""` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Storage account name (3-24 lowercase letters and digits, globally unique). Blank = st<name without dashes> plus a random suffix. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags on the Azure resources. | `map(string)` | `{}` | no |
| <a name="input_user_principal_ids"></a> [user\_principal\_ids](#input\_user\_principal\_ids) | Object IDs of users or groups that get the read-only User role on the dashboard. | `list(string)` | `[]` | no |
| <a name="input_vault_private_dns_zone_id"></a> [vault\_private\_dns\_zone\_id](#input\_vault\_private\_dns\_zone\_id) | Existing privatelink.vaultcore.azure.net private DNS zone (e.g. in a hub), already linked to the VNet. Blank = create one and link it to the VNet. | `string` | `""` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Address space of the VNet created when private\_network = true and no subnets are given. A /24 is plenty: a /26 for the app and a /27 for private endpoints. | `list(string)` | <pre>[<br/>  "10.90.0.0/24"<br/>]</pre> | no |
| <a name="input_vnet_integration_subnet_id"></a> [vnet\_integration\_subnet\_id](#input\_vnet\_integration\_subnet\_id) | Existing subnet for the web app's VNet integration (delegated to Microsoft.Web/serverFarms, /28 or larger). With private endpoints set together with private\_endpoint\_subnet\_id; blank = create a VNet. | `string` | `""` | no |
| <a name="input_vnet_route_all"></a> [vnet\_route\_all](#input\_vnet\_route\_all) | Send all the web app's outbound traffic through the VNet (needs a NAT gateway or firewall there for internet access). false = only private addresses go through the VNet, which is all the private endpoint needs. | `bool` | `false` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_customer_containers"></a> [customer\_containers](#output\_customer\_containers) | History storage container per customer. |
| <a name="output_customer_onboarding"></a> [customer\_onboarding](#output\_customer\_onboarding) | Per customer: the app registration to make in that tenant and the permissions to give it. Terraform does not touch customer tenants. |
| <a name="output_deploy_webhook_url"></a> [deploy\_webhook\_url](#output\_deploy\_webhook\_url) | With continuous\_deployment: the URL that makes the app pull its image again. Holds the publishing password; put it in the dashboard repo's STABLE\_DEPLOY\_WEBHOOKS secret (one URL per line) so Promote to stable updates this app. null otherwise. |
| <a name="output_graph_request"></a> [graph\_request](#output\_graph\_request) | What to ask an Entra admin for when grant\_graph\_permissions = false: the scan identity's Graph application permissions. |
| <a name="output_history_storage_url"></a> [history\_storage\_url](#output\_history\_storage\_url) | Blob endpoint of the history storage account (null when create\_history\_storage = false). |
| <a name="output_private_network"></a> [private\_network](#output\_private\_network) | VNet integration subnet, how storage and the vault are reached, their private endpoints and the web app's own private endpoint (null when private\_network = false). |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group the dashboard lives in. |
| <a name="output_role_groups"></a> [role\_groups](#output\_role\_groups) | Entra security group per dashboard role (role => group object ID). Add people to these groups; one person can be in several customers' groups. |
| <a name="output_secret_vault_uri"></a> [secret\_vault\_uri](#output\_secret\_vault\_uri) | Address of the key vault holding the secrets entered in Settings (null when create\_secret\_vault = false). |
| <a name="output_shared_spn_role_assignments"></a> [shared\_spn\_role\_assignments](#output\_shared\_spn\_role\_assignments) | Roles the shared SPN got from shared\_spn\_access, as scope => roles. |
| <a name="output_sso_app_client_id"></a> [sso\_app\_client\_id](#output\_sso\_app\_client\_id) | Client ID of the sign-in app registration. |
| <a name="output_sso_app_request"></a> [sso\_app\_request](#output\_sso\_app\_request) | What to ask the app-registration team for when create\_sso\_app = false. |
| <a name="output_sso_identity_client_id"></a> [sso\_identity\_client\_id](#output\_sso\_identity\_client\_id) | Client ID of the user-assigned identity used for secretless SSO. |
| <a name="output_url"></a> [url](#output\_url) | Dashboard address. |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | Resource ID of the web app. |
| <a name="output_web_app_principal_id"></a> [web\_app\_principal\_id](#output\_web\_app\_principal\_id) | Object ID of the web app's system-assigned identity (the shared SPN). Extra roles can go in shared\_spn\_access or be granted elsewhere with this ID. |
<!-- END_TF_DOCS -->

## License

[MIT](LICENSE). The dashboard itself (Cirrus Watch) is a separate project under its own license.
