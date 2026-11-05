# Security policy

This module deploys [Cirrus Watch](https://github.com/Gooseankles/cirrus-watch) into an Azure subscription. The
app has its own [security policy](https://github.com/Gooseankles/cirrus-watch/blob/main/SECURITY.md); this one
covers the Terraform code in this repository.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately through
[Security advisories](https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/security/advisories)
("Report a vulnerability"). You get an answer within a week. A fix ships as a new tag and is named in
[CHANGELOG.md](CHANGELOG.md); the advisory is published when the fix is out.

## Supported versions

Only the newest tag gets fixes. Pin `?ref=` to it and read the **Upgrading** section of the changelog before you
raise it.

## What the module does for you

- Secrets (the client secret, the session key, Discord hooks) live in a Key Vault with purge protection and never in
  Terraform outputs; the app reads them through its managed identity.
- The storage account has account keys turned off and public blob access off; the app uses its identity.
- TLS 1.2 is the minimum everywhere, HTTPS only on the web app.
- With `private_network = true` the web app, the Key Vault and the storage account are reachable only through
  private endpoints. The default keeps them public with Entra sign-in in front, because a private network adds
  fixed cost; the accepted scanner findings for that default are listed in `.trivyignore.yaml`.
- Every pull request runs `terraform validate`, the module tests and a Trivy misconfiguration scan (`ci.yml`);
  Dependabot keeps the pinned actions and provider constraints current; `main` only changes through a reviewed pull
  request with all checks green, admins included.
