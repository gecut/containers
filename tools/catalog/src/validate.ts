import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { imageCatalogSchema } from "./schema.js";
import { buildDependencyGraph } from "./graph.js";
import { normalizeCatalog } from "./normalize.js";
import type { CatalogDiagnostic, ImageCatalog, ImageId } from "./types.js";
import { CatalogValidationError } from "./types.js";

function duplicateDiagnostics(values: readonly string[], path: string, code: string, label: string): CatalogDiagnostic[] {
  const seen = new Set<string>();
  const duplicates = new Set<string>();
  for (const value of values) {
    if (seen.has(value)) {
      duplicates.add(value);
    }
    seen.add(value);
  }
  return [...duplicates].sort().map((value) => ({
    code,
    path,
    message: `duplicate ${label}: ${value}`
  }));
}

function addPathDiagnostic(
  diagnostics: CatalogDiagnostic[],
  exists: boolean,
  path: string,
  code: string,
  message: string
): void {
  if (!exists) {
    diagnostics.push({ code, path, message });
  }
}

function existsRepositoryPath(path: string): boolean {
  if (existsSync(path)) {
    return true;
  }

  let current = process.cwd();
  while (true) {
    if (existsSync(join(current, path))) {
      return true;
    }

    const parent = dirname(current);
    if (parent === current) {
      return false;
    }
    current = parent;
  }
}

function detectCycles(catalog: ImageCatalog): CatalogDiagnostic[] {
  const byId = new Map(catalog.active_images.map((image) => [image.id, image]));
  const diagnostics: CatalogDiagnostic[] = [];

  for (const image of catalog.active_images) {
    const seen = new Set<ImageId>();
    let current: ImageId | null = image.parent;
    while (current) {
      if (current === image.id || seen.has(current)) {
        diagnostics.push({
          code: "CATALOG_PARENT_CYCLE",
          path: `active_images.${image.id}.parent`,
          message: `parent chain for ${image.id} contains a cycle`
        });
        break;
      }
      seen.add(current);
      current = byId.get(current)?.parent ?? null;
    }
  }

  return diagnostics;
}

export function validateCatalog(input: unknown): ImageCatalog {
  const parsed = imageCatalogSchema.safeParse(input);
  const diagnostics: CatalogDiagnostic[] = [];

  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      diagnostics.push({
        code: "CATALOG_SCHEMA",
        path: issue.path.length > 0 ? issue.path.join(".") : "catalog",
        message: issue.message
      });
    }
    throw new CatalogValidationError(diagnostics);
  }

  const catalog = parsed.data as ImageCatalog;
  const active = catalog.active_images;
  const activeIds = new Set(active.map((image) => image.id));
  const activeCanonicalNames = new Set(active.map((image) => image.canonical_oci_name));
  const legacyNames = new Set(catalog.legacy_inventory.map((item) => item.name));

  diagnostics.push(...duplicateDiagnostics(active.map((image) => image.id), "active_images[].id", "CATALOG_DUPLICATE_ID", "image id"));
  diagnostics.push(
    ...duplicateDiagnostics(
      active.map((image) => image.canonical_oci_name),
      "active_images[].canonical_oci_name",
      "CATALOG_DUPLICATE_CANONICAL_NAME",
      "canonical OCI name"
    )
  );
  diagnostics.push(
    ...duplicateDiagnostics(
      active.map((image) => image.canonical_ghcr_path),
      "active_images[].canonical_ghcr_path",
      "CATALOG_DUPLICATE_GHCR_PATH",
      "canonical GHCR path"
    )
  );
  diagnostics.push(
    ...duplicateDiagnostics(
      active.map((image) => image.source_context),
      "active_images[].source_context",
      "CATALOG_DUPLICATE_CONTEXT",
      "source context"
    )
  );
  diagnostics.push(
    ...duplicateDiagnostics(
      active.map((image) => image.dockerfile),
      "active_images[].dockerfile",
      "CATALOG_DUPLICATE_DOCKERFILE",
      "Dockerfile"
    )
  );

  for (const [index, image] of active.entries()) {
    const path = `active_images[${index}]`;
    const expectedName = `gecut/${image.family}/${image.variant}`;
    const expectedGhcr = `ghcr.io/${expectedName}`;

    if (image.canonical_oci_name !== expectedName) {
      diagnostics.push({
        code: "CATALOG_CANONICAL_NAME",
        path: `${path}.canonical_oci_name`,
        message: `expected ${expectedName}`
      });
    }
    if (image.canonical_ghcr_path !== expectedGhcr) {
      diagnostics.push({
        code: "CATALOG_GHCR_PATH",
        path: `${path}.canonical_ghcr_path`,
        message: `expected ${expectedGhcr}`
      });
    }
    if (image.initial_version !== "1.0.0") {
      diagnostics.push({
        code: "CATALOG_INITIAL_VERSION",
        path: `${path}.initial_version`,
        message: "active images must retain initial_version 1.0.0"
      });
    }
    if (image.parent === image.id) {
      diagnostics.push({
        code: "CATALOG_SELF_PARENT",
        path: `${path}.parent`,
        message: `${image.id} cannot be its own parent`
      });
    } else if (image.parent && !activeIds.has(image.parent)) {
      diagnostics.push({
        code: "CATALOG_UNKNOWN_PARENT",
        path: `${path}.parent`,
        message: `${image.parent} is not a declared active image`
      });
    }
    if (!catalog.registries[image.publication_registry]?.enabled) {
      diagnostics.push({
        code: "CATALOG_DISABLED_REGISTRY",
        path: `${path}.publication_registry`,
        message: `${image.publication_registry} is not an enabled publication registry`
      });
    }
    for (const platform of image.platforms) {
      if (!catalog.platforms.active.includes(platform)) {
        diagnostics.push({
          code: "CATALOG_UNKNOWN_PLATFORM",
          path: `${path}.platforms`,
          message: `${platform} is not listed in platforms.active`
        });
      }
    }
    for (const alias of image.aliases) {
      if (activeIds.has(alias) || activeCanonicalNames.has(alias) || legacyNames.has(alias)) {
        diagnostics.push({
          code: "CATALOG_INVALID_ALIAS",
          path: `${path}.aliases`,
          message: `${alias} conflicts with an active or legacy inventory identifier`
        });
      }
    }

    addPathDiagnostic(diagnostics, existsRepositoryPath(image.source_context), `${path}.source_context`, "CATALOG_MISSING_CONTEXT", `${image.source_context} does not exist`);
    addPathDiagnostic(diagnostics, existsRepositoryPath(image.dockerfile), `${path}.dockerfile`, "CATALOG_MISSING_DOCKERFILE", `${image.dockerfile} does not exist`);
    addPathDiagnostic(
      diagnostics,
      existsRepositoryPath(image.documentation_target),
      `${path}.documentation_target`,
      "CATALOG_MISSING_DOCUMENTATION",
      `${image.documentation_target} does not exist`
    );
  }

  for (const [index, item] of catalog.legacy_inventory.entries()) {
    if (item.support_status !== "active-alias" && item.tracks !== null) {
      diagnostics.push({
        code: "CATALOG_ARCHIVED_TRACKS_ACTIVE",
        path: `legacy_inventory[${index}].tracks`,
        message: "frozen and archived items must not track active image releases"
      });
    }
    if (item.tracks && !activeIds.has(item.tracks)) {
      diagnostics.push({
        code: "CATALOG_LEGACY_UNKNOWN_TRACK",
        path: `legacy_inventory[${index}].tracks`,
        message: `${item.tracks} is not an active image`
      });
    }
  }

  diagnostics.push(...detectCycles(catalog));

  if (diagnostics.length > 0) {
    throw new CatalogValidationError(diagnostics);
  }

  buildDependencyGraph(catalog);
  return normalizeCatalog(catalog);
}
