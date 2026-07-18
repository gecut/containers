# NGINX CDN diagnostics

Diagnose from the observable request and the entrypoint stage that owns it.

## Fast triage

1. Capture the exact URL, method, Host, Accept, Accept-Encoding, status, and response headers.
2. Confirm which image reference/digest is running.
3. Read container logs from the first entrypoint error.
4. Render the effective config through the real entrypoint.
5. Verify representative files exist and are readable in `/data`.
6. Compare origin behavior directly before involving the external CDN.

## Inspect startup and rendered configuration

```sh
docker run --rm ghcr.io/gecut/nginx/cdn:2.0.0 nginx -T
```

With the same environment and content mount as production:

```sh
docker run --rm \
  --env-file ./cdn.env \
  --mount type=bind,src="$PWD/public",dst=/data,readonly \
  ghcr.io/gecut/nginx/cdn:2.0.0 nginx -T
```

This executes validation and envsubst before `nginx -T`. Do not run a host NGINX against raw `.template` files and call that equivalent.

Entrypoint prefixes identify the failing phase:

| Prefix | Likely cause |
| --- | --- |
| `19-validate-env.sh` | Unsupported enum, malformed number/path/header, unsafe policy string |
| `20-envsubst-on-templates.sh` | Missing matching variables, unwritable output, template traversal/mount problem |
| `21-real-ip-trusted-proxies.sh` | Trusted proxy is not an explicit CIDR |
| `22-resolver.sh` | `local` requested but none detected, or malformed resolver |
| `30-copy-default-data.sh` | Usually informational; read-only document roots skip defaults |
| `40-disallow-robots.sh` | Robots replacement requested on unwritable root |
| `99-validate-nginx.sh` | Rendered NGINX syntax or directive value is invalid |

## Verify the origin

Resolve `SKILL_ROOT` to the installed directory containing this skill's
`SKILL.md`, then run the bundled read-only checker against known fixtures:

```sh
"$SKILL_ROOT/scripts/verify-origin.sh" \
  --origin http://127.0.0.1:8080 \
  --hashed /assets/app-C6uTJdX2.js \
  --html / \
  --json /manifest.webmanifest \
  --service-worker /service-worker.js
```

Use `--help` for optional paths, stock-policy expectations, and customized TTL
expectations. The script performs GET/HEAD requests only, creates temporary
local header/body files, and never mutates the origin.

Manual probes:

```sh
curl -sS -D - -o /dev/null http://127.0.0.1:8080/app.abcdef12.js
curl -sS -D - -o /dev/null http://127.0.0.1:8080/missing.js
curl -sS -D - -o /dev/null -H 'Accept: image/webp' http://127.0.0.1:8080/photo.jpg
```

Count authorities, not only values:

```sh
curl -sSI http://127.0.0.1:8080/app.abcdef12.js |
  awk 'BEGIN{IGNORECASE=1} /^Cache-Control:/{n++} END{print n+0}'
```

Expected count is one for both Cache-Control and Vary.

## Symptom map

### Hashed asset is not immutable

- Check the exact filename against the classifier, including case, separator, token length, and extension.
- Confirm the response is 2xx/3xx; 4xx/5xx intentionally override with `no-store`.
- Confirm the request is GET or HEAD.
- Inspect effective `NGINX_CDN_CACHE_HASHED` and `NGINX_CDN_S_MAXAGE`.

### Mutable file became immutable

- The heuristic may have mistaken a human suffix for a fingerprint.
- Rename the asset using a controlled content-hash convention or replace the URI classifier.
- Purge the downstream CDN if the incorrect response was already stored.

### Missing asset is cached

- Origin expectation is 404 plus `Cache-Control: no-store`.
- If origin is correct, inspect CDN override rules, negative caching, and cached historical responses.
- Verify through an origin-bypass hostname or direct port before changing NGINX.

### Duplicate Cache-Control or Vary

- Search custom templates for `add_header Cache-Control`, `add_header Vary`, and `expires`.
- Keep the CDN HTTP-level maps as the sole authority.
- Keep `NGINX_GZIP_VARY=off`; explicit CDN Vary already includes Accept-Encoding.

### WebP is not served

- Set `NGINX_AUTO_WEBP=on`.
- Ensure the alternate is named by appending `.webp`, such as `photo.jpg.webp`.
- Send `Accept: image/webp`.
- Inspect `nginx -T` for the WebP map and location; the feature-off script removes both.

### CORS missing on JPEG/PNG

- The stock WebP regex location bypasses the root CORS include.
- Verify whether the request selected that regex location.
- Replace the location with an explicit combined policy if the product needs CORS and WebP together.

### Wrong client IP

- Real-IP rewriting is off until trusted CIDRs are configured.
- Set only actual proxy CIDRs and the exact header the proxy controls.
- Check the JSON access log’s `remote_addr` and forwarded header separately.

### Healthcheck fails with forced domain

- Confirm `NGINX_FORCE_DOMAIN` is a hostname without scheme or port.
- Confirm `/server-info` remains reachable with that Host.
- Inspect canonical redirect configuration and container logs.

## Separate origin from edge behavior

When direct-origin headers are correct but users see stale/wrong content, collect:

- CDN cache status/age headers;
- cache-key inputs: host, path, query, encoding, and Accept;
- provider TTL override and negative-cache rules;
- last purge/invalidation result;
- origin digest and asset filename deployed in each region.

Do not “fix” correct origin headers to compensate for an unidentified provider rule.
