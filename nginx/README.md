# NGINX Stack (`base` -> `core` -> `cdn` -> `spa`)

This repository ships a layered NGINX stack designed for production workloads:

- `nginx/base`: runtime and template engine foundation
- `nginx/core`: hardened static-origin profile on top of `base`
- `nginx/cdn`: CDN-focused cache policy layer on top of `core`
- `nginx/spa`: strict single-page application routing on top of `cdn`

## Layer Model

```
docker.io/library/nginx:1.30.4-alpine-slim (digest pinned)
  -> ghcr.io/gecut/nginx/base:2.0.0
    -> ghcr.io/gecut/nginx/core:2.0.0
      -> ghcr.io/gecut/nginx/cdn:2.0.0
        -> ghcr.io/gecut/nginx/spa:1.0.0
```

Each layer can override `/etc/nginx/*` from its parent. The effective config is rendered from templates at container startup.

## Layer Comparison

| Layer | Primary role | Adds | Typical usage |
| --- | --- | --- | --- |
| `base` | Runtime foundation | Entrypoint orchestration, envsubst template rendering, worker auto-tune | Build your own NGINX profile |
| `core` | Secure origin profile | Static serving defaults, security locations, real IP handling, gzip, optional CORS/webp/force-domain/rate-limit | General static origin behind LB/CDN |
| `cdn` | Cache policy specialization | Cache-Control policy maps, ETag, CDN-oriented defaults | High-performance static CDN origin |
| `spa` | SPA static hosting | Strict asset 404s, deep-route shell fallback, shell readiness | React/Vue/Vite/CRA deployments |

## Config Rendering and Precedence

1. The official entrypoint runs scripts in `/docker-entrypoint.d` in version order.
2. `20-envsubst-on-templates.sh` renders all `*.template` files from `/etc/nginx/templates` to `/etc/nginx/conf.d`.
3. Later scripts can remove or generate files (feature toggles and runtime-generated includes).
4. NGINX loads `/etc/nginx/conf.d/*.conf` from `nginx.conf`.

Practical precedence:

`base defaults < core defaults < cdn cache policy < spa routing < runtime env vars`

## Key Paths

- official `/docker-entrypoint.sh`
- `nginx/base/etc/nginx/entrypoint.d/20-envsubst-on-templates.sh`
- `nginx/base/etc/nginx/templates/*`
- `nginx/core/etc/nginx/templates/http.d/*`
- `nginx/core/etc/nginx/templates/location.d/*`
- `nginx/cdn/etc/nginx/templates/http.d/*`
- `nginx/spa/etc/nginx/templates/location.d/*`

## Layer Docs

- [Base Image Contract](./base/README.md)
- [Core Origin Guide](./core/README.md)
- [CDN Production Guide](./cdn/README.md)
- [SPA Hosting Guide](./spa/README.md)
