# Versions, security, and verification

## SemVer-only references

Resolve current compatible stable releases and write complete SemVer tags for
actions, tool images, base images, and package setup. Do not write `@v4`,
`@latest`, `@sha256:...`, or an action SHA in generated examples. Explain that
this is the repository policy and has a supply-chain tradeoff compared with
immutable action pinning.

## Security checks

Verify permissions, PR login behavior, shell quoting, lowercase image names,
cache scope, and publish conditions. Do not expose secrets in logs. Run
actionlint and YAML parsing before handoff.

## Evidence

Report separately:

- YAML/actionlint validation;
- Docker build and runtime tests;
- registry push and manifest evidence;
- scan/signature evidence;
- promoted tag digest verification.

An origin or local build check does not prove GHCR retention, registry policy,
or downstream deployment behavior.
