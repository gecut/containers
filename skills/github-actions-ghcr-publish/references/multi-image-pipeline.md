# Multi-image promotion pipeline

## Dependency closure

Represent the image graph explicitly. Build the base image first, pass its
candidate tag to the next image, and continue until the leaf image. Use unique
candidate tags containing commit, run, and attempt identifiers so retries do
not collide.

## Gates

After the candidate build:

1. resolve every pushed manifest to a digest;
2. run integration tests using digest references;
3. scan all candidate images for configured severity thresholds;
4. sign every digest;
5. promote only after all previous gates pass;
6. verify major, minor, patch, commit, and `latest` aliases against the signed
   digest.

Never promote one image of a closure while another gate is failing. Keep the
promotion concurrency group non-cancelable.

## Release safety

Validate every `major.minor.patch` input before deriving aliases. Keep
candidate and promoted repositories separate in variables. Use complete
Buildx output when extracting digests; do not rely on a truncated pipeline
result under `pipefail`.
