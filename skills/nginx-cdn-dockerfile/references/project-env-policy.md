# Project environment policy

Infer defaults from the files actually emitted by the project. Keep the final
stage explicit and short; do not copy the entire environment from another
repository.

## Baseline mutable policy

Use five-minute browser and shared-cache revalidation for ordinary mutable
static content:

| Variable | Default |
| --- | --- |
| `NGINX_CDN_S_MAXAGE` | `300` |
| `NGINX_CDN_IMAGE_S_MAXAGE` | `300` |
| `NGINX_CDN_HTML_S_MAXAGE` | `300` |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=300, must-revalidate` |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=300, must-revalidate` |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=300, must-revalidate` |
| `NGINX_CDN_CACHE_IMAGE` | `public, max-age=300, must-revalidate` |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=300, must-revalidate` |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` |
| `NGINX_CDN_CACHE_ERROR` | `no-store` |

Always keep `NGINX_GZIP`, `NGINX_GZIP_STATIC`, and `NGINX_GZIP_VARY` off and
the three `NGINX_EXPIRES_*` variables off unless the user explicitly changes
the policy.

## Project-specific additions

- Set `NGINX_FORCE_DOMAIN` only when the canonical host is known.
- Set `NGINX_SPA_INDEX_URI` only for the SPA runtime, not nginx-cdn.
- Set CORS and WebP only when the actual consumer and response paths require
  them, then verify the resulting headers.
- Set `NGINX_TRUSTED_PROXY_CIDRS` before trusting forwarded client IP headers.
- Use immutable cache only when the filename changes with the content.

Unsupported or uncertain variables must be reported and confirmed rather than
silently added.
