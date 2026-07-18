# Customization recipes

## Copy-in production image

Use [the bundled Dockerfile](../assets/Dockerfile) after producing `dist/`. Pin the consumer image tag in Compose/Kubernetes too; a digest may be added by release automation for stronger immutability.

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0
COPY --chown=nginx:nginx dist/ /data/
```

Do not mount an empty volume over `/data` in the resulting deployment, because it hides copied artifacts and causes stage `45` to fail.

## Custom shell

If the build emits `app.html`:

```yaml
environment:
  NGINX_SPA_INDEX_URI: /app.html
```

The file must exist at `/data/app.html`. Prefer an `.html` suffix so inherited cache classification treats shell responses as revalidating HTML.

## Base-path deployment

For a client build published below `/portal/`:

1. configure the bundler/router base as `/portal/`;
2. place the shell at `dist/portal/index.html` and assets below `dist/portal/`;
3. set `NGINX_SPA_INDEX_URI=/portal/index.html`;
4. verify `/portal/dashboard`, `/portal/assets/<file>`, and behavior at `/`.

This image does not strip a path prefix. If an ingress rewrites `/portal/...` to `/...`, align the on-disk layout, shell URI, build base, and router basename with the rewritten URI visible to NGINX.

## Environment-only policy

Example behind a known proxy and canonical host:

```yaml
environment:
  NGINX_FORCE_DOMAIN: app.example.com
  NGINX_CANONICAL_SCHEME: https
  NGINX_FORCE_DOMAIN_STATUS: "308"
  NGINX_TRUSTED_PROXY_CIDRS: 10.20.0.0/16,2001:db8:1234::/48
  NGINX_REAL_IP_HEADER: X-Forwarded-For
  NGINX_ENABLE_GLOBAL_LIMIT_REQ: "on"
  NGINX_LIMIT_REQ_RATE: "200"
  NGINX_LIMIT_REQ_BURST: "1000"
```

Quote YAML booleans and integers so environment values remain strings. Trust
only networks controlled by the deployment. The image's Docker `HEALTHCHECK`
sends `Host: $NGINX_FORCE_DOMAIN` automatically, but Kubernetes `httpGet`
probes do not. When force-domain is enabled in Kubernetes, add an explicit
`Host` entry under `httpHeaders` on both readiness and liveness probes.

## CSP and additional headers

Overlay a uniquely named HTTP template in a downstream image:

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0
COPY --chown=nginx:nginx dist/ /data/
COPY docker/nginx/templates/http.d/83-app-security.conf.template \
  /etc/nginx/templates/http.d/83-app-security.conf.template
```

```nginx
add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' https://api.example.com" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

The base env validator rejects quotes only in selected environment-backed text. Static templates may contain CSP quotes. Run the real app and inspect browser CSP reports before enforcement.

## Redirect map

Overlay a map file below `/etc/nginx/templates/redirect.d/`; each destination is returned using `NGINX_FORCE_REDIRECT_STATUS`:

```nginx
/old-dashboard /dashboard;
/legacy/docs https://docs.example.com/;
```

The map keys use `$request_uri`, which includes query arguments. Add explicit variants if queries must redirect, or replace the map design deliberately. Avoid redirect loops and open redirects.

## Custom error page

The error location uses `root /default-data`. Override the inherited file in a downstream image:

```dockerfile
COPY docker/nginx/_error.html /default-data/_error.html
```

Do not copy it only to `/data/_error.html`. Errors keep their original status and receive the cache policy selected by status (`no-store` by default).

## Cache-classification override

To change classification, copy a complete replacement to the same template path:

```dockerfile
COPY docker/nginx/templates/http.d/82-cache-policy-map.conf.template \
  /etc/nginx/templates/http.d/82-cache-policy-map.conf.template
```

Start from the inherited map and change the smallest rule. The file owns cache profile selection, status/method precedence, and the single `Cache-Control` header. Keeping a second cache map or `add_header Cache-Control` causes ambiguous duplicate headers.

Common valid reason: a build emits hashes shorter than six hex characters. Prefer changing the build's filename strategy because immutable caching is safest when filenames change with content.

## CORS and WebP limits

`NGINX_CORS_ENABLE=on` injects headers and an OPTIONS handler only into the SPA root/fallback locations. It does not guarantee CORS on the exact shell, strict asset regex, automatic WebP regex, error page, or health endpoint. If static assets require global CORS, overlay a reviewed HTTP/location design and test every affected location.

`NGINX_AUTO_WEBP=on` serves an adjacent `.webp` file for JPEG/PNG clients that advertise WebP. It does not convert images. Generate `.webp` artifacts during the build and ensure edge caches honor `Vary: Accept`.
