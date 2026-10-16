// Ported from WMF Framework/WMFArticle+CoreDataProperties.h (CoreData entity WMFArticle).
// Relations (readingLists/previewReadingLists) are carried as reading-list id arrays;
// the join rows live in Database.ts.

export interface WMFArticleRow {
  key?: string;
  variant?: string;
  savedDate?: number;
  errorCodeNumber?: number;
  isDownloaded?: number;
  downloadRetryDate?: number;
  downloadAttemptCount?: number;
  isConversionFromMobileViewNeeded?: number;
  viewedDate?: number;
  viewedDateWithoutTime?: number;
  lastModifiedDate?: number;
  viewedFragment?: string;
  viewedScrollPosition?: number;
  wasSignificantlyViewed?: number;
  isExcludedFromFeed?: number;
  newsNotificationDate?: number;
  placesSortOrder?: number;
  displayTitle?: string;
  displayTitleHTMLString?: string;
  imageURLString?: string;
  imageHeight?: number;
  imageWidth?: number;
  pageViewsJSON?: string;
  snippet?: string;
  wikidataDescription?: string;
  wikidataID?: string;
  pageID?: number;
  signedQuadKey?: number;
  geoDimensionNumber?: number;
  geoTypeNumber?: number;
  latitude?: number;
  longitude?: number;
  ns?: number;
  thumbnailURLString?: string;
  isSavedMigrated?: number;
}

export class WMFArticle {
  key: string | null = null;
  variant: string | null = null;
  savedDate: number | null = null;                 // epoch ms; null = never saved
  readingListIds: number[] = [];                   // relation: readingLists
  previewReadingListIds: number[] = [];            // relation: previewReadingLists
  errorCodeNumber: number | null = null;
  isDownloaded: boolean = false;
  downloadRetryDate: number | null = null;
  downloadAttemptCount: number = 0;
  isConversionFromMobileViewNeeded: boolean = false;
  viewedDate: number | null = null;
  viewedDateWithoutTime: number | null = null;
  lastModifiedDate: number | null = null;
  viewedFragment: string | null = null;
  viewedScrollPosition: number = 0;
  wasSignificantlyViewed: boolean = false;
  isExcludedFromFeed: boolean = false;
  newsNotificationDate: number | null = null;
  placesSortOrder: number | null = null;
  displayTitle: string | null = null;
  displayTitleHTMLString: string | null = null;
  imageURLString: string | null = null;
  imageHeight: number | null = null;
  imageWidth: number | null = null;
  pageViewsJSON: string | null = null;             // serialized pageViews dictionary (date -> count)
  snippet: string | null = null;
  wikidataDescription: string | null = null;
  wikidataID: string | null = null;
  pageID: number | null = null;
  signedQuadKey: number | null = null;
  geoDimensionNumber: number | null = null;
  geoTypeNumber: number | null = null;
  latitude: number = 0;
  longitude: number = 0;
  ns: number | null = null;
  thumbnailURLString: string | null = null;
  isSavedMigrated: boolean = false;

  get displayTitleHTML(): string {
    if (this.displayTitleHTMLString !== null && this.displayTitleHTMLString !== '') {
      return this.displayTitleHTMLString;
    }
    return this.displayTitle ?? '';
  }

  get isSaved(): boolean {
    return this.savedDate !== null;
  }

  static fromRow(r: WMFArticleRow): WMFArticle {
    const out = new WMFArticle();
    out.key = r.key ?? null;
    out.variant = r.variant ?? null;
    out.savedDate = r.savedDate ?? null;
    out.errorCodeNumber = r.errorCodeNumber ?? null;
    out.isDownloaded = (r.isDownloaded ?? 0) !== 0;
    out.downloadRetryDate = r.downloadRetryDate ?? null;
    out.downloadAttemptCount = r.downloadAttemptCount ?? 0;
    out.isConversionFromMobileViewNeeded = (r.isConversionFromMobileViewNeeded ?? 0) !== 0;
    out.viewedDate = r.viewedDate ?? null;
    out.viewedDateWithoutTime = r.viewedDateWithoutTime ?? null;
    out.lastModifiedDate = r.lastModifiedDate ?? null;
    out.viewedFragment = r.viewedFragment ?? null;
    out.viewedScrollPosition = r.viewedScrollPosition ?? 0;
    out.wasSignificantlyViewed = (r.wasSignificantlyViewed ?? 0) !== 0;
    out.isExcludedFromFeed = (r.isExcludedFromFeed ?? 0) !== 0;
    out.newsNotificationDate = r.newsNotificationDate ?? null;
    out.placesSortOrder = r.placesSortOrder ?? null;
    out.displayTitle = r.displayTitle ?? null;
    out.displayTitleHTMLString = r.displayTitleHTMLString ?? null;
    out.imageURLString = r.imageURLString ?? null;
    out.imageHeight = r.imageHeight ?? null;
    out.imageWidth = r.imageWidth ?? null;
    out.pageViewsJSON = r.pageViewsJSON ?? null;
    out.snippet = r.snippet ?? null;
    out.wikidataDescription = r.wikidataDescription ?? null;
    out.wikidataID = r.wikidataID ?? null;
    out.pageID = r.pageID ?? null;
    out.signedQuadKey = r.signedQuadKey ?? null;
    out.geoDimensionNumber = r.geoDimensionNumber ?? null;
    out.geoTypeNumber = r.geoTypeNumber ?? null;
    out.latitude = r.latitude ?? 0;
    out.longitude = r.longitude ?? 0;
    out.ns = r.ns ?? null;
    out.thumbnailURLString = r.thumbnailURLString ?? null;
    out.isSavedMigrated = (r.isSavedMigrated ?? 0) !== 0;
    return out;
  }
}
