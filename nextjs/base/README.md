# Next.js + Payload Runner (Production-Ready)

A minimal, secure, and extensible Docker base image to run combined Next.js and Payload CMS apps in production.

- Uses `tini` as PID 1 for reliable signal handling and zombie reaping
- Starts via modular shell scripts under `/scripts`
- Runs as non-root `nextjs` user
- Includes graceful shutdown handling
- Ships with a minimal runtime dependency set (e.g., `vips` for sharp/image processing)

---

## Key Features

- **Security-first**: Drops privileges to `nextjs` (UID 1001) and `nodejs` group.
- **Graceful shutdown**: `tini` + signal trapping in `99-entrypoint.sh`.
- **Database migrations**: Built-in migration step for Payload via `20-payload-migrate.sh`.
- **Storage permissions**: Auto-fix storage paths via `10-fix-permissions.sh`.
- **Extensible startup**: Add custom scripts as `NN-name.sh` to `/scripts`.

---

## Prerequisites

- Docker (latest)
- Docker Compose (optional for local dev)

---

## How to Use

### 1) Minimal Dockerfile in your app

```docker
# Base runner image
FROM ghcr.io/gecut/nextjs/with-payload:latest

# Copy application code
COPY . .

# Default command of your app (example)
CMD ["node", "server.js"]
```

> Tip: If you use Next.js standalone output, you may run `node server.js` or `next start`. Make sure your CMD matches your build output.

### 2) Docker Compose example

```yaml
version: '3.8'
services:
  app:
    image: my-next-payload-app
    build: .
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - DATABASE_URL=postgres://user:pass@db:5432/app
      - UPLOADS_STORAGE_PATH=/app/public/uploads
    volumes:
      - ./public/uploads:/app/public/uploads
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    volumes:
      - dbdata:/var/lib/postgresql/data
volumes:
  dbdata:
```

---

## Configuration

These environment variables influence container behavior:

- `PORT`: HTTP port (default `3000`)
- `DATABASE_URL` or `DATABASE_URI`: Database connection string for Payload migrations
- `*_STORAGE_PATH` or `*_DIR`: Any env ending with these suffixes will be treated as a directory path whose ownership is fixed to `nextjs:nodejs` on startup

> Note: For uploads, set `UPLOADS_STORAGE_PATH=/app/public/uploads` and mount a volume to persist data.

---

## Startup Architecture

- `setup.sh`: Orchestrator; executes all `*.sh` in `/scripts` (sorted by name).
- `/scripts/10-fix-permissions.sh`: Creates and fixes ownership for storage directories based on env vars.
- `/scripts/20-payload-migrate.sh`: Validates prerequisites and runs `payload migrate` as `nextjs`.
- `/scripts/99-entrypoint.sh`: Launches your app with graceful shutdown handling.

> The container uses `tini` as ENTRYPOINT and sets `STOPSIGNAL SIGTERM` for standard shutdown.

---

## Package Manager Compatibility

The migration script expects `payload` CLI to be runnable. Two reliable approaches:

- Via Corepack/PNPM (recommended): enable `corepack` in your build image and use `pnpm`.
- Via local binary: call `./node_modules/.bin/payload migrate` directly (no global pnpm required).

Adjust your CI/build to ensure one of the above strategies is available at runtime.

---

## Healthchecks (optional)

Add an HTTP health endpoint in your app and configure Docker healthcheck in your project image:

```docker
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s CMD \
  wget -qO- http://localhost:${PORT}/api/health || exit 1
```

---

## File Structure (inside this base image)

```
.
├── Dockerfile
├── setup.sh
└── scripts/
    ├── 10-fix-permissions.sh
    ├── 20-payload-migrate.sh
    └── 99-entrypoint.sh
```

---

## Best Practices

- Ensure your app handles `SIGTERM`/`SIGINT` to close DB connections and HTTP servers.
- Use volumes for user uploads and cache directories.
- Keep runtime image minimal; move build-only dependencies to a separate build stage.

---

## License

MIT
