// Ported from WMFData/Sources/WMFData/Models/Watchlist/WMFWatchlist.swift (WMFWatchlist.Item).

export interface WMFWatchlistItemJson {
  title?: string;
  revid?: number;
  old_revid?: number;
  user?: string;
  anon?: boolean;
  bot?: boolean;
  temp?: boolean;
  timestamp?: string;
  comment?: string;
  parsedcomment?: string;
  newlen?: number;
  oldlen?: number;
}

export class WMFWatchlistItem {
  title: string = '';
  revisionID: number = 0;                          // JSON: revid
  oldRevisionID: number = 0;                       // JSON: old_revid
  username: string = '';                           // JSON: user
  isAnon: boolean = false;
  isBot: boolean = false;
  isTemp: boolean = false;
  timestamp: string = '';                          // ISO 8601
  commentWikitext: string = '';                    // JSON: comment
  commentHtml: string = '';                        // JSON: parsedcomment
  byteLength: number = 0;                          // JSON: newlen
  oldByteLength: number = 0;                       // JSON: oldlen
  project: string = '';                            // WMFProject identifier (e.g. "en.wikipedia.org")

  static fromJson(j: WMFWatchlistItemJson, project: string): WMFWatchlistItem {
    const out = new WMFWatchlistItem();
    out.title = j.title ?? '';
    out.revisionID = j.revid ?? 0;
    out.oldRevisionID = j.old_revid ?? 0;
    out.username = j.user ?? '';
    out.isAnon = j.anon ?? false;
    out.isBot = j.bot ?? false;
    out.isTemp = j.temp ?? false;
    out.timestamp = j.timestamp ?? '';
    out.commentWikitext = j.comment ?? '';
    out.commentHtml = j.parsedcomment ?? '';
    out.byteLength = j.newlen ?? 0;
    out.oldByteLength = j.oldlen ?? 0;
    out.project = project;
    return out;
  }
}

export class WMFWatchlist {
  items: WMFWatchlistItem[] = [];
  activeFilterCount: number = 0;
}
