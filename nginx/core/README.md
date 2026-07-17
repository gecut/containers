# `gecut/nginx/core` v2

Secure static-origin profile built on `gecut/nginx/base:2.0.0`. It serves files
from `/data` on IPv4 and IPv6 port `80` and is intended to run behind a trusted
load balancer or CDN.

## Included behavior

- Static serving, MIME types, gzip and optional precompressed `.gz` files
- Safe generic response headers and deterministic error responses
- `/server-info` health endpoint
- Optional real-IP rewriting, CORS, WebP negotiation, canonical-domain
  redirect, request limiting, and robots blocking
- Dotfile and sensitive-extension denial while allowing real files below
  `/.well-known/`

The image does not terminate TLS and does not proxy requests.

## Security defaults

- Real-IP rewriting is disabled until `NGINX_TRUSTED_PROXY_CIDRS` is set.
- Resolver configuration is disabled until `NGINX_RESOLVERS` is set.
- `X-Content-Type-Options`, `X-Frame-Options`, and `Referrer-Policy` are emitted
  with `always` and inherited by nested locations.
- Generic CSP is intentionally application-owned.
- Directory listing, CORS, automatic WebP, rate limiting, and robots blocking
  are disabled by default.

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `NGINX_DOCUMENT_ROOT` | `/data` | Absolute static document root |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Access-log target and format |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | Valid NGINX log level |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `10m` | Request body limit |
| `NGINX_TRUSTED_PROXY_CIDRS` | empty | Comma/semicolon-separated trusted proxy CIDRs |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header accepted only from configured trusted proxies |
| `NGINX_RESOLVERS` | empty | Empty, `local`, or explicit IP literals |
| `NGINX_FORCE_DOMAIN` | empty | Canonical hostname; empty disables redirect |
| `NGINX_CANONICAL_SCHEME` | `https` | `http` or `https` for canonical redirects |
| `NGINX_FORCE_DOMAIN_STATUS` | `308` | Permanent canonical redirect status |
| `NGINX_CORS_ENABLE` | `off` | `on` or `off` |
| `NGINX_AUTO_WEBP` | `off` | `on` or `off` |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | `on` or `off` |
| `NGINX_LIMIT_REQ_RATE` | `200` | Requests per second when enabled |
| `NGINX_LIMIT_REQ_BURST` | `100` | Immediate burst when enabled |
| `NGINX_DISALLOW_ROBOTS` | `off` | Replace only the bundled permissive robots file |
| `NGINX_DISABLE_SYMLINKS` | `off` | NGINX `disable_symlinks` policy |

## Run

```bash
docker run --rm -p 8080:80 -v "$PWD/public:/data:ro" \
  ghcr.io/gecut/nginx/core:2.0.0
```

## Migration from v1

- Configure exact trusted proxy CIDRs; private networks are no longer trusted
  implicitly.
- Configure `NGINX_RESOLVERS=local` only if downstream configuration needs
  runtime DNS resolution.
- Boolean feature flags now require `on` or `off`.
- Canonical redirects default to HTTPS and use status `308`.
- The bundled robots file permits indexing unless blocking is explicitly on.
- Obsolete custom `Server`, `X-XSS-Protection`, and `X-UA-Compatible` headers
  have been removed.
