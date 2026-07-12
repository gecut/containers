#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { loadCatalog } from "@gecut/container-catalog";
import type { ReleasePlan } from "@gecut/container-release";
import { checkBakeDrift, createBuildPlan, generateBakeFile } from "./index.js";

function flag(args: readonly string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

function changedFiles(base: string, head: string): string[] {
  return execFileSync("git", ["diff", "--name-only", `${base}...${head}`], { encoding: "utf8" }).split("\n").filter(Boolean);
}

function repositoryPath(path: string): string {
  let current = process.cwd();
  while (true) {
    if (existsSync(join(current, "catalog/images.yaml"))) {
      return join(current, path);
    }
    const parent = dirname(current);
    if (parent === current) return path;
    current = parent;
  }
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  const catalog = loadCatalog();

  if (command === "generate") {
    const output = generateBakeFile(catalog);
    if (args.includes("--write")) {
      writeFileSync(repositoryPath("docker-bake.hcl"), output);
      return;
    }
    process.stdout.write(output);
    return;
  }

  if (command === "check") {
    const expected = generateBakeFile(catalog);
    const bakePath = repositoryPath("docker-bake.hcl");
    const committed = existsSync(bakePath) ? readFileSync(bakePath, "utf8") : "";
    const result = checkBakeDrift(expected, committed);
    if (!result.ok) {
      process.stderr.write(`${result.message}\n`);
      process.exitCode = 2;
      return;
    }
    process.stderr.write(`${result.message}\n`);
    return;
  }

  if (command === "plan") {
    const mode = flag(args, "--mode") ?? "full";
    if (mode === "changed") {
      const base = flag(args, "--base-ref");
      const head = flag(args, "--head-ref");
      const files = base && head ? changedFiles(base, head) : [];
      process.stdout.write(`${JSON.stringify(createBuildPlan(catalog, { mode, changedPaths: files }), null, 2)}\n`);
      return;
    }
    if (mode === "release") {
      const releasePlanPath = flag(args, "--release-plan");
      if (!releasePlanPath) throw new Error("--release-plan is required for release mode");
      const releasePlan = JSON.parse(readFileSync(releasePlanPath, "utf8")) as ReleasePlan;
      process.stdout.write(`${JSON.stringify(createBuildPlan(catalog, { mode, releaseImages: releasePlan.images.map((image) => image.id) }), null, 2)}\n`);
      return;
    }
    process.stdout.write(`${JSON.stringify(createBuildPlan(catalog, { mode: "full" }), null, 2)}\n`);
    return;
  }

  process.stdout.write("Usage: gecut-bake <generate|check|plan>\n");
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
