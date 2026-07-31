# NGINX CDN runtime contract

The final image is a static origin. It emits cache metadata but is not a
reverse proxy, dynamic application server, object store, TLS terminator, or
provider-side CDN.

## Required runtime behavior

- Static files live under `/data`.
- Files and directories are served normally.
- Missing assets and error responses remain real `404`/error responses.
- Non-GET/HEAD and authenticated requests are not publicly cached.
- HTML, JSON, and service workers revalidate rather than receiving an
  accidental long-lived policy.
- `NGINX_EXPIRES_DYNAMIC`, `NGINX_EXPIRES_STATIC`, and
  `NGINX_EXPIRES_DEFAULT` stay `off` so Cache-Control has one authority.
- Gzip and gzip-generated `Vary` stay disabled by default for this policy.

## Version and health

Resolve the current compatible stable nginx-cdn release and write its full
SemVer tag. Do not write `latest` or a digest in a consumer Dockerfile. Use
the image's `/server-info` endpoint and inherited health contract when present;
do not add a health command that depends on an absent tool.

## Boundaries

Use `nginx-spa` when an extensionless missing path must return an application
shell. Use a dedicated application/proxy tier for SSR, APIs, WebSockets,
TLS, upstream proxying, `proxy_cache`, authentication, or purge APIs.
