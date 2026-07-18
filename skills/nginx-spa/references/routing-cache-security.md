# Routing, cache, and security contract

## Location precedence

NGINX evaluates the relevant SPA locations as follows:

1. Exact special locations such as `/server-info`, `/robots.txt`, `/favicon.ico`, the configured shell, and the internal error page win where applicable.
2. When automatic WebP is enabled, its case-sensitive JPEG/PNG regex can handle matching image requests.
3. The case-insensitive known-asset regex handles HTML, JavaScript, JSON, CSS, maps, WASM, images, fonts, media, manifests, XML, and related extensions with `try_files $uri =404`.
4. The extensionless regex `~ ^/[^.]*$` tries the URI, then a directory, then `NGINX_SPA_INDEX_URI`.
5. The prefix `location /` tries the URI and directory, otherwise returns `404`.

Consequences:

- `/projects/42` falls back to the shell when no file/directory exists.
- `/assets/app.abc12345.js` serves only if the file exists.
- `/missing.js` returns `404`; it never receives shell HTML.
- `/account.settings` returns `404`, because any dot excludes the URI from extensionless fallback even when the suffix is not in the known-asset list.
- Query strings do not affect file classification because maps and locations use the normalized URI path.
- A directory can be handled by NGINX index processing. Ensure generated directory/index behavior is intended.

The exact shell and strict-asset locations do not include the root-level CORS/method snippets directly. Avoid statements that those snippets cover every response.

## Cache precedence

One inherited CDN policy selects cache headers in this order:

1. classify the normalized URI;
2. replace the URI policy with `NGINX_CDN_CACHE_ERROR` for any `4xx` or `5xx` status;
3. replace the result with `NGINX_CDN_CACHE_ERROR` for any method other than GET/HEAD.

Default profiles:

| Response class | `Cache-Control` |
| --- | --- |
| fingerprinted static asset | `public, max-age=31536000, immutable, s-maxage=31536000` |
| unversioned static asset | `public, max-age=3600, stale-while-revalidate=30` |
| `/`, trailing-slash URI, `.htm`, or `.html` | `public, max-age=0, must-revalidate, s-maxage=0` |
| `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| `service-worker.js` or `sw.js` | `no-cache` |
| any error or non-GET/HEAD method | `no-store` |

The fingerprint heuristics recognize a dot or hyphen followed by at least six hexadecimal characters, or a hyphen followed by at least eight URL-safe characters, before a known asset extension. Human-readable names can accidentally match. Verify classification before relying on a year-long immutable policy.

An extensionless custom shell is classified as unversioned static after fallback internally redirects to that shell URI. Prefer an `.html` shell URI and verify deep-route responses explicitly. If policy must change, overlay the CDN cache map; do not add a second `Cache-Control` header.

ETag is enabled. Conditional requests may return `304`. `Vary` is `Accept-Encoding` by default and includes `Accept` for JPEG/PNG URI classes. Preserve/merge `Vary` at outer CDNs, especially when automatic WebP is enabled.

## Cache variables

| Variable | Default |
| --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` |
| `NGINX_CDN_S_MAXAGE` | `31536000` |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` |
| `NGINX_CDN_CACHE_ERROR` | `no-store` |

Cache text cannot contain control characters, single/double quotes, or backslashes. The two `s-maxage` values are unsigned integers.

The inherited `expires` profiles are all `off`, preventing an additional `Expires`-derived cache authority. Keep them off unless deliberately replacing the cache design.

## Security behavior

All responses normally inherit:

- `X-Frame-Options: SAMEORIGIN`;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`.

NGINX `add_header_inherit merge` preserves inherited headers in nested locations on this pinned NGINX version. CSP is intentionally not generic because SPA asset/API requirements differ. Add an application-specific CSP only after inventorying required origins.

Sensitive extensions, dotfiles, scripts, and common scanner paths are denied. `/.well-known/` serves real files only. Symlink restrictions are configurable and off by default. Directory listing is off.

Canonical-domain redirects compare `$host`; they do not independently inspect the incoming scheme. Put HTTP-to-HTTPS policy at ingress/CDN or test a deliberate downstream template.

Real-IP rewriting activates only with explicit trusted proxy CIDRs. Enabling request limiting behind a proxy without that trust boundary can rate-limit all traffic under the proxy address, while trusting broad/uncontrolled CIDRs enables header spoofing.
