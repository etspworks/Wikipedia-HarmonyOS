// Ported from WMFData/Sources/WMFData/Models/Donor Experience/WMFDonateConfig.swift.

export interface WMFDonateConfigJson {
  version?: number;
  currencyMinimumDonation?: Record<string, number>;
  currencyMaximumDonation?: Record<string, number>;
  currencyAmountPresets?: Record<string, number[]>;
  currencyTransactionFees?: Record<string, number>;
  countryCodeEmailOptInRequired?: string[];
  countryCodeApplePayEnabled?: string[];
}

export class WMFDonateConfig {
  version: number = 0;
  currencyMinimumDonation: Map<string, number> = new Map<string, number>();
  currencyMaximumDonation: Map<string, number> = new Map<string, number>();
  currencyAmountPresets: Map<string, number[]> = new Map<string, number[]>();
  currencyTransactionFees: Map<string, number> = new Map<string, number>();
  countryCodeEmailOptInRequired: string[] = [];
  countryCodeApplePayEnabled: string[] = [];       // Apple Pay N/A on HarmonyOS; kept for parity
  cachedDate: number | null = null;                // epoch ms

  // Source: getMaxAmount(for:) — scale from the USD bounds when the currency has no max.
  getMaxAmount(currencyCode: string): number {
    let max: number = this.currencyMaximumDonation.get(currencyCode) ?? 0;
    if (max === 0) {
      const defaultMin = this.currencyMinimumDonation.get('USD');
      const defaultMax = this.currencyMaximumDonation.get('USD');
      const currencyMin = this.currencyMinimumDonation.get(currencyCode);
      if (defaultMin !== undefined && defaultMax !== undefined && currencyMin !== undefined && defaultMin !== 0) {
        max = currencyMin / defaultMin * defaultMax;
      }
    }
    return max;
  }

  static fromJson(j: WMFDonateConfigJson): WMFDonateConfig {
    const out = new WMFDonateConfig();
    out.version = j.version ?? 0;
    const minimum = j.currencyMinimumDonation;
    if (minimum !== undefined) {
      for (const code of Object.keys(minimum)) {
        out.currencyMinimumDonation.set(code, minimum[code]);
      }
    }
    const maximum = j.currencyMaximumDonation;
    if (maximum !== undefined) {
      for (const code of Object.keys(maximum)) {
        out.currencyMaximumDonation.set(code, maximum[code]);
      }
    }
    const presets = j.currencyAmountPresets;
    if (presets !== undefined) {
      for (const code of Object.keys(presets)) {
        out.currencyAmountPresets.set(code, presets[code]);
      }
    }
    const fees = j.currencyTransactionFees;
    if (fees !== undefined) {
      for (const code of Object.keys(fees)) {
        out.currencyTransactionFees.set(code, fees[code]);
      }
    }
    out.countryCodeEmailOptInRequired = j.countryCodeEmailOptInRequired ?? [];
    out.countryCodeApplePayEnabled = j.countryCodeApplePayEnabled ?? [];
    return out;
  }
}
