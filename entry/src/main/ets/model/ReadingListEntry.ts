// Ported from WMF Framework/ReadingListEntry+CoreDataProperties.swift (CoreData entity ReadingListEntry).

export interface ReadingListEntryRow {
  readingListEntryID?: number;
  createdDate?: number;
  updatedDate?: number;
  displayTitle?: string;
  listID?: number;
  articleKey?: string;
  variant?: string;
  isDeletedLocally?: number;
  isUpdatedLocally?: number;
  errorCode?: string;
}

export class ReadingListEntry {
  readingListEntryID: number | null = null;
  createdDate: number | null = null;               // epoch ms
  updatedDate: number | null = null;
  displayTitle: string | null = null;
  listID: number | null = null;                    // relation: list (ReadingList.readingListID)
  articleKey: string | null = null;
  variant: string | null = null;
  isDeletedLocally: boolean = false;
  isUpdatedLocally: boolean = false;
  errorCode: string | null = null;

  static fromRow(r: ReadingListEntryRow): ReadingListEntry {
    const out = new ReadingListEntry();
    out.readingListEntryID = r.readingListEntryID ?? null;
    out.createdDate = r.createdDate ?? null;
    out.updatedDate = r.updatedDate ?? null;
    out.displayTitle = r.displayTitle ?? null;
    out.listID = r.listID ?? null;
    out.articleKey = r.articleKey ?? null;
    out.variant = r.variant ?? null;
    out.isDeletedLocally = (r.isDeletedLocally ?? 0) !== 0;
    out.isUpdatedLocally = (r.isUpdatedLocally ?? 0) !== 0;
    out.errorCode = r.errorCode ?? null;
    return out;
  }
}
