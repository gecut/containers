import type { ImageCatalog } from "./types.js";

function sortRecord<T>(input: Record<string, T>): Record<string, T> {
  return Object.fromEntries(Object.entries(input).sort(([left], [right]) => left.localeCompare(right)));
}

export function normalizeCatalog(catalog: ImageCatalog): ImageCatalog {
  return {
    ...catalog,
    registries: sortRecord(catalog.registries),
    active_images: [...catalog.active_images]
      .map((image) => ({
        ...image,
        aliases: [...image.aliases].sort(),
        platforms: [...image.platforms].sort(),
        build_inputs: image.build_inputs ? [...image.build_inputs].sort() : undefined
      }))
      .sort((left, right) => left.id.localeCompare(right.id)),
    legacy_inventory: [...catalog.legacy_inventory]
      .map((item) => ({ ...item, evidence: [...item.evidence].sort() }))
      .sort((left, right) => left.name.localeCompare(right.name))
  };
}
