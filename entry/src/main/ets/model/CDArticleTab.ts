// Ported from WMFData.xcdatamodeld entity CDArticleTab.

export interface CDArticleTabRow {
  identifier?: string;
  isCurrent?: number;
  timestamp?: number;
}

export class CDArticleTab {
  identifier: string = '';                         // UUID
  isCurrent: boolean = false;
  timestamp: number = 0;                           // epoch ms
  itemIdentifiers: string[] = [];                  // relation: items (ordered CDArticleTabItem)

  static fromRow(r: CDArticleTabRow): CDArticleTab {
    const out = new CDArticleTab();
    out.identifier = r.identifier ?? '';
    out.isCurrent = (r.isCurrent ?? 0) !== 0;
    out.timestamp = r.timestamp ?? 0;
    return out;
  }
}
