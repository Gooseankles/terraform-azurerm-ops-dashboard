# Dashboard with nothing made in Entra ID

Terraform builds only the Azure side (web app, identities, storage, key vault, Azure role assignments). Everything
in Entra ID is made by whoever owns it: the sign-in app registration, its app roles, the groups and their members,
and the scan identity's Graph permissions. Whoever runs Terraform needs no Entra role.

1. Copy `terraform.tfvars.example` to `terraform.tfvars`, fill it in, `terraform init` and `terraform apply`.
   SSO is off; sign in with the local admin login.
2. Send the Entra team both requests:
   - `terraform output -raw sso_app_request`: the app registration, redirect URI, every app role (Admin, User,
     Admin-&lt;key&gt; / User-&lt;key&gt; and the area roles from `area_roles`), "assignment required" and the federated
     credential, so no secret is needed.
   - `terraform output -raw graph_request`: the Graph application permissions for the scan identity, with admin
     consent.
3. The Entra team makes a security group per app role, assigns each group to its role in the Enterprise app
   (needs Entra ID P1 or P2) and manages the members there.
4. Put the client ID they send back in `sso_app_client_id` and apply again. Clear `admin_password` once SSO works.

`area_roles` and the customers' `area_roles` only decide which role names the request lists; adding an area later
means asking the Entra team for the new roles. People get access the next time they sign in.
