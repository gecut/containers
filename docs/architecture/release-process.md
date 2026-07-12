# Container Release Process

Releases are planned from validated catalog data and YAML change fragments.

The source implementation PR does not publish images. A generated Release PR records the release plan, catalog version updates, changelog updates, and consumed stable fragments. Merging that generated Release PR is the publication authorization consumed by GitHub Actions.

Stable releases consume `release` fragments and advance `current_version` in `catalog/images.yaml`. `next` and `rc` plans keep stable version state unchanged and do not consume fragments.

The release plan encodes SHA tags as an intent. The publish workflow resolves that tag from the merged commit SHA.
