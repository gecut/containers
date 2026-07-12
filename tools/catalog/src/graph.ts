import type { DependencyGraph, ImageCatalog, ImageId } from "./types.js";

export function buildDependencyGraph(catalog: ImageCatalog): DependencyGraph {
  const ids = catalog.active_images.map((image) => image.id).sort();
  const imageById = new Map(catalog.active_images.map((image) => [image.id, image]));
  const directDependents = new Map<ImageId, ImageId[]>(ids.map((id) => [id, []]));
  const directDependencies = new Map<ImageId, ImageId[]>(ids.map((id) => [id, []]));

  for (const image of catalog.active_images) {
    if (image.parent) {
      directDependencies.get(image.id)?.push(image.parent);
      directDependents.get(image.parent)?.push(image.id);
    }
  }

  for (const values of [...directDependencies.values(), ...directDependents.values()]) {
    values.sort();
  }

  const visitDependents = (id: ImageId, seen = new Set<ImageId>()): ImageId[] => {
    for (const child of directDependents.get(id) ?? []) {
      if (!seen.has(child)) {
        seen.add(child);
        visitDependents(child, seen);
      }
    }
    return [...seen].sort();
  };

  const visitDependencies = (id: ImageId, seen = new Set<ImageId>()): ImageId[] => {
    const parent = imageById.get(id)?.parent;
    if (parent && !seen.has(parent)) {
      seen.add(parent);
      visitDependencies(parent, seen);
    }
    return [...seen].sort();
  };

  const topologicalOrder: ImageId[] = [];
  const remaining = new Set(ids);
  while (remaining.size > 0) {
    const ready = [...remaining].filter((id) => (directDependencies.get(id) ?? []).every((dep) => !remaining.has(dep))).sort();
    if (ready.length === 0) {
      throw new Error("dependency cycle detected in validated catalog");
    }
    for (const id of ready) {
      remaining.delete(id);
      topologicalOrder.push(id);
    }
  }

  return {
    nodes: ids.map((id) => ({
      id,
      parent: imageById.get(id)?.parent ?? null,
      directDependencies: directDependencies.get(id) ?? [],
      directDependents: directDependents.get(id) ?? [],
      transitiveDependencies: visitDependencies(id),
      transitiveDependents: visitDependents(id)
    })),
    edges: catalog.active_images
      .filter((image) => image.parent)
      .map((image) => ({ from: image.parent as ImageId, to: image.id }))
      .sort((left, right) => left.from.localeCompare(right.from) || left.to.localeCompare(right.to)),
    topologicalOrder
  };
}

export function getBuildClosure(graph: DependencyGraph, changed: readonly ImageId[]): readonly ImageId[] {
  const nodeById = new Map(graph.nodes.map((node) => [node.id, node]));
  const closure = new Set<ImageId>();
  for (const id of changed) {
    const node = nodeById.get(id);
    if (!node) {
      throw new Error(`unknown image id in build closure: ${id}`);
    }
    closure.add(id);
    for (const dependent of node.transitiveDependents) {
      closure.add(dependent);
    }
  }
  return graph.topologicalOrder.filter((id) => closure.has(id));
}
