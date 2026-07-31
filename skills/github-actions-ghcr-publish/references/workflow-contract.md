# Shared workflow contract

## Event and permissions

PR validation is non-publishing. The default branch and an explicit manual
dispatch may publish. Use a job-level publish condition when a workflow also
handles pull requests. Keep `contents: read` and `packages: write` as the
baseline; grant `id-token: write` only for Cosign or attestations.

Use a concurrency group derived from workflow and ref. Validation may cancel
in progress. Promotion must use a separate non-cancelable group.

## Registry and metadata

Derive the image as `ghcr.io/<lowercase github.repository>` for a single image.
For multiple images, derive each repository from an explicit image name and
the lowercased owner. Never use user-controlled unquoted shell interpolation.

Use commit tags for traceability and `latest` only when the default branch
publishes. Keep image tags distinct from action/tool version references.

## Build contract

Use Buildx and GHA cache. Use QEMU for multi-platform builds. Pass build args
only when they are declared and required by the Dockerfile. Let the Dockerfile
own the production application build. Publish provenance and SBOM on trusted
publish events.
