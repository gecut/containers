export type ImageId = string;

export type RegistryId = "ghcr" | "docker_hub";

export interface CatalogDiagnostic {
  code: string;
  path: string;
  message: string;
}

export class CatalogValidationError extends Error {
  readonly diagnostics: readonly CatalogDiagnostic[];

  constructor(diagnostics: readonly CatalogDiagnostic[]) {
    super(diagnostics.map((item) => `${item.path} [${item.code}]: ${item.message}`).join("\n"));
    this.name = "CatalogValidationError";
    this.diagnostics = diagnostics;
  }
}

export interface ImageCatalog {
  schema_version: number;
  contract_issue: string;
  source_of_truth: string;
  publication_policy: Record<string, unknown>;
  canonical_naming: Record<string, unknown>;
  platforms: {
    active: readonly string[];
  };
  registries: Record<string, Registry>;
  active_images: readonly CatalogImage[];
  legacy_inventory: readonly LegacyInventoryItem[];
  registry_inventory_gaps?: readonly Record<string, unknown>[];
  out_of_scope?: readonly string[];
}

export interface Registry {
  host: string;
  enabled: boolean;
  publication?: string;
  compatibility?: string;
}

export interface CatalogImage {
  id: ImageId;
  family: string;
  variant: string;
  canonical_oci_name: string;
  canonical_ghcr_path: string;
  source_context: string;
  dockerfile: string;
  role: string;
  ownership_boundary: string;
  parent: ImageId | null;
  initial_version: string;
  current_version: string;
  platforms: readonly string[];
  support_status: "active";
  publication_registry: RegistryId;
  aliases: readonly string[];
  documentation_target: string;
  consumer_skill_target: string;
  compatibility: Record<string, unknown>;
  tag_policy: Record<string, unknown>;
  build_inputs?: readonly string[];
}

export interface LegacyInventoryItem {
  name: string;
  kind: string;
  support_status: "active-alias" | "frozen" | "archived-pullable";
  tracks: ImageId | null;
  evidence: readonly string[];
  policy?: string;
}

export interface DependencyGraphNode {
  id: ImageId;
  parent: ImageId | null;
  directDependencies: readonly ImageId[];
  directDependents: readonly ImageId[];
  transitiveDependencies: readonly ImageId[];
  transitiveDependents: readonly ImageId[];
}

export interface DependencyGraphEdge {
  from: ImageId;
  to: ImageId;
}

export interface DependencyGraph {
  nodes: readonly DependencyGraphNode[];
  edges: readonly DependencyGraphEdge[];
  topologicalOrder: readonly ImageId[];
}
