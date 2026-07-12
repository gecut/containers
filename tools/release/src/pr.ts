import type { ReleasePlan, ReleasePrClient, ReleasePrContent, ReleasePrResult, UpsertReleasePrInput } from "./types.js";

export function renderReleasePullRequest(plan: ReleasePlan): ReleasePrContent {
  const imageLines = plan.images.length === 0 ? ["No image releases planned."] : plan.images.map((image) => `- ${image.id}: ${image.previousVersion} -> ${image.nextVersion}`);
  return {
    title: `Release containers: ${plan.releaseId}`,
    body: [`Release plan: \`${plan.releaseId}\``, "", ...imageLines, "", "Merging this Release PR authorizes publication by GitHub Actions."].join("\n")
  };
}

export async function upsertReleasePullRequest(client: ReleasePrClient, input: UpsertReleasePrInput): Promise<ReleasePrResult> {
  return client.upsert(input);
}
