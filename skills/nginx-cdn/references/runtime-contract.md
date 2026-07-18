# NGINX CDN runtime contract

This reference describes the effective runtime inherited by `ghcr.io/gecut/nginx/cdn:2.0.0`.

## Image chain and ownership

```text
docker.io/library/nginx:1.30.4-alpine-slim (digest-pinned by the base image)
  -> ghcr.io/gecut/nginx/base:2.0.0
    -> ghcr.io/gecut/nginx/core:2.0.0
      -> ghcr.io/gecut/nginx/cdn:2.0.0
```

The layers own different contracts:

| Layer | Owns |
| --- | --- |
| `base` | Official entrypoint integration, recursive envsubst, worker/event settings, final configuration validation |
| `core` | Static origin, security locations, logs, MIME types, gzip, default/error files, health endpoint, real IP, resolver, CORS, WebP, canonical redirects, robots, request limiting |
| `cdn` | Cache classification and headers, ETag, CDN-oriented defaults, WebP/header deduplication |

The CDN image serves local files. It does not proxy upstream traffic, terminate TLS, create a disk cache, or purge a downstream CDN.

## Process and filesystem

| Contract | Value |
| --- | --- |
| Entrypoint | `/docker-entrypoint.sh` |
| Command | `nginx -g 'daemon off;'` |
| Port | `80`, IPv4 and IPv6 |
| Stop signal | `SIGQUIT` |
| Working/document root | `/data` by default |
| Worker user | `nginx`; master follows the official root/port-80 model |
| Templates | `/etc/nginx/templates/**/*.template` |
| Rendered config | `/etc/nginx/conf.d/**` |
| Health endpoint | `GET /server-info`, plain text, status 200 |
| Container healthcheck | Requests `/server-info` on loopback, using `NGINX_FORCE_DOMAIN` as Host when configured |

Bind mounts under `/data` may be read-only. Files must be readable by the `nginx` worker. The core layer copies bundled defaults from `/default-data` only when the document root is writable and never overwrites an existing file. A read-only consumer mount skips this copy.

## Startup sequence

The official entrypoint processes `/docker-entrypoint.d` by filename. The effective custom sequence is:

1. `19-validate-env.sh` rejects known unsafe or malformed values.
2. `20-envsubst-on-templates.sh` recursively renders matching templates with temporary-file replacement.
3. `21-real-ip-trusted-proxies.sh` writes or removes the real-IP include.
4. `22-resolver.sh` writes or removes the resolver include.
5. `30-copy-default-data.sh` copies absent bundled files when `/data` is writable.
6. `40-disallow-robots.sh` conditionally replaces only the bundled permissive robots file.
7. `91-force-domain.sh`, `92-auto-webp.sh`, `93-cors.sh`, and `94-global-rate-limit.sh` remove rendered feature files when their feature is off.
8. `99-validate-nginx.sh` runs `nginx -t`; failure prevents startup.

Only environment names matching `NGINX_ENVSUBST_FILTER` are substituted. Its default `^NGINX_` preserves runtime NGINX variables such as `$uri`, `$status`, and `$request_method`.

## Core variables inherited by CDN

These are the public inherited controls most relevant to consumers:

| Variable | Default | Meaning |
| --- | --- | --- |
| `NGINX_DOCUMENT_ROOT` | `/data` | Absolute static document root |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Access-log destination and optional format |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | NGINX error-log level |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `1k` in CDN | Request-body limit |
| `NGINX_AUTOINDEX` | `off` | Directory listing |
| `NGINX_FORCE_DOMAIN` | empty | Canonical hostname; empty disables redirect |
| `NGINX_FORCE_DOMAIN_STATUS` | `308` | Canonical redirect status |
| `NGINX_CANONICAL_SCHEME` | `https` | Canonical redirect scheme |
| `NGINX_CORS_ENABLE` | `off` | Enable configured CORS headers in root-including locations |
| `NGINX_CORS_ORIGIN` | `*` | CORS allow-origin value |
| `NGINX_CORS_METHODS` | `GET, OPTIONS` | CORS allow-methods value |
| `NGINX_CORS_HEADERS` | `*` | CORS allow-headers value |
| `NGINX_CORS_MAXAGE` | `86400` | Preflight max age |
| `NGINX_AUTO_WEBP` | `off` | Try `<original>.webp` for JPEG/PNG clients accepting WebP |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | Enable global request limiting |
| `NGINX_LIMIT_REQ_RATE` | `200` | Requests/second when enabled |
| `NGINX_LIMIT_REQ_BURST` | `1000` in CDN | Immediate burst when enabled |
| `NGINX_TRUSTED_PROXY_CIDRS` | empty | Explicit comma/semicolon-separated proxy CIDRs |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Trusted client-IP header after CIDRs are configured |
| `NGINX_RESOLVERS` | empty | Empty, `local`, or explicit IP literals |
| `NGINX_RESOLVER_VALID` | `10s` | Resolver validity period |
| `NGINX_DISALLOW_ROBOTS` | `off` | Replace only the bundled permissive robots file |
| `NGINX_DISABLE_SYMLINKS` | `off` | `off`, `on`, or `if_not_owner` |
| `NGINX_GZIP` | `on` | Dynamic gzip |
| `NGINX_GZIP_STATIC` | `on` | Serve matching precompressed `.gz` files |
| `NGINX_GZIP_VARY` | `off` in CDN | Disabled because CDN emits one explicit Vary field |
| `NGINX_GZIP_COMP_LEVEL` | `5` | Compression level 1-9 |
| `NGINX_GZIP_MIN_LENGTH` | `256` | Minimum response length |

Performance controls remain available: `NGINX_SENDFILE`, `NGINX_TCP_NOPUSH`, `NGINX_TCP_NODELAY`, `NGINX_OPEN_FILE_CACHE`, `NGINX_OPEN_FILE_CACHE_VALID`, `NGINX_OPEN_FILE_CACHE_MIN_USES`, `NGINX_KEEPALIVE_TIMEOUT`, `NGINX_KEEPALIVE_REQUESTS`, `NGINX_WORKER_CONNECTIONS`, `NGINX_WORKER_RLIMIT_NOFILE`, and `NGINX_MULTI_ACCEPT`.

CDN deliberately sets `NGINX_EXPIRES_DYNAMIC`, `NGINX_EXPIRES_STATIC`, and `NGINX_EXPIRES_DEFAULT` to `off`. Keep them off so `Cache-Control` remains the single cache authority.

## Routing and security

- Existing files are served with normal NGINX static routing.
- Missing files produce a real 404 rendered through the internal bundled error document.
- `HEAD`, `GET`, and `OPTIONS` are allowed in the ordinary root location; other methods are denied there.
- Dotfiles and sensitive backup/config/script extensions are denied.
- Real files below `/.well-known/` remain available.
- Security headers include `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, and `Referrer-Policy: strict-origin-when-cross-origin`, including error responses.
- Generic CSP and TLS/HSTS are application/edge owned.

### CORS and WebP caveat

CORS directives live in a `root.d` include. The optional JPEG/PNG WebP regex location does not include `root.d`, so CORS is not reliably present on image responses handled by that location. If both features are required, replace the WebP location template to include an intentional CORS policy and verify actual responses. Do not assume that enabling both environment flags composes them automatically.

## Advanced renderer controls

The renderer also recognizes:

- `NGINX_ENVSUBST_FILTER` (default `^NGINX_`)
- `NGINX_ENVSUBST_TEMPLATE_DIR` (default `/etc/nginx/templates`)
- `NGINX_ENVSUBST_TEMPLATE_SUFFIX` (default `.template`)
- `NGINX_ENVSUBST_OUTPUT_DIR` (default `/etc/nginx/conf.d`)

Changing the output directory alone disconnects generated files from the default NGINX includes. Treat these as derived-image controls and adjust `nginx.conf` consistently.
