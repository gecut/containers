# `gecut/nginx/spa` v1

Production static hosting for React, Vue, Svelte, Angular, and other
single-page applications. It inherits the complete CDN-origin policy from
`gecut/nginx/cdn:2.0.0`.

## Routing contract

- Existing files and directories are served normally.
- Missing extensionless routes internally resolve to the SPA shell with status
  `200`, enabling React Router, Vue Router, and equivalent history routing.
- Missing known assets such as JS, CSS, JSON, source maps, WASM, images, fonts,
  and media return a real `404` with `Cache-Control: no-store`.
- Non-GET methods are not routed to the shell.
- The container fails startup when the configured shell is missing or unreadable.

## Environment

| Variable | Default | Contract |
| --- | --- | --- |
| `NGINX_SPA_INDEX_URI` | `/index.html` | Absolute local URI without query, fragment, traversal, whitespace, or control characters |

All `core` and `cdn` variables remain available.

## Runtime usage

Mount a completed Vite/CRA output directory at `/data`:

```bash
docker run --rm -p 8080:80 -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0
```

Or copy the output in a downstream image:

```dockerfile
FROM ghcr.io/gecut/nginx/spa:1.0.0
COPY --chown=nginx:nginx dist/ /data/
```

For a custom shell:

```bash
docker run --rm -p 8080:80 \
  -e NGINX_SPA_INDEX_URI=/app.html \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0
```

The application router owns client-side not-found UI. NGINX intentionally
returns the shell with status `200` for unknown application routes.
