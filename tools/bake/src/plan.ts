import { buildDependencyGraph, getBuildClosure } from "@gecut/container-catalog";
import type { ImageCatalog, ImageId } from "@gecut/container-catalog";
import { resolveChangedImages } from "./changes.js";
import type { BuildPlan, BuildPlanInput } from "./types.js";

function toStages(catalog: ImageCatalog, closure: readonly ImageId[]): readonly ImageId[][] {
  const byId = new Map(catalog.active_images.map((image) => [image.id, image]));
  const depths = new Map<ImageId, number>();
  const depth = (id: ImageId): number => {
    const existing = depths.get(id);
    if (existing !== undefined) return existing;
    const parent = byId.get(id)?.parent;
    const value = parent && closure.includes(parent) ? depth(parent) + 1 : 0;
    depths.set(id, value);
    return value;
  };
  for (const id of closure) depth(id);
  return [...new Set([...depths.values()].sort((left, right) => left - right))].map((level) => closure.filter((id) => depths.get(id) === level));
}

export function createBuildPlan(catalog: ImageCatalog, input: BuildPlanInput): BuildPlan {
  const graph = buildDependencyGraph(catalog);
  const roots =
    input.mode === "full"
      ? catalog.active_images.map((image) => image.id)
      : input.mode === "release"
        ? [...(input.releaseImages ?? [])].sort()
        : input.roots ?? resolveChangedImages(catalog, input.changedPaths ?? []);
  const closure = input.mode === "full" ? graph.topologicalOrder : getBuildClosure(graph, roots);
  return {
    schemaVersion: 1,
    mode: input.mode,
    roots,
    closure,
    stages: toStages(catalog, closure),
    targets: closure
  };
}
