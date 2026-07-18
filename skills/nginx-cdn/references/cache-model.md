# NGINX CDN cache model

The CDN image emits browser/shared-cache instructions. It does not itself cache response bodies.

## Decision pipeline

The final `Cache-Control` value is selected in three stages:

1. Classify normalized `$uri` into a content profile.
2. Override every 4xx/5xx response with the error policy.
3. Override every method other than GET/HEAD with the error policy.

This makes status and method safety stronger than filename classification.

## Default profiles

| Profile | Match | Default Cache-Control |
| --- | --- | --- |
| Hashed | Supported static extension with `.` or `-` followed by 6+ case-insensitive hex characters, or `-` followed by 8+ URL-safe characters | `public, max-age=31536000, immutable, s-maxage=31536000` |
| Service worker | URI ending in `/service-worker.js`, `/sw.js`, or the root equivalents | `no-cache` |
| HTML | `/`, any URI ending `/`, `.html`, or `.htm` | `public, max-age=0, must-revalidate, s-maxage=0` |
| JSON | `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| Unversioned static | Everything else | `public, max-age=3600, stale-while-revalidate=30` |
| Error/non-cacheable method | 4xx/5xx, or any method other than GET/HEAD | `no-store` |

Supported hashed extensions include common images, CSS, JavaScript, source maps, modules, audio/video, fonts, PDF, text, WASM, and WebP.

## Classification examples

| URI | Profile | Reason |
| --- | --- | --- |
| `/assets/app-C6uTJdX2.js` | hashed | Vite-style hyphen token, 8+ URL-safe characters |
| `/static/main.abc12345.chunk.js` | hashed | Dot-separated hexadecimal token; matching is case-insensitive |
| `/logo.svg` | unversioned static | No fingerprint |
| `/docs/` | HTML | Trailing slash |
| `/index.html` | HTML | HTML extension |
| `/manifest.webmanifest` | JSON | Manifest extension |
| `/service-worker.js` | service worker | Exact service-worker name |
| `/missing.js` returning 404 | error | Status overrides URI |
| `POST /logo.svg` | error | Method overrides URI |

Rules are ordered. Hashed classification is evaluated before service-worker classification. A renamed worker such as `/service-worker-abcdef12.js` is therefore hashed and immutable; use the conventional exact worker filename when update checks are required.

## Fingerprint safety

The built-in patterns are heuristics, not proof of content addressing:

- A human suffix containing six hexadecimal characters, in either case, may be classified as hashed.
- Any hyphen suffix of eight URL-safe characters may be classified as hashed.
- A dot-separated token containing non-hex characters remains unversioned; the broader URL-safe matcher requires a hyphen separator.

Before relying on immutable policy, verify representative build filenames with live headers. If the build naming scheme does not fit safely, replace the classifier template rather than stretching cache-value variables.

## Environment controls

| Variable | Default | Used by |
| --- | --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` | Hashed assets, before appended shared max age |
| `NGINX_CDN_S_MAXAGE` | `31536000` | Appended to hashed policy |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` | Default profile |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` | HTML/directory profile, before appended shared max age |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` | Appended to HTML policy |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` | JSON/webmanifest |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` | Exact service worker |
| `NGINX_CDN_CACHE_ERROR` | `no-store` | Errors and non-GET/HEAD methods |

Values reject control characters, single/double quotes, and backslashes. Numeric shared max ages must be unsigned integers. A syntactically invalid rendered directive also fails final `nginx -t`.

Environment variables change policy values only. They do not add extensions, change hash recognition, or change rule precedence.

## Vary, compression, and WebP

- Every response explicitly varies on `Accept-Encoding`.
- JPEG/PNG URIs vary on both `Accept` and `Accept-Encoding` because optional WebP changes the selected representation.
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
