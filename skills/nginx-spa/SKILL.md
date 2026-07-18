---
name: nginx-spa
description: Deploy, customize, verify, and troubleshoot static single-page applications on ghcr.io/gecut/nginx/spa. Use this skill whenever a user is serving a Vite, React Router, Vue Router, Svelte, Angular, or other client-routed static build with this image; needs deep-link fallback with strict asset 404s; asks about NGINX_SPA_INDEX_URI, subpath hosting, cache or security headers, Compose or Kubernetes manifests; or is diagnosing this container's startup and routing behavior. Do not use it for Next.js SSR, API proxying, TLS termination, or general-purpose NGINX reverse-proxy design.
license: AGPL-3.0-only
compatibility: Requires a container runtime for deployment and curl for the bundled verifier. Examples target ghcr.io/gecut/nginx/spa:1.0.0.
metadata:
  image: "ghcr.io/gecut/nginx/spa:1.0.0"
  audience: "static SPA consumers"
  scope: "deployment customization verification troubleshooting"
---

# NGINX SPA consumer workflow

Use this skill to produce consumer-side deployment artifacts and operational guidance for `ghcr.io/gecut/nginx/spa:1.0.0`. Preserve the image's runtime contract. Do not redesign its internal entrypoint or templates unless the user explicitly asks to work on the image source.

## Establish fit first

Confirm that the application produces a complete static directory containing a readable HTML shell. Choose this image when client-side routing owns extensionless application URLs and missing files must remain real `404` responses.

Decline or redirect the design when the workload requires:

- server-side rendering or a Node runtime;
- API, WebSocket, or upstream reverse proxying;
- `proxy_cache` or artifact fetching at request time;
- TLS certificate management inside this container;
- runtime HTML generation.

For these cases, recommend the application's server runtime or a dedicated ingress/reverse proxy in front of it. Do not invent unsupported NGINX directives and present them as image environment variables.

## Read only the references needed

- Read [runtime contract](references/runtime-contract.md) before choosing mounts, users, health checks, or environment variables.
- Read [routing, cache, and security](references/routing-cache-security.md) for deep links, dotted routes, cache precedence, CORS, WebP, canonical redirects, real IP, or rate limiting.
- Read [customization recipes](references/customization-recipes.md) when producing a Dockerfile, Compose/Kubernetes deployment, custom shell, subpath setup, CSP/header override, redirect map, or custom template.
- Read [diagnostics](references/diagnostics.md) when startup fails, a route returns the wrong status, or rendered configuration must be inspected.

## Workflow

1. Identify the build output directory, shell URI, public base path, client router mode, and edge proxy/CDN topology.
2. Confirm the shell exists at `<document-root><NGINX_SPA_INDEX_URI>` and that asset URLs match the build's public base.
3. Select immutable delivery:
   - copy artifacts into a downstream image for production releases;
   - use a read-only bind mount for local or externally managed artifacts.
4. Start from a pinned image tag: `ghcr.io/gecut/nginx/spa:1.0.0`. Never emit `latest` in deployable examples.
5. Apply the smallest customization level that meets the requirement:
   - environment variables;
   - consumer-provided static files;
   - a downstream image that overlays a template or map;
   - an external ingress/CDN for TLS, WAF, or proxy behavior.
6. Verify the actual origin with [scripts/verify-spa.sh](scripts/verify-spa.sh), resolving the command from this installed `SKILL.md`; then inspect `nginx -T` if behavior differs from the contract.
7. Report assumptions, generated artifacts, verification evidence, and any behavior that remains owned by an external CDN/ingress.

## Routing invariants

Preserve these properties:

- Existing files and directories are served normally.
- A missing extensionless URI internally resolves to the configured shell with final status `200`.
- A missing URI containing a dot is a real `404`, even when the dot belongs to an application route.
- Missing known static assets are strict `404` responses and never fall back to HTML.
- The application router owns client-side not-found UI after a shell fallback.
- The configured shell is validated before NGINX starts.

Do not add a broad `try_files ... /index.html` location that turns missing assets into `200` HTML. Do not add another `Cache-Control` authority without first removing or replacing the inherited CDN map.

## Deployment defaults

Prefer the copy-in [Dockerfile asset](assets/Dockerfile), the [Compose asset](assets/compose.yaml), or the [Kubernetes asset](assets/kubernetes.yaml). Adapt names, registry, probes, resources, and artifact source to the user's environment while retaining the pinned base image and health endpoint.

Use `/data` unless an absolute `NGINX_DOCUMENT_ROOT` is intentionally configured. A read-only `/data` mount is supported. The entrypoint still needs writable configuration and runtime paths, so do not set the entire container filesystem read-only without supplying correct writable tmpfs mounts.

## Safety rules

- Treat `NGINX_FORCE_DOMAIN` as host canonicalization, not automatic HTTP-to-HTTPS enforcement. `NGINX_CANONICAL_SCHEME` controls only the generated redirect URL.
- Configure `NGINX_TRUSTED_PROXY_CIDRS` before trusting a forwarded client IP. Rate limits otherwise operate on the direct peer address.
- Do not enable `NGINX_DISALLOW_ROBOTS=on` with a read-only document root unless the desired `robots.txt` already exists and differs from the bundled permissive file.
- CORS snippets are included only by the two SPA fallback locations; exact shell, strict asset, WebP, and special locations can bypass them. Do not claim global CORS coverage.
- Automatic WebP uses URI negotiation for JPEG/PNG. Verify both variants and `Vary` behavior at the outer CDN.
- Keep secrets out of static SPA artifacts and `NGINX_*` variables. Browser-delivered files are public.
- Keep CSP application-specific. Validate it against the actual script, style, font, image, API, and worker origins.

## Output contract

Return an implementation-ready response containing:

1. **Fit decision** — why the workload is or is not a static SPA match.
2. **Deployment artifact** — pinned Dockerfile, Compose, Kubernetes, or exact command requested.
3. **Routing and cache expectations** — representative shell, deep-route, asset, dotted-route, and error statuses.
4. **Customization notes** — each non-default environment variable or overlaid template and its consequence.
5. **Verification** — exact verifier command plus any direct `curl` or `nginx -T` checks.
6. **Risks/ownership** — ingress, CDN, DNS, TLS, CSP, and client-router behavior that cannot be proven locally.

When editing a repository, follow its conventions and make only authorized changes. When only advice is requested, do not mutate files or external systems.
