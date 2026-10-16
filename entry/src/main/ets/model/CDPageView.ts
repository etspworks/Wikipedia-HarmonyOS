// Ported from WMFData.xcdatamodeld entity CDPageView.

export interface CDPageViewRow {
  id?: number;
  numberOfSeconds?: number;
  timestamp?: number;
  pageId?: number;
  previousPageViewId?: number;
}

export class CDPageView {
  id: number = 0;                                  // rowid
  numberOfSeconds: number = 0;
  timestamp: number = 0;                           // epoch ms
  pageId: number | null = null;                    // relation: page (CDPage.id)
  previousPageViewId: number | null = null;        // relation: previousPageView (CDPageView.id)

  static fromRow(r: CDPageViewRow): CDPageView {
    const out = new CDPageView();
    out.id = r.id ?? 0;
    out.numberOfSeconds = r.numberOfSeconds ?? 0;
    out.timestamp = r.timestamp ?? 0;
    out.pageId = r.pageId ?? null;
    out.previousPageViewId = r.previousPageViewId ?? null;
    return out;
  }
}
