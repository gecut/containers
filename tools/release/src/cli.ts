#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { loadCatalog } from "@gecut/container-catalog";
import { loadChangeFragments } from "@gecut/container-changes";
import { planRelease } from "./plan.js";
import { applyReleasePlan } from "./apply.js";
import { renderReleasePullRequest } from "./pr.js";
import { verifyReleasePlan } from "./verify.js";
import type { ReleaseChannel, ReleasePlan } from "./types.js";

function flag(args: readonly string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

function channel(args: readonly string[]): ReleaseChannel {
  const value = flag(args, "--channel") ?? "stable";
  if (!["stable", "next", "rc"].includes(value)) throw new Error(`invalid channel: ${value}`);
  return value as ReleaseChannel;
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  const catalog = loadCatalog();

  if (command === "plan") {
    process.stdout.write(`${JSON.stringify(planRelease({ catalog, fragments: loadChangeFragments(), channel: channel(args) }), null, 2)}\n`);
    return;
  }
  if (command === "prepare") {
    const plan = planRelease({ catalog, fragments: loadChangeFragments(), channel: channel(args) });
    applyReleasePlan(plan, catalog);
    process.stdout.write(`release/plans/${plan.releaseId}.json\n`);
    return;
  }
  if (command === "verify") {
    const planPath = flag(args, "--plan");
    const plan = planPath ? (JSON.parse(readFileSync(planPath, "utf8")) as ReleasePlan) : planRelease({ catalog, fragments: loadChangeFragments(), channel: channel(args) });
    const result = verifyReleasePlan(plan);
    if (!result.ok) {
      for (const error of result.errors) process.stderr.write(`${error}\n`);
      process.exitCode = 2;
    }
    return;
  }
  if (command === "pr-metadata") {
    const planPath = flag(args, "--plan");
    if (!planPath) throw new Error("pr-metadata requires --plan");
    process.stdout.write(`${JSON.stringify(renderReleasePullRequest(JSON.parse(readFileSync(planPath, "utf8")) as ReleasePlan), null, 2)}\n`);
    return;
  }
  if (command === "upsert-pr") {
    throw new Error("upsert-pr requires the GitHub Actions workflow adapter");
  }

  process.stdout.write("Usage: gecut-release <plan|prepare|verify|pr-metadata|upsert-pr> [--channel stable|next|rc]\n");
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
