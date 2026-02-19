# `gecut/nginx/base` - Foundation Contract

`nginx/base` is the lowest layer of this stack. It provides the runtime contract for startup scripts and template rendering, without imposing a specific application profile.

## Purpose

- Provide a predictable NGINX startup pipeline
- Render NGINX config from environment variables
- Expose generic process and connection tuning controls

## Non-Goals

- Opinionated cache policy for CDN behavior
- Origin-specific security/location rules
- App-specific routing logic

Those belong to higher layers (`core`, `cdn`, or downstream images).

## Runtime Flow

Main entrypoint:

- `nginx/base/etc/nginx/entrypoint.sh`

Flow:

1. Runs only when command is `nginx` or `nginx-debug`
2. Scans `/etc/nginx/entrypoint.d`
3. Sources executable `*.envsh`
4. Executes executable `*.sh`
5. Starts the requested command

Default scripts in this layer:

- `10-local-resolvers.envsh`: resolves `NGINX_RESOLVERS=local` from `/etc/resolv.conf`
- `20-envsubst-on-templates.sh`: renders `*.template` into `/etc/nginx/conf.d`
- `30-tune-worker-processes.sh`: optional worker auto-tuning

## Template Engine Contract

Script: `nginx/base/etc/nginx/entrypoint.d/20-envsubst-on-templates.sh`

Defaults:

- Template dir: `/etc/nginx/templates`
- Template suffix: `.template`
- Output dir: `/etc/nginx/conf.d`

Behavior:

- Preserves subdirectory layout from template tree
- Uses current env vars for substitution
- Creates missing output subdirectories

This contract is used directly by `core` and `cdn`.

## Process and Connection Tunables

The following are public knobs at this layer:

| Env var | Default | Used in | Effect | Risk if misconfigured |
| --- | --- | --- | --- | --- |
| `NGINX_WORKER_CONNECTIONS` | `2048` | `templates/10-event.conf.template` | Max simultaneous connections per worker | Too low limits throughput; too high can exhaust file descriptors |
| `NGINX_WORKER_RLIMIT_NOFILE` | `262144` | `templates/00-main.conf.template` | Sets process open-file limit | Too low causes `too many open files` |
| `NGINX_MULTI_ACCEPT` | `off` | `templates/10-event.conf.template` | Controls whether a worker accepts multiple new connections at once | `on` can increase burst CPU pressure |
| `NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE` | `1` | `entrypoint.d/30-tune-worker-processes.sh` | Auto-sets `worker_processes` from cgroup/CPU constraints | Disable only when pinning worker count intentionally |
| `NGINX_ENTRYPOINT_QUIET_LOGS` | empty | `entrypoint.sh` | Suppresses entrypoint logs when non-empty | Lower startup visibility |

Related template engine knobs (no Dockerfile defaults, but supported):

- `NGINX_ENVSUBST_TEMPLATE_DIR`
- `NGINX_ENVSUBST_TEMPLATE_SUFFIX`
- `NGINX_ENVSUBST_OUTPUT_DIR`

## Extension Pattern for Downstream Images

Recommended pattern:

1. Copy additional templates to `/etc/nginx/templates`
2. Add optional startup scripts to `/etc/nginx/entrypoint.d`
3. Set defaults with `ENV` in child Dockerfile

Because render happens at startup, downstream images can remain static while behavior changes via env vars.

## Security and Operational Caveats

- Keep `entrypoint.d` scripts executable and numerically ordered.
- Avoid shell scripts with side effects outside config generation.
- Keep template variables explicit and documented to avoid silent misconfiguration.
- Treat `NGINX_RESOLVERS=local` as runtime-dependent behavior.

## Minimal Usage Example

```dockerfile
FROM ghcr.io/gecut/nginx/base:latest

COPY ./etc/nginx/templates/ /etc/nginx/templates/
COPY ./etc/nginx/entrypoint.d/ /etc/nginx/entrypoint.d/
```

Build and run:

```bash
docker build -t my-nginx-base-derived -f Dockerfile .
docker run --rm -p 8080:80 my-nginx-base-derived
```

Inspect rendered config:

```bash
docker run --rm my-nginx-base-derived nginx -T
```
