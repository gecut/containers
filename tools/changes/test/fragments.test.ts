import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { loadCatalog } from "@gecut/container-catalog";
import {
  createFragmentFilename,
  FragmentValidationError,
  loadChangeFragments,
  parseChangeFragment,
  validateChangeFragment,
  validateFragmentFilename
} from "../src/index.js";

const context = { catalog: loadCatalog() };

function expectInvalid(source: string, code: string, filename = "20260712T000000Z-abcdef123456-test.yaml"): void {
  try {
    validateChangeFragment(parseChangeFragment(source, filename), context, filename);
  } catch (error) {
    expect(error).toBeInstanceOf(FragmentValidationError);
    expect((error as FragmentValidationError).diagnostics.map((item) => item.code)).toContain(code);
    return;
  }
  throw new Error(`expected ${code}`);
}

describe("change fragments", () => {
  it("validates multi-image release fragments", () => {
    const fragment = validateChangeFragment(
      parseChangeFragment(
        `
schema_version: 1
type: release
summary: Add cache controls.
images:
  nginx-core: minor
  nginx-cdn: patch
`,
        "20260712T000000Z-abcdef123456-cache-controls.yaml"
      ),
      context,
      "20260712T000000Z-abcdef123456-cache-controls.yaml"
    );
    expect(fragment.type).toBe("release");
  });

  it("validates documentation and no-release fragments", () => {
    for (const type of ["documentation", "no-release"] as const) {
      const fragment = validateChangeFragment(
        parseChangeFragment(`schema_version: 1\ntype: ${type}\nsummary: Update docs.\n`, `20260712T000000Z-abcdef123456-${type}.yaml`),
        context,
        `20260712T000000Z-abcdef123456-${type}.yaml`
      );
      expect(fragment.type).toBe(type);
    }
  });

  it("rejects invalid image IDs and aliases", () => {
    expectInvalid("schema_version: 1\ntype: release\nsummary: Bad target.\nimages:\n  api: patch\n", "FRAGMENT_UNKNOWN_IMAGE");
    expectInvalid("schema_version: 1\ntype: release\nsummary: Bad alias.\nimages:\n  nexload: patch\n", "FRAGMENT_UNKNOWN_IMAGE");
  });

  it("enforces major breaking notes", () => {
    expectInvalid("schema_version: 1\ntype: release\nsummary: Breaking.\nimages:\n  nginx-core: major\n", "FRAGMENT_MISSING_BREAKING_NOTE");
    expectInvalid(
      "schema_version: 1\ntype: release\nsummary: Note mismatch.\nimages:\n  nginx-core: minor\nbreaking_notes:\n  nginx-core: Not allowed.\n",
      "FRAGMENT_UNEXPECTED_BREAKING_NOTE"
    );
  });

  it("rejects duplicate YAML keys", () => {
    expectInvalid("schema_version: 1\ntype: no-release\ntype: documentation\nsummary: Duplicate.\n", "FRAGMENT_YAML_PARSE");
  });

  it("validates collision-safe filenames", () => {
    const filename = createFragmentFilename("Add cache policy", new Date("2026-07-12T00:00:00.000Z"));
    expect(filename).toMatch(/^20260712T000000Z-[a-f0-9]{12}-add-cache-policy\.yaml$/);
    expect(() => validateFragmentFilename(filename)).not.toThrow();
    expect(() => validateFragmentFilename("release.yaml")).toThrow();
  });

  it("loads fragments in deterministic filename order", () => {
    const directory = mkdtempSync(join(tmpdir(), "gecut-fragments-"));
    writeFileSync(join(directory, "20260712T000001Z-abcdef123456-b.yaml"), "schema_version: 1\ntype: no-release\nsummary: B.\n");
    writeFileSync(join(directory, "20260712T000000Z-abcdef123456-a.yaml"), "schema_version: 1\ntype: documentation\nsummary: A.\n");
    expect(loadChangeFragments(directory, context).map((fragment) => fragment.filename)).toEqual([
      "20260712T000000Z-abcdef123456-a.yaml",
      "20260712T000001Z-abcdef123456-b.yaml"
    ]);
  });
});
