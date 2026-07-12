import type { ImageCatalog, ImageId } from "@gecut/container-catalog";

export type ChangeType = "release" | "documentation" | "no-release";
export type BumpType = "patch" | "minor" | "major";

export interface FragmentDiagnostic {
  code: string;
  path: string;
  message: string;
}

export class FragmentValidationError extends Error {
  readonly diagnostics: readonly FragmentDiagnostic[];

  constructor(diagnostics: readonly FragmentDiagnostic[]) {
    super(diagnostics.map((item) => `${item.path} [${item.code}]: ${item.message}`).join("\n"));
    this.name = "FragmentValidationError";
    this.diagnostics = diagnostics;
  }
}

export interface FragmentValidationContext {
  catalog: ImageCatalog;
}

export interface BaseChangeFragment {
  schema_version: 1;
  type: ChangeType;
  summary: string;
}

export interface ReleaseChangeFragment extends BaseChangeFragment {
  type: "release";
  images: Record<ImageId, BumpType>;
  breaking_notes?: Record<ImageId, string>;
}

export interface DocumentationChangeFragment extends BaseChangeFragment {
  type: "documentation";
}

export interface NoReleaseChangeFragment extends BaseChangeFragment {
  type: "no-release";
}

export type ChangeFragment = ReleaseChangeFragment | DocumentationChangeFragment | NoReleaseChangeFragment;

export interface LoadedFragment {
  filename: string;
  path: string;
  fragment: ChangeFragment;
}
