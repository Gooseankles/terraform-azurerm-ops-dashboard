<!-- markdownlint-disable-file MD041 -->
## What and why

<!-- One or two lines: what changes for whoever deploys the module, and why. -->

## Done means

- [ ] `terraform fmt -recursive` run; the module and both examples validate
- [ ] terraform-docs run (`.terraform-docs.yml`), so the README Reference section is current
- [ ] `CHANGELOG.md` has the change under **Unreleased** (and under **Upgrading** if an apply changes or deletes something)
- [ ] New input or output: a description that says what blank or the default means; the examples' tfvars mention it
- [ ] New permission or role: `docs/permissions.md` and the README section about it
- [ ] Version pins in the README and the examples raised when a release is tagged
