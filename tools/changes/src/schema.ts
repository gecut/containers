import { z } from "zod";

const summarySchema = z.string().trim().min(1);
const bumpSchema = z.enum(["patch", "minor", "major"]);

export const releaseFragmentSchema = z.object({
  schema_version: z.literal(1),
  type: z.literal("release"),
  summary: summarySchema,
  images: z.record(z.string(), bumpSchema),
  breaking_notes: z.record(z.string(), z.string().trim().min(1)).optional()
});

export const documentationFragmentSchema = z.object({
  schema_version: z.literal(1),
  type: z.literal("documentation"),
  summary: summarySchema
}).strict();

export const noReleaseFragmentSchema = z.object({
  schema_version: z.literal(1),
  type: z.literal("no-release"),
  summary: summarySchema
}).strict();

export const changeFragmentSchema = z.discriminatedUnion("type", [
  releaseFragmentSchema,
  documentationFragmentSchema,
  noReleaseFragmentSchema
]);
