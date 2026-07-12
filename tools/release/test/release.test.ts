import { describe, expect, it } from "vitest";
import { loadCatalog } from "@gecut/container-catalog";
import type { LoadedFragment } from "@gecut/container-changes";
import { planRelease, renderReleasePullRequest, verifyReleasePlan } from "../src/index.js";

function fragment(filename: string, images: Record<string, "patch" | "minor" | "major">, breaking_notes?: Record<string, string>): LoadedFragment {
  return {
    filename,
    path: `.changes/images/${filename}`,
    fragment: {
      schema_version: 1,
      type: "release",
      summary: filename,
      images,
      breaking_notes
    }
  };
}

describe("release planning", () => {
  it("propagates parent patch releases to dependents", () => {
    const plan = planRelease({
      catalog: loadCatalog(),
      channel: "stable",
      fragments: [fragment("20260712T000000Z-abcdef123456-nginx-base.yaml", { "nginx-base": "minor" })]
    });
    expect(plan.images.map((image) => `${image.id}:${image.nextVersion}:${image.effectiveBump}`)).toEqual([
      "nginx-base:1.1.0:minor",
      "nginx-core:1.0.1:patch",
      "nginx-cdn:1.0.1:patch"
    ]);
    expect(verifyReleasePlan(plan).ok).toBe(true);
  });

  it("lets explicit child bumps override inherited patch", () => {
    const plan = planRelease({
      catalog: loadCatalog(),
      channel: "stable",
      fragments: [
        fragment("20260712T000000Z-abcdef123456-nginx-base.yaml", { "nginx-base": "patch" }),
        fragment("20260712T000001Z-abcdef123456-nginx-cdn.yaml", { "nginx-cdn": "minor" })
      ]
    });
    const cdn = plan.images.find((image) => image.id === "nginx-cdn");
    expect(cdn?.nextVersion).toBe("1.1.0");
    expect(cdn?.effectiveBump).toBe("minor");
  });

  it("plans prereleases without stable moving aliases", () => {
    const plan = planRelease({
      catalog: loadCatalog(),
      channel: "next",
      fragments: [fragment("20260712T000000Z-abcdef123456-payload.yaml", { "nextjs-payload": "patch" })]
    });
    expect(plan.images[0]?.nextVersion).toBe("1.0.1-next.1");
    expect(plan.images[0]?.tags.map((tag) => tag.kind)).toEqual(["exact", "channel", "sha"]);
  });

  it("is deterministic for identical inputs", () => {
    const input = {
      catalog: loadCatalog(),
      channel: "stable" as const,
      fragments: [fragment("20260712T000000Z-abcdef123456-prisma.yaml", { "nextjs-prisma": "patch" })]
    };
    expect(planRelease(input)).toEqual(planRelease(input));
  });

  it("renders release PR metadata", () => {
    const plan = planRelease({
      catalog: loadCatalog(),
      channel: "stable",
      fragments: [fragment("20260712T000000Z-abcdef123456-prisma.yaml", { "nextjs-prisma": "patch" })]
    });
    const content = renderReleasePullRequest(plan);
    expect(content.title).toContain(plan.releaseId);
    expect(content.body).toContain("authorizes publication");
  });

  it("allows no-op plans for no-release/documentation-only fragments", () => {
    const plan = planRelease({ catalog: loadCatalog(), channel: "stable", fragments: [] });
    expect(plan.images).toEqual([]);
    expect(verifyReleasePlan(plan).ok).toBe(true);
  });
});
