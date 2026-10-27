// CodeBuddy quota rows are a credit allowance, not a request count. The
// ProviderLimits progress bar used to hardcode "requests", so a CodeBuddy row
// read "2.33 / 100 requests" while the upstream dashboard says
// "2.33 / 100 credits". The usage handler now forwards the package's own unit
// and parseQuotaData must not drop it.
import { describe, expect, it } from "vitest";

import { parseQuotaData } from "../../src/app/(dashboard)/dashboard/usage/components/ProviderLimits/utils.js";

const quotas = {
  Monthly: { used: 2.33, total: 100, resetAt: "2026-10-31T16:59:59Z", recurring: true, unit: "credits" },
  "Bonus Pack 1": { used: 0, total: 250, resetAt: "2026-11-10T07:41:20Z", recurring: false, unit: "credits" },
};

function byName(parsed, name) {
  return parsed.find((q) => q.name === name);
}

describe("parseQuotaData forwards `unit` for codebuddy intl/cn", () => {
  for (const provider of ["codebuddy-intl", "codebuddy-cn"]) {
    it(`keeps the credit unit for ${provider}`, () => {
      const parsed = parseQuotaData(provider, { quotas });
      expect(byName(parsed, "Monthly").unit).toBe("credits");
      expect(byName(parsed, "Bonus Pack 1").unit).toBe("credits");
    });
  }

  it("preserves the used/total values the UI renders", () => {
    const parsed = parseQuotaData("codebuddy-intl", { quotas });
    const monthly = byName(parsed, "Monthly");
    expect(monthly.used).toBe(2.33);
    expect(monthly.total).toBe(100);
  });
});
