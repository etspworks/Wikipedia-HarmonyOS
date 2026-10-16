// svc_recent_searches — recent search list.
// Ported from Wikipedia/Code/MWKRecentSearchList.m + MWKRecentSearchEntry.m:
// entries are {url, searchTerm} dicts, deduped by searchTerm, newest first, persisted as
// an array (plist via MWKDataStore.saveRecentSearchList -> preferences JSON here).

import { Prefs } from './Prefs';

const RECENT_SEARCHES_KEY: string = 'WMFRecentSearchList';

// MWKRecentSearchEntry.dataExport — {url, searchTerm}.
export interface RecentSearchEntryJson {
  url?: string;
  searchTerm?: string;
}

export class RecentSearchEntry {
  url: string = '';                                // desktop site URL of the search language
  searchTerm: string = '';

  static fromJson(j: RecentSearchEntryJson): RecentSearchEntry {
    const out = new RecentSearchEntry();
    out.url = j.url ?? '';
    out.searchTerm = j.searchTerm ?? '';
    return out;
  }
}

export class RecentSearchStore {
  // initWithDataStore — read + tolerate bad entries.
  static entries(): RecentSearchEntry[] {
    const text: string = Prefs.getString(RECENT_SEARCHES_KEY, '');
    if (text === '') {
      return [];
    }
    const raw: RecentSearchEntryJson[] = JSON.parse(text) as RecentSearchEntryJson[];
    const out: RecentSearchEntry[] = [];
    for (const j of raw) {
      const entry: RecentSearchEntry = RecentSearchEntry.fromJson(j);
      if (RecentSearchStore.isEntryValid(entry)) {
        out.push(entry);
      }
    }
    return out;
  }

  // isEntryValid — searchTerm non-empty and a url present.
  static isEntryValid(entry: RecentSearchEntry): boolean {
    return entry.searchTerm.length > 0 && entry.url.length > 0;
  }

  // addEntry — validate, remove any existing entry with the same searchTerm
  // (listIndex = searchTerm), insert at index 0, save.
  static addEntry(searchTerm: string, url: string): void {
    const entry = new RecentSearchEntry();
    entry.searchTerm = searchTerm;
    entry.url = url;
    if (!RecentSearchStore.isEntryValid(entry)) {
      return;
    }
    const current: RecentSearchEntry[] = RecentSearchStore.entries();
    const kept: RecentSearchEntry[] = [];
    for (const e of current) {
      if (e.searchTerm !== searchTerm) {
        kept.push(e);
      }
    }
    kept.splice(0, 0, entry);
    RecentSearchStore.save(kept);
  }

  // removeEntryWithListIndex.
  static removeEntry(searchTerm: string): void {
    const current: RecentSearchEntry[] = RecentSearchStore.entries();
    const kept: RecentSearchEntry[] = [];
    for (const e of current) {
      if (e.searchTerm !== searchTerm) {
        kept.push(e);
      }
    }
    RecentSearchStore.save(kept);
  }

  // removeAllEntries.
  static removeAllEntries(): void {
    RecentSearchStore.save([]);
  }

  // performSave / dataExport.
  private static save(entries: RecentSearchEntry[]): void {
    const out: RecentSearchEntryJson[] = [];
    for (const e of entries) {
      const j: RecentSearchEntryJson = { url: e.url, searchTerm: e.searchTerm };
      out.push(j);
    }
    Prefs.putString(RECENT_SEARCHES_KEY, JSON.stringify(out));
  }
}
