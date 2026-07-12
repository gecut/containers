import { parseDocument, YAMLMap } from "yaml";
import { changeFragmentSchema } from "./schema.js";
import type { ChangeFragment, FragmentDiagnostic, FragmentValidationContext } from "./types.js";
import { FragmentValidationError } from "./types.js";
import { validateFragmentFilename } from "./naming.js";

export function parseChangeFragment(source: string, filename: string): unknown {
  const document = parseDocument(source, {
    prettyErrors: false,
    uniqueKeys: true
  });
  const diagnostics: FragmentDiagnostic[] = [];
  for (const error of document.errors) {
    diagnostics.push({
      code: "FRAGMENT_YAML_PARSE",
      path: filename,
      message: error.message
    });
  }
  if (diagnostics.length > 0) {
    throw new FragmentValidationError(diagnostics);
  }
  if (!(document.contents instanceof YAMLMap)) {
    throw new FragmentValidationError([
      { code: "FRAGMENT_ROOT_OBJECT", path: filename, message: "fragment root must be a YAML mapping" }
    ]);
  }
  return document.toJSON();
}

export function validateChangeFragment(
  input: unknown,
  context: FragmentValidationContext,
  filename = "<fragment>"
): ChangeFragment {
  const diagnostics: FragmentDiagnostic[] = [];
  try {
    validateFragmentFilename(filename);
  } catch (error) {
    diagnostics.push({
      code: "FRAGMENT_FILENAME",
      path: filename,
      message: error instanceof Error ? error.message : String(error)
    });
  }

  const parsed = changeFragmentSchema.safeParse(input);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      diagnostics.push({
        code: "FRAGMENT_SCHEMA",
        path: issue.path.length > 0 ? `${filename}.${issue.path.join(".")}` : filename,
        message: issue.message
      });
    }
    throw new FragmentValidationError(diagnostics);
  }

  const fragment = parsed.data as ChangeFragment;
  const activeIds = new Set(context.catalog.active_images.map((image) => image.id));
  const aliasNames = new Set(context.catalog.active_images.flatMap((image) => image.aliases));
  const legacyNames = new Set(context.catalog.legacy_inventory.map((item) => item.name));

  if (fragment.type === "release") {
    const imageEntries = Object.entries(fragment.images);
    if (imageEntries.length === 0) {
      diagnostics.push({ code: "FRAGMENT_EMPTY_RELEASE", path: `${filename}.images`, message: "release fragments require at least one image" });
    }

    for (const [imageId, bump] of imageEntries) {
      if (!activeIds.has(imageId)) {
        const reason = aliasNames.has(imageId) || legacyNames.has(imageId) ? "aliases and archived names are not release targets" : "unknown image id";
        diagnostics.push({ code: "FRAGMENT_UNKNOWN_IMAGE", path: `${filename}.images.${imageId}`, message: `${imageId}: ${reason}` });
      }
      const note = fragment.breaking_notes?.[imageId];
      if (bump === "major" && !note) {
        diagnostics.push({ code: "FRAGMENT_MISSING_BREAKING_NOTE", path: `${filename}.breaking_notes.${imageId}`, message: "major bumps require a breaking note" });
      }
      if (bump !== "major" && note) {
        diagnostics.push({ code: "FRAGMENT_UNEXPECTED_BREAKING_NOTE", path: `${filename}.breaking_notes.${imageId}`, message: "breaking notes are allowed only for major bumps" });
      }
    }

    for (const imageId of Object.keys(fragment.breaking_notes ?? {})) {
      if (!(imageId in fragment.images)) {
        diagnostics.push({ code: "FRAGMENT_ORPHAN_BREAKING_NOTE", path: `${filename}.breaking_notes.${imageId}`, message: "breaking note has no matching image bump" });
      }
    }
  }

  if (diagnostics.length > 0) {
    throw new FragmentValidationError(diagnostics);
  }

  return fragment;
}
