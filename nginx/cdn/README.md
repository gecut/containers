# `gecut/nginx/cdn` v2

`ghcr.io/gecut/nginx/cdn:2.0.0` is a production static-file origin. Use it to
serve a completed website or asset bundle from `/data`, either directly or
behind a CDN.

It provides deterministic `Cache-Control` rules, ETags, representation-aware
`Vary` headers, security defaults, and a `/server-info` health endpoint. It does
not run an application and it does not replace an external CDN, load balancer,
or reverse proxy.

> [!IMPORTANT]
> This image serves files from disk. It is not a reverse proxy, does not provide
> `proxy_cache`, and does not terminate TLS. Put a load balancer or CDN in front
> when those capabilities are required.

For client-side history routing, use
[`ghcr.io/gecut/nginx/spa:1.0.0`](../spa/README.md). For a static origin without
the CDN cache policy, use [`ghcr.io/gecut/nginx/core:2.0.0`](../core/README.md).
For upstream applications, use a separate application runtime and proxy tier.

## Is this the right image?

Use this image when:

- your application produces complete static files;
- files can be served from `/data`;
- missing files should remain real `404` responses;
- cache behavior belongs at the origin and may also be honored by a CDN.

Use [`nginx/spa`](../spa/README.md) when a missing extensionless URL must return
the application shell for client-side routing. Missing assets and dotted paths
must still return real `404` responses.

Use another runtime or proxy when you need SSR, APIs, WebSockets, TLS
termination, authentication, `proxy_cache`, dynamic image conversion, or purge
APIs.

## Using this image with AI agents

This repository provides four portable Agent Skills. They are instructions for
an AI coding agent. They do not install Docker, deploy your application, or
change files unless you explicitly ask the agent to do so.

| Skill | Use it for |
| --- | --- |
| [`nginx-cdn`](../../skills/nginx-cdn/) | Static-origin deployment, cache headers, ETags, WebP, CORS, startup, and diagnostics |
| [`nginx-spa`](../../skills/nginx-spa/) | SPA shell fallback, deep links, strict asset `404`s, and SPA probes |
| [`nginx-cdn-dockerfile`](../../skills/nginx-cdn-dockerfile/) | Multi-stage Dockerfiles that build an application and copy static output into NGINX |
| [`github-actions-ghcr-publish`](../../skills/github-actions-ghcr-publish/) | Single-image and dependency-ordered multi-image GHCR workflows |

### Install the skills

After this repository version is published, list the remote skills:

```bash
npx skills@1.5.19 add gecut/containers --list
```

Install all four:

```bash
npx skills@1.5.19 add gecut/containers \
  --skill nginx-cdn \
  --skill nginx-spa \
  --skill nginx-cdn-dockerfile \
  --skill github-actions-ghcr-publish
```

For local development, install from a checkout:

```bash
npx skills@1.5.19 add /path/to/containers --list
npx skills@1.5.19 add /path/to/containers --skill nginx-cdn-dockerfile
```

The CLI installs instructions for the agent. It does not install the image or
the tools needed for live checks. The agent may still need repository access,
Docker, `curl`, registry credentials, or GitHub Actions permissions.

### Choose the skill

| Task | Start with | Add when needed |
| --- | --- | --- |
| Serve a normal static site | `nginx-cdn` | `nginx-cdn-dockerfile` for a build image |
| Serve a React/Vue/Svelte/Angular SPA | `nginx-spa` | `nginx-cdn-dockerfile` for the application Dockerfile |
| Review or write a Dockerfile | `nginx-cdn-dockerfile` | `nginx-cdn` or `nginx-spa` for runtime behavior |
| Publish one image to GHCR | `github-actions-ghcr-publish` | `nginx-cdn-dockerfile` for build checks |
| Publish dependent images as one release | `github-actions-ghcr-publish` | Image-specific consumer skills |
| Diagnose cache, headers, startup, or routing | `nginx-cdn` or `nginx-spa` | Dockerfile/workflow skill if the issue starts there |

`nginx/cdn` is only a static origin. Use a separate runtime or proxy for SSR,
APIs, WebSockets, TLS termination, authentication, `proxy_cache`, or purge
APIs. If an extensionless URL must return the application shell, use
`nginx-spa`; missing assets and dotted paths must still return real `404`s.

### Important policy differences

The image defaults are optimized for static delivery: proven fingerprinted
assets use long immutable caching and gzip is enabled. The
`nginx-cdn-dockerfile` skill may apply a separate short-cache policy for
projects that overwrite mutable URLs and may disable gzip. Do not assume that
direct `docker run` has the same settings as a downstream Dockerfile generated
by that skill.

Generated consumer examples use full `major.minor.patch` versions without
action SHAs or image digests. This is easier to read but less immutable than
SHA/digest pinning. The internal workflow for this repository may use SHA or
digest pinning as a separate maintainer security policy. Image tags such as
`sha-<commit>` are output metadata and are not dependency pinning.

Agents should check the latest compatible stable version, compare it with the
lockfile and runner, explain the choice, and ask before applying an
incompatible major upgrade.

### Ready-to-run prompts

Replace bracketed values with your paths and names. These prompts are
analysis-first and ask the agent not to edit files. Remove that instruction only
when you want implementation.

#### Choose the right runtime

```text
Use the nginx-cdn skill.

Inspect this repository before changing anything:
- build output: [dist/ or out/ path]
- current Dockerfile or image: [path]
- deployment files: [paths]

Decide whether this workload needs nginx/cdn, nginx/spa, nginx/core, or a
separate application runtime. Check static output completeness, SPA history
routing, asset and service-worker behavior, cache expectations, /server-info,
and external CDN or proxy assumptions.

Do not edit files. Return the fit decision, risks, and a minimal implementation
plan with exact verification commands.
```

#### Build a production Dockerfile

```text
Use nginx-cdn-dockerfile and the appropriate runtime skill.

Inspect [Dockerfile path], package manifests, lockfiles, build scripts, build
output, and deployment workflows. Decide first whether the result is a normal
static origin or an SPA; do not assume nginx-cdn if client-side history routing
is required.

Prepare a production Dockerfile that uses the repository's package manager and
lockfile, BuildKit dependency caching, a multi-stage build, and a minimal final
image. Copy only the final static output to /data with nginx ownership. Use the
latest compatible NGINX image with a full major.minor.patch tag and no digest.

For mutable-project defaults, use short cache values, keep service workers
no-cache and errors no-store, and disable gzip, gzip-static, and expires. Keep
long immutable caching only when filenames are proven content-addressed. Use
/server-info for probes; add Docker HEALTHCHECK only if the base image does not
already provide one.

Do not edit files. Return the Dockerfile, assumptions, risks, and build,
inspect, and smoke-test commands.
```

#### Deploy an SPA

```text
Use the nginx-spa skill.

Inspect the build output at [path] and determine the shell file, public base
path, client-side router, deep-link behavior, and missing-asset behavior.

Prepare a deployment using ghcr.io/gecut/nginx/spa. It must return 200 for a
missing extensionless application route, return a real 404 for a missing asset
or dotted path, validate the shell at startup, and use the correct health
probes. Check the bundler base path, router base path, NGINX_SPA_INDEX_URI, and
any ingress rewrite.

Do not edit files. Return the deployment artifact and curl verification matrix.
```

#### Publish one image to GHCR

```text
Use github-actions-ghcr-publish and, when needed, nginx-cdn-dockerfile.

Inspect [workflow path], [Dockerfile path], package scripts, repository
settings, and the default branch. Classify this as a single-image workflow.

Propose a workflow where pull requests validate and build without login or push,
and only the default branch or workflow_dispatch publishes to GHCR. Use a
lowercase image name, Buildx, GitHub Actions cache, commit tags, latest only on
the default branch, provenance and SBOM on publish, and the Dockerfile as the
only production application-build source. Use compatible full
major.minor.patch action and tool versions without SHAs.

Do not edit files. Return the job graph, permissions, event matrix, risks, and
validation commands.
```

#### Publish dependent images

```text
Use github-actions-ghcr-publish.

Inspect the workflows and Dockerfiles for these images and dependency order:
[image list and order]. Decide whether they require one dependency-ordered
release pipeline or independent workflows.

If one closure is required, design these gates:
1. build unique multi-platform candidate tags in dependency order;
2. resolve every candidate manifest to a digest;
3. run integration tests using digest references;
4. scan every candidate image;
5. sign every candidate digest;
6. promote only after all gates pass;
7. verify major, minor, patch, commit, and latest aliases point to signed
   digests.

First audit GHCR permissions, OIDC/Cosign setup, scanner availability, and
release policy. Report missing prerequisites instead of assuming them. Use
compatible full major.minor.patch action and tool versions without SHAs.

Do not edit files. Return the dependency graph, permissions, concurrency rules,
failure conditions, required settings, and validation commands.
```

#### Diagnose cache and headers

```text
Use the nginx-cdn skill. The origin is running at [URL] and the problem is:
[describe the symptom].

Inspect the rendered NGINX configuration first. Build a request matrix for
HTML, a hashed asset, JSON, an image, a service worker, a missing asset, and a
request with If-None-Match. Check status, exactly one Cache-Control field,
Vary, ETag/304, 404 no-store, and query-string behavior.

Separate origin evidence from external CDN evidence. If a CDN is present, check
Age, X-Cache, Vary, query-string policy, and purge behavior separately. Do not
claim that a healthy origin proves the edge is correct.

Do not edit files. Return findings, likely cause, and the smallest safe fix.
```

### What the agent should return

Ask the agent to report the selected image and why it fits, every file/env/
permission assumption, expected routing and cache behavior, commands actually
run with their results, and limitations such as missing Docker, `curl`,
`actionlint`, registry access, credentials, or CDN staging.

The bundled `verify-origin.sh` needs a running origin and real fixture paths.
The SPA verifier also needs a running origin. Static Dockerfile and workflow
verifiers are useful filters, but they do not replace a real build, container
startup, registry publish, or CDN-edge test.

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

Use `GET /server-info` for Docker Compose and Kubernetes liveness/readiness
probes. This endpoint proves that the origin is serving requests; it does not
prove that DNS, TLS, an external CDN, an upstream application, or a load
balancer is healthy. For an SPA, readiness should also confirm that the shell
file exists and is readable.

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
| Image with any supported filename | `public, max-age=0, must-revalidate, s-maxage=86400` |
| Unversioned static file | `public, max-age=3600, stale-while-revalidate=30` |
| `/`, a URI ending in `/`, `.htm`, or `.html` | `public, max-age=0, must-revalidate, s-maxage=0` |
| `.json` or `.webmanifest` | `public, max-age=60, stale-while-revalidate=30` |
| `service-worker.js` or `sw.js` | `no-cache` |
| Any `4xx` or `5xx` response | `no-store` |
| Any method other than `GET` or `HEAD` | `no-store` |
| Any request with `Authorization` | `private, no-store` |

Policy evaluation is deliberately layered:

1. `$uri` selects `image`, `hashed`, `service_worker`, `html`, `json`, or the
   default `static_unversioned` profile. Image extensions are selected before
   filename hash heuristics.
2. A `4xx` or `5xx` status replaces the URI policy with the error policy.
3. A method other than `GET` or `HEAD` replaces either result with the error
   policy.
4. An Authorization request is forced to `private, no-store`.

Images are never classified as hashed by filename. Non-image build assets use
dot-delimited hexadecimal hashes or mixed-case Vite-style tokens containing a
digit. Long immutable caching still requires a content-addressed URL.

### Validators and representation variance

- ETags are enabled, so a matching `If-None-Match` request can return `304`.
- `Accept-Encoding` is present only when gzip or gzip-static can vary bytes.
- `.jpg`, `.jpeg`, and `.png` URIs add `Accept` only when automatic WebP can
  select a different representation.
- No `Vary` field is emitted when neither feature changes representation.
- The inherited `expires` policy is set to `off`. `Cache-Control` is therefore
  the single cache authority emitted by the stock image.

Do not add a second `expires` directive or another unconditional
`Cache-Control` header in a downstream template. Replace the stock policy map
when the policy must change.

### Origin checks and CDN checks are different

An origin test proves what this container returns. A CDN test proves what users
receive from the edge. Check them separately:

- **Origin:** status, `Cache-Control`, `Vary`, ETag/304, error `no-store`, and
  the selected representation.
- **Edge:** `Age`, `X-Cache`, query-string cache keys, `Vary` handling, purge,
  and provider-specific cache precedence.

A healthy origin does not prove that a downstream CDN stored, purged, or served
the response correctly.

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

This example expects `dist/` to already exist. If the repository must build the
application inside Docker, use the
[`nginx-cdn-dockerfile` skill](../../skills/nginx-cdn-dockerfile/) to select the
package manager, cache dependency installation, run the repository's build
scripts, and copy only the final output into the NGINX stage. It will route SPA
projects to the `nginx-spa` runtime instead of adding a fallback to this image.

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
| `NGINX_CDN_CACHE_IMAGE` | `public, max-age=0, must-revalidate` | Base policy for supported image extensions, independent of filename |
| `NGINX_CDN_IMAGE_S_MAXAGE` | `86400` | Unsigned integer appended as `s-maxage` to the image policy |
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
| `NGINX_OPEN_FILE_CACHE_VALID` | `1s` | NGINX time; short by default for live uploads |
| `NGINX_OPEN_FILE_CACHE_MIN_USES` | `2` | Unsigned integer |
| `NGINX_OPEN_FILE_CACHE_ERRORS` | `off` | `on` or `off`; negative lookup caching is disabled for live uploads |
| `NGINX_KEEPALIVE_TIMEOUT` | `65` | NGINX time |
| `NGINX_KEEPALIVE_REQUESTS` | `1000` | Unsigned integer |
| `NGINX_GZIP` | `on` | `on` or `off` |
| `NGINX_GZIP_STATIC` | `on` | `on` or `off`; serves precompressed `.gz` files when available |
| `NGINX_GZIP_VARY` | `off` | `on` or `off`; keep off because the CDN map owns conditional Vary |
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
- Requests carrying `Authorization` are never shared-cacheable.
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

The stock CDN image does not cache lookup errors and revalidates cached file
metadata after `1s`, so a newly uploaded or overwritten path becomes visible
quickly. Immutable baked content may increase the interval and enable
`NGINX_OPEN_FILE_CACHE_ERRORS`.

### ArvanCloud edge compatibility

Enable ArvanCloud Origin Cache Control so origin `Cache-Control` remains
authoritative. `max-age` controls browsers and `s-maxage` controls Arvan's
shared cache. This origin ignores query arguments when selecting file bytes;
Arvan's ignore-query mode is safe only when no transform or signed-query layer
changes the representation.

Order Arvan page rules as bypass/private, health and errors, mutable public
files, immutable versioned assets, then a conservative fallback. Keep Arvan's
ignore-Vary option disabled when gzip or automatic WebP is enabled. Mutable
URLs that require immediate replacement need targeted purge and client-side
verification of `X-Cache` and `Age`; a `MISS` alone does not prove storage.

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
| Image has an unexpected cache policy | Image profile envs differ from the stock values | Inspect `NGINX_CDN_CACHE_IMAGE` and `NGINX_CDN_IMAGE_S_MAXAGE` |
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
