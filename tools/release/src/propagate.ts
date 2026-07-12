import { buildDependencyGraph, getBuildClosure } from "@gecut/container-catalog";
import type { ImageCatalog, ImageId } from "@gecut/container-catalog";
import type { BumpType } from "./types.js";
import { compareBump } from "./semver.js";

export function propagateBumps(catalog: ImageCatalog, requested: ReadonlyMap<ImageId, BumpType>): Map<ImageId, BumpType> {
  const graph = buildDependencyGraph(catalog);
  const effective = new Map<ImageId, BumpType>();

  for (const [imageId, bump] of requested) {
    const closure = getBuildClosure(graph, [imageId]);
    for (const closureImage of closure) {
      const inherited: BumpType = closureImage === imageId ? bump : "patch";
      effective.set(closureImage, compareBump(effective.get(closureImage) ?? null, inherited) as BumpType);
    }
  }

  return effective;
}
