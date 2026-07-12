import { createHash } from "node:crypto";
import { buildDependencyGraph } from "@gecut/container-catalog";
import { aggregateFragments } from "./aggregate.js";
import { propagateBumps } from "./propagate.js";
import { bumpVersion, prereleaseVersion } from "./semver.js";
import type { ReleaseImagePlan, ReleasePlan, ReleasePlanningInput } from "./types.js";

function stableJson(value: unknown): string {
  return JSON.stringify(value, (_key, inner) => {
    if (inner && typeof inner === "object" && !Array.isArray(inner)) {
      return Object.fromEntries(Object.entries(inner as Record<string, unknown>).sort(([left], [right]) => left.localeCompare(right)));
    }
    return inner;
  });
}

function hash(value: unknown): string {
  return createHash("sha256").update(stableJson(value)).digest("hex");
}

function tagSet(version: string, channel: ReleasePlanningInput["channel"]) {
  if (channel === "stable") {
    const [major, minor] = version.split(".");
    return [
      { kind: "exact" as const, value: version },
      { kind: "minor" as const, value: `${major}.${minor}` },
      { kind: "major" as const, value: major },
      { kind: "latest" as const, value: "latest" },
      { kind: "sha" as const }
    ];
  }
  return [
    { kind: "exact" as const, value: version },
    { kind: "channel" as const, value: channel },
    { kind: "sha" as const }
  ];
}

function nextPrereleaseCounter(input: ReleasePlanningInput, imageIds: readonly string[]): number {
  const matching = (input.priorPlans ?? []).filter((plan) => plan.channel === input.channel && plan.images.some((image) => imageIds.includes(image.id)));
  return matching.length + 1;
}

export function planRelease(input: ReleasePlanningInput): ReleasePlan {
  const aggregated = aggregateFragments(input.fragments);
  const requested = new Map(aggregated.changes.map((change) => [change.imageId, change.requestedBump]));
  const effective = propagateBumps(input.catalog, requested);
  const graph = buildDependencyGraph(input.catalog);
  const fragmentNames = input.fragments.map((fragment) => fragment.filename).sort();
  const releaseIds = graph.topologicalOrder.filter((id) => effective.has(id));
  const prereleaseCounter = input.channel === "stable" ? 0 : nextPrereleaseCounter(input, releaseIds);

  const images: ReleaseImagePlan[] = releaseIds.map((id) => {
    const image = input.catalog.active_images.find((item) => item.id === id);
    if (!image) throw new Error(`unknown image id in release plan: ${id}`);
    const effectiveBump = effective.get(id);
    if (!effectiveBump) throw new Error(`missing effective bump for ${id}`);
    const stableNext = bumpVersion(image.current_version, effectiveBump);
    const nextVersion = input.channel === "stable" ? stableNext : prereleaseVersion(stableNext, input.channel, prereleaseCounter);
    const explicit = aggregated.changes.find((change) => change.imageId === id);
    return {
      id,
      previousVersion: image.current_version,
      nextVersion,
      requestedBump: explicit?.requestedBump ?? null,
      effectiveBump,
      reasons: explicit?.reasons ?? ["parent-change"],
      tags: tagSet(nextVersion, input.channel),
      aliases: image.aliases
    };
  });

  const inputHash = hash({ channel: input.channel, fragments: input.fragments.map((fragment) => ({ filename: fragment.filename, fragment: fragment.fragment })), images });
  const releaseId = `${input.channel}-${inputHash.slice(0, 16)}`;

  return {
    schemaVersion: 1,
    releaseId,
    channel: input.channel,
    inputHash,
    catalogHash: hash(input.catalog),
    fragments: fragmentNames,
    images
  };
}
