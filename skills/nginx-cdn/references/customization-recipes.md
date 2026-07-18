# NGINX CDN customization recipes

Choose the smallest customization seam that satisfies the requirement.

## Serve a local directory

```sh
docker run --rm -p 8080:80 \
  --mount type=bind,src="$PWD/public",dst=/data,readonly \
  ghcr.io/gecut/nginx/cdn:2.0.0
```

Ensure files are readable by the `nginx` worker. The entrypoint still needs a writable container layer for rendered configuration; a read-only `/data` mount is supported.

## Build immutable site content into an image

Resolve `SKILL_ROOT` to the installed directory that contains this skill's
`SKILL.md`, then use its bundled [Dockerfile](../assets/Dockerfile):

```sh
docker build -t example/static-origin:1.0.0 -f "$SKILL_ROOT/assets/Dockerfile" .
docker run --rm -p 8080:80 example/static-origin:1.0.0
```

The example expects a `public/` directory in the build context. In a multi-stage frontend build, copy the completed static output into `/data/` in the final stage.

## Customize cache durations with environment variables

```yaml
services:
  origin:
    image: ghcr.io/gecut/nginx/cdn:2.0.0
    environment:
      NGINX_CDN_CACHE_UNVERSIONED_STATIC: "public, max-age=300, stale-while-revalidate=30"
      NGINX_CDN_CACHE_JSON: "public, max-age=30, stale-while-revalidate=30"
      NGINX_CDN_HTML_S_MAXAGE: "0"
    volumes:
      - ./public:/data:ro
```

Do not use environment values to make mutable filenames immutable. Fix the build’s content hashing first.

## Enable trusted client IP rewriting

```yaml
environment:
  NGINX_TRUSTED_PROXY_CIDRS: "192.0.2.0/24,2001:db8:1234::/48"
  NGINX_REAL_IP_HEADER: "X-Forwarded-For"
```

Use only the actual egress CIDRs of the load balancer/CDN. Never trust all private networks or the public internet by default. Provider CIDRs change; manage updates through the operator’s normal release process.

## Enable canonical-host redirects

```yaml
environment:
  NGINX_FORCE_DOMAIN: "static.example.com"
  NGINX_CANONICAL_SCHEME: "https"
  NGINX_FORCE_DOMAIN_STATUS: "308"
```

NGINX still listens on plain HTTP inside the container. TLS is expected at the ingress, load balancer, or CDN edge. The healthcheck sends the forced domain as Host.

## Enable precompressed and WebP representations

- Place `app.js.gz` next to `app.js`; `NGINX_GZIP_STATIC=on` is already the CDN default.
- Place `photo.jpg.webp` next to `photo.jpg` and set `NGINX_AUTO_WEBP=on`.
- Verify JPEG/PNG returns `Vary: Accept, Accept-Encoding`, serves WebP only when accepted, and falls back to the original.

If CORS is also required for image responses, replace the WebP location deliberately because the stock regex location does not include the root CORS fragment.

## Replace URI cache classification

Environment variables cannot change match rules. In a downstream image, replace the parent template at the same relative path:

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY nginx/82-cache-policy-map.conf.template \
  /etc/nginx/templates/http.d/82-cache-policy-map.conf.template
COPY --chown=nginx:nginx public/ /data/
```

Start by copying the current upstream template, then make the smallest rule change. Preserve this pipeline:

```text
URI profile -> status override -> method override -> one global Cache-Control header
```

Keep 4xx/5xx and non-GET/HEAD as `no-store`. Keep a single global Vary authority. A parent release can change the upstream template; review the replacement during every parent upgrade.

## Add an extra NGINX fragment

Templates render recursively into matching paths under `/etc/nginx/conf.d`. Common destinations:

- `http.d/*.conf` for maps and HTTP-wide directives;
- `server.d/*.conf` for complete servers;
- `location.d/*.conf` for locations included by the default server;
- `location.d/root.d/*.conf` for directives included by the ordinary root location.

Example:

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY nginx/85-extra-header.conf.template \
  /etc/nginx/templates/http.d/85-extra-header.conf.template
COPY --chown=nginx:nginx public/ /data/
```

Numbering communicates intent, but NGINX location selection still follows exact/prefix/regex rules. Regex locations are checked in configuration order and can preempt inherited WebP or security behavior. Inspect `nginx -T` after adding one.

## CORS customization

Basic root CORS controls are:

```yaml
environment:
  NGINX_CORS_ENABLE: "on"
  NGINX_CORS_ORIGIN: "https://www.example.com"
  NGINX_CORS_METHODS: "GET, OPTIONS"
  NGINX_CORS_HEADERS: "Content-Type, If-None-Match"
  NGINX_CORS_MAXAGE: "86400"
```

The built-in values produce a static policy and do not implement dynamic origin allowlists or credentials-aware reflection. For credentials or multiple origins, design an explicit map/template and test preflight plus every regex-handled asset class.

## Compose and Kubernetes

- Use the installed skill's [Compose asset](../assets/compose.yaml) for a local/read-only bind mount.
- Use the installed skill's [Kubernetes asset](../assets/kubernetes.yaml) only as a small working probe example.
- For production Kubernetes content, build a versioned downstream image or mount a suitable read-only volume. ConfigMaps have size and operational limits.
- Keep readiness/liveness on `/server-info`; add a representative content readiness check externally if content availability is a separate failure mode.
- Pin the exact base tag in examples and resolve it to a digest in the consumer’s controlled release pipeline.

## Avoid these customizations

- Do not add SPA fallback to CDN root routing; select `nginx/spa`.
- Do not add a second Cache-Control header in a location.
- Do not re-enable `expires` alongside the CDN policy map.
- Do not use the image as a dynamic reverse proxy or TLS endpoint.
- Do not mount a complete `/etc/nginx/conf.d` over generated output unless intentionally replacing the entire contract.
