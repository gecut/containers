# `gecut/nginx/core` - Origin Layer Guide

`nginx/core` extends `gecut/nginx/base` with an opinionated static-origin profile for production environments, especially when running behind a CDN or load balancer.

## What `core` Adds on Top of `base`

- Default static server on port `80`
- Security-focused location rules
- Real IP handling with runtime-generated trusted CIDRs
- Performance defaults (`sendfile`, keepalive, open file cache, gzip)
- Optional runtime toggles for CORS, force-domain redirect, auto-webp, and global request limiting
- Default error page handling and health endpoint (`/server-info`)

## HTTP Template Map

Primary template roots:

- `nginx/core/etc/nginx/templates/http.d`
- `nginx/core/etc/nginx/templates/server.d`
- `nginx/core/etc/nginx/templates/location.d`
- `nginx/core/etc/nginx/templates/location.d/root.d`

High-impact files:

- `http.d/00-main.conf.template`: transport and resolver settings
- `http.d/10-real-ip.conf.template`: real IP strategy
- `http.d/40-map-expire.conf.template`: `expires` policy map
- `http.d/60-performance.conf.template`: keepalive, file cache, output buffers
- `http.d/61-gzip.conf.template`: gzip and gzip_static
- `http.d/70-request-limit.conf.template`: request limiting directives
- `server.d/00-default.conf.template`: default static server
- `location.d/10-error-page.conf.template`: error handling with `no-store`

## Real IP Trust Model

Files:

- `nginx/core/etc/nginx/templates/http.d/10-real-ip.conf.template`
- `nginx/core/etc/nginx/entrypoint.d/21-real-ip-trusted-proxies.sh`
- `nginx/core/etc/nginx/templates/http.d/10-real-ip-trusted.conf.template`

Model:

1. `real_ip_header` is configurable via `NGINX_REAL_IP_HEADER`
2. trusted proxy CIDRs are generated at startup into `/etc/nginx/conf.d/http.d/10-real-ip-trusted.conf`
3. default trusted CIDRs:
   - `10.0.0.0/8`
   - `172.16.0.0/12`
   - `192.168.0.0/16`
   - `127.0.0.1/32`

Why this matters:

- Controls correctness of `$remote_addr`
- Impacts logs, rate limiting, and security decisions

## Performance Defaults and Rationale

| Env var | Default | Purpose | Risk / note |
| --- | --- | --- | --- |
| `NGINX_SENDFILE` | `on` | Kernel-level file transfer | Can be unsuitable for some network filesystems |
| `NGINX_SENDFILE_MAX_CHUNK` | `2m` | Fairness across connections | Too high may increase worker monopolization |
| `NGINX_TCP_NOPUSH` | `on` | Better packet coalescing for static responses | Mostly relevant with sendfile |
| `NGINX_TCP_NODELAY` | `on` | Lower latency for keepalive traffic | Usually safe default |
| `NGINX_OPEN_FILE_CACHE` | `max=1000 inactive=30m` | Reduce fs lookup overhead | Tune for inode churn |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | Cache revalidation interval | Too long can delay file visibility |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | Connection reuse window | Too high can increase idle FD usage |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | Requests per keepalive connection | Too low increases reconnect overhead |
| `NGINX_GZIP` | `on` | Dynamic compression | CPU cost on high traffic |
| `NGINX_GZIP_STATIC` | `on` | Serve precompressed `.gz` when available | Requires artifact pipeline support |

## Optional Features via Runtime Toggles

Toggles are implemented by removing rendered config files during startup.

| Feature | Default behavior | Toggle env | Script |
| --- | --- | --- | --- |
| Global request limit | Disabled | `NGINX_ENABLE_GLOBAL_LIMIT_REQ=on` to enable | `entrypoint.d/94-global-rate-limit.sh` |
| CORS block in root location | Disabled | `NGINX_CORS_ENABLE` non-empty to enable | `entrypoint.d/93-cors.sh` |
| Auto WebP mapping/location | Disabled | `NGINX_AUTO_WEBP` non-empty to enable | `entrypoint.d/92-auto-webp.sh` |
| Force-domain redirect | Disabled | `NGINX_FORCE_DOMAIN` non-empty to enable | `entrypoint.d/91-force-domain.sh` |
| Robots disallow file swap | Disabled | `NGINX_DISALLOW_ROBOTS` non-empty to enable | `entrypoint.d/40-disallow-robots.sh` |

## Error Handling Behavior

File: `nginx/core/etc/nginx/templates/location.d/10-error-page.conf.template`

- Maps many `4xx/5xx` statuses to `/_error.html`
- Marks `/_error.html` as `internal`
- Sets `Cache-Control: no-store` on error page responses

Operational impact:

- Prevents caching of error pages at downstream cache layers by default

## Public Environment Interface (`core`)

Defaults declared in `nginx/core/Dockerfile`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Access log target and format |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | Error log verbosity |
| `NGINX_WORKER_CONNECTIONS` | `2048` | Connections per worker |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | Open file descriptor limit |
| `NGINX_MULTI_ACCEPT` | `off` | Accept multiple new connections per event cycle |
| `NGINX_LIMIT_REQ_ERROR` | `503` | Status code when request limiting is triggered |
| `NGINX_LIMIT_REQ_LOG` | `notice` | Log level for request limiting |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | Enables global `limit_req` block when `on` |
| `NGINX_AUTOINDEX` | `off` | Directory listing behavior |
| `NGINX_DOCUMENT_ROOT` | `/data` | Static content root |
| `NGINX_FORCE_DOMAIN` | empty | Enables force-domain redirect when non-empty |
| `NGINX_FORCE_DOMAIN_STATUS` | `307` | Redirect status for force-domain logic |
| `NGINX_FORCE_REDIRECT_STATUS` | `307` | Redirect status for URI map redirects |
| `NGINX_AUTO_WEBP` | empty | Enables webp map/location when non-empty |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | Auto-tune worker count from runtime constraints |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | Suppress entrypoint logs when non-empty |
| `NGINX_CORS_ENABLE` | empty | Enables CORS block when non-empty |
| `NGINX_CORS_ORIGIN` | `*` | CORS allowed origin |
| `NGINX_CORS_METHODS` | `GET, OPTIONS` | CORS allowed methods |
| `NGINX_CORS_HEADERS` | `*` | CORS allowed headers |
| `NGINX_CORS_MAXAGE` | `86400` | CORS preflight cache time |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header used for real client IP |
| `NGINX_TRUSTED_PROXY_CIDRS` | `10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1/32` | Trusted proxy networks |
| `NGINX_RESOLVERS` | `127.0.0.11` | Resolver addresses |
| `NGINX_RESOLVER_VALID` | `10s` | Resolver cache validity |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `10m` | Max request body size |
| `NGINX_SENDFILE` | `on` | Kernel sendfile optimization |
| `NGINX_SENDFILE_MAX_CHUNK` | `2m` | Sendfile fairness control |
| `NGINX_TCP_NOPUSH` | `on` | Packet coalescing hint |
| `NGINX_TCP_NODELAY` | `on` | Disable Nagle on keepalive connections |
| `NGINX_OPEN_FILE_CACHE` | `max=1000 inactive=30m` | Open file metadata cache |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | Open file cache revalidation interval |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Min accesses for open file cache entry |
| `NGINX_OUTPUT_BUFFERS` | `8 16k` | Response output buffers |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | Keepalive connection timeout |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | Max requests per keepalive connection |
| `NGINX_EXPIRES_DYNAMIC` | `epoch` | `expires` value for dynamic content |
| `NGINX_EXPIRES_STATIC` | `epoch` | `expires` value for static content |
| `NGINX_EXPIRES_DEFAULT` | `epoch` | Fallback `expires` value |
| `NGINX_LIMIT_REQ_RATE` | `200` | Rate limit requests per second |
| `NGINX_LIMIT_REQ_BURST` | `1000` | Rate limit burst capacity |
| `NGINX_GZIP` | `on` | Enable gzip compression |
| `NGINX_GZIP_VARY` | `on` | Emit `Vary: Accept-Encoding` for gzip |
| `NGINX_GZIP_STATIC` | `on` | Serve static precompressed assets |
| `NGINX_GZIP_COMP_LEVEL` | `5` | Gzip compression level |
| `NGINX_GZIP_MIN_LENGTH` | `256` | Minimum size for gzip compression |
| `NGINX_DISABLE_SYMLINKS` | `if_not_owner` | Symlink serving restriction mode |

Additional runtime toggles supported by scripts:

- `NGINX_DISALLOW_ROBOTS` (swaps `robots.txt` to disallow all)

## Operational Playbook

Use `core` as-is when:

- You need a secure static origin profile
- You are behind LB/CDN and want predictable defaults

Override carefully when:

- You serve user-generated mutable assets (tune `expires` and open-file cache)
- You need strict client-IP trust boundaries (`NGINX_TRUSTED_PROXY_CIDRS`)
- You enable global rate limiting on heavily cached static traffic

## Quick Validation Commands

Render and inspect config:

```bash
docker run --rm ghcr.io/gecut/nginx/core:latest nginx -T
```

Run with custom trusted proxies:

```bash
docker run --rm -e NGINX_TRUSTED_PROXY_CIDRS='10.0.0.0/8,203.0.113.0/24' ghcr.io/gecut/nginx/core:latest nginx -T
```
