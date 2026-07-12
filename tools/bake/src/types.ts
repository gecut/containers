import type { ImageId } from "@gecut/container-catalog";

export type BuildPlanMode = "changed" | "full" | "release";

export interface BuildPlanInput {
  mode: BuildPlanMode;
  roots?: readonly ImageId[];
  changedPaths?: readonly string[];
  releaseImages?: readonly ImageId[];
}

export interface BuildPlan {
  schemaVersion: 1;
  mode: BuildPlanMode;
  roots: readonly ImageId[];
  closure: readonly ImageId[];
  stages: readonly ImageId[][];
  targets: readonly ImageId[];
}

export interface BakeDriftResult {
  ok: boolean;
  message: string;
}
