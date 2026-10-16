// Ported from Wikipedia/Code/WMFPageHistoryRevision.h/.m (action=query&prop=revisions rows).

export interface WMFPageHistoryRevisionJson {
  user?: string;
  timestamp?: string;
  parsedcomment?: string;
  // formatversion=2 sends these flags as booleans (minor: false on a normal edit); the
  // older format sent an empty string only when set. Both spellings are accepted.
  anon?: boolean | string;
  minor?: boolean | string;
  temp?: boolean | string;
  parentid?: number;
  revid?: number;
  size?: number;
}

export class WMFPageHistoryRevision {
  user: string | null = null;
  revisionDate: string | null = null;              // JSON: timestamp (ISO 8601)
  parsedComment: string | null = null;             // JSON: parsedcomment
  isAnon: boolean = false;                         // JSON: anon (presence flag)
  isMinor: boolean = false;                        // JSON: minor (presence flag)
  temp: string | null = null;
  parentID: number = 0;                            // JSON: parentid
  revisionID: number = 0;                          // JSON: revid
  articleSizeAtRevision: number = 0;               // JSON: size
  revisionSize: number = 0;                        // computed: size delta vs parent

  // Source: isTemp is true when `temp` is present (empty string in the API response).
  get isTemp(): boolean {
    return this.temp === '';
  }

  private static flag(v: boolean | string | undefined): boolean {
    return v === true || v === '';
  }

  static fromJson(j: WMFPageHistoryRevisionJson): WMFPageHistoryRevision {
    const out = new WMFPageHistoryRevision();
    out.user = j.user ?? null;
    out.revisionDate = j.timestamp ?? null;
    out.parsedComment = j.parsedcomment ?? null;
    out.isAnon = WMFPageHistoryRevision.flag(j.anon);
    out.isMinor = WMFPageHistoryRevision.flag(j.minor);
    out.temp = WMFPageHistoryRevision.flag(j.temp) ? '' : null;
    out.parentID = j.parentid ?? 0;
    out.revisionID = j.revid ?? 0;
    out.articleSizeAtRevision = j.size ?? 0;
    out.revisionSize = 0;
    return out;
  }
}
