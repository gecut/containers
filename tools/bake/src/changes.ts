import type { ImageCatalog, ImageId } from "@gecut/container-catalog";

function matchesPattern(path: string, pattern: string): boolean {
  if (pattern.endsWith("/**")) {
    return path === pattern.slice(0, -3) || path.startsWith(pattern.slice(0, -2));
  }
  return path === pattern;
}

export function resolveChangedImages(catalog: ImageCatalog, changedPaths: readonly string[]): readonly ImageId[] {
  const fullMatrixInputs = catalog.build_policy?.full_matrix_inputs ?? [];
  if (changedPaths.some((path) => fullMatrixInputs.some((pattern) => matchesPattern(path, pattern)))) {
    return catalog.active_images.map((image) => image.id);
  }

  const roots = new Set<ImageId>();
  for (const path of changedPaths) {
    for (const image of catalog.active_images) {
      const patterns = image.build_inputs ?? [`${image.source_context}/**`];
      if (patterns.some((pattern) => matchesPattern(path, pattern))) {
        roots.add(image.id);
      }
    }
  }
  return [...roots].sort();
}
