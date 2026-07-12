import type { BumpType, AggregatedChanges } from "./types.js";
import type { LoadedFragment } from "@gecut/container-changes";
import { compareBump } from "./semver.js";

export function aggregateFragments(fragments: readonly LoadedFragment[]): AggregatedChanges {
  const releaseFragments = fragments.filter((item) => item.fragment.type === "release");
  const byImage = new Map<string, { bump: BumpType; reasons: string[]; breakingNotes: string[] }>();

  for (const loaded of releaseFragments) {
    if (loaded.fragment.type !== "release") continue;
    for (const [imageId, bump] of Object.entries(loaded.fragment.images)) {
      const existing = byImage.get(imageId);
      byImage.set(imageId, {
        bump: compareBump(existing?.bump ?? null, bump) as BumpType,
        reasons: [...(existing?.reasons ?? []), loaded.filename].sort(),
        breakingNotes: [...(existing?.breakingNotes ?? []), ...(loaded.fragment.breaking_notes?.[imageId] ? [loaded.fragment.breaking_notes[imageId]] : [])].sort()
      });
    }
  }

  return {
    releaseFragments,
    changes: [...byImage.entries()]
      .map(([imageId, value]) => ({
        imageId,
        requestedBump: value.bump,
        reasons: value.reasons,
        breakingNotes: value.breakingNotes
      }))
      .sort((left, right) => left.imageId.localeCompare(right.imageId))
  };
}
