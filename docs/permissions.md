# Permissions

Every identity the dashboard uses and the access it needs, in one place. The scans only read; nothing here lets
the dashboard change a customer's resources.

| Identity | Where | Made by |
| --- | --- | --- |
| [Shared SPN](#shared-spn-home-tenant) | Home tenant | Terraform (the web app's system-assigned identity) |
| [Customer tenant app](#customer-tenant-app-other-tenants) | Each customer tenant | The customer, by hand |
| [Per-tool SPN](#per-tool-spn-optional) | Home tenant | You, optional |
| [Web app's own data](#web-apps-own-data) | Home tenant | Terraform |
| [SSO app](#sso-app) | Home tenant | Terraform, or by request |
| [Whoever runs Terraform](#whoever-runs-terraform) | Home tenant | — |

## Shared SPN (home tenant)

The web app's system-assigned managed identity. Every tool without its own SPN scans the home tenant with it.
Terraform grants all of this through `shared_spn_access` and `grant_graph_permissions`.

**Azure roles**, on each subscription to scan, or once on a management group so new subscriptions are picked up
automatically:

| Role | Used for |
| --- | --- |
| Reader | Every scan: resources, Resource Graph (including Advisor, backup items and resource changes), metrics, diagnostic settings, role assignments, NSG rules, storage container and database firewall lists, App Service config, AKS versions, quota usage, Defender for Cloud secure scores, recommendations and plans, budgets and resource locks, virtual network subnet usage, Azure Policy (including the `checkPolicyRestrictions` probes, a read operation), Azure Monitor (agents, data collection rules, alert rules, action groups, workspaces, and a `Heartbeat` query per Log Analytics workspace through ARM; give Log Analytics Reader on the workspaces if Reader alone is refused) |
| Cost Management Reader | Cost anomalies and cost history |
| Key Vault Reader | For the Key Vault item check (`KEYVAULT_ITEM_CHECK`, on by default; in the default `shared_spn_access` roles). Names and expiry dates of secrets, keys and certificates on RBAC vaults; never a secret's value |

A vault still on access policies needs a policy for the identity with **list** on secrets,
keys and certificates instead of Key Vault Reader. A vault whose firewall keeps the dashboard out shows as "Items not checked".

**Microsoft Graph application permissions**, with admin consent:

| Permission | Used for |
| --- | --- |
| `User.Read.All` | Access lookup (search people by name and find them), names of role holders; PIM: names, guest and disabled state of everyone with PIM access; Guest owners and Administrative units: guest and disabled state of group owners and scoped admins |
| `GroupMember.Read.All` | Group memberships and group search (access lookup, with the chain through nested groups; access review; privileged roles: members of groups that hold an admin role; access packages: who is in each approver group; PIM: members and owners of groups that hold a role; guest owners: every group's owners) |
| `Application.Read.All` | App registration secret and certificate expiry, federated credentials, redirect URIs and supported account types; enterprise apps |
| `EntitlementManagement.Read.All` | Access packages (only matters with Entra ID Governance / P2) |
| `RoleManagement.Read.Directory` | Privileged roles: who holds Entra admin roles, PIM eligibility (PIM needs P2); PIM: role settings, eligibility and activation history; access lookup: a person's or group's Entra roles; Conditional Access: which admins a policy leaves out |
| `AuditLog.Read.All` | Stale accounts (last sign-in), MFA coverage and admins' MFA registration, Legacy sign-ins (the sign-in log); all need Entra ID P1 or P2 |
| `Policy.Read.All` | Conditional Access policies, security defaults and the user consent setting (Conditional Access needs P1); Entra tenant settings: the authorization, cross-tenant access (default and partners) and authentication methods policies |
| `DelegatedPermissionGrant.Read.All` | App permissions: delegated consents given to apps |
| `LicenseAssignment.Read.All` | Licence coverage: the licences the tenant owns |
| `PrivilegedEligibilitySchedule.Read.AzureADGroup`, `PrivilegedAssignmentSchedule.Read.AzureADGroup` | Licence coverage: who is eligible or time-bound in PIM for Groups; PIM: who can activate a group membership, and when they last did |

**Extra Graph permissions**, for the checks listed in `extra_graph_checks` (all four by default; `[]` grants none
and sets `EXTRA_GRAPH_CHECKS=none`, which turns them off). Each check listed is granted its permission with
`grant_graph_permissions` (or added to the `graph_request` output) and turned on in the home tenant
(`EXTRA_GRAPH_CHECKS`):

| `extra_graph_checks` value | Permission | Used for |
| --- | --- | --- |
| `risky-users` | `IdentityRiskyUser.Read.All` | Risky users in Entra ID Protection (needs Entra ID P2; without it the check logs that and reports nothing) |
| `secure-score` | `SecurityEvents.Read.All` | Microsoft Secure Score: the score, a drop against last week, the open improvement actions |
| `admin-units` | `AdministrativeUnit.Read.All` | Administrative units: guest or disabled scoped admins, empty restricted units |
| `directory-sync` | `Organization.Read.All` | Directory sync from on-premises Active Directory late or stopped |

A customer's `extra_graph_checks` (all four by default) only adds those permissions to its `customer_onboarding`
steps. The dashboard runs the checks in a customer tenant unless that tenant's Settings tab turns them off (`none`);
until the customer grants a permission, that check shows one scan error. A customer tenant never takes the home
tenant's value. Guest owners needs nothing extra (`GroupMember.Read.All`).

All of these only read. Without P1 the stale accounts and MFA coverage scans and the admin MFA check report that the licence is
missing, and the legacy sign-ins scan notes it in the log and reports nothing; the other checks still run.

No Entra directory role is needed.

**Licence coverage** counts licences the way Microsoft does: one per member user who benefits, not one per feature
switched on. P1 for everyone in scope of an enabled Conditional Access policy; P2 (or ID Governance) for people in
scope of a risk-based policy, with an eligible or time-bound PIM assignment (Entra roles, Azure roles, PIM for Groups)
or with an access package; ID Governance for access packages that use auto-assignment or custom extensions. Guests
are billed per monthly active user instead and are shown apart. Not counted: PIM approvers and access reviews.

## Customer tenant app (other tenants)

Each customer tenant has its own app registration, made in that tenant by the customer (Terraform never touches a
customer tenant). It needs **the same access as the shared SPN, granted in the customer's tenant**:

1. **App registration**: single tenant. Its Application (client) ID goes in Terraform's `customers.<key>.client_id`
   or in Settings → Customer tenants.
2. **Client secret**: Certificates & secrets → New client secret. Paste the value in Settings → Customer tenants →
   Edit; it is kept in the dashboard's key vault and never shown again. Note the expiry date: the dashboard stops
   scanning that tenant when it runs out. (A managed identity or federated credential cannot be used across tenants;
   Entra refuses it with AADSTS700236.)
3. **Entra (Microsoft Graph)**: API permissions → Microsoft Graph → **Application** permissions `User.Read.All`,
   `GroupMember.Read.All`, `Application.Read.All`, `EntitlementManagement.Read.All`, `RoleManagement.Read.Directory`,
   `AuditLog.Read.All`, `Policy.Read.All`, `DelegatedPermissionGrant.Read.All`, `LicenseAssignment.Read.All`,
   `PrivilegedEligibilitySchedule.Read.AzureADGroup`, `PrivilegedAssignmentSchedule.Read.AzureADGroup`, then **Grant admin consent**
   (needs a Privileged Role Administrator or Global Administrator in that tenant). No directory role.
4. **Subscriptions (Azure RBAC)**: `Reader`, `Cost Management Reader` and `Key Vault Reader` (the last for the
   Key Vault item check; leave it out and turn that check off if you prefer) for the app's
   service principal on each subscription to scan, or on a management group (the tenant root group's ID is the
   tenant ID) to cover all of them:

   ```sh
   az role assignment create --assignee <client-id> --role "Reader"                 --scope /subscriptions/<id>
   az role assignment create --assignee <client-id> --role "Cost Management Reader" --scope /subscriptions/<id>
   # for the Key Vault item check:
   az role assignment create --assignee <client-id> --role "Key Vault Reader"       --scope /subscriptions/<id>
   ```

   Giving these needs Owner, User Access Administrator or Role Based Access Control Administrator there.

`terraform output customer_onboarding` prints these steps per customer, with that customer's subscription IDs
filled in. Settings → Customer tenants → Test checks that the app can sign in to Azure and to Graph; a missing role or Graph
permission shows up later as an error entry on that tool's page, never as an empty result. Test also lists what is
missing: Graph application permissions from the `roles` claim of the app's Graph token (only consented ones are in
it), and the roles above on each subscription the app can see (assignments on a management group above count; a role
given through a group is not seen). The shared SPN's and each SPN override's Test connection do the same for the
tools they serve, and a failed scan shows the permissions its tool needs.

A customer delegated to your tenant with **Azure Lighthouse** needs none of this: give the shared SPN the Azure roles
in the delegation and it scans those subscriptions like its own (Graph-based tools then only see your home tenant).

## Per-tool SPN (optional)

A tool can scan as its own service principal (Settings → SPN override, or `<TOOL_ID>_AZURE_CLIENT_ID` and friends
in `.env`). It needs only what that tool uses from the lists above, for example Cost Management Reader for the cost
tools or `Application.Read.All` for app secret expiry.

## Web app's own data

The web app's system-assigned identity also gets, on the dashboard's own resources only:

| Role | On | Used for |
| --- | --- | --- |
| Storage Blob Data Contributor | The history storage account | Scan results and run history (`create_history_storage`) |
| Key Vault Secrets Officer | The dashboard's secret vault | Client secrets entered in Settings (`create_secret_vault`) |

People in `secret_vault_admin_ids` also get Key Vault Secrets Officer on the secret vault, to see or fix a stored
secret in the portal. Nobody else can read those secrets.

## SSO app

The app registration people sign in with. It reads no data: it has the delegated permissions `openid` and
`profile` (admin consent, `grant_sso_consent`), the app roles Admin, User, Admin-&lt;key&gt; and User-&lt;key&gt;,
and a federated credential for the user-assigned identity, so it has no secret.

## Deploy identity (continuous deployment)

Only with `continuous_deployment = true`: the user-assigned identity `id-<name>-deploy`, which the dashboard repo's
Promote to stable workflow signs in as (GitHub OIDC, federated credential for `deploy_github_subject`; no secret).

| Role | On | Used for |
| --- | --- | --- |
| Custom role `Cirrus Watch deploy (<name>)`: `Microsoft.Web/sites/read`, `Microsoft.Web/sites/restart/action` | The web app only | Restart it after `:stable` moves, so App Service pulls the image again |

Nothing else: it cannot read or change app settings, see publishing credentials or reach any data. The built-in
Website Contributor was not used because it could read the app settings (the session secret and admin password).

## Whoever runs Terraform

A person or a pipeline service principal in the home tenant:

| Needs | For |
| --- | --- |
| Contributor on the subscription | The resource group, App Service, storage account, key vault and network |
| Owner, User Access Administrator or Role Based Access Control Administrator | Role assignments: on each `shared_spn_access` scope, and on the dashboard's own resource group (storage, secret vault) |
| Rights to register resource providers on the subscription | `Microsoft.Web`, `Microsoft.Storage`, `Microsoft.ManagedIdentity`, `Microsoft.KeyVault` (or remove `resource_providers_to_register` from `versions.tf` if they are already registered) |
| Network Contributor (subscription or existing VNet) | `private_network = true` |
| Owner or User Access Administrator on the dashboard's resource group | The custom deploy role and its assignment (`continuous_deployment`; creating a role needs `Microsoft.Authorization/roleDefinitions/write`) |
| Write access on the Log Analytics workspace, e.g. Log Analytics Contributor (Contributor covers it when it is in the same subscription) | Resource logs (`log_analytics_workspace_id`) |
| Entra: Application Administrator | The SSO app registration (`create_sso_app`) |
| Entra: Privileged Role Administrator or Global Administrator | The Graph permissions for the shared SPN (`grant_graph_permissions`; set `false` and ask an admin otherwise) |
| Entra: Groups Administrator (or `Group.ReadWrite.All`) | Role groups (`create_role_groups`) |
| Graph application permission `DelegatedPermissionGrant.ReadWrite.All` (pipeline SP only; a person needs Application Administrator) | Admin consent for sign-in (`grant_sso_consent`) |

For a pipeline service principal, the Entra roles above are directory roles assigned to it (or the matching Graph
application permissions: `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`, `Group.ReadWrite.All`).
Terraform never writes a secret into the vault, so it needs no access to the vault's data, and it never touches a
customer tenant.
