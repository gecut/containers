# `gecut/nginx/spa` v1

Production static hosting for React, Vue, Svelte, Angular, and other
single-page applications that use client-side history routing. It extends
`ghcr.io/gecut/nginx/cdn:2.0.0`, so it combines strict SPA fallback behavior
with the CDN-origin cache, security, compression, and edge-integration policy.

> [!IMPORTANT]
> This image serves a completed static build. It does not run Node.js, perform
> server-side rendering, proxy `/api`, or terminate TLS. Next.js SSR, Nuxt SSR,
> application servers, and reverse-proxy caching require a different runtime.

Use [`ghcr.io/gecut/nginx/cdn:2.0.0`](../cdn/README.md) when unknown paths must
remain real `404` responses rather than application routes. Agents can use the
standalone [`nginx-spa` skill](../../skills/nginx-spa/) for deployment,
customization, and diagnosis workflows.

## Runtime contract

| Property | Contract |
| --- | --- |
| Image | `ghcr.io/gecut/nginx/spa:1.0.0` |
| Parent chain | `nginx:1.30.4-alpine-slim` → `base:2.0.0` → `core:2.0.0` → `cdn:2.0.0` → `spa:1.0.0` |
| Listener | HTTP on IPv4 and IPv6 port `80` |
| Document root | `/data` by default |
| Required shell | `/index.html` by default |
| Worker | NGINX workers run as `nginx`; the master retains the official port-80 model |
| Health check | Requires both `GET /server-info` and the configured shell to succeed |
| Stop signal | `SIGQUIT` for graceful shutdown |
| Templates | `/etc/nginx/templates/**/*.template` |
| Rendered configuration | `/etc/nginx/conf.d/**` |

Unlike the parent CDN image, SPA removes the bundled default `index.html`. The
container therefore cannot become ready without a consumer-provided shell.

## How routing works

NGINX location precedence is part of the public behavior. Exact inherited
locations such as `/server-info`, `/robots.txt`, and the configured shell are
handled first. Regex locations then classify known assets and extensionless SPA
routes; the ordinary `/` prefix is the final fallback.

| Request | Result |
| --- | --- |
| Existing file | Served normally |
| Existing directory | Served through normal NGINX index processing |
| Configured shell URI | Served only if that exact file exists |
| Missing known asset extension | Real `404`; never the SPA shell |
| Missing route with no `.` in its path | Internal fallback to the configured shell with `200` |
| Missing route containing `.` | Real `404` |
| Non-GET request to an extensionless application route | Denied; it is not routed to the shell |

The strict known-asset matcher includes HTML, CSS, JavaScript, JSON, source
maps, WASM, images, fonts, documents, text/XML, audio, and video extensions.
For example:

| URI | Stock outcome |
| --- | --- |
| `/users/42?tab=profile` | Shell, `200`; the query does not affect routing |
| `/users/42/` | Shell, `200`, unless an existing directory handles it |
| `/assets/app.abcdef12.js` | File when present; `404` when missing |
| `/catalog/item.v2` | `404` because the path contains a dot |
| `/missing.json` | `404`, not shell |
| `/api/users` | Shell, `200`, unless a custom location excludes `/api` |

The application router owns the client-side not-found experience. NGINX cannot
know whether an extensionless route is valid and intentionally returns the
shell with status `200`.

## Startup lifecycle

The official Docker entrypoint runs scripts in lexical order:

1. Upstream resolver discovery and optional worker tuning run first.
2. `19-validate-env.sh` validates all inherited variables and
   `NGINX_SPA_INDEX_URI`.
3. `20-envsubst-on-templates.sh` recursively renders `.template` files. The
   default `^NGINX_` filter preserves NGINX runtime variables such as `$uri`.
4. Stages `21`, `22`, `30`, and `40` configure real IP, resolver, bundled files,
   and optional robots blocking.
5. `45-validate-spa-shell.sh` verifies that
   `${NGINX_DOCUMENT_ROOT}${NGINX_SPA_INDEX_URI}` is a readable regular file.
6. Stages `91`–`94` remove disabled canonical-host, WebP, CORS, and global
   request-limit snippets.
7. `99-validate-nginx.sh` runs `nginx -t` before the server starts.

Because shell validation runs before NGINX, both a normal start and a command
such as `nginx -T` require the shell mount or baked content.

## Cache behavior

SPA inherits the CDN policy without adding a second cache authority:

| Content or outcome | Default `Cache-Control` |
| --- | --- |
| Fingerprinted asset | `public, max-age=31536000, immutable, s-maxage=31536000` |
| Unversioned static file | `public, max-age=3600, stale-while-revalidate=30` |
| `.html` shell | `public, max-age=0, must-revalidate, s-maxage=0` |
| Extensionless deep route that falls back to an `.html` shell | HTML shell policy after internal redirect |
| `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| `service-worker.js` or `sw.js` | `no-cache` |
| Any `4xx` or `5xx`, including a missing asset | `no-store` |
| Any method other than `GET` or `HEAD` | `no-store` |

ETags are enabled. All responses vary on `Accept-Encoding`; JPEG and PNG URIs
also vary on `Accept` for optional WebP sidecars.

> [!WARNING]
> A shell URI without `.htm` or `.html`, for example `/app-shell`, is classified
> as unversioned static content after the internal redirect and receives the
> one-hour default policy. Prefer an `.html` shell name or replace the CDN cache
> classification map deliberately.

The CDN hash matchers run before service-worker, HTML, and JSON matchers. Use
content-addressed asset names; a human-readable hyphenated token of eight or
more characters can be misclassified as immutable. See the
[CDN cache details](../cdn/README.md#cache-behavior) before changing filename or
cache conventions.

## Quick start

### Bind-mount a completed build

Vite commonly outputs `dist/`; Create React App commonly outputs `build/`.
Mount the directory containing `index.html`, not its parent.

```bash
docker run --rm --name web-app \
  -p 8080:80 \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0
```

### Build an immutable image

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0

COPY --chown=nginx:nginx dist/ /data/
```

```bash
docker build -t example/web-app:1.0.0 .
docker run --rm -p 8080:80 example/web-app:1.0.0
```

### Use a custom shell

```bash
docker run --rm -p 8080:80 \
  -e NGINX_SPA_INDEX_URI=/app.html \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0
```

`dist/app.html` must exist and be readable.

### Docker Compose

```yaml
services:
  web:
    image: ghcr.io/gecut/nginx/spa:1.0.0
    ports:
      - "8080:80"
    volumes:
      - ./dist:/data:ro
    environment:
      NGINX_FORCE_DOMAIN: app.example.com
      NGINX_TRUSTED_PROXY_CIDRS: 10.0.0.0/8
    restart: unless-stopped
```

Replace the example proxy CIDR with the exact load-balancer network. If the
content is baked into a downstream image, remove the volume.

### Kubernetes

This example assumes `example/web-app:1.0.0` derives from the SPA image and
contains the completed build.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: nginx
          image: example/web-app:1.0.0
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /index.html
              port: http
          livenessProbe:
            httpGet:
              path: /server-info
              port: http
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
            limits:
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Change the readiness path when `NGINX_SPA_INDEX_URI` changes. With
`NGINX_FORCE_DOMAIN`, add a matching `Host` header to both probes to avoid the
canonical redirect.

## Base-path deployment

If the application is built for `/app/`, place its files under `/data/app/` and
point the fallback at that shell:

```text
dist/
└── app/
    ├── index.html
    └── assets/
```

```bash
docker run --rm -p 8080:80 \
  -e NGINX_SPA_INDEX_URI=/app/index.html \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0
```

The frontend build must also emit asset URLs and router basenames for `/app/`.
The environment variable changes the shell target, not the application's URLs.
Stock fallback remains global: `/unrelated-route` also resolves to the
`/app/index.html` shell. To restrict routing to `/app/`, add a custom location
configuration rather than relying on `NGINX_SPA_INDEX_URI` alone.

## Environment reference

Empty means an empty string. Stage `19` validates environment shape and stage
`99` validates final NGINX syntax.

### SPA routing

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_SPA_INDEX_URI` | `/index.html` | Absolute local URI; rejects control characters, whitespace, `..`, query strings, and fragments; target must be a readable regular file |

### CDN cache policy

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` | Base fingerprinted-file policy; no controls, quotes, apostrophes, or backslashes |
| `NGINX_CDN_S_MAXAGE` | `31536000` | Unsigned integer appended to the hashed policy |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` | Default URI policy; same safe-text validation |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` | Base HTML policy; same safe-text validation |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` | Unsigned integer appended to the HTML policy |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` | JSON/web-manifest policy; same safe-text validation |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` | Conventional service-worker policy; same safe-text validation |
| `NGINX_CDN_CACHE_ERROR` | `no-store` | Error and non-GET/HEAD policy; same safe-text validation |

### Routing, security, and edge integration

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_DOCUMENT_ROOT` | `/data` | Absolute path without whitespace or `..`; combined with the shell URI at startup |
| `NGINX_AUTOINDEX` | `off` | `on` or `off`; controls directory listing |
| `NGINX_DISABLE_SYMLINKS` | `off` | `off`, `on`, or `if_not_owner` |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `1k` | Non-negative NGINX size inherited from CDN |
| `NGINX_FORCE_DOMAIN` | empty | Hostname only; enables canonical-host redirect when set |
| `NGINX_FORCE_DOMAIN_STATUS` | `308` | `301`, `302`, `307`, or `308` |
| `NGINX_CANONICAL_SCHEME` | `https` | `http` or `https`; emitted redirect scheme |
| `NGINX_FORCE_REDIRECT_STATUS` | `307` | `301`, `302`, `307`, or `308` for redirect maps |
| `NGINX_TRUSTED_PROXY_CIDRS` | empty | Comma/semicolon-separated explicit CIDRs; empty disables real-IP rewriting |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | Header name accepted only from trusted CIDRs |
| `NGINX_RESOLVERS` | empty | Empty, `local`, or space-separated IP literals |
| `NGINX_RESOLVER_VALID` | `10s` | NGINX time for optional resolver entries |
| `NGINX_ENTRYPOINT_LOCAL_RESOLVERS` | `1` | `1` enables local-resolver discovery; empty disables it |
| `NGINX_CORS_ENABLE` | `off` | `on` or `off`; controls the root-location CORS snippet |
| `NGINX_CORS_ORIGIN` | `*` | Safe `Access-Control-Allow-Origin` text |
| `NGINX_CORS_METHODS` | `GET, OPTIONS` | Safe `Access-Control-Allow-Methods` text |
| `NGINX_CORS_HEADERS` | `*` | Safe `Access-Control-Allow-Headers` text |
| `NGINX_CORS_MAXAGE` | `86400` | Unsigned preflight max-age |
| `NGINX_AUTO_WEBP` | `off` | `on` or `off`; selects an existing `.jpg.webp`/`.png.webp` sidecar |
| `NGINX_DISALLOW_ROBOTS` | `off` | `on` or `off`; installs `Disallow: /` only when no custom policy exists |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | `on` or `off`; enables inherited HTTP-scope limiting |
| `NGINX_LIMIT_REQ_RATE` | `200` | Unsigned requests per second |
| `NGINX_LIMIT_REQ_BURST` | `1000` | Unsigned immediate burst with `nodelay` |
| `NGINX_LIMIT_REQ_ERROR` | `429` | Only `429` is accepted |
| `NGINX_LIMIT_REQ_LOG` | `notice` | `info`, `notice`, `warn`, or `error` |

### Serving, compression, files, and connections

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_SENDFILE` | `on` | `on` or `off` |
| `NGINX_TCP_NOPUSH` | `on` | `on` or `off` |
| `NGINX_TCP_NODELAY` | `on` | `on` or `off` |
| `NGINX_OPEN_FILE_CACHE` | `max=1000 inactive=30m` | Directive arguments; `;`, `{`, and `}` are rejected |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | NGINX time |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Unsigned integer |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | NGINX time |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | Unsigned integer |
| `NGINX_GZIP` | `on` | `on` or `off` |
| `NGINX_GZIP_STATIC` | `on` | `on` or `off`; serves precompressed `.gz` files |
| `NGINX_GZIP_VARY` | `off` | `on` or `off`; CDN already emits `Vary: Accept-Encoding` |
| `NGINX_GZIP_COMP_LEVEL` | `5` | Integer `1`–`9` |
| `NGINX_GZIP_MIN_LENGTH` | `256` | Unsigned byte count |
| `NGINX_EXPIRES_DYNAMIC` | `off` | Safe NGINX `expires` value; keep `off` to avoid duplicate cache authority |
| `NGINX_EXPIRES_STATIC` | `off` | Safe NGINX `expires` value; keep `off` to avoid duplicate cache authority |
| `NGINX_EXPIRES_DEFAULT` | `off` | Safe NGINX `expires` value; keep `off` to avoid duplicate cache authority |
| `NGINX_WORKER_CONNECTIONS` | `2048` | Unsigned per-worker limit |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | Unsigned file-descriptor limit |
| `NGINX_MULTI_ACCEPT` | `off` | `on` or `off` |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | `1` enables tuning; empty disables it; `0` and `off` are invalid |

### Logging and template rendering

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Absolute path plus optional format, or `off`; `json` and `main` are built in |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | `debug`, `info`, `notice`, `warn`, `error`, `crit`, `alert`, or `emerg` |
| `NGINX_ENVSUBST_FILTER` | `^NGINX_` | Regex selecting environment variables rendered into templates |
| `NGINX_ENVSUBST_TEMPLATE_DIR` | `/etc/nginx/templates` | Recursive input tree |
| `NGINX_ENVSUBST_TEMPLATE_SUFFIX` | `.template` | Rendered filename suffix |
| `NGINX_ENVSUBST_OUTPUT_DIR` | `/etc/nginx/conf.d` | Writable output root |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | Any nonempty value suppresses official entrypoint informational logs |

## Customization

Prefer environment variables, then immutable content, then additive templates.
Replace stock templates only when their behavior must change.

### Add CSP and application headers

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0

COPY --chown=nginx:nginx dist/ /data/
COPY docker/nginx/templates/ /etc/nginx/templates/
```

```nginx
# docker/nginx/templates/http.d/83-application-headers.conf.template
add_header Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'self'" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

The inherited `add_header_inherit merge` retains the stock security and CDN
headers. Tailor CSP to the real frontend dependencies.

### Prevent `/api` from falling back to the SPA

SPA fallback is global. Add a `^~` prefix location to exclude a namespace while
preventing the extensionless-route regex from taking precedence:

```nginx
# docker/nginx/templates/location.d/53-api-not-found.conf.template
location ^~ /api/ {
  return 404;
}
```

This remains a static `404`; it does not proxy an API.

### Add redirect-map entries

```nginx
# docker/nginx/templates/redirect.d/20-application.map.template
/old-route /new-route;
~^/legacy/(.*)$ /$1;
```

Entries match `$request_uri` and use `NGINX_FORCE_REDIRECT_STATUS` (`307` by
default).

### Replace the error document

Error responses use the internal `/_error.html` from `/default-data`, not the
SPA document root:

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0

COPY --chown=nginx:nginx dist/ /data/
COPY docker/nginx/error.html /default-data/_error.html
```

### Change route or cache classification

- Replace `/etc/nginx/templates/location.d/60-root.conf.template` to change SPA
  fallback scope.
- Replace `/etc/nginx/templates/location.d/55-spa-assets.conf.template` to
  change which extensions are strict assets.
- Replace `/etc/nginx/templates/http.d/82-cache-policy-map.conf.template` to
  change CDN URI classification.

Copy replacements at the exact paths in a downstream image. Preserve method
denial, strict missing-asset `404` behavior, status/method cache overrides, and
the variables consumed by the inherited header template. Confirm the result
with `nginx -T` and runtime probes.

## Security and interaction notes

- Dotfiles are denied except real files under `/.well-known/`; inherited
  sensitive-file patterns are also denied.
- Stock security headers are emitted with `always`. CSP, HSTS, authentication,
  WAF behavior, and TLS remain deployment-owned.
- `NGINX_FORCE_DOMAIN` canonicalizes a mismatched host but does not redirect an
  HTTP request that already uses the canonical host to HTTPS. Enforce scheme at
  the TLS terminator.
- Global rate limiting keys on `$binary_remote_addr`. Behind a proxy, configure
  exact `NGINX_TRUSTED_PROXY_CIDRS` or clients can share one proxy-address
  bucket. Never trust forwarded headers globally.
- The CORS snippet exists only in locations that include `root.d`. The strict
  SPA asset location and the optional WebP JPEG/PNG location do not include it.
  Therefore `NGINX_CORS_ENABLE=on` is not a promise that every SPA response has
  CORS headers.
- Automatic WebP selects `/photo.jpg.webp` for `/photo.jpg`; it does not convert
  images and does not look for `/photo.webp`.
- `NGINX_DISALLOW_ROBOTS=on` preserves a consumer-provided policy. If it must
  create or replace `robots.txt`, a read-only root causes startup failure at
  stage `40`.
- Open-file lookup errors are cached. Prefer immutable deployments; tune
  `NGINX_OPEN_FILE_CACHE_VALID` when mutating a mounted build in place.
- Setting `NGINX_RESOLVERS` only supports custom downstream directives that
  need runtime DNS. It does not enable proxying.

## Verification cookbook

Rendered configuration inspection requires the real shell:

```bash
docker run --rm \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0 nginx -T
```

After starting the container on port `8080`, verify routing and policy:

```bash
base=http://127.0.0.1:8080

curl -sS "$base/users/42?tab=profile" | head
curl -sS -o /dev/null -D - "$base/assets/app.abcdef12.js"
curl -sS -o /dev/null -D - "$base/assets/missing.js"
curl -sS -o /dev/null -D - "$base/unknown.route"
curl -sS -o /dev/null -D - -X POST "$base/users/42"
```

Expected invariants:

- a valid extensionless deep route returns the shell with `200`, the HTML cache
  policy, and stock security headers;
- a present fingerprinted asset returns `200`, an immutable policy, ETag, and
  `Vary`;
- a missing known asset and a dotted unknown route return `404` plus
  `Cache-Control: no-store`;
- a POST to an extensionless route is denied and has `no-store`;
- a matching `If-None-Match` request for a real asset can return `304`.

## Troubleshooting

| Symptom or log stage | Likely cause | Resolution |
| --- | --- | --- |
| `19-validate-env.sh: NGINX_SPA_INDEX_URI ...` | Shell URI is relative or contains traversal, whitespace, query, fragment, or control characters | Use an absolute local URI such as `/index.html` |
| `20-envsubst... not writable` | Rendered configuration tree is mounted read-only | Leave `/etc/nginx/conf.d` writable at startup |
| Stage `21` rejects trusted proxy | Proxy value is not an explicit CIDR | Supply exact CIDRs, not bare addresses |
| Stage `22` cannot find local resolver | `NGINX_RESOLVERS=local` but discovery is empty | Use explicit IP literals or remove the unused setting |
| Stage `40` reports read-only root | Robots blocking needs to write `robots.txt` | Bake a custom policy or use a writable root |
| `45-validate-spa-shell.sh: ... missing or unreadable` | Wrong mount level, wrong shell URI, missing build, or unreadable file | Verify `${NGINX_DOCUMENT_ROOT}${NGINX_SPA_INDEX_URI}` inside the container |
| Stage `91`–`94` removes configuration | Corresponding feature is empty or `off` | Set the documented flag to `on`; inspect `nginx -T` |
| Stage `99` / `nginx -t` fails | Custom template or rendered value is invalid | Inspect startup output and the rendered configuration after correcting it |
| Deep route returns `404` | URI contains a dot, custom location wins, or shell is not in stock fallback | Check location precedence with `nginx -T`; use an extensionless route or intentionally customize routing |
| Missing asset returns the shell | Its extension is absent from the strict asset matcher or a downstream location changed precedence | Extend the strict asset matcher without weakening route fallback |
| Deep route has one-hour cache | Custom shell has no `.htm`/`.html` suffix | Rename the shell or override CDN classification |
| `/api/users` returns the frontend | Stock fallback treats it as an extensionless app route | Add a `^~ /api/` static `404` location or use an actual application gateway outside this image |
| CORS missing on an asset | SPA/WebP regex location bypasses `root.d` | Add a deliberate location-aware CORS/header configuration |
| All proxied clients get `429` together | Limiting sees the proxy address | Configure only the exact trusted proxy CIDRs and correct real-IP header |
| Health check redirects or fails | Canonical host is enabled or custom shell probe path is stale | Send the canonical `Host` and probe the configured shell URI |

## Unsupported use cases

This image is not appropriate for:

- Next.js, Nuxt, SvelteKit, or other server-rendered runtime output;
- API execution, `/api` proxying, upstream load balancing, WebSockets, or
  `proxy_cache`;
- TLS certificate handling, HTTP/3 termination, or forced HTTPS for an already
  canonical host;
- dynamic image conversion;
- server-known `404` semantics for arbitrary extensionless application routes.

## Migration notes

### From `nginx/cdn`

- Provide a readable SPA shell; no bundled `index.html` is available.
- Missing extensionless paths now return the shell with `200`.
- Missing known assets and dotted routes continue to return real `404`
  responses with `no-store`.
- Non-GET application-route requests are not sent to the shell.
- All CDN and core environment variables remain available with CDN-effective
  defaults.

### From ad hoc SPA configurations

- Remove broad `try_files $uri /index.html` rules that turn missing assets into
  `200` HTML responses.
- Keep the shell `.html`-suffixed or account for cache classification explicitly.
- Move TLS, API proxying, and SSR to the appropriate edge or application
  runtime instead of adding them implicitly to this static-origin contract.
