import { execFileSync } from "node:child_process";
import { describe, expect, it } from "vitest";
import {
  buildDependencyGraph,
  CatalogValidationError,
  getBuildClosure,
  loadCatalog,
  validateCatalog
} from "../src/index.js";
import type { ImageCatalog } from "../src/types.js";

function productionCatalog(): ImageCatalog {
  return loadCatalog();
}

function expectInvalid(input: unknown, code: string): void {
  try {
    validateCatalog(input);
  } catch (error) {
    expect(error).toBeInstanceOf(CatalogValidationError);
    expect((error as CatalogValidationError).diagnostics.map((item) => item.code)).toContain(code);
    return;
  }
  throw new Error(`expected ${code}`);
}

describe("catalog validation", () => {
  it("validates the production catalog", () => {
    const catalog = productionCatalog();
    expect(catalog.active_images.map((image) => image.id)).toEqual([
      "nextjs-base",
      "nextjs-payload",
      "nextjs-prisma",
      "nginx-base",
      "nginx-cdn",
      "nginx-core"
    ]);
  });

  it("rejects duplicate image identifiers", () => {
    const catalog = structuredClone(productionCatalog()) as ImageCatalog;
    catalog.active_images = catalog.active_images.map((image, index) => (index === 1 ? { ...image, id: catalog.active_images[0]?.id ?? image.id } : image));
    expectInvalid(catalog, "CATALOG_DUPLICATE_ID");
  });

  it("rejects missing parents and self-parenting", () => {
    const missingParent = structuredClone(productionCatalog()) as ImageCatalog;
    missingParent.active_images = missingParent.active_images.map((image) => (image.id === "nginx-core" ? { ...image, parent: "nginx-missing" } : image));
    expectInvalid(missingParent, "CATALOG_UNKNOWN_PARENT");

    const selfParent = structuredClone(productionCatalog()) as ImageCatalog;
    selfParent.active_images = selfParent.active_images.map((image) => (image.id === "nginx-core" ? { ...image, parent: image.id } : image));
    expectInvalid(selfParent, "CATALOG_SELF_PARENT");
  });

  it("rejects parent cycles", () => {
    const catalog = structuredClone(productionCatalog()) as ImageCatalog;
    catalog.active_images = catalog.active_images.map((image) => {
      if (image.id === "nginx-base") return { ...image, parent: "nginx-cdn" };
      return image;
    });
    expectInvalid(catalog, "CATALOG_PARENT_CYCLE");
  });

  it("rejects archived legacy entries tracking active releases", () => {
    const catalog = structuredClone(productionCatalog()) as ImageCatalog;
    catalog.legacy_inventory = catalog.legacy_inventory.map((item, index) => (index === 1 ? { ...item, support_status: "frozen", tracks: "nginx-base" } : item));
    expectInvalid(catalog, "CATALOG_ARCHIVED_TRACKS_ACTIVE");
  });
});

describe("catalog graph", () => {
  it("builds deterministic dependencies and closure", () => {
    const graph = buildDependencyGraph(productionCatalog());
    expect(graph.edges).toEqual([
      { from: "nextjs-base", to: "nextjs-payload" },
      { from: "nextjs-base", to: "nextjs-prisma" },
      { from: "nginx-base", to: "nginx-core" },
      { from: "nginx-core", to: "nginx-cdn" }
    ]);
    expect(graph.topologicalOrder).toEqual(["nextjs-base", "nginx-base", "nextjs-payload", "nextjs-prisma", "nginx-core", "nginx-cdn"]);
    expect(getBuildClosure(graph, ["nginx-base"])).toEqual(["nginx-base", "nginx-core", "nginx-cdn"]);
    expect(getBuildClosure(graph, ["nextjs-base"])).toEqual(["nextjs-base", "nextjs-payload", "nextjs-prisma"]);
  });
});

describe("catalog CLI", () => {
  it("prints graph JSON to stdout only", () => {
    const output = execFileSync("pnpm", ["--silent", "--filter", "@gecut/container-catalog", "cli", "graph"], {
      cwd: process.cwd(),
      encoding: "utf8"
    });
    const graph = JSON.parse(output) as { edges: unknown[] };
    expect(graph.edges).toHaveLength(4);
  });
});
