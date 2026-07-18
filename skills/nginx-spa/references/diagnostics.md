# Verification and diagnostics

## Fast verification

Resolve `SKILL_ROOT` to the installed directory containing this skill's
`SKILL.md`, then run the bundled verifier against a started origin:

```sh
"$SKILL_ROOT/scripts/verify-spa.sh" \
  --asset /assets/app.abcdef12.js \
  http://127.0.0.1:8080
```

Custom shell/base path:

```sh
"$SKILL_ROOT/scripts/verify-spa.sh" \
  --shell-path /portal/index.html \
  --asset /portal/assets/app.abcdef12.js \
  --deep-route /portal/__verify/deep-link \
  --missing-asset /portal/__verify/missing.js \
  --dotted-route /portal/__verify/account.settings \
  http://127.0.0.1:8080
```

The script checks shell/deep-link success, an existing hashed asset when supplied,
shell and asset caching/security headers, strict asset/dotted-route `404`,
no-store errors, ETag, and `Vary`. It sends only HEAD requests by default. Add
`--check-post` only against a known-static or disposable origin to verify that a
non-GET route is rejected; POST can mutate state if traffic is routed elsewhere.

## Inspect startup by stage

Match the first error prefix:

- `19-validate-env.sh`: correct the named value; do not bypass validation with raw template injection.
- `20-envsubst-on-templates.sh`: make `/etc/nginx/conf.d` writable or correct custom output/template settings.
- `21-real-ip-trusted-proxies.sh`: use explicit CIDR notation such as `10.0.0.0/8`, never a bare IP.
- `22-resolver.sh`: remove unused resolver configuration or ensure local resolver discovery exists.
- `30-copy-default-data.sh`: a read-only-root skip is expected when all required files are supplied.
- `40-disallow-robots.sh`: provide an intentional `robots.txt` before using a read-only mount, or disable replacement.
- `45-validate-spa-shell.sh`: align document root, shell URI, mount/copy destination, permissions, and build output.
- `91`–`94`: removal messages indicate optional domain, WebP, CORS, or rate-limit features are disabled.
- `99-validate-nginx.sh`: inspect the rendered configuration for syntax, scope, duplicate location, or missing include errors.

## Inspect rendered NGINX configuration

For a running container:

```sh
docker exec <container> nginx -T
```

For a container that exits during startup, reproduce its environment and mounts
while asking the normal entrypoint to print the rendered configuration:

```sh
docker run --rm \
  -v "$PWD/dist:/data:ro" \
  ghcr.io/gecut/nginx/spa:1.0.0 nginx -T
```

This preserves official resolver discovery, worker tuning, and the repository's
ordered validation/rendering stages. The command exits at the first failing
entrypoint stage and prints that stage's diagnostic.

## Manual request matrix

```sh
curl -sSI http://127.0.0.1:8080/index.html
curl -sSI http://127.0.0.1:8080/a/deep/route
curl -sSI http://127.0.0.1:8080/missing.js
curl -sSI http://127.0.0.1:8080/account.settings
curl -sSI -H 'If-None-Match: "<etag>"' http://127.0.0.1:8080/index.html
curl -sSI -X POST http://127.0.0.1:8080/a/deep/route
```

Expected defaults: shell/deep route `200`; missing asset/dotted route `404`;
conditional shell commonly `304`; POST must not return shell content as a
normal `200`; errors and non-GET/HEAD responses use `Cache-Control: no-store`.

## Symptom guide

| Symptom | Likely cause | Check / fix |
| --- | --- | --- |
| startup says shell missing | volume hides image content, wrong build folder, custom URI mismatch, unreadable file | `ls -l` at the resolved shell path; align `/data` and `NGINX_SPA_INDEX_URI` |
| deep link is `404` | URI contains a dot, custom template replaced SPA regex, ingress rewrite mismatch | inspect request path and `nginx -T` |
| missing JS returns `200 text/html` | consumer added a broad fallback location or request never reached this origin | inspect response server/path and rendered locations |
| deep response caches for one hour | fallback internally redirects to an extensionless shell URI, which selects unversioned-static policy | use an `.html` shell plus complete cache-map override if deep-route policy must change; verify edge behavior |
| duplicate `Cache-Control` | custom location/header added another authority | retain one complete cache map/header owner |
| CORS absent on asset | asset regex does not include root CORS snippet | use a reviewed broader customization; test exact asset and error locations |
| all users share rate-limit bucket | proxy CIDRs not trusted, so peer is the load balancer | configure exact controlled CIDRs and verify logged remote address |
| canonical redirect loops | ingress host/scheme/forwarding conflicts | compare client Host, origin Host, `NGINX_FORCE_DOMAIN`, and ingress rewrite |
| deny-all robots fails on read-only root | entrypoint needs to replace bundled/default robots file | ship desired robots file or keep feature off |
| correct locally, wrong through CDN | stale edge object or CDN ignores origin cache/Vary | bypass edge, purge safely, and compare origin/edge headers |
