// Ported from WMFData.xcdatamodeld entity CDPage.

export interface CDPageRow {
  id?: number;
  namespaceID?: number;
  projectID?: string;
  timestamp?: number;
  title?: string;
}

export class CDPage {
  id: number = 0;                                  // rowid (relations reference it)
  namespaceID: number = 0;
  projectID: string = '';
  timestamp: number = 0;                           // epoch ms
  title: string = '';

  static fromRow(r: CDPageRow): CDPage {
    const out = new CDPage();
    out.id = r.id ?? 0;
    out.namespaceID = r.namespaceID ?? 0;
    out.projectID = r.projectID ?? '';
    out.timestamp = r.timestamp ?? 0;
    out.title = r.title ?? '';
    return out;
  }
}
