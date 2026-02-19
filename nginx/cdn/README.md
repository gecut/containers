# `gecut/nginx/cdn` - Production CDN Origin Guide

`gecut/nginx/cdn` is a CDN-focused NGINX image for high-throughput static delivery.  
It extends `gecut/nginx/core` and keeps the same runtime template pipeline while overriding cache behavior for common CDN content classes.

## Target Use Cases

- Static web assets behind CDN/LB
- Fingerprinted (`hashed`) asset pipelines
- Production origins requiring deterministic cache headers
- Teams that want env-driven tuning without rebuilding image layers

## Layer Inheritance and Exact Overrides

Inheritance:

`docker nginx official -> gecut/nginx/base -> gecut/nginx/core -> gecut/nginx/cdn`

`cdn`-specific template overrides:

- `nginx/cdn/nginx/core/etc/nginx/templates/http.d/81-header.conf.template`
- `nginx/cdn/nginx/core/etc/nginx/templates/http.d/82-cache-policy-map.conf.template`
- `nginx/cdn/nginx/core/etc/nginx/templates/location.d/50-webp.conf.template`

What these add:

- `etag on`
- Cache policy maps by URI and status
- `Cache-Control` and `Vary: Accept-Encoding` headers applied with `always`
- WebP location override with `Vary: Accept,Accept-Encoding`

## Quick Start

### Pull and run

```bash
docker run --rm -p 8080:80 ghcr.io/gecut/nginx/cdn:latest
```

### Serve your own static files

```bash
docker run --rm -p 8080:80 \
  -v "$(pwd)/public:/data:ro" \
  ghcr.io/gecut/nginx/cdn:latest
```

### Docker Compose example

```yaml
services:
  cdn-origin:
    image: ghcr.io/gecut/nginx/cdn:latest
    ports:
      - "8080:80"
    volumes:
      - ./public:/data:ro
    environment:
      NGINX_TRUSTED_PROXY_CIDRS: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32"
```

## Cache Policy Engine

Defined in:

- `nginx/cdn/nginx/core/etc/nginx/templates/http.d/82-cache-policy-map.conf.template`

Policy selection:

1. `map $uri $cdn_cache_profile`
2. `map $cdn_cache_profile $cdn_cache_control_by_uri`
3. `map $status $cdn_cache_control` (forces `no-store` for `4xx/5xx`)

URI profiles:

- `hashed`: filenames matching `.<hex{6+}>.<ext>`
- `html`: `/`, directory paths, and `.html`
- `json`: `.json`
- `default`: unversioned static

Header output:

- `Cache-Control: $cdn_cache_control` (`always`)
- `Vary: Accept-Encoding` (`always`)
- plus ETag from `81-header.conf.template`

## Header Semantics Matrix

| Content class | Matching rule | Default Cache-Control | Notes |
| --- | --- | --- | --- |
| Hashed assets | `~*^.+\\.[0-9a-f]{6,}\\.(...)$` | `public, max-age=31536000, immutable, s-maxage=31536000` | Best performance path for versioned assets |
| Unversioned static | fallback/default | `public, max-age=3600, stale-while-revalidate=30` | Prevents long stale windows |
| HTML | `/`, `.../`, `.html` | `public, max-age=0, must-revalidate, s-maxage=0` | Shell pages revalidate each request |
| JSON artifact | `.json` | `public, max-age=60, stale-while-revalidate=30` | Short cache for artifacts/metadata |
| Error responses | status `4xx/5xx` | `no-store` | Avoids caching failures |

## Content-Class Examples

Examples assume a mounted `./public` directory.

### 1) Hashed asset

File: `public/app.abc12345.js`

Expected:

- `Cache-Control` contains `immutable` and `max-age=31536000`

### 2) Unversioned static

File: `public/app.js`

Expected:

- `Cache-Control: public, max-age=3600, stale-while-revalidate=30`

### 3) HTML shell

File: `public/index.html`

Expected:

- `Cache-Control: public, max-age=0, must-revalidate, s-maxage=0`

### 4) JSON artifact

File: `public/manifest.json`

Expected:

- `Cache-Control: public, max-age=60, stale-while-revalidate=30`

### 5) Error response

Missing file: `GET /does-not-exist.css`

Expected:

- HTTP 404
- `Cache-Control: no-store`

## Environment Variables

CDN cache policy variables:

| Variable | Default | Impact | Risk if changed |
| --- | --- | --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` | Base policy for hashed assets | Unsafe if assets are not fingerprinted |
| `NGINX_CDN_S_MAXAGE` | `31536000` | Shared cache TTL for hashed assets | Very long stale if CDN keying is wrong |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` | Fallback for non-hashed static files | Too long can delay content updates |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` | Browser behavior for HTML shells | More origin traffic if too strict |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` | Shared cache behavior for HTML | Setting high can serve stale HTML |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` | JSON artifact caching | Too high may break freshness assumptions |
| `NGINX_CDN_CACHE_ERROR` | `no-store` | Error response caching policy | Relaxing may cache transient failures |

Core behavior defaults re-declared in `nginx/cdn/Dockerfile`:

| Variable | Default | Impact |
| --- | --- | --- |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `1k` | Strongly limits request body size for CDN origin profile |
| `NGINX_SENDFILE` | `on` | Enables sendfile optimization |
| `NGINX_SENDFILE_MAX_CHUNK` | `2m` | Balances large transfers across connections |
| `NGINX_TCP_NOPUSH` | `on` | Optimizes packet delivery for static payloads |
| `NGINX_TCP_NODELAY` | `on` | Lowers latency on keepalive traffic |
| `NGINX_OPEN_FILE_CACHE` | `max=1000 inactive=30m` | Reduces filesystem lookup overhead |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | Cache metadata revalidation interval |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Minimum open-file cache usage threshold |
| `NGINX_OUTPUT_BUFFERS` | `8 16k` | Response output buffer sizing |
| `NGINX_EXPIRES_DYNAMIC` | `max` | Fallback `expires` policy for dynamic-like content |
| `NGINX_EXPIRES_STATIC` | `max` | Fallback `expires` policy for static-like content |
| `NGINX_EXPIRES_DEFAULT` | `max` | Global fallback `expires` policy |
| `NGINX_LIMIT_REQ_RATE` | `200` | Request-rate threshold if global limit is enabled in parent layer |
| `NGINX_LIMIT_REQ_BURST` | `1000` | Burst allowance for request limiting |
| `NGINX_GZIP` | `on` | Enables gzip compression |
| `NGINX_GZIP_VARY` | `on` | Adds gzip-related vary behavior |
| `NGINX_GZIP_STATIC` | `on` | Serves precompressed gzip artifacts |
| `NGINX_GZIP_COMP_LEVEL` | `5` | Compression level vs CPU tradeoff |
| `NGINX_GZIP_MIN_LENGTH` | `256` | Minimum payload size for gzip |
| `NGINX_DISABLE_SYMLINKS` | `if_not_owner` | Symlink serving restrictions |

High-impact inherited variables from `core` and `base`:

| Variable | Default in inherited layer | Layer |
| --- | --- | --- |
| `NGINX_WORKER_CONNECTIONS` | `2048` | base |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | base |
| `NGINX_MULTI_ACCEPT` | `off` | base |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | base/core |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | base/core |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | core |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | core |
| `NGINX_DOCUMENT_ROOT` | `/data` | core |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | core |
| `NGINX_TRUSTED_PROXY_CIDRS` | `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32` | core |
| `NGINX_RESOLVERS` | `127.0.0.11` | core |
| `NGINX_RESOLVER_VALID` | `10s` | core |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | core |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | core |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | core |

## Safe Tuning Recipes

### Throughput-first (default-oriented)

Use when assets are fingerprinted and freshness risks are controlled:

```bash
docker run --rm -p 8080:80 \
  -e NGINX_CDN_S_MAXAGE=31536000 \
  -e NGINX_CDN_CACHE_HASHED='public, max-age=31536000, immutable' \
  -v "$(pwd)/public:/data:ro" \
  ghcr.io/gecut/nginx/cdn:latest
```

### Freshness-first

Use when release pipeline has weak asset versioning:

```bash
docker run --rm -p 8080:80 \
  -e NGINX_CDN_CACHE_UNVERSIONED_STATIC='public, max-age=120, stale-while-revalidate=15' \
  -e NGINX_CDN_CACHE_JSON='public, max-age=15, stale-while-revalidate=5' \
  -v "$(pwd)/public:/data:ro" \
  ghcr.io/gecut/nginx/cdn:latest
```

### Balanced

Use when you want moderate CDN offload with predictable updates:

```bash
docker run --rm -p 8080:80 \
  -e NGINX_CDN_CACHE_UNVERSIONED_STATIC='public, max-age=900, stale-while-revalidate=30' \
  -e NGINX_CDN_CACHE_JSON='public, max-age=30, stale-while-revalidate=10' \
  -v "$(pwd)/public:/data:ro" \
  ghcr.io/gecut/nginx/cdn:latest
```

## Verification Commands

Start a local instance:

```bash
docker run --rm --name cdn-test -p 8080:80 -v "$(pwd)/public:/data:ro" ghcr.io/gecut/nginx/cdn:latest
```

Check hashed asset:

```bash
curl -sI http://localhost:8080/app.abc12345.js | rg -i 'cache-control|vary|etag'
```

Check unversioned static:

```bash
curl -sI http://localhost:8080/app.js | rg -i 'cache-control|vary|etag'
```

Check HTML:

```bash
curl -sI http://localhost:8080/ | rg -i 'cache-control|vary|etag'
```

Check JSON:

```bash
curl -sI http://localhost:8080/manifest.json | rg -i 'cache-control|vary|etag'
```

Check error response:

```bash
curl -sI http://localhost:8080/does-not-exist.css | rg -i 'http/|cache-control'
```

Inspect fully rendered config:

```bash
docker run --rm ghcr.io/gecut/nginx/cdn:latest nginx -T
```

## Troubleshooting

### Stale content for updated files

Likely causes:

- unversioned assets served with longer-than-expected TTL
- assets not actually fingerprinted

Actions:

- shorten `NGINX_CDN_CACHE_UNVERSIONED_STATIC`
- ensure CI emits hashed asset names

### Wrong client IP in logs

Likely cause:

- `NGINX_TRUSTED_PROXY_CIDRS` does not match your LB/CDN egress ranges

Actions:

- update `NGINX_TRUSTED_PROXY_CIDRS`
- confirm `NGINX_REAL_IP_HEADER` matches upstream header behavior

### Unexpected cache behavior with query strings

Current map logic uses `$uri` (path) not query args.  
Different query strings on same path still map to the same cache policy class.

Action:

- enforce versioning in path/filename for static assets

### Rate-limit unexpectedly active

Global request limit is disabled by default in `core`.  
If enabled intentionally, confirm:

- `NGINX_ENABLE_GLOBAL_LIMIT_REQ=on`
- `NGINX_LIMIT_REQ_RATE`
- `NGINX_LIMIT_REQ_BURST`

## Migration Notes from Older CDN Behavior

Compared to older minimal CDN headers:

- Removed incorrect `Expires "$http_date"` usage
- Replaced one-size-fits-all immutable policy with URI/status-driven policy map
- Added explicit `no-store` for `4xx/5xx`
- Added deterministic `Vary: Accept-Encoding` and WebP override with `Vary: Accept,Accept-Encoding`

Impact:

- Better cache correctness for HTML/JSON
- Better safety for failures
- Preserved high performance for hashed assets

## Contributing and Compatibility

- Keep CDN policy changes in `nginx/cdn/nginx/core/etc/nginx/templates/*`.
- Keep origin-hardening changes in `nginx/core`.
- Keep startup/runtime engine changes in `nginx/base`.

Compatibility assumptions:

- Origin is behind CDN/LB
- Static assets are fingerprinted for long immutable caching

License: AGPL-3.0-only (repository root `LICENSE`).
