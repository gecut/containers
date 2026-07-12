import { readFileSync, rmSync, writeFileSync } from "node:fs";
import type { ImageCatalog } from "@gecut/container-catalog";
import type { ReleasePlan, ReleaseRepository } from "./types.js";
import { renderChangelogEntry } from "./changelog.js";

export function applyReleasePlan(plan: ReleasePlan, catalog: ImageCatalog, repository: ReleaseRepository = {
  writeFile: (path, content) => writeFileSync(path, content),
  removeFile: (path) => rmSync(path)
}) {
  repository.writeFile(`release/plans/${plan.releaseId}.json`, `${JSON.stringify(plan, null, 2)}\n`);

  if (plan.channel !== "stable") {
    return { updatedImages: plan.images.map((image) => image.id), consumedFragments: [] };
  }

  for (const imagePlan of plan.images) {
    const image = catalog.active_images.find((item) => item.id === imagePlan.id);
    if (!image) continue;
    const existing = readFileSync(image.documentation_target.replace(/README\.md$/, "CHANGELOG.md"), "utf8");
    repository.writeFile(image.documentation_target.replace(/README\.md$/, "CHANGELOG.md"), `${existing.trimEnd()}\n\n${renderChangelogEntry(plan, imagePlan)}`);
  }

  for (const filename of plan.fragments) {
    if (filename.endsWith(".yaml") || filename.endsWith(".yml")) {
      repository.removeFile(`.changes/images/${filename}`);
    }
  }

  return { updatedImages: plan.images.map((image) => image.id), consumedFragments: plan.fragments };
}
