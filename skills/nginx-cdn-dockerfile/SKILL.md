---
name: nginx-cdn-dockerfile
description: Write, review, and modernize production Dockerfiles for static web applications built on ghcr.io/gecut/nginx/cdn. Use this skill whenever a project needs a Node/pnpm build stage, a static artifact copied into nginx-cdn, default NGINX cache/compression settings, a basic health contract, or a Dockerfile audit. Detect SPA and legacy Gecut images, route SPA work to nginx-spa, and ask before applying an incompatible major upgrade.
license: AGPL-3.0-only
metadata:
  author: "Gecut"
  version: "1.0.0"
  image: "ghcr.io/gecut/nginx/cdn:2.0.0"
  scope: "consumer Dockerfile authoring"
compatibility: "Requires Dockerfile inspection and a POSIX shell for the bundled verifier. Examples target Docker BuildKit, Node/pnpm static builds, and ghcr.io/gecut/nginx/cdn."
---

# NGINX CDN Dockerfile authoring

Use this skill to produce a maintainable consumer Dockerfile whose final image
is a static Gecut CDN origin. The Dockerfile is the source of truth for the
application build; a deployment workflow may run independent checks but must
not build the application a second time merely to produce the same artifact.

## Establish fit

Inspect the repository before writing anything:

1. Find the package manager, lockfile, build output, build script, and optional
   lint/typecheck scripts.
2. Confirm that the output is a complete static directory.
3. Detect client-side history routing. If extensionless unknown paths must
   return the application shell, route to `nginx-spa` and do not weaken CDN
   404 behavior.
4. Treat `ghcr.io/gecut/nginx:0.0.0-cdn` and similar legacy names as migration
   work. Do not silently preserve them as the recommended runtime.
5. Verify the latest compatible stable versions of the Node base image, pnpm,
   and nginx-cdn before generating output. Use `major.minor.patch` references;
   do not add digest syntax. Ask when the latest major is incompatible with
   the lockfile or application runtime.

## Build-stage contract

- Use a multi-stage Dockerfile with a small, explicit base/dependency/builder
  structure when the repository builds with Node.
- Copy manifests and the lockfile before source files so dependency layers are
  reusable.
- Use BuildKit cache mounts for pnpm's store and `--frozen-lockfile`.
- Enable Corepack and activate the exact stable pnpm version used by the repo.
- Run `lint`, `typecheck`, and `build` only when the corresponding scripts
  exist and are appropriate for the project.
- Do not copy `node_modules`, source files, or a Node runtime into the final
  static image.
- Copy the actual build directory into `/data` with `--chown=nginx:nginx`.
- Keep the final base image at the latest compatible
  `ghcr.io/gecut/nginx/cdn:X.Y.Z` tag, never `latest` or a digest.

## Runtime defaults

Set only supported variables in the final stage. The baseline for mutable
static deployments is a five-minute browser/shared-cache policy:

```dockerfile
ENV NGINX_CDN_S_MAXAGE=300 \
    NGINX_CDN_IMAGE_S_MAXAGE=300 \
    NGINX_CDN_HTML_S_MAXAGE=300 \
    NGINX_CDN_CACHE_HASHED="public, max-age=300, must-revalidate" \
    NGINX_CDN_CACHE_UNVERSIONED_STATIC="public, max-age=300, must-revalidate" \
    NGINX_CDN_CACHE_JSON="public, max-age=300, must-revalidate" \
    NGINX_CDN_CACHE_IMAGE="public, max-age=300, must-revalidate" \
    NGINX_CDN_CACHE_HTML="public, max-age=300, must-revalidate" \
    NGINX_CDN_CACHE_SERVICE_WORKER="no-cache" \
    NGINX_CDN_CACHE_ERROR="no-store" \
    NGINX_GZIP=off \
    NGINX_GZIP_STATIC=off \
    NGINX_GZIP_VARY=off \
    NGINX_EXPIRES_DYNAMIC=off \
    NGINX_EXPIRES_STATIC=off \
    NGINX_EXPIRES_DEFAULT=off
```

Adjust domain, CORS, WebP, real-IP CIDRs, and security headers only when the
project contract proves they are needed. Never invent an unsupported NGINX
variable. Keep service workers revalidating, errors `no-store`, and avoid
immutable policy for mutable filenames.

Use the image's `/server-info` and health contract. Add an explicit
`HEALTHCHECK` only when the selected image does not already provide a valid
one and the health command exists in the image.

## Required output

Return:

1. Fit decision and selected image version.
2. Complete Dockerfile with stage and cache rationale.
3. Final-stage environment matrix and project-specific assumptions.
4. Exact build, lint, inspect, and smoke commands.
5. Duplicate-build findings in the deployment workflow.
6. Limitations, especially CDN-edge behavior that the origin cannot prove.

Read only the relevant references:

- [dockerfile-build-stages.md](references/dockerfile-build-stages.md) for
  package-manager and stage selection.
- [nginx-cdn-runtime.md](references/nginx-cdn-runtime.md) for runtime image,
  env ownership, cache, compression, and health behavior.
- [project-env-policy.md](references/project-env-policy.md) for default env
  selection and project-specific overrides.
- [dockerfile-verification.md](references/dockerfile-verification.md) for
  validation and failure handling.

Start from [assets/Dockerfile](assets/Dockerfile) and
[assets/compose.yaml](assets/compose.yaml) when they fit. Run
[scripts/verify-dockerfile.sh](scripts/verify-dockerfile.sh) against the final
Dockerfile before handing it off.
