import { existsSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { parseCatalogYaml } from "./parse.js";
import { validateCatalog } from "./validate.js";

export { buildDependencyGraph, getBuildClosure } from "./graph.js";
export { normalizeCatalog } from "./normalize.js";
export { parseCatalogYaml } from "./parse.js";
export { validateCatalog } from "./validate.js";
export type {
  CatalogDiagnostic,
  CatalogImage,
  DependencyGraph,
  DependencyGraphEdge,
  DependencyGraphNode,
  ImageCatalog,
  ImageId,
  LegacyInventoryItem
} from "./types.js";
export { CatalogValidationError } from "./types.js";

function resolveCatalogPath(path: string): string {
  if (isAbsolute(path) || existsSync(path)) {
    return path;
  }

  let current = process.cwd();
  while (true) {
    const candidate = join(current, path);
    if (existsSync(candidate)) {
      return candidate;
    }

    const parent = dirname(current);
    if (parent === current) {
      return resolve(path);
    }
    current = parent;
  }
}

export function loadCatalog(path = "catalog/images.yaml") {
  const resolvedPath = resolveCatalogPath(path);
  return validateCatalog(parseCatalogYaml(readFileSync(resolvedPath, "utf8"), resolvedPath));
}
