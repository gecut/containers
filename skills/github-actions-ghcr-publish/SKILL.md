---
name: github-actions-ghcr-publish
description: Design, review, and troubleshoot GitHub Actions workflows that build and publish one or many container images to GHCR. Use this skill whenever a workflow needs PR validation without push, default-branch publishing, Buildx, QEMU, GHA cache, SemVer action references, candidate image promotion, signing, SBOM, vulnerability scanning, or digest verification. Detect single-image and dependency-closure pipelines and ask before applying incompatible version upgrades.
license: AGPL-3.0-only
metadata:
  author: "Gecut"
  version: "1.0.0"
  scope: "GHCR image publishing workflows"
compatibility: "Requires GitHub Actions YAML knowledge. Examples target GitHub-hosted Ubuntu runners, Docker Buildx, GHCR, actionlint, Cosign, and Trivy with SemVer-only references."
---

# GitHub Actions GHCR publishing

Use this skill to produce a release-ready workflow for container images. First
classify the repository as single-image or multi-image. Keep application build
logic in the Dockerfile; workflow checks may validate the project, but must not
rebuild the same production artifact as a separate handoff.

## Version policy

Before writing the workflow, resolve the latest compatible stable versions of
every action and containerized tool. Use complete `major.minor.patch` tags:

```yaml
uses: actions/checkout@v4.2.2
```

Do not emit action SHAs, image digests, or `latest` for dependency/tool
references. Image output tags such as `sha-<commit>` and `latest` are release
metadata and are allowed when the project policy requires them. If the latest
major is incompatible with the repository or runner, stop and ask instead of
silently migrating it.

## Common workflow contract

- Use `pull_request`, default-branch `push`, and `workflow_dispatch` according
  to the repository release policy.
- PR jobs may build and test but must not log in to GHCR or push an image.
- Publish jobs use only `contents: read` and `packages: write`, adding
  `id-token: write` only when signing/attestation needs it.
- Set a concurrency group and cancel stale validation runs; never cancel an
  in-flight promotion.
- Lowercase `${{ github.repository }}` before creating the GHCR image name.
- Use Buildx, GHA cache, explicit context, and labels.
- Enable provenance and SBOM on publish builds.
- Verify outputs and report external registry behavior separately from local
  build evidence.

## Single-image model

Use the sequence:

1. checkout;
2. independent lint/typecheck checks when scripts exist;
3. Buildx setup;
4. metadata and lowercase image name;
5. login only on publish events;
6. Docker build with `push: false` on PR and `true` on authorized publish;
7. commit tag on every build and `latest` only on the default branch;
8. cache configuration, provenance, SBOM, and final summary.

Do not run the application build separately when the Dockerfile already owns
it. Do not publish from arbitrary branches or from untrusted pull requests.

## Multi-image model

For dependency-ordered images, build and push uniquely named candidate tags in
dependency order. Resolve each candidate manifest to its digest, test the
native manifests using digest references, scan every candidate, sign every
digest, then promote only after all gates pass.

Promotion must validate `major.minor.patch`, create major/minor/patch,
commit, and `latest` aliases, and verify every promoted alias resolves to the
signed candidate digest. Keep promotion concurrency non-cancelable.

## Required output

Return:

1. Model selection and event/publish matrix.
2. Complete workflow with exact action/tool versions.
3. Permissions, concurrency, cache, tag, and login rationale.
4. Single-image or dependency-closure job graph.
5. Verification commands and expected failure behavior.
6. Any unresolved version compatibility or registry ownership assumptions.

Read only the relevant references:

- [workflow-contract.md](references/workflow-contract.md) for shared policy.
- [single-image-workflow.md](references/single-image-workflow.md) for one
  image.
- [multi-image-pipeline.md](references/multi-image-pipeline.md) for closure,
  candidate, promotion, scan, and signing.
- [versions-security-and-verification.md](references/versions-security-and-verification.md)
  for SemVer references, permissions, and checks.

Start from [assets/single-image.yml](assets/single-image.yml) or
[assets/multi-image.yml](assets/multi-image.yml). Run
[scripts/verify-workflow.sh](scripts/verify-workflow.sh) against the result.
