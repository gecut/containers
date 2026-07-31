# Single-image workflow

## Job shape

The default shape is one validation/build job with a publish condition:

1. checkout;
2. optional lint/typecheck checks;
3. Buildx setup;
4. derive lowercase image and tags;
5. login only when pushing;
6. build with `push: ${{ ... }}`;
7. GHA cache and publish metadata.

The Dockerfile should run the static application build. A separate workflow
build is allowed only for independent validation and must not be passed as a
second source of production files.

## Tag behavior

Use a short commit tag for every successful build. Add `latest` only for the
default branch or an explicitly approved release event. Do not publish tags
from arbitrary PRs or feature branches.

## Project differences

If the repository already has a different event policy, preserve it only when
it is intentional and safe. Report changes such as publishing on every push,
unconditional GHCR login, or duplicate application builds.
