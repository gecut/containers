# NGINX CDN cache model

The CDN image emits browser/shared-cache instructions. It does not itself cache response bodies.

## Decision pipeline

The final `Cache-Control` value is selected in four stages:

1. Classify normalized `$uri` into a content profile.
2. Override every 4xx/5xx response with the error policy.
3. Override every method other than GET/HEAD with the error policy.
4. Override a request carrying `Authorization` with `private, no-store`.

This makes status and method safety stronger than filename classification.

## Default profiles

| Profile | Match | Default Cache-Control |
| --- | --- | --- |
| Image | Common image extension, independent of filename shape | `public, max-age=0, must-revalidate, s-maxage=86400` |
| Hashed | Non-image build asset with a dot-delimited hexadecimal hash or a mixed-case Vite token containing a digit | `public, max-age=31536000, immutable, s-maxage=31536000` |
| Service worker | URI ending in `/service-worker.js`, `/sw.js`, or the root equivalents | `no-cache` |
| HTML | `/`, any URI ending `/`, `.html`, or `.htm` | `public, max-age=0, must-revalidate, s-maxage=0` |
| JSON | `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| Unversioned static | Everything else | `public, max-age=3600, stale-while-revalidate=30` |
| Error/non-cacheable request | 4xx/5xx, any method other than GET/HEAD, or an Authorization request | `no-store` or `private, no-store` |

Image extensions are AVIF, BMP, GIF, ICO, JPEG, PNG, SVG, and WebP. Images
never enter the heuristic hashed profile.

## Classification examples

| URI | Profile | Reason |
| --- | --- | --- |
| `/assets/app-C6uTJdX2.js` | hashed | Vite-style hyphen token, 8+ URL-safe characters |
| `/static/main.abc12345.chunk.js` | hashed | Dot-separated hexadecimal token; matching is case-insensitive |
| `/logo.129fc3.webp` | image | Image policy wins regardless of a hash-looking name |
| `/550e8400-e29b-41d4-a716-446655440000.png` | image | UUID filename does not imply immutability |
| `/docs/` | HTML | Trailing slash |
| `/index.html` | HTML | HTML extension |
| `/manifest.webmanifest` | JSON | Manifest extension |
| `/service-worker.js` | service worker | Exact service-worker name |
| `/missing.js` returning 404 | error | Status overrides URI |
| `POST /logo.svg` | error | Method overrides URI |
| `GET /logo.svg` with Authorization | private | Authorization guard wins last |

Rules are ordered. Image classification precedes the heuristic hashed rules.
Conventional service-worker names keep their dedicated policy.

## Fingerprint safety

The built-in non-image patterns remain heuristics, not proof of content
addressing. Dot-separated hexadecimal tokens are accepted. Hyphenated tokens
must contain an uppercase character and a digit, which fits common Vite output
while excluding UUIDs and ordinary lowercase names.

Before relying on immutable policy, verify representative build filenames with live headers. If the build naming scheme does not fit safely, replace the classifier template rather than stretching cache-value variables.

## Environment controls

| Variable | Default | Used by |
| --- | --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` | Hashed assets, before appended shared max age |
| `NGINX_CDN_S_MAXAGE` | `31536000` | Appended to hashed policy |
| `NGINX_CDN_CACHE_IMAGE` | `public, max-age=0, must-revalidate` | All image extensions, before appended shared max age |
| `NGINX_CDN_IMAGE_S_MAXAGE` | `86400` | Appended to image policy |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` | Default profile |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` | HTML/directory profile, before appended shared max age |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` | Appended to HTML policy |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` | JSON/webmanifest |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` | Exact service worker |
| `NGINX_CDN_CACHE_ERROR` | `no-store` | Errors and non-GET/HEAD methods |

Values reject control characters, single/double quotes, and backslashes. Numeric shared max ages must be unsigned integers. A syntactically invalid rendered directive also fails final `nginx -t`.

Environment variables change policy values only. They do not add extensions, change hash recognition, or change rule precedence.

## Vary, compression, and WebP

- `Accept-Encoding` is emitted only when gzip or gzip-static is enabled.
- `Accept` is emitted for JPEG/PNG only when automatic WebP is enabled.
- When neither feature can change bytes, no Vary header is emitted.
- CDN sets `NGINX_GZIP_VARY=off` to prevent gzip from emitting a second Vary field.
- CDN replaces the core WebP location, relying on the global Vary map instead of a location-level Vary header.

Keep one Vary field. A duplicate field is not necessarily semantically invalid, but it complicates intermediaries and violates this image’s tested contract.

## ETag and conditional requests

ETag is enabled for static files. A client can send `If-None-Match`; unchanged content should return 304. Cache-Control and Vary remain relevant on conditional responses. ETag supports revalidation but does not replace filename fingerprinting or deployment invalidation.

## Origin versus downstream CDN

Origin verification proves only what NGINX emits. Separately verify that the chosen CDN:

- honors or overrides `s-maxage`, `no-cache`, `no-store`, and `Vary` as expected;
- includes query strings in its cache key according to product configuration;
- supports purge/invalidation required by the release process;
- does not normalize away `Accept` when WebP negotiation occurs;
- forwards conditional headers when desired.

Do not encode provider-specific assumptions into this image without an explicit provider contract.

## ArvanCloud compatibility

Use ArvanCloud Origin Cache Control so the origin remains authoritative.
`max-age` controls browsers and `s-maxage` controls Arvan's shared edge cache.
For this static origin, query arguments do not change bytes, so Arvan's
ignore-query mode is safe only when no external transform or signed-query layer
changes the representation. Otherwise use with-query-string mode.

Order Arvan page rules from narrowest/safest to broadest: bypass/private,
health and errors, mutable public files, immutable versioned assets, then a
conservative fallback. Keep Arvan's ignore-Vary setting disabled whenever gzip
or automatic WebP is enabled. Mutable URLs require targeted purge when an
immediate update is required; a purge result is not proof that every edge is
already refreshed. Inspect `X-Cache` and `Age` from the client side. `MISS`
alone does not prove that Arvan stored the object.
