# containers

Container images and base runtimes for the Gecut stack.

## NGINX Stack

- [NGINX Architecture Index](./nginx/README.md)
- [NGINX Base](./nginx/base/README.md)
- [NGINX Core](./nginx/core/README.md)
- [NGINX CDN](./nginx/cdn/README.md)

## Next.js Stack

- [Next.js Base](./nextjs/base/README.md)
- [Next.js Prisma](./nextjs/prisma/README.md)
- [Next.js Payload](./nextjs/payload/README.md)

## Catalog Tooling

The image catalog source of truth is [`catalog/images.yaml`](./catalog/images.yaml). Local automation exposes a TypeScript API and CLI from `tools/catalog`.

```bash
pnpm install
pnpm catalog:validate
pnpm catalog:normalize
pnpm catalog:graph
```

`normalize` and `graph` are generated views written to stdout only; their outputs are not committed.
