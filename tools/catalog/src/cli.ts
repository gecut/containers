#!/usr/bin/env node
import { buildDependencyGraph, loadCatalog, normalizeCatalog } from "./index.js";
import { CatalogValidationError } from "./types.js";

function getCatalogPath(args: readonly string[]): string {
  const index = args.indexOf("--catalog");
  if (index === -1) {
    return "catalog/images.yaml";
  }
  const value = args[index + 1];
  if (!value) {
    throw new Error("--catalog requires a path");
  }
  return value;
}

function writeJson(value: unknown): void {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);
}

function printValidationError(error: CatalogValidationError): void {
  for (const diagnostic of error.diagnostics) {
    process.stderr.write(`${diagnostic.path} [${diagnostic.code}]: ${diagnostic.message}\n`);
  }
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  if (!command || command === "--help" || command === "-h") {
    process.stdout.write("Usage: gecut-catalog <validate|normalize|graph> [--catalog catalog/images.yaml]\n");
    return;
  }

  const catalogPath = getCatalogPath(args);
  const catalog = loadCatalog(catalogPath);

  if (command === "validate") {
    process.stderr.write(`valid catalog: ${catalogPath}\n`);
    return;
  }
  if (command === "normalize") {
    writeJson(normalizeCatalog(catalog));
    return;
  }
  if (command === "graph") {
    writeJson(buildDependencyGraph(catalog));
    return;
  }

  throw new Error(`unknown command: ${command}`);
}

main().catch((error: unknown) => {
  if (error instanceof CatalogValidationError) {
    printValidationError(error);
    process.exitCode = 2;
    return;
  }
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
