---
name: nginx-cdn
description: Design, configure, extend, and diagnose static CDN origins built from ghcr.io/gecut/nginx/cdn. Use this skill whenever a user mentions the Gecut nginx/cdn image, CDN-origin Cache-Control or Vary behavior, immutable hashed assets, service-worker caching, ETag validation, WebP negotiation, derived NGINX templates, or deploying this image with Docker Compose or Kubernetes. Do not use it for reverse proxies, proxy_cache, dynamic upstream applications, or SPA history fallback; nginx/spa owns SPA routing.
license: AGPL-3.0-only
metadata:
  author: "Gecut"
  version: "1.0.0"
  image: "ghcr.io/gecut/nginx/cdn:2.0.0"
  source: "https://github.com/gecut/containers/tree/main/nginx/cdn"
compatibility: "Requires a POSIX shell for bundled diagnostics and curl for live origin verification. Examples target Docker, Compose Specification, and Kubernetes v1 APIs."
---

# Gecut NGINX CDN

Operate `ghcr.io/gecut/nginx/cdn:2.0.0` as a static-file CDN origin. Treat the image as an origin server that emits cache metadata; it is not a reverse proxy, a `proxy_cache`, an object store, or a CDN provider.

## Establish the task boundary

Use this skill when the requested outcome is one or more of:

- serve static files from `/data` with CDN-safe response headers;
- explain or customize cache classification, `Cache-Control`, `Vary`, ETag, gzip, or optional WebP;
- build a downstream image or deployment around `nginx/cdn`;
- diagnose startup validation, routing, cache, conditional-request, or header behavior.

Route adjacent work deliberately:

- Use `nginx/spa` for history-mode application routes and shell fallback.
- Use `nginx/core` when cache specialization is unwanted.
- Design a separate NGINX profile for upstream proxying, TLS termination, `proxy_cache`, authentication, or dynamic application traffic.
- In mixed applications, keep `nginx/cdn` only as a separate origin for completed static assets; run dynamic APIs/SSR behind their own application runtime and proxy tier.

## Read only what the task needs

- Read [references/runtime-contract.md](references/runtime-contract.md) before changing deployment, inherited settings, filesystem layout, startup behavior, headers, CORS, WebP, or health checks.
- Read [references/cache-model.md](references/cache-model.md) for every cache-policy, filename, status, method, `Vary`, ETag, or invalidation question.
- Read [references/customization-recipes.md](references/customization-recipes.md) before producing environment configuration, a derived image, a replacement template, Compose, or Kubernetes output.
- Read [references/diagnostics.md](references/diagnostics.md) for failures, verification, incident response, or cache-header audits.

Each reference is standalone. Load more than one when the change crosses concerns.

## Workflow

1. **Identify the artifact and route inventory.** Record the document root, HTML entry points, hashed and unhashed assets, JSON/manifests, service-worker filename, image formats, and whether any client-side route fallback is required.
2. **Select the correct image.** Choose `nginx/cdn` only for ordinary static-origin routing. If an unknown extensionless route must return an application shell, switch to `nginx/spa` rather than weakening CDN 404 behavior.
3. **Classify the requested change.** Prefer an existing environment variable for cache values and inherited core features. Replace a template only when URI classification or NGINX structure must change.
4. **Preserve single header authority.** Keep CDN `Cache-Control` and `Vary` maps authoritative. Do not add a second `add_header Cache-Control`, enable inherited `expires`, or turn gzip-generated `Vary` back on without proving that duplicates cannot occur.
5. **Pin inputs.** Use exact image tag `2.0.0` in copy-ready examples. For a production release, let the consumer additionally pin the resolved digest through their own update process.
6. **Validate startup configuration.** Exercise the actual entrypoint, not only `nginx -t` against unrendered templates. Invalid environment values, generated configuration, or template syntax must stop the container.
7. **Verify externally visible behavior.** Check status, one Cache-Control field, one Vary field, ETag/304 behavior, 404 `no-store`, and every customized content class. Use [scripts/verify-origin.sh](scripts/verify-origin.sh) when fixtures are available; resolve its command path from this installed `SKILL.md`, not from a repository-relative assumption.
8. **Report limitations.** State that origin headers do not prove a downstream CDN honors them. Call out untested CDN-provider behavior, absent Docker/Kubernetes access, and any route class without a real fixture.

## Non-negotiable invariants

- Keep error responses and non-GET/HEAD responses `no-store`.
- Keep service workers revalidated; never make `service-worker.js` or `sw.js` immutable.
- Apply immutable caching only to filenames whose content changes whenever the filename changes.
- Keep HTML revalidating unless the user explicitly owns a safe release/invalidation strategy.
- Keep `NGINX_EXPIRES_DYNAMIC`, `NGINX_EXPIRES_STATIC`, and `NGINX_EXPIRES_DEFAULT` at `off` in this layer.
- Cache environment variables change policy values only; they cannot change URI classification or filename matching.
- Preserve `Vary: Accept-Encoding`; preserve `Accept` for JPEG/PNG when WebP negotiation is enabled.
- Never trust forwarded client IP headers without explicit trusted proxy CIDRs.
- Do not claim Brotli, TLS, reverse proxying, on-disk caching, purge APIs, range-cache logic, or SPA fallback; this image does not provide them.

## Required response contents

For deployment or architecture work, explicitly return:

1. the fit decision and exact pinned image;
2. the content path plus environment/template changes and why each seam is sufficient;
3. the expected cache/routing matrix and runnable verification commands;
4. limitations owned elsewhere, including TLS and the downstream CDN's cache,
   purge, and invalidation behavior;
5. for mixed static/dynamic systems, the separate static-assets role that can
   remain on `nginx/cdn` after dynamic traffic moves to an application/proxy tier.

## Prefer bundled assets

Start from these copy-ready, pinned examples instead of recreating deployment boilerplate:

- [assets/Dockerfile](assets/Dockerfile) builds static content into a downstream image.
- [assets/compose.yaml](assets/compose.yaml) bind-mounts a local static directory read-only.
- [assets/kubernetes.yaml](assets/kubernetes.yaml) serves a small ConfigMap-backed origin and demonstrates probes.

Adapt names, ownership, replicas, resource requests, ingress/CDN integration, and digest pinning to the consumer environment. Do not copy the Kubernetes ConfigMap pattern for large sites; build content into an image or use an appropriate read-only volume.

## Review checklist

- The selected image matches static CDN-origin semantics.
- `/data` contains readable files and the deployment does not expect SPA fallback.
- Hashed filenames match the actual classifier before receiving immutable policy.
- HTML, JSON/manifests, service workers, errors, and non-GET methods have deliberate policies.
- Cache headers have one authority; `expires` is not re-enabled accidentally.
- CORS and WebP interaction has been verified on actual image responses when both are enabled.
- Real-IP trust lists contain only the load balancer/CDN CIDRs the operator controls.
- The entrypoint completes and its final `nginx -t` succeeds.
- Origin checks cover status, Cache-Control, Vary, ETag, and 304.
- Provider-side caching and purge behavior are explicitly left to the configured CDN.
