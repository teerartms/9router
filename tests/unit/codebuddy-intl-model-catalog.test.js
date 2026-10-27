// The codebuddy-intl registry must not advertise model ids the intl gateway
// rejects with 11102 "model service info not found": a combo or a fallback
// chain that picks one burns a request slot and returns a hard 400.
//
// Verified live on 2026-10-27 by POSTing a one-token request per id to
// https://www.codebuddy.ai/v2/chat/completions. Every id in `models` answered
// 200 at that time; the ids in DEAD answered 11102.
import { describe, expect, it } from "vitest";

import codebuddyIntl from "../../open-sse/providers/registry/codebuddy-intl.js";

const DEAD = [
  "glm-5.0-turbo",
  "glm-4.7",
  "minimax-m2.7",
  "hy3-preview",
  "deepseek-v4-pro",
  "deepseek-v3-2-volc",
  "kimi-k3-1",
];

// Ids that were missing from the registry even though the intl endpoint serves
// them (they exist on the CN catalog, which is the same backend).
const EXPECTED_ALIVE = ["glm-5.3", "glm-5.3-flash", "kimi-k2.8-preview", "hy4-preview", "hy3"];

describe("codebuddy-intl model catalog", () => {
  const ids = codebuddyIntl.models.map((m) => m.id);

  it("does not list ids the gateway rejects with 11102", () => {
    for (const dead of DEAD) expect(ids).not.toContain(dead);
  });

  it("lists the newer models the endpoint actually serves", () => {
    for (const alive of EXPECTED_ALIVE) expect(ids).toContain(alive);
  });

  it("keeps glm-5.0, which resolves but is rate-limited rather than gone", () => {
    expect(ids).toContain("glm-5.0");
  });

  it("has no duplicate ids", () => {
    expect(new Set(ids).size).toBe(ids.length);
  });
});
