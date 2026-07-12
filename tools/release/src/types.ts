import type { ImageCatalog, ImageId } from "@gecut/container-catalog";
import type { LoadedFragment } from "@gecut/container-changes";

export type ReleaseChannel = "stable" | "next" | "rc";
export type BumpType = "patch" | "minor" | "major";

export interface AggregatedChange {
  imageId: ImageId;
  requestedBump: BumpType;
  reasons: readonly string[];
  breakingNotes: readonly string[];
}

export interface AggregatedChanges {
  releaseFragments: readonly LoadedFragment[];
  changes: readonly AggregatedChange[];
}

export interface ReleasePlanningInput {
  catalog: ImageCatalog;
  fragments: readonly LoadedFragment[];
  channel: ReleaseChannel;
  priorPlans?: readonly ReleasePlan[];
}

export interface ReleaseImagePlan {
  id: ImageId;
  previousVersion: string;
  nextVersion: string;
  requestedBump: BumpType | null;
  effectiveBump: BumpType;
  reasons: readonly string[];
  tags: readonly ReleaseTag[];
  aliases: readonly string[];
}

export interface ReleaseTag {
  kind: "exact" | "minor" | "major" | "latest" | "sha" | "channel";
  value?: string;
}

export interface ReleasePlan {
  schemaVersion: 1;
  releaseId: string;
  channel: ReleaseChannel;
  inputHash: string;
  catalogHash: string;
  fragments: readonly string[];
  images: readonly ReleaseImagePlan[];
}

export interface VerificationResult {
  ok: boolean;
  errors: readonly string[];
}

export interface ReleasePrContent {
  title: string;
  body: string;
}

export interface ReleasePrClient {
  upsert(input: UpsertReleasePrInput): Promise<ReleasePrResult>;
}

export interface UpsertReleasePrInput {
  base: string;
  head: string;
  draft: boolean;
  content: ReleasePrContent;
}

export interface ReleasePrResult {
  url: string;
  number: number;
}

export interface ReleaseRepository {
  writeFile(path: string, content: string): void;
  removeFile(path: string): void;
}
