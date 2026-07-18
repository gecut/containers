# Runtime and environment contract

## Image chain

`ghcr.io/gecut/nginx/spa:1.0.0` inherits, in order:

1. `nginx:1.30.4-alpine-slim` through `gecut/nginx/base:2.0.0`;
2. static-origin configuration from `gecut/nginx/core:2.0.0`;
3. cache policy from `gecut/nginx/cdn:2.0.0`;
4. SPA shell validation and routing from `gecut/nginx/spa:1.0.0`.

It listens on HTTP port `80`, serves `$NGINX_DOCUMENT_ROOT`, and runs the standard NGINX entrypoint followed by `nginx -g 'daemon off;'`. It does not terminate TLS or contact an upstream application.

## Filesystem and process

- Working directory and default document root: `/data`.
- Default bundled `index.html` is removed in the SPA image, so consumers must provide a shell.
- Other inherited defaults such as `_error.html`, favicons, and `robots.txt` are copied from `/default-data` only when absent and when the document root is writable.
- The custom error page is always read from `/default-data/_error.html`, not from `/data/_error.html`.
- A read-only document root works when required application files already exist.
- NGINX's master process starts with the image defaults and workers run as `nginx`. Files need directory traversal and read permission for that user; copying with `--chown=nginx:nginx` is a safe downstream default.
- The entrypoint renders `/etc/nginx/templates/**/*.template` into the matching path below `/etc/nginx/conf.d`. That output tree must be writable during startup.

## Startup stages

Stages execute in lexical order:

| Stage | Behavior | Typical failure |
| --- | --- | --- |
| `19-validate-env.sh` | Validates supported values and rejects unsafe template text | invalid enum, URI, path, host, time, size, or cache text |
| `20-envsubst-on-templates.sh` | Renders all `.template` files using defined `NGINX_*` variables | output directory not writable or no matching environment variables |
| `21-real-ip-trusted-proxies.sh` | Generates trusted real-IP configuration | a proxy entry is not explicit CIDR notation |
| `22-resolver.sh` | Generates optional resolver configuration | `local` requested but no resolver detected |
| `30-copy-default-data.sh` | Copies missing bundled files without overwrite | skips a read-only root; does not fail |
| `40-disallow-robots.sh` | Optionally installs deny-all robots policy | read-only root needs a robots replacement |
| `45-validate-spa-shell.sh` | Requires a readable configured shell | shell absent or unreadable |
| `91`–`94` | Remove disabled domain, WebP, CORS, and rate-limit snippets | usually diagnostic, not failure |
| `99-validate-nginx.sh` | Runs `nginx -t` on rendered configuration | invalid or conflicting consumer template |

## SPA variable

| Variable | Default | Validation and effect |
| --- | --- | --- |
| `NGINX_SPA_INDEX_URI` | `/index.html` | Absolute local URI; rejects traversal, query, fragment, whitespace, and control characters. The corresponding readable file must exist below the document root. It becomes the fallback target and exact shell location. |

## Inherited operational variables

| Variable | SPA default | Validation / effect |
| --- | --- | --- |
| `NGINX_DOCUMENT_ROOT` | `/data` | Absolute path without `..` or whitespace. |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Absolute target plus optional format, or `off`. |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | `debug`, `info`, `notice`, `warn`, `error`, `crit`, `alert`, or `emerg`. |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `1k` | Non-negative NGINX size. Inherited CDN default intentionally discourages request bodies. |
| `NGINX_AUTOINDEX` | `off` | `on` or `off`. Do not expose directory listings without intent. |
| `NGINX_DISABLE_SYMLINKS` | `off` | `off`, `on`, or `if_not_owner`. Default supports bind mounts. |
| `NGINX_TRUSTED_PROXY_CIDRS` | empty | Comma/semicolon/space-separated explicit CIDRs; enables real-IP rewriting. |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Valid HTTP header name, used only with trusted CIDRs. |
| `NGINX_RESOLVERS` | empty | Empty, `local`, or IP literals. Usually unnecessary for static SPA serving. |
| `NGINX_RESOLVER_VALID` | `10s` | Safe NGINX time. |
| `NGINX_FORCE_DOMAIN` | empty | Hostname only. Nonmatching hosts redirect when set. |
| `NGINX_FORCE_DOMAIN_STATUS` | `308` | `301`, `302`, `307`, or `308`. |
| `NGINX_CANONICAL_SCHEME` | `https` | `http` or `https`; controls redirect target only. |
| `NGINX_FORCE_REDIRECT_STATUS` | `307` | Status for URI redirect-map entries. |
| `NGINX_DISALLOW_ROBOTS` | `off` | `on` or `off`; may need to write `/data/robots.txt`. |
| `NGINX_CORS_ENABLE` | `off` | `on` or `off`; scope is location-dependent. |
| `NGINX_CORS_ORIGIN` | `*` | Safe text without controls, quotes, or backslash. |
| `NGINX_CORS_METHODS` | `GET, OPTIONS` | Safe text. |
| `NGINX_CORS_HEADERS` | `*` | Safe text. |
| `NGINX_CORS_MAXAGE` | `86400` | Unsigned integer. |
| `NGINX_AUTO_WEBP` | `off` | `on` or `off`. |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | `on` or `off`; applies at HTTP scope when enabled. |
| `NGINX_LIMIT_REQ_RATE` | `200` | Unsigned requests/second. |
| `NGINX_LIMIT_REQ_BURST` | `1000` | Unsigned CDN/SPA burst default. |
| `NGINX_LIMIT_REQ_ERROR` | `429` | Fixed validation contract. |
| `NGINX_LIMIT_REQ_LOG` | `notice` | `info`, `notice`, `warn`, or `error`. |

## Performance variables

Defaults are: sendfile `on`, `tcp_nopush`/`tcp_nodelay` `on`, open-file cache `max=1000 inactive=30m`, validation `30s`, minimum uses `2`, keepalive timeout `65`, keepalive requests `1000`, gzip `on`, static gzip `on`, level `5`, minimum length `256`, and gzip vary `off` from the CDN layer. Values pass through NGINX after validation; change them only from measured operational requirements.

Worker defaults are `2048` connections, `262144` file limit, `multi_accept=off`, and worker-process autotuning enabled. Container CPU/file limits remain deployment-platform responsibilities.
