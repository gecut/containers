import { z } from "zod";

const recordSchema = z.record(z.string(), z.unknown());

export const registrySchema = z.object({
  host: z.string().min(1),
  enabled: z.boolean(),
  publication: z.string().optional(),
  compatibility: z.string().optional()
});

export const catalogImageSchema = z.object({
  id: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  family: z.string().min(1),
  variant: z.string().min(1),
  canonical_oci_name: z.string().min(1),
  canonical_ghcr_path: z.string().min(1),
  source_context: z.string().min(1),
  dockerfile: z.string().min(1),
  role: z.string().min(1),
  ownership_boundary: z.string().min(1),
  parent: z.string().nullable(),
  initial_version: z.string().regex(/^\d+\.\d+\.\d+$/),
  current_version: z.string().regex(/^\d+\.\d+\.\d+$/),
  platforms: z.array(z.string().min(1)).nonempty(),
  support_status: z.literal("active"),
  publication_registry: z.enum(["ghcr", "docker_hub"]),
  aliases: z.array(z.string()),
  documentation_target: z.string().min(1),
  consumer_skill_target: z.string().min(1),
  compatibility: recordSchema,
  tag_policy: recordSchema,
  build_inputs: z.array(z.string()).optional()
});

export const legacyInventoryItemSchema = z.object({
  name: z.string().min(1),
  kind: z.string().min(1),
  support_status: z.enum(["active-alias", "frozen", "archived-pullable"]),
  tracks: z.string().nullable(),
  evidence: z.array(z.string().min(1)).nonempty(),
  policy: z.string().optional()
});

export const imageCatalogSchema = z.object({
  schema_version: z.literal(1),
  contract_issue: z.string().min(1),
  source_of_truth: z.string().min(1),
  publication_policy: recordSchema,
  canonical_naming: recordSchema,
  platforms: z.object({
    active: z.array(z.string()).nonempty()
  }),
  compatibility_policy: recordSchema.optional(),
  tag_policy: recordSchema.optional(),
  registries: z.record(z.string(), registrySchema),
  active_images: z.array(catalogImageSchema).nonempty(),
  legacy_inventory: z.array(legacyInventoryItemSchema),
  registry_inventory_gaps: z.array(recordSchema).optional(),
  out_of_scope: z.array(z.string()).optional()
});
