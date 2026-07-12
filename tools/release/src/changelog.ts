import type { ReleaseImagePlan, ReleasePlan } from "./types.js";

export function renderChangelogEntry(plan: ReleasePlan, image: ReleaseImagePlan): string {
  const lines = [
    `## ${image.nextVersion}`,
    "",
    `Release plan: ${plan.releaseId}`,
    `Effective bump: ${image.effectiveBump}`,
    `Reason: ${image.reasons.join(", ")}`,
    ""
  ];
  return `${lines.join("\n")}\n`;
}
