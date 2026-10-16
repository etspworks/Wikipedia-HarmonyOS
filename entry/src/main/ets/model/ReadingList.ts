// Ported from WMF Framework/ReadingList+CoreDataProperties.swift (CoreData entity ReadingList).

export interface ReadingListRow {
  canonicalName?: string;
  color?: string;
  countOfEntries?: number;
  createdDate?: number;
  errorCode?: string;
  iconName?: string;
  imageName?: string;
  isDefault?: number;
  isDeletedLocally?: number;
  isUpdatedLocally?: number;
  readingListDescription?: string;
  readingListID?: number;
  updatedDate?: number;
  sortOrder?: number;
}

export class ReadingList {
  static readonly defaultListCanonicalName: string = 'default';

  canonicalName: string | null = null;
  color: string | null = null;
  countOfEntries: number = 0;
  createdDate: number | null = null;               // epoch ms
  errorCode: string | null = null;
  iconName: string | null = null;
  imageName: string | null = null;
  isDefault: boolean = false;
  isDeletedLocally: boolean = false;
  isUpdatedLocally: boolean = false;
  readingListDescription: string | null = null;
  readingListID: number | null = null;
  updatedDate: number | null = null;
  sortOrder: number | null = null;
  articleKeys: string[] = [];                      // relation: articles
  previewArticleKeys: string[] = [];               // relation: previewArticles (ordered)

  // Source: `name` returns the localized default-list title for the default list.
  nameWithDefaultTitle(defaultListTitle: string): string {
    if (this.isDefault) {
      return defaultListTitle;
    }
    return this.canonicalName ?? '';
  }

  static fromRow(r: ReadingListRow): ReadingList {
    const out = new ReadingList();
    out.canonicalName = r.canonicalName ?? null;
    out.color = r.color ?? null;
    out.countOfEntries = r.countOfEntries ?? 0;
    out.createdDate = r.createdDate ?? null;
    out.errorCode = r.errorCode ?? null;
    out.iconName = r.iconName ?? null;
    out.imageName = r.imageName ?? null;
    out.isDefault = (r.isDefault ?? 0) !== 0;
    out.isDeletedLocally = (r.isDeletedLocally ?? 0) !== 0;
    out.isUpdatedLocally = (r.isUpdatedLocally ?? 0) !== 0;
    out.readingListDescription = r.readingListDescription ?? null;
    out.readingListID = r.readingListID ?? null;
    out.updatedDate = r.updatedDate ?? null;
    out.sortOrder = r.sortOrder ?? null;
    return out;
  }
}
