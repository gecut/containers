import type { ReleasePlan, VerificationResult } from "./types.js";

export function verifyReleasePlan(plan: ReleasePlan): VerificationResult {
  const errors: string[] = [];
  if (plan.schemaVersion !== 1) errors.push("unsupported release plan schema");
  if (!/^(stable|next|rc)-[a-f0-9]{16}$/.test(plan.releaseId)) errors.push("invalid release id");
  if (!["stable", "next", "rc"].includes(plan.channel)) errors.push("invalid release channel");
  const ids = new Set<string>();
  for (const image of plan.images) {
    if (ids.has(image.id)) errors.push(`duplicate image in plan: ${image.id}`);
    ids.add(image.id);
    if (image.previousVersion === image.nextVersion) errors.push(`image version did not change: ${image.id}`);
    if (plan.channel === "stable" && image.nextVersion.includes("-")) errors.push(`stable image has prerelease version: ${image.id}`);
    if (plan.channel !== "stable" && !image.nextVersion.includes(`-${plan.channel}.`)) errors.push(`prerelease image missing channel suffix: ${image.id}`);
  }
  return { ok: errors.length === 0, errors };
}
