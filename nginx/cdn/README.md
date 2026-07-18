# `gecut/nginx/cdn` v2

Production static-origin NGINX for assets that are delivered directly or through
an external CDN. It extends `ghcr.io/gecut/nginx/core:2.0.0` with one
deterministic `Cache-Control` policy, ETag support, and representation-aware
`Vary` headers.

> [!IMPORTANT]
> This image serves files from disk. It is not a reverse proxy, does not provide
> `proxy_cache`, and does not terminate TLS. Put a load balancer or CDN in front
> when those capabilities are required.

For client-side history routing, use
[`ghcr.io/gecut/nginx/spa:1.0.0`](../spa/README.md). For a static origin without
the CDN cache policy, use [`ghcr.io/gecut/nginx/core:2.0.0`](../core/README.md).
Agents can use the standalone [`nginx-cdn` skill](../../skills/nginx-cdn/) for
deployment, customization, and diagnosis workflows.

## Runtime contract

| Property | Contract |
| --- | --- |
| Image | `ghcr.io/gecut/nginx/cdn:2.0.0` |
| Parent chain | `nginx:1.30.4-alpine-slim` → `base:2.0.0` → `core:2.0.0` → `cdn:2.0.0` |
| Listener | HTTP on IPv4 and IPv6 port `80` |
| Document root | `/data` by default |
| Worker | NGINX workers run as `nginx`; the master retains the official port-80 model |
| Health endpoint | `GET /server-info` returns `200` |
| Stop signal | `SIGQUIT` for graceful shutdown |
| Templates | `/etc/nginx/templates/**/*.template` |
| Rendered configuration | `/etc/nginx/conf.d/**` |

The image is designed for immutable build output. A read-only bind mount is
supported when every required file is already present. In a downstream image,
copy content with ownership that keeps it readable by the `nginx` worker.

## Startup lifecycle

The official Docker entrypoint runs scripts in lexical order before NGINX:

1. The upstream entrypoint discovers local resolvers and optionally tunes worker
   processes.
2. `19-validate-env.sh` rejects unsafe or malformed values.
3. `20-envsubst-on-templates.sh` recursively renders `.template` files. Only
   variables matching `NGINX_ENVSUBST_FILTER` are expanded, so NGINX variables
   such as `$uri` remain intact with the default filter.
4. `21-real-ip-trusted-proxies.sh` and `22-resolver.sh` generate optional runtime
   configuration.
5. `30-copy-default-data.sh` copies bundled files into the document root without
   overwriting consumer files; it skips this step when the root is read-only.
6. `40-disallow-robots.sh` optionally installs a blocking `robots.txt`.
7. Stages `91`–`94` remove disabled canonical-host, WebP, CORS, and global
   request-limit snippets.
8. `99-validate-nginx.sh` runs `nginx -t`; invalid rendered configuration stops
   the container.

Templates and rendered configuration directories must be writable during
startup. The content root may be read-only, subject to the robots behavior
described under [Interactions and gotchas](#interactions-and-gotchas).

## Cache behavior

### Default policy

The normalized URI path selects a profile. Query strings do not affect the
profile.

| Request or response | Default `Cache-Control` |
| --- | --- |
| Hex-fingerprinted asset, for example `main.abc12345.chunk.js` | `public, max-age=31536000, immutable, s-maxage=31536000` |
| Vite-style asset, for example `app-C6uTJdX2.js` | `public, max-age=31536000, immutable, s-maxage=31536000` |
| Unversioned static file | `public, max-age=3600, stale-while-revalidate=30` |
| `/`, a URI ending in `/`, `.htm`, or `.html` | `public, max-age=0, must-revalidate, s-maxage=0` |
| `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| `service-worker.js` or `sw.js` | `no-cache` |
| Any `4xx` or `5xx` response | `no-store` |
| Any method other than `GET` or `HEAD` | `no-store` |

Policy evaluation is deliberately layered:

1. `$uri` selects `hashed`, `service_worker`, `html`, `json`, or the default
   `static_unversioned` profile. URI regexes are evaluated in template order;
   hashed patterns precede the other regex profiles.
2. A `4xx` or `5xx` status replaces the URI policy with the error policy.
3. A method other than `GET` or `HEAD` replaces either result with the error
   policy.

The second hashed matcher accepts a broad hyphenated token of eight or more
letters, digits, `_`, or `-`. It recognizes modern bundler output, but a
human-readable filename such as `hero-marketing.svg` can also look
fingerprinted. Use genuinely content-addressed filenames or override the
classification map if such false positives are possible. A renamed service
worker that itself matches a hashed pattern also receives the hashed policy
because hashed matching comes first; keep the conventional `service-worker.js`
or `sw.js` name unless the map is customized.

### Validators and representation variance

- ETags are enabled, so a matching `If-None-Match` request can return `304`.
- Every response has `Vary: Accept-Encoding`.
- `.jpg`, `.jpeg`, and `.png` URIs have `Vary: Accept, Accept-Encoding` because
  enabling automatic WebP can select a different representation.
- The inherited `expires` policy is set to `off`. `Cache-Control` is therefore
  the single cache authority emitted by the stock image.

Do not add a second `expires` directive or another unconditional
`Cache-Control` header in a downstream template. Replace the stock policy map
when the policy must change.

## Quick start

### Bind-mount a completed build

```bash
docker run --rm --name static-origin \
  -p 8080:80 \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/cdn:2.0.0
```

```bash
curl -sSI http://127.0.0.1:8080/app-C6uTJdX2.js
curl -sSI http://127.0.0.1:8080/missing.js
```

### Build an immutable image

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY --chown=nginx:nginx dist/ /data/
```

```bash
docker build -t example/static-origin:1.0.0 .
docker run --rm -p 8080:80 example/static-origin:1.0.0
```

### Docker Compose

```yaml
services:
  origin:
    image: ghcr.io/gecut/nginx/cdn:2.0.0
    ports:
      - "8080:80"
    volumes:
      - ./dist:/data:ro
    environment:
      NGINX_FORCE_DOMAIN: static.example.com
      NGINX_TRUSTED_PROXY_CIDRS: 10.0.0.0/8
    restart: unless-stopped
```

Replace the example proxy CIDR with the exact network used by your load
balancer. Do not trust a broad range merely to make forwarded addresses work.

### Kubernetes

This example assumes application files are already baked into
`example/static-origin:1.0.0`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: static-origin
spec:
  replicas: 2
  selector:
    matchLabels:
      app: static-origin
  template:
    metadata:
      labels:
        app: static-origin
    spec:
      containers:
        - name: nginx
          image: example/static-origin:1.0.0
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /server-info
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
  name: static-origin
spec:
  selector:
    app: static-origin
  ports:
    - name: http
      port: 80
      targetPort: http
```

If `NGINX_FORCE_DOMAIN` is enabled, configure the same host in probe
`httpHeaders`; otherwise the canonical redirect can make the probe fail.

## Environment reference

Empty means an empty string. Values are validated at stage `19`, then the final
NGINX syntax is validated at stage `99`.

### CDN cache policy

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_CDN_CACHE_HASHED` | `public, max-age=31536000, immutable` | Base policy for classified fingerprinted files; no controls, quotes, apostrophes, or backslashes |
| `NGINX_CDN_S_MAXAGE` | `31536000` | Unsigned integer appended as `s-maxage` to the hashed policy |
| `NGINX_CDN_CACHE_UNVERSIONED_STATIC` | `public, max-age=3600, stale-while-revalidate=30` | Default URI policy; same safe-text validation |
| `NGINX_CDN_CACHE_HTML` | `public, max-age=0, must-revalidate` | Base HTML/directory policy; same safe-text validation |
| `NGINX_CDN_HTML_S_MAXAGE` | `0` | Unsigned integer appended as `s-maxage` to the HTML policy |
| `NGINX_CDN_CACHE_JSON` | `public, max-age=60, stale-while-revalidate=30` | JSON and web-manifest policy; same safe-text validation |
| `NGINX_CDN_CACHE_SERVICE_WORKER` | `no-cache` | Conventional service-worker policy; same safe-text validation |
| `NGINX_CDN_CACHE_ERROR` | `no-store` | Error and non-GET/HEAD policy; same safe-text validation |

### Routing, security, and edge integration

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_DOCUMENT_ROOT` | `/data` | Absolute path without whitespace or `..`; server root and bundled-default destination |
| `NGINX_AUTOINDEX` | `off` | `on` or `off`; controls directory listing |
| `NGINX_DISABLE_SYMLINKS` | `off` | `off`, `on`, or `if_not_owner` |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `1k` | Non-negative NGINX size; intentionally small for a static origin |
| `NGINX_FORCE_DOMAIN` | empty | Hostname only; nonmatching hosts redirect when set |
| `NGINX_FORCE_DOMAIN_STATUS` | `308` | `301`, `302`, `307`, or `308` |
| `NGINX_CANONICAL_SCHEME` | `https` | `http` or `https`; scheme written into canonical redirects |
| `NGINX_FORCE_REDIRECT_STATUS` | `307` | `301`, `302`, `307`, or `308` for redirect-map entries |
| `NGINX_TRUSTED_PROXY_CIDRS` | empty | Comma/semicolon-separated explicit CIDRs; empty disables real-IP rewriting |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | HTTP header name used only when trusted CIDRs exist |
| `NGINX_RESOLVERS` | empty | Empty disables the directive; `local` uses discovered resolvers; otherwise space-separated IP literals |
| `NGINX_RESOLVER_VALID` | `10s` | NGINX time used by the optional resolver directive |
| `NGINX_ENTRYPOINT_LOCAL_RESOLVERS` | `1` | `1` enables upstream local-resolver discovery; empty disables it |
| `NGINX_CORS_ENABLE` | `off` | `on` or `off`; retains/removes the stock root-location CORS snippet |
| `NGINX_CORS_ORIGIN` | `*` | Safe text inserted into `Access-Control-Allow-Origin` |
| `NGINX_CORS_METHODS` | `GET, OPTIONS` | Safe text inserted into `Access-Control-Allow-Methods` |
| `NGINX_CORS_HEADERS` | `*` | Safe text inserted into `Access-Control-Allow-Headers` |
| `NGINX_CORS_MAXAGE` | `86400` | Unsigned preflight max-age |
| `NGINX_AUTO_WEBP` | `off` | `on` or `off`; when on, `image.jpg.webp` may satisfy `/image.jpg` if the client accepts WebP |
| `NGINX_DISALLOW_ROBOTS` | `off` | `on` or `off`; installs the bundled `Disallow: /` file only when no custom robots policy exists |
| `NGINX_ENABLE_GLOBAL_LIMIT_REQ` | `off` | `on` or `off`; applies the inherited per-client limit at HTTP scope |
| `NGINX_LIMIT_REQ_RATE` | `200` | Unsigned requests per second when limiting is enabled |
| `NGINX_LIMIT_REQ_BURST` | `1000` | Unsigned immediate burst with `nodelay` when limiting is enabled |
| `NGINX_LIMIT_REQ_ERROR` | `429` | Only `429` is accepted |
| `NGINX_LIMIT_REQ_LOG` | `notice` | `info`, `notice`, `warn`, or `error` |

### Serving, compression, files, and connections

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_SENDFILE` | `on` | `on` or `off` |
| `NGINX_TCP_NOPUSH` | `on` | `on` or `off` |
| `NGINX_TCP_NODELAY` | `on` | `on` or `off` |
| `NGINX_OPEN_FILE_CACHE` | `max=1000 inactive=30m` | NGINX directive arguments; `;`, `{`, and `}` are rejected |
| `NGINX_OPEN_FILE_CACHE_VALID` | `30s` | NGINX time |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Unsigned integer |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | NGINX time |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | Unsigned integer |
| `NGINX_GZIP` | `on` | `on` or `off` |
| `NGINX_GZIP_STATIC` | `on` | `on` or `off`; serves precompressed `.gz` files when available |
| `NGINX_GZIP_VARY` | `off` | `on` or `off`; the CDN policy already emits `Vary: Accept-Encoding` |
| `NGINX_GZIP_COMP_LEVEL` | `5` | Integer `1`–`9` |
| `NGINX_GZIP_MIN_LENGTH` | `256` | Unsigned byte count |
| `NGINX_EXPIRES_DYNAMIC` | `off` | Safe NGINX `expires` value; keep `off` to retain one cache authority |
| `NGINX_EXPIRES_STATIC` | `off` | Safe NGINX `expires` value; keep `off` to retain one cache authority |
| `NGINX_EXPIRES_DEFAULT` | `off` | Safe NGINX `expires` value; keep `off` to retain one cache authority |
| `NGINX_WORKER_CONNECTIONS` | `2048` | Unsigned per-worker connection limit |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | Unsigned worker file-descriptor limit |
| `NGINX_MULTI_ACCEPT` | `off` | `on` or `off` |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | `1` enables tuning; use empty to disable it; `0` and `off` are invalid |

### Logging and template rendering

| Variable | Effective default | Validation and effect |
| --- | --- | --- |
| `NGINX_ACCESS_LOG` | `/var/log/nginx/access.log json` | Absolute path plus optional format, or `off`; `json` and `main` are built in |
| `NGINX_ERROR_LOG_LEVEL` | `notice` | `debug`, `info`, `notice`, `warn`, `error`, `crit`, `alert`, or `emerg` |
| `NGINX_ENVSUBST_FILTER` | `^NGINX_` | Regex selecting environment names rendered into templates |
| `NGINX_ENVSUBST_TEMPLATE_DIR` | `/etc/nginx/templates` | Input tree used by the recursive renderer |
| `NGINX_ENVSUBST_TEMPLATE_SUFFIX` | `.template` | File suffix selected for rendering |
| `NGINX_ENVSUBST_OUTPUT_DIR` | `/etc/nginx/conf.d` | Output root; must be writable at startup |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | Any nonempty value suppresses official entrypoint informational logs |

> [!WARNING]
> Changing the template directory, suffix, output directory, or substitution
> filter replaces a stack-wide startup assumption. Prefer adding or replacing
> files under the default template tree.

## Customization

Use the narrowest mechanism that satisfies the requirement:

1. Set documented environment variables for supported policy changes.
2. Supply immutable content at `/data`.
3. Derive an image and add or replace templates.
4. Replace the server template only when the image is no longer acting as the
   stock static origin.

### Add CSP and application headers

The stock image intentionally does not guess an application CSP. Add an HTTP
snippet in a downstream image:

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY --chown=nginx:nginx dist/ /data/
COPY docker/nginx/templates/ /etc/nginx/templates/
```

```nginx
# docker/nginx/templates/http.d/83-application-headers.conf.template
add_header Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'self'" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

The inherited configuration uses `add_header_inherit merge`, so these headers
are merged with `X-Frame-Options`, `X-Content-Type-Options`, and
`Referrer-Policy`. Validate the CSP against the application; do not copy the
example blindly when external scripts, fonts, or connections are required.

### Add redirect-map entries

```nginx
# docker/nginx/templates/redirect.d/20-application.map.template
/old-path /new-path;
~^/docs/v1/(.*)$ /docs/v2/$1;
```

The map uses `$request_uri`, so an exact key includes the query string when one
is present. Redirects use `NGINX_FORCE_REDIRECT_STATUS` (`307` by default).

### Replace the error document

The internal error location serves `/_error.html` from `/default-data`, not from
the application document root:

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY --chown=nginx:nginx dist/ /data/
COPY docker/nginx/error.html /default-data/_error.html
```

### Override cache classification

Environment variables change policy values, not which URI belongs to a profile.
To change classification, copy a replacement at the same path:

```dockerfile
FROM ghcr.io/gecut/nginx/cdn:2.0.0

COPY docker/nginx/82-cache-policy-map.conf.template \
  /etc/nginx/templates/http.d/82-cache-policy-map.conf.template
COPY --chown=nginx:nginx dist/ /data/
```

The replacement must continue defining `$cdn_cache_control` and `$cdn_vary` if
the stock header template still consumes them. Preserve status and method
overrides so errors and unsafe methods remain `no-store`. Run `nginx -T` to
confirm that only one `Cache-Control` authority remains.

### Use an alternate document root

Set `NGINX_DOCUMENT_ROOT` and copy or mount content at the same absolute path:

```bash
docker run --rm -p 8080:80 \
  -e NGINX_DOCUMENT_ROOT=/srv/site \
  -v "$PWD/dist:/srv/site:ro" \
  ghcr.io/gecut/nginx/cdn:2.0.0
```

## Security model

- Dotfiles are denied except real files below `/.well-known/`.
- Sensitive backup, configuration, script, database, and template extensions
  are denied by inherited locations.
- Methods other than `GET`, `HEAD`, and `OPTIONS` are denied in the stock root
  location. Specialized downstream locations must enforce their own method
  policy.
- `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, and
  `Referrer-Policy: strict-origin-when-cross-origin` are emitted with `always`.
- CSP, HSTS, authentication, WAF behavior, and TLS are deployment-owned.
- Real-IP rewriting is disabled until exact trusted proxy CIDRs are configured.
- Directory listing, CORS, WebP negotiation, rate limiting, and robots blocking
  are disabled by default.

## Interactions and gotchas

### Canonical host is not an HTTP-to-HTTPS redirect

`NGINX_FORCE_DOMAIN` redirects only when `$host` differs. A request using the
canonical host over plain HTTP is not redirected merely because
`NGINX_CANONICAL_SCHEME=https`. Enforce external HTTP-to-HTTPS redirects at the
TLS terminator.

### Rate limiting depends on correct client identity

The global limit uses `$binary_remote_addr`. Behind a proxy, configure
`NGINX_TRUSTED_PROXY_CIDRS` correctly or every client may share the proxy's
address and exhaust one bucket. Never trust forwarded headers from arbitrary
networks.

### CORS is location-scoped

The stock CORS snippet is included by the root location. When automatic WebP is
enabled, the dedicated JPEG/PNG regex location does not include that root
snippet. Do not assume CORS covers every response; add an intentional
location-aware header policy if cross-origin image responses are required.

### Automatic WebP expects sidecar naming

For `/photo.jpg`, the alternate lookup is `/photo.jpg.webp`, not
`/photo.webp`. The original file remains the fallback. The CDN-level `Vary` map
is emitted whether the feature is enabled or disabled, which is conservative
for intermediary caches.

### Robots blocking can require a writable root

With `NGINX_DISALLOW_ROBOTS=on`, a custom `robots.txt` is preserved. If the file
is absent or still equals the bundled permissive file, startup must replace it;
a read-only document root then fails at stage `40`. Bake the blocking file into
content or provide a writable root.

### Open-file cache and mutable mounts

The stock image caches file lookups, including errors. Immutable content is the
recommended deployment model. If files are changed in place, account for
`NGINX_OPEN_FILE_CACHE_VALID=30s` or disable/tune the open-file cache.

### Resolver configuration does not create proxying

`NGINX_RESOLVERS` only emits the NGINX `resolver` directive for downstream
configuration that needs runtime DNS. It has no effect on stock static serving
and does not turn the image into a reverse proxy.

## Verification cookbook

Inspect the fully rendered configuration with the same environment and mounts
used in production:

```bash
docker run --rm \
  -e NGINX_AUTO_WEBP=on \
  -e NGINX_TRUSTED_PROXY_CIDRS=10.0.0.0/8 \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/cdn:2.0.0 nginx -T
```

Check core cache invariants:

```bash
base=http://127.0.0.1:8080

curl -sSI "$base/app-C6uTJdX2.js" | grep -Ei '^(cache-control|etag|vary):'
curl -sSI "$base/index.html" | grep -Ei '^(cache-control|etag|vary):'
curl -sSI "$base/service-worker.js" | grep -Ei '^cache-control:'
curl -sSI "$base/missing.js" | grep -Ei '^(HTTP/|cache-control|x-content-type-options):'
```

Exercise conditional requests:

```bash
etag=$(curl -sSI "$base/app-C6uTJdX2.js" | sed -n 's/^ETag: //Ip' | tr -d '\r')
curl -sS -o /dev/null -D - -H "If-None-Match: $etag" \
  "$base/app-C6uTJdX2.js"
```

Expected results include exactly one `Cache-Control` header, an ETag on a real
file, `304` for the matching conditional request, and `no-store` on the `404`.

## Troubleshooting

| Symptom or log stage | Likely cause | Resolution |
| --- | --- | --- |
| `19-validate-env.sh: ERROR` | Invalid enum, path, hostname, CIDR, size, time, or unsafe text | Correct the named variable; do not bypass validation |
| `20-envsubst-on-templates.sh: ... not writable` | Render output is read-only | Keep `/etc/nginx/conf.d` writable during startup |
| Stage `20` says no variables match | Custom `NGINX_ENVSUBST_FILTER` excludes every environment name | Restore `^NGINX_` or provide a matching variable |
| `21-real-ip-trusted-proxies.sh` rejects a proxy | Address is not an explicit CIDR | Use values such as `10.20.0.0/16`, not a bare host address |
| `22-resolver.sh: no local resolver was detected` | `NGINX_RESOLVERS=local` but discovery produced no value | Supply explicit IP literals or remove the unused resolver setting |
| Stage `40` reports a read-only document root | Robots blocking needs to create/replace `robots.txt` | Bake the policy into content or make the root writable |
| Stage `91`–`94` removes a snippet | Its feature flag is empty or `off` | Set the documented flag to `on` and inspect `nginx -T` |
| `99-validate-nginx.sh` / `nginx: configuration file ... test failed` | A rendered value or custom template is invalid NGINX | Inspect the rendered output with the startup logs and `nginx -T` after correcting it |
| Asset unexpectedly has one-year cache | Human-readable name matched the broad hyphenated hash regex | Rename it or replace the classification map |
| Error has application cache policy | A downstream location added a competing header | Remove duplicate cache authority and preserve status override |
| All proxied clients receive `429` together | Proxy address is being used as client identity | Configure only the actual trusted proxy CIDRs and correct real-IP header |
| WebP/CORS behavior differs by file type | Regex location precedence bypasses the root CORS snippet | Inspect `nginx -T` and add an explicit location-aware policy |

## Unsupported use cases

Choose another image or derive and own a materially different configuration for:

- reverse proxying, upstream load balancing, or `proxy_cache`;
- TLS certificate management or HTTP/3 termination;
- server-side rendering, application runtimes, APIs, or WebSockets;
- dynamic image conversion—the WebP feature only selects an existing sidecar;
- application-specific authentication, CSP generation, or CDN invalidation.

## Migration from v1

- `expires max` is removed. The stock `Cache-Control` map is the only cache
  authority.
- Vite-style hyphenated hashes and conventional service-worker names receive
  dedicated policies.
- `4xx` and `5xx` responses and non-GET/HEAD methods are always `no-store`.
- ETag and deterministic `Vary` behavior are part of the CDN profile.
- Inherited boolean feature flags require `on` or `off`; worker and resolver
  entrypoint toggles accept `1` or empty as documented.
- Trusted proxy networks must be explicit CIDRs; private networks are not
  trusted automatically.
