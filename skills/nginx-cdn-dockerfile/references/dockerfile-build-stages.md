# Dockerfile build stages

## Stage selection

Inspect `package.json`, the lockfile, workspace file, and build output before
choosing stages. For Node/pnpm applications use:

1. `base`: Node version, Corepack, pnpm version, workdir, and shared env.
2. `deps`: manifests only and frozen dependency installation with a BuildKit
   pnpm-store cache mount.
3. `builder`: dependency layer plus source, then lint/typecheck/build.
4. `runtime`: `ghcr.io/gecut/nginx/cdn:X.Y.Z` and only the generated static
   directory under `/data`.

If the repository already produces static files outside Docker, use a small
runtime-only Dockerfile and state that the external build is now the source of
truth. Do not create a second build path without an explicit reason.

## Package versions

Use the latest compatible stable Node and pnpm versions as exact
`major.minor.patch` values. Preserve the lockfile contract. A major upgrade
that changes the package manager, Node ABI, or build behavior is a question,
not an invisible edit.

## Cache and ownership

Copy manifests before source files. Use `--mount=type=cache` only for package
stores, never as a runtime data dependency. Copy the final artifact with
`--chown=nginx:nginx`; static files must be readable by the worker.

## Anti-patterns

- `FROM ...:latest` or digest references in generated consumer examples.
- Installing dependencies after copying the complete source tree.
- Running the application server in the final static image.
- Copying `node_modules` into the final stage.
- Building the same app in both workflow and Dockerfile without a deliberate
  artifact handoff.
- Adding a broad SPA fallback to an nginx-cdn image.
