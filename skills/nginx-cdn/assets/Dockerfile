# syntax=docker/dockerfile:1
FROM ghcr.io/gecut/nginx/cdn:2.0.0

# Build with a context that contains public/. Files must remain readable by the
# nginx worker. The exact parent tag is intentional; pin its digest in your
# controlled release pipeline when reproducibility requires it.
COPY --chown=nginx:nginx public/ /data/
