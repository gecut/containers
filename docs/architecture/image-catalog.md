# Image Catalog and Compatibility Contract

HT-34 freezes the public image catalog for `gecut/containers`. The source of truth is [`catalog/images.yaml`](../../catalog/images.yaml); this document is the human-readable contract and must stay consistent with that YAML. Later issues own schema validation, dependency graph automation, release engines, workflow changes, and registry mutations.

## Scope and ownership boundary

This contract defines names, support status, inheritance boundaries, compatibility guarantees, tag policy, and inventory evidence only. It does not publish, delete, archive, repoint, tag, release, deploy, or mutate any registry package.

A feature belongs to the lowest layer that owns it. Downstream images inherit parent behavior and must not redefine the same ownership contract.

## Active canonical images

Exactly seven GHCR packages are active. Every active image starts independent SemVer at `1.0.0`, supports `linux/amd64` and `linux/arm64`, publishes only to GHCR, and uses the compatibility and tag policy in this document. The NGINX base/core/CDN contract has a major v2 release line; SPA starts at v1.

| ID | Canonical GHCR path | Source context | Parent | Role | Ownership boundary |
| --- | --- | --- | --- | --- | --- |
| `nginx-base` | `ghcr.io/gecut/nginx/base` | `nginx/base` | none | NGINX runtime and template-engine foundation | Entrypoint orchestration, environment-template rendering, NGINX process defaults, and base runtime cleanup only. |
| `nginx-core` | `ghcr.io/gecut/nginx/core` | `nginx/core` | `nginx-base` | NGINX static-origin profile | Static serving defaults, security locations, real-IP handling, gzip, optional CORS, WebP, force-domain, rate-limit, healthcheck, and default data behavior inherited by CDN. |
| `nginx-cdn` | `ghcr.io/gecut/nginx/cdn` | `nginx/cdn` | `nginx-core` | CDN-focused NGINX cache-policy specialization | CDN cache headers, cache-policy maps, ETag behavior, CDN-oriented static defaults, and downstream CDN-origin tuning only. |
| `nginx-spa` | `ghcr.io/gecut/nginx/spa` | `nginx/spa` | `nginx-cdn` | Strict static SPA hosting | SPA shell readiness, extensionless route fallback, and real 404 behavior for missing static assets. |
| `nextjs-base` | `ghcr.io/gecut/nextjs/base` | `nextjs/base` | none | Next.js runtime foundation | Non-root Next.js runtime setup, shared startup scripts, permission repair, public asset copy, revalidation hook, tini entrypoint, and base Node runtime behavior. |
| `nextjs-prisma` | `ghcr.io/gecut/nextjs/prisma` | `nextjs/with-prisma` | `nextjs-base` | Next.js runtime with Prisma application-start hook | Prisma-specific startup detection and command hook only; shared Next.js runtime behavior belongs to `nextjs-base`. |
| `nextjs-payload` | `ghcr.io/gecut/nextjs/payload` | `nextjs/with-payload` | `nextjs-base` | Next.js runtime with Payload application-start hook | Payload-specific startup detection and command hook only; shared Next.js runtime behavior belongs to `nextjs-base`. |

### Inheritance model

```text
NGINX:  nginx-base -> nginx-core -> nginx-cdn -> nginx-spa
Next.js: nextjs-base -> nextjs-prisma
         nextjs-base -> nextjs-payload
```

Parent changes that affect a child require a new child release. The release mechanics are intentionally out of scope for HT-34 and will be implemented later.

## Registry and naming policy

- GHCR is the only active publication registry.
- Docker Hub publication is disabled now.
- The catalog remains Docker Hub compatibility-ready so a future mirror can be added without renaming canonical images or redesigning the schema.
- Canonical OCI naming follows `gecut/{family}/{variant}`.
- No two source contexts may claim the same canonical package.
- `nexload` is an active alias that tracks `nextjs-payload` / `ghcr.io/gecut/nextjs/payload`.
- `gecut/nextjs` remains frozen and must not be repointed to another image.

## Compatibility contract

- Released exact SemVer tags are immutable and remain pullable.
- SHA tags are immutable and remain pullable.
- Breaking public behavior or configuration changes require a major release.
- Backward-compatible capabilities use a minor release.
- Backward-compatible fixes use a patch release.
- Every active canonical image versions independently.
- Parent changes that affect a child require a new child release.
- Active aliases resolve to the same intended release/digest as their canonical target.
- Frozen and archived-pullable packages receive no compatibility evolution, maintenance promise, or vulnerability-fix commitment.
- Archived tags must not be reused or repointed.
- GHCR-only publication is active now; Docker Hub remains compatibility-ready but disabled.

## Tag policy

Exact SemVer tags such as `1.0.0` and SHA tags are immutable. Major tags, minor tags, and `latest` are moving convenience aliases governed by release policy. Archived tags must not be reused or repointed.

## Legacy inventory and support classification

Every non-canonical item discovered from repository directories, Dockerfiles, workflow references, documentation, scripts, and available registry checks is classified as exactly one of `active-alias`, `frozen`, or `archived-pullable`.

| Item | Classification | Evidence | Policy |
| --- | --- | --- | --- |
| `ghcr.io/gecut/nexload` | `active-alias` | Workflow matrix names `nexload` for `nextjs/with-payload`; Payload Dockerfile labels the image title as `gecut/nextjs/nexload`. | Tracks `ghcr.io/gecut/nextjs/payload` and must resolve to the same intended release/digest. |
| `ghcr.io/gecut/nextjs` | `frozen` | Workflow matrix names `nextjs` for `nextjs/base`; Prisma README references legacy `gecut/nextjs` Docker Hub package. | Remains pullable at existing state and must not be repointed. |
| `ghcr.io/gecut/nextjs/with-prisma` | `archived-pullable` | Prisma README documents `ghcr.io/gecut/nextjs/with-prisma`; Prisma Dockerfile labels `gecut/nextjs/with-prisma`. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `ghcr.io/gecut/nextjs/with-payload` | `archived-pullable` | Payload README documents `ghcr.io/gecut/nextjs/with-payload`. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `docker.io/mm25zamanian/nginx/base` | `archived-pullable` | The pre-v2 workflow contained this disabled Docker Hub target. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `docker.io/mm25zamanian/nginx/core` | `archived-pullable` | The pre-v2 workflow contained this disabled Docker Hub target. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `docker.io/mm25zamanian/nginx/cdn` | `archived-pullable` | The pre-v2 workflow contained this disabled Docker Hub target. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `docker.io/mm25zamanian/nextjs` | `frozen` | Workflow metadata includes disabled Docker Hub target `docker.io/mm25zamanian/${matrix.name}`. | Remains frozen and must not be repointed. |
| `docker.io/mm25zamanian/nexload` | `archived-pullable` | Workflow metadata includes disabled Docker Hub target `docker.io/mm25zamanian/${matrix.name}`. | Pullable if present, with no new releases, maintenance, or vulnerability fixes. |
| `docker.io/gecut/nextjs` | `frozen` | Prisma README has Docker Hub badge/link for `gecut/nextjs`. | Remains frozen and must not be repointed. |

## Registry inventory evidence gap

Read-only GHCR package inventory could not be completed from this environment. The GitHub Packages API returned `401 Unauthorized` for package-version requests for the active and legacy GHCR names, and no credentials were available. This is an evidence gap, not an assumption; no registry mutation was attempted.

## Active responsibilities

Active platform responsibilities are limited to the ownership boundaries in the active catalog. In particular, the active NGINX stack covers base templating, static-origin behavior, CDN-origin cache header policy, and strict static SPA routing. The active Next.js stack covers base runtime behavior plus Prisma-specific or Payload-specific application-start hooks in the corresponding child images.

## Out of scope for the current platform contract

The following are intentionally excluded from the current platform contract:

- NGINX reverse-proxy cache mode.
- Brotli support.
- Active Docker Hub publishing.
- Runtime-managed Prisma or Payload migrations.

The repository may contain scripts, skipped templates, or historical documentation that mention excluded capabilities. HT-34 does not expand the active contract for those features.
