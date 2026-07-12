import type { BumpType } from "./types.js";

export function compareBump(left: BumpType | null, right: BumpType | null): BumpType | null {
  const order: Record<BumpType, number> = { patch: 1, minor: 2, major: 3 };
  if (!left) return right;
  if (!right) return left;
  return order[left] >= order[right] ? left : right;
}

export function bumpVersion(version: string, bump: BumpType): string {
  const [majorRaw, minorRaw, patchRaw] = version.split(".");
  const major = Number(majorRaw);
  const minor = Number(minorRaw);
  const patch = Number(patchRaw);
  if (![major, minor, patch].every(Number.isInteger)) {
    throw new Error(`invalid SemVer: ${version}`);
  }
  if (bump === "major") return `${major + 1}.0.0`;
  if (bump === "minor") return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
}

export function prereleaseVersion(stableVersion: string, channel: "next" | "rc", counter: number): string {
  return `${stableVersion}-${channel}.${counter}`;
}
