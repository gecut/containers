FROM ghcr.io/gecut/nginx/spa:1.0.0

# Build the SPA before building this image. The output must include index.html.
COPY --chown=nginx:nginx dist/ /data/

