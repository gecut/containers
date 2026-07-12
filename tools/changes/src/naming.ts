import { randomBytes } from "node:crypto";

const fragmentNamePattern = /^\d{8}T\d{6}Z-[a-f0-9]{12}-[a-z0-9]+(?:-[a-z0-9]+)*\.ya?ml$/;

export function validateFragmentFilename(filename: string): void {
  if (!fragmentNamePattern.test(filename)) {
    throw new Error(`invalid change fragment filename: ${filename}`);
  }
}

export function slugifySummary(summary: string): string {
  const slug = summary
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
  return slug.length > 0 ? slug : "change";
}

export function createFragmentFilename(summary: string, date = new Date()): string {
  const timestamp = date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  return `${timestamp}-${randomBytes(6).toString("hex")}-${slugifySummary(summary)}.yaml`;
}
