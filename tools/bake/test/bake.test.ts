import { describe, expect, it } from "vitest";
import { loadCatalog } from "@gecut/container-catalog";
import { checkBakeDrift, createBuildPlan, generateBakeFile, resolveChangedImages } from "../src/index.js";

describe("bake generation", () => {
  it("generates deterministic HCL", () => {
    const catalog = loadCatalog();
    expect(generateBakeFile(catalog)).toBe(generateBakeFile(catalog));
    expect(generateBakeFile(catalog)).toContain('target "nginx-base"');
    expect(generateBakeFile(catalog)).not.toContain("with-prisma");
  });

  it("detects drift", () => {
    const expected = generateBakeFile(loadCatalog());
    expect(checkBakeDrift(expected, expected).ok).toBe(true);
    expect(checkBakeDrift(expected, `${expected}\n`).ok).toBe(false);
  });
});

describe("build planning", () => {
  it("maps changed paths to image roots", () => {
    expect(resolveChangedImages(loadCatalog(), ["nginx/core/Dockerfile"])).toEqual(["nginx-core"]);
  });

  it("forces full matrix for global inputs", () => {
    expect(resolveChangedImages(loadCatalog(), ["catalog/images.yaml"])).toEqual([
      "nextjs-base",
      "nextjs-payload",
      "nextjs-prisma",
      "nginx-base",
      "nginx-cdn",
      "nginx-core"
    ]);
  });

  it("includes transitive dependents for changed parent images", () => {
    const plan = createBuildPlan(loadCatalog(), { mode: "changed", changedPaths: ["nginx/base/Dockerfile"] });
    expect(plan.targets).toEqual(["nginx-base", "nginx-core", "nginx-cdn"]);
    expect(plan.stages).toEqual([["nginx-base"], ["nginx-core"], ["nginx-cdn"]]);
  });

  it("creates full and release plans", () => {
    expect(createBuildPlan(loadCatalog(), { mode: "full" }).targets).toHaveLength(6);
    expect(createBuildPlan(loadCatalog(), { mode: "release", releaseImages: ["nextjs-base"] }).targets).toEqual([
      "nextjs-base",
      "nextjs-payload",
      "nextjs-prisma"
    ]);
  });
});
