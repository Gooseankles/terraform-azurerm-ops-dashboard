# Changelog

What changed in each release of the Cirrus Watch Terraform module, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and releases follow [Semantic Versioning](https://semver.org/):
each is a git tag `v<major>.<minor>.<patch>` to pin with `?ref=`. The app has its own
[changelog](https://github.com/Gooseankles/cirrus-watch/blob/main/CHANGELOG.md).

## Upgrading

Read this before you raise `?ref=`.

- **v1.5.0: the `<Area>.Run` app roles and their Entra groups are deleted on the next apply.** People in
  `run_members` are put in the matching `.Read` group instead, and the app (0.57.0.0 or newer) lets everyone who can
  see a scan run it, so nobody loses access. `run_members` still works but is deprecated: move those people to
  `read_members`; it will be removed in the next major version. Check the plan for the deleted groups if something
  outside Terraform (an access package, a PIM group) points at them.
- **v1.4.0: the default image is `trozity/azure-ops-dashboard:stable`** (was `:latest`). Set `image` to keep
  following every push.
- **v1.2.0: area roles need app image 0.53.0.0 or newer**, and Key Vault Reader is no longer granted by default (only
  with the Key Vault item check; add it to `shared_spn_access` roles if you turn that on).
- **v1.0.0: the module moved to its own repo.** A root configuration that used the old `infra/terraform` folder keeps
  its resources through the `moved` blocks in `examples/default`.

## [Unreleased]

## [1.7.0] - 2026-10-30

### Changed

- `app_private_endpoint` keeps the web app's public network access on instead of turning it off. The access
  restrictions deny every network (default action Deny), so the private endpoint is still the way in. This stops
  deployments from being blocked.
- `allowed_ip_ranges` and `allowed_subnet_ids` now work together with `app_private_endpoint`, as extra ways in.
- With `continuous_deployment` the Kudu (scm) site stays open (it still needs the publishing credentials), so the
  deploy webhook gets through even when the site is restricted by allowed IPs, subnets or `app_private_endpoint`.
  It used to follow the site's rules, which refused GitHub's runners. `continuous_deployment` is no longer refused
  with `app_private_endpoint`.

## [1.6.1] - 2026-10-30

### Changed

- With `private_access = "private_endpoint"` the history storage account and the secret vault keep public network
  access on ("Enabled from selected networks") instead of turning it off. Their firewalls deny every network
  (default action Deny, trusted Azure services allowed), so the private endpoints are still the only way in. The
  next apply changes this setting in place; nothing is recreated.

## [1.6.0] - 2026-10-30

### Added

- `app_private_endpoint`: the web app itself gets an inbound private endpoint (subresource `sites`) in the private
  endpoint subnet, and its public network access is turned off for the site and the scm site. A
  `privatelink.azurewebsites.net` zone is created and linked to the VNet, or `app_private_dns_zone_id` points at an
  existing one. Needs `private_network = true`; refused together with `allowed_ip_ranges`, `allowed_subnet_ids` or
  `continuous_deployment`. Works with both `private_access` values (the private endpoint subnet is now also created
  for `"service_endpoint"` when this is on).
- `private_network` output: `app_endpoint_id`, `app_private_ip` and `app_public_access`.
- README: what `allowed_subnet_ids` does and does not do, and subnet sizes (/28 is enough for this app).

## [1.5.4] - 2026-10-29

### Fixed

- The examples no longer mention Run roles (gone since 1.5.0): area roles are `<Area>.Read` only, and `run_members`
  is described as deprecated.
- The default example passes `continuous_deployment` and shows the `resource_group_name`, `web_app_id`,
  `deploy_webhook_url` and `graph_request` outputs.
- Usage snippets point at v1.5.4.

## [1.5.3] - 2026-10-29

### Changed

- Links point at the app repo's new name, `Gooseankles/cirrus-watch` (the old address redirects).
- The README says how to run it for one tenant only.

## [1.5.2] - 2026-10-29

### Changed

- Docs links point at the dashboard's new guides (sign-in and roles, setup low-level design, operations) instead of
  its README.
- The pull request checklist asks for every change to be documented, with the dashboard's setup low-level design
  and high-level design updated when affected.

## [1.5.1] - 2026-10-29

### Added

- A Reference section in the README with every input, output and provider version, written by terraform-docs.
- CI: `terraform fmt`, `terraform validate` of the module and both examples, and a check that the Reference is current.
- This changelog and a pull request template.

### Fixed

- Version pins in the README and the examples (v1.5.1).
- Input descriptions: placeholders such as `<name>` and `<key>` show on GitHub; the customer roles no longer mention
  `.Run` roles.

## [1.5.0] - 2026-10-29

### Removed

- The `<Area>.Run` and `<Area>.Run-<key>` app roles and groups. See [Upgrading](#upgrading).

### Deprecated

- `run_members` in `area_roles` (also per customer): its members join the `.Read` group.

## [1.4.0] - 2026-10-29

### Added

- `continuous_deployment` and the `deploy_webhook_url` output: the web app pulls a new image when the tag moves.

### Changed

- The default image is `:stable`.

## [1.3.1] - 2026-10-28

### Changed

- Licence: MIT.

## [1.3.0] - 2026-10-28

### Changed

- Default names: the sign-in app and role groups are called `Cirrus Watch (<name>)`.

## [1.2.1] - 2026-10-28

### Added

- Example `existing-sso`: nothing is made in Entra; the `sso_app_request` output lists the area roles and a
  `graph_request` output lists the Graph permissions to ask for.

## [1.2.0] - 2026-10-28

### Added

- Area roles (Identity, Platform, Security, Cost), for every tenant and per customer.

### Changed

- Key Vault Reader is no longer among the default scan roles.

## [1.1.0] - 2026-10-27

### Added

- `private_access = "service_endpoint"`: reach storage and Key Vault through service endpoints on the integration
  subnet, without private endpoints.

## [1.0.1] - 2026-10-26

### Fixed

- The permissions doc lists what the PIM review and Azure Monitor scans use.

## [1.0.0] - 2026-10-23

### Added

- The module at the repo root, split from the app repo, with a root configuration in `examples/default` and
  `docs/permissions.md`.

[Unreleased]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.5.4...v1.6.0
[1.5.4]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Gooseankles/terraform-azurerm-ops-dashboard/releases/tag/v1.0.0
