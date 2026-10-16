// WMFDonateDataController local donation history: SinglePageWebViewController reaching the
// donation thank-you page (thankyou.wikipedia.org / thankyou.wikimedia.org) parses its amount,
// currency and recurring flag and saves an entry (saveLocalDonationHistory), which turns on
// hasLocallySavedDonations and with it Settings' "Delete local donation history" row.
import { Prefs, WMFDataPrefKeys } from './Prefs';

const HISTORY_KEY: string = 'donate-history-local';

interface DonateLocalHistory {
  donationTimestamp: string;
  donationType: string;            // 'oneTime' | 'recurring'
  donationAmount: number;
  currencyCode: string;
  isNative: boolean;
  isFirstDonation: boolean;
}

function queryValue(query: string, name: string): string | null {
  for (const pair of query.split('&')) {
    const eq: number = pair.indexOf('=');
    const key: string = decodeURIComponent(eq < 0 ? pair : pair.substring(0, eq));
    if (key === name) {
      return eq < 0 ? '' : decodeURIComponent(pair.substring(eq + 1).replace(/\+/g, ' '));
    }
  }
  return null;
}

export class DonateHistory {
  // URL.isThankYouDonationURL + parseThankYouURL + saveDonationToLocalHistory
  static recordIfThankYouPage(pageUrl: string): void {
    const m: RegExpMatchArray | null = pageUrl.match(/^https?:\/\/thankyou\.wiki[mp]edia\.org[^?#]*\?([^#]*)/);
    if (m === null) {
      return;
    }
    const amount: string | null = queryValue(m[1], 'amount');
    const currency: string | null = queryValue(m[1], 'currency');
    if (amount === null || currency === null || queryValue(m[1], 'country') === null) {
      return;
    }
    const value: number = Number(amount);
    if (Number.isNaN(value)) {
      return;
    }
    const recurring: string | null = queryValue(m[1], 'recurring');
    const history: DonateLocalHistory[] = DonateHistory.load();
    history.push({
      donationTimestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      donationType: recurring === 'true' || recurring === '' ? 'recurring' : 'oneTime',
      donationAmount: value,
      currencyCode: currency,
      isNative: true,
      isFirstDonation: history.length === 0
    });
    Prefs.putString(HISTORY_KEY, JSON.stringify(history));
    Prefs.putBoolean(WMFDataPrefKeys.hasLocallySavedDonations, true);
  }

  // userDonatedWithinLast250Days: a donation saved on this device since the given time
  static hasDonatedSince(sinceMs: number): boolean {
    return DonateHistory.load().some((d: DonateLocalHistory) => Date.parse(d.donationTimestamp) >= sinceMs);
  }

  // deleteLocalDonationHistory
  static deleteAll(): void {
    Prefs.putBoolean(WMFDataPrefKeys.hasLocallySavedDonations, false);
    Prefs.remove(HISTORY_KEY);
  }

  private static load(): DonateLocalHistory[] {
    const raw: string = Prefs.getString(HISTORY_KEY, '');
    if (raw === '') {
      return [];
    }
    try {
      return JSON.parse(raw) as DonateLocalHistory[];
    } catch (e) {
      return [];
    }
  }
}
