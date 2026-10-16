// Ported from WMF Framework/CacheGroup+CoreDataProperties.swift and CacheItem+CoreDataProperties.swift
// (Cache.xcdatamodeld entities CacheGroup / CacheItem).

export interface CacheItemRow {
  date?: number;
  isDownloaded?: number;
  key?: string;
  url?: string;
  variant?: string;
}

export class CacheItem {
  date: number | null = null;                      // epoch ms
  isDownloaded: boolean = false;
  key: string | null = null;
  url: string | null = null;
  variant: string | null = null;

  static fromRow(r: CacheItemRow): CacheItem {
    const out = new CacheItem();
    out.date = r.date ?? null;
    out.isDownloaded = (r.isDownloaded ?? 0) !== 0;
    out.key = r.key ?? null;
    out.url = r.url ?? null;
    out.variant = r.variant ?? null;
    return out;
  }
}

export interface CacheGroupRow {
  key?: string;
}

export class CacheGroup {
  key: string | null = null;
  cacheItemKeys: string[] = [];                    // relation: cacheItems
  mustHaveCacheItemKeys: string[] = [];            // relation: mustHaveCacheItems

  static fromRow(r: CacheGroupRow): CacheGroup {
    const out = new CacheGroup();
    out.key = r.key ?? null;
    return out;
  }
}
