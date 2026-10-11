# OpenTofu and Terragrunt formatting

- Separate adjacent top-level HCL blocks with one blank line in `.tf` and `.hcl`
  files. This applies to `terraform`, `provider`, `variable`, `locals`, `resource`,
  `output`, `include`, `generate`, and other top-level blocks.
- Preserve these blank lines when adding or editing configuration. Running a
  formatter does not replace checking this repository convention.
- Run `tofu fmt` for OpenTofu files and `make fmt-terragrunt` for Terragrunt files
  when the corresponding tools are available.
- Do not format generated caches or local state/credential files.
