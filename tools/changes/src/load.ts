import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { loadCatalog } from "@gecut/container-catalog";
import { parseChangeFragment, validateChangeFragment } from "./validate.js";
import type { FragmentValidationContext, LoadedFragment } from "./types.js";
import { FragmentValidationError } from "./types.js";

export function loadChangeFragments(directory = ".changes/images", context: FragmentValidationContext = { catalog: loadCatalog() }): readonly LoadedFragment[] {
  if (!existsSync(directory)) {
    return [];
  }

  const diagnostics = [];
  const fragments: LoadedFragment[] = [];
  const filenames = readdirSync(directory).filter((filename) => /\.ya?ml$/.test(filename)).sort();
  for (const filename of filenames) {
    const path = join(directory, filename);
    if (!statSync(path).isFile()) {
      continue;
    }
    try {
      const parsed = parseChangeFragment(readFileSync(path, "utf8"), filename);
      fragments.push({ filename, path, fragment: validateChangeFragment(parsed, context, basename(filename)) });
    } catch (error) {
      if (error instanceof FragmentValidationError) {
        diagnostics.push(...error.diagnostics);
      } else {
        diagnostics.push({ code: "FRAGMENT_READ", path, message: error instanceof Error ? error.message : String(error) });
      }
    }
  }

  if (diagnostics.length > 0) {
    throw new FragmentValidationError(diagnostics);
  }

  return fragments;
}
