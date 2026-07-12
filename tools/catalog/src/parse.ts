import { parseDocument, YAMLMap } from "yaml";
import type { CatalogDiagnostic } from "./types.js";
import { CatalogValidationError } from "./types.js";

export function parseCatalogYaml(source: string, sourceName = "catalog/images.yaml"): unknown {
  const document = parseDocument(source, {
    prettyErrors: false,
    uniqueKeys: true
  });

  const diagnostics: CatalogDiagnostic[] = [];
  for (const error of document.errors) {
    diagnostics.push({
      code: "CATALOG_YAML_PARSE",
      path: sourceName,
      message: error.message
    });
  }

  if (diagnostics.length > 0) {
    throw new CatalogValidationError(diagnostics);
  }

  const value = document.toJSON();
  if (!(document.contents instanceof YAMLMap) || value === null || typeof value !== "object") {
    throw new CatalogValidationError([
      {
        code: "CATALOG_ROOT_OBJECT",
        path: sourceName,
        message: "catalog root must be a YAML mapping"
      }
    ]);
  }

  return value;
}
