# `gecut/nginx/base` v2

Foundation image for the Gecut NGINX stack. It is based on the exact official
`nginx:1.30.4-alpine-slim` multi-platform digest and keeps the official Docker
entrypoint, signal handling, log streams, envsubst support, and worker tuning.

Use this image to build another NGINX profile. It intentionally does not define
an HTTP virtual host.

## Runtime contract

- Port: `80`
- Document workdir: `/data`
- Entrypoint: `/docker-entrypoint.sh`
- Templates: `/etc/nginx/templates/**/*.template`
- Rendered configuration: `/etc/nginx/conf.d/**`
- Worker user: `nginx`; the master keeps the official port-80 runtime model.
- Shutdown: `SIGQUIT`

Templates are rendered atomically. Only environment variables matching
`NGINX_ENVSUBST_FILTER` are substituted; the default is `^NGINX_`, which leaves
NGINX runtime variables such as `$uri` intact. Environment validation runs
before rendering and `nginx -t` runs before startup.

## Environment

| Variable | Default | Contract |
| --- | --- | --- |
| `NGINX_ENVSUBST_FILTER` | `^NGINX_` | Regex selecting variables available to envsubst |
| `NGINX_WORKER_CONNECTIONS` | `2048` | Positive connection limit per worker |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | Worker open-file limit |
| `NGINX_MULTI_ACCEPT` | `off` | `on` or `off` |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | `1` or empty; other values fail validation |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | Suppress official entrypoint logs when non-empty |

## Example

```dockerfile
FROM ghcr.io/gecut/nginx/base:2.0.0

COPY nginx/templates/ /etc/nginx/templates/
COPY nginx/entrypoint.d/ /docker-entrypoint.d/
```

```bash
docker run --rm ghcr.io/gecut/nginx/base:2.0.0 nginx -T
```

## Migration from v1

- The official entrypoint replaces the cloned v1 runner.
- Invalid environment values and invalid rendered configuration fail startup.
- `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=0|off` is invalid; use an empty
  value to disable it.
- Resolver configuration is no longer injected by the base image.
