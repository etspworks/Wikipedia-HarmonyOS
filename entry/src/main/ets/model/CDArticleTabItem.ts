// Ported from WMFData.xcdatamodeld entity CDArticleTabItem.

export interface CDArticleTabItemRow {
  identifier?: string;
  isCurrent?: number;
  pageId?: number;
  tabIdentifier?: string;
}

export class CDArticleTabItem {
  identifier: string = '';                         // UUID
  isCurrent: boolean = false;
  pageId: number | null = null;                    // relation: page (CDPage rowid)
  tabIdentifier: string | null = null;             // relation: tab (CDArticleTab.identifier)

  static fromRow(r: CDArticleTabItemRow): CDArticleTabItem {
    const out = new CDArticleTabItem();
    out.identifier = r.identifier ?? '';
    out.isCurrent = (r.isCurrent ?? 0) !== 0;
    out.pageId = r.pageId ?? null;
    out.tabIdentifier = r.tabIdentifier ?? null;
    return out;
  }
}
