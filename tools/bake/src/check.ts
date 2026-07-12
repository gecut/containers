export function checkBakeDrift(expected: string, committed: string) {
  return expected === committed
    ? { ok: true, message: "docker-bake.hcl is current" }
    : { ok: false, message: "docker-bake.hcl is stale; run pnpm bake:generate" };
}
