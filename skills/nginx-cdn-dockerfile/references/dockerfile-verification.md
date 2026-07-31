# Dockerfile verification

## Static checks

Run Hadolint when available, inspect the base image and all `FROM` lines, and
reject `latest`, digest syntax, root-owned static files, and missing artifact
copy. Confirm that every build command is backed by a package script.

## Build checks

Build with BuildKit and the real context. Confirm that the final image does
not contain source or `node_modules`, that `/data` has the expected shell and
assets, and that the entrypoint can render its NGINX configuration.

## Runtime checks

Against a running origin, verify `/server-info`, the shell, one representative
HTML/JSON/image/asset path, the service worker, a missing asset, and an
authenticated or non-GET request. Check status, exactly one Cache-Control,
Vary behavior, ETag/304, and error `no-store`.

## Failure handling

Stop and ask when the build output is unknown, the selected major is
incompatible, the project needs SPA fallback, or an environment variable is
not in the runtime contract. Separate origin evidence from downstream CDN
cache, purge, TLS, and WAF behavior.
