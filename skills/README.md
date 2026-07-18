# Consumer agent skills

This directory publishes portable [Agent Skills](https://agentskills.io/) for
consumers of Gecut container images. The skills contain deployment workflows,
runtime contracts, reusable configuration assets, diagnostics, and evaluation
cases. They do not change the behavior of the images themselves.

## Available skills

| Skill | Image | Use it for |
| --- | --- | --- |
| [`nginx-cdn`](./nginx-cdn/SKILL.md) | `ghcr.io/gecut/nginx/cdn:2.0.0` | Static CDN origins, cache policy, ETag, WebP, CORS, proxy trust, and origin verification |
| [`nginx-spa`](./nginx-spa/SKILL.md) | `ghcr.io/gecut/nginx/spa:1.0.0` | Static SPAs with history fallback, strict asset 404s, inherited CDN caching, and shell readiness |

## Install

List the skills without installing them:

```bash
npx skills add gecut/containers --list
```

Install one skill into a supported agent:

```bash
npx skills add gecut/containers --skill nginx-cdn
npx skills add gecut/containers --skill nginx-spa
```

The skill names intentionally match their top-level directory names. This keeps
them unambiguous in public skill catalogs and conforms to the Agent Skills
naming contract.

## Validate

From the repository root:

```bash
ruby tests/skills/validate.rb
npx --yes skills@1.5.19 add . --list
```

The repository validator checks frontmatter, names, metadata, references,
scripts, eval definitions, trigger balance, and catalog targets. Runtime HTTP
behavior is covered by `tests/nginx/integration.sh` when Docker is available.
