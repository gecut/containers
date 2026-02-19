# NGINX Stack (`base` -> `core` -> `cdn`)

This repository ships a layered NGINX stack designed for production workloads:

- `nginx/base`: runtime and template engine foundation
- `nginx/core`: hardened static-origin profile on top of `base`
- `nginx/cdn`: CDN-focused cache policy layer on top of `core`

## Layer Model

```
docker.io/library/nginx:1.28.2-alpine-slim
  -> ghcr.io/gecut/nginx/base
    -> ghcr.io/gecut/nginx/core
      -> ghcr.io/gecut/nginx/cdn
```

Each layer can override `/etc/nginx/*` from its parent. The effective config is rendered from templates at container startup.

## Layer Comparison

| Layer | Primary role | Adds | Typical usage |
| --- | --- | --- | --- |
| `base` | Runtime foundation | Entrypoint orchestration, envsubst template rendering, worker auto-tune | Build your own NGINX profile |
| `core` | Secure origin profile | Static serving defaults, security locations, real IP handling, gzip, optional CORS/webp/force-domain/rate-limit | General static origin behind LB/CDN |
| `cdn` | Cache policy specialization | Cache-Control policy maps, ETag, CDN-oriented defaults | High-performance static CDN origin |

## Config Rendering and Precedence

1. Entrypoint (`/etc/nginx/entrypoint.sh`) runs scripts in `/etc/nginx/entrypoint.d` sorted by filename.
2. `20-envsubst-on-templates.sh` renders all `*.template` files from `/etc/nginx/templates` to `/etc/nginx/conf.d`.
3. Later scripts can remove or generate files (feature toggles and runtime-generated includes).
4. NGINX loads `/etc/nginx/conf.d/*.conf` from `nginx.conf`.

Practical precedence:

`base defaults < core defaults and templates < cdn overrides and templates < runtime env vars`

## Key Paths

- `nginx/base/etc/nginx/entrypoint.sh`
- `nginx/base/etc/nginx/entrypoint.d/20-envsubst-on-templates.sh`
- `nginx/base/etc/nginx/templates/*`
- `nginx/core/etc/nginx/templates/http.d/*`
- `nginx/core/etc/nginx/templates/location.d/*`
- `nginx/cdn/nginx/core/etc/nginx/templates/http.d/*`

## Layer Docs

- [Base Image Contract](./base/README.md)
- [Core Origin Guide](./core/README.md)
- [CDN Production Guide](./cdn/README.md)
