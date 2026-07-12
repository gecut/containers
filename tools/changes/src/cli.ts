#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { stringify } from "yaml";
import { loadCatalog } from "@gecut/container-catalog";
import { createFragmentFilename } from "./naming.js";
import { loadChangeFragments } from "./load.js";
import type { BumpType, ChangeFragment } from "./types.js";
import { FragmentValidationError } from "./types.js";

function flag(args: readonly string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

function flags(args: readonly string[], name: string): string[] {
  const values: string[] = [];
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === name && args[index + 1]) {
      values.push(args[index + 1] as string);
    }
  }
  return values;
}

function parseImageBumps(values: readonly string[]): Record<string, BumpType> {
  const images: Record<string, BumpType> = {};
  for (const value of values) {
    const [image, bump] = value.split(":");
    if (!image || !["patch", "minor", "major"].includes(bump ?? "")) {
      throw new Error(`invalid --image value: ${value}; expected image-id:patch|minor|major`);
    }
    images[image] = bump as BumpType;
  }
  return images;
}

function printFragmentError(error: FragmentValidationError): void {
  for (const diagnostic of error.diagnostics) {
    process.stderr.write(`${diagnostic.path} [${diagnostic.code}]: ${diagnostic.message}\n`);
  }
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  const directory = flag(args, "--dir") ?? ".changes/images";

  if (command === "create") {
    const type = flag(args, "--type");
    const summary = flag(args, "--summary");
    if (!type || !summary) throw new Error("create requires --type and --summary");
    if (!["release", "documentation", "no-release"].includes(type)) throw new Error(`invalid fragment type: ${type}`);

    const fragment: ChangeFragment =
      type === "release"
        ? { schema_version: 1, type, summary, images: parseImageBumps(flags(args, "--image")) }
        : { schema_version: 1, type: type as "documentation" | "no-release", summary };
    const filename = createFragmentFilename(summary);
    mkdirSync(directory, { recursive: true });
    const path = join(directory, filename);
    writeFileSync(path, stringify(fragment), { flag: "wx" });
    process.stdout.write(`${path}\n`);
    return;
  }

  if (command === "validate") {
    loadChangeFragments(directory, { catalog: loadCatalog() });
    process.stderr.write(`valid change fragments: ${directory}\n`);
    return;
  }

  if (command === "list") {
    const fragments = loadChangeFragments(directory, { catalog: loadCatalog() });
    if (args.includes("--json")) {
      process.stdout.write(`${JSON.stringify(fragments, null, 2)}\n`);
      return;
    }
    for (const fragment of fragments) {
      process.stdout.write(`${fragment.filename}\n`);
    }
    return;
  }

  process.stdout.write("Usage: gecut-changes <create|validate|list> [--dir .changes/images]\n");
}

main().catch((error: unknown) => {
  if (error instanceof FragmentValidationError) {
    printFragmentError(error);
    process.exitCode = 2;
    return;
  }
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
