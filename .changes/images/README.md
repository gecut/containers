# Image Change Fragments

Every pull request should include one image change fragment unless the change is purely release automation maintenance already covered by a generated Release PR.

## Release Fragment

```yaml
schema_version: 1
type: release
summary: Add configurable NGINX cache policy.
images:
  nginx-core: minor
  nginx-cdn: patch
breaking_notes:
  nginx-core: Required only when nginx-core is a major bump.
```

## Documentation Fragment

```yaml
schema_version: 1
type: documentation
summary: Clarify the NGINX inheritance guide.
```

## No-Release Fragment

```yaml
schema_version: 1
type: no-release
summary: Refactor release automation tests without changing published images.
```

Release fragments must use active catalog image IDs from `catalog/images.yaml`. Aliases such as `nexload`, archived image names, and registry paths are not valid release targets.
