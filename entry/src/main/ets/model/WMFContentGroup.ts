// Ported from WMF Framework/WMFContentGroup+CoreDataProperties.h (CoreData entity WMFContentGroup).

export interface WMFContentGroupRow {
  key?: string;
  date?: number;
  midnightUTCDate?: number;
  contentMidnightUTCDate?: number;
  contentDate?: number;
  siteURLString?: string;
  variant?: string;
  contentGroupKindInteger?: number;
  contentTypeInteger?: number;
  isVisible?: number;
  wasDismissed?: number;
  contentPreviewJSON?: string;
  dailySortPriority?: number;
  articleURLString?: string;
  featuredContentIdentifier?: string;
  locationLatitude?: number;
  locationLongitude?: number;
  placemarkTitle?: string;
  countOfFullContent?: number;
  fullContentId?: number;
  undoTypeInteger?: number;
  placement?: string;
}

export class WMFContentGroup {
  key: string | null = null;
  date: number | null = null;                      // epoch ms
  midnightUTCDate: number | null = null;
  contentMidnightUTCDate: number | null = null;
  contentDate: number | null = null;
  siteURLString: string | null = null;
  variant: string | null = null;
  contentGroupKindInteger: number = 0;
  contentTypeInteger: number = 0;
  isVisible: boolean = false;
  wasDismissed: boolean = false;
  contentPreviewJSON: string | null = null;        // serialized contentPreview (source: id<NSCoding>)
  dailySortPriority: number = 0;
  articleURLString: string | null = null;
  featuredContentIdentifier: string | null = null;
  locationLatitude: number | null = null;          // source: CLLocation
  locationLongitude: number | null = null;
  placemarkTitle: string | null = null;            // source: CLPlacemark (display string)
  countOfFullContent: number | null = null;
  fullContentId: number | null = null;             // relation: fullContent (WMFContent.id)
  undoTypeInteger: number = 0;
  placement: string | null = null;

  static fromRow(r: WMFContentGroupRow): WMFContentGroup {
    const out = new WMFContentGroup();
    out.key = r.key ?? null;
    out.date = r.date ?? null;
    out.midnightUTCDate = r.midnightUTCDate ?? null;
    out.contentMidnightUTCDate = r.contentMidnightUTCDate ?? null;
    out.contentDate = r.contentDate ?? null;
    out.siteURLString = r.siteURLString ?? null;
    out.variant = r.variant ?? null;
    out.contentGroupKindInteger = r.contentGroupKindInteger ?? 0;
    out.contentTypeInteger = r.contentTypeInteger ?? 0;
    out.isVisible = (r.isVisible ?? 0) !== 0;
    out.wasDismissed = (r.wasDismissed ?? 0) !== 0;
    out.contentPreviewJSON = r.contentPreviewJSON ?? null;
    out.dailySortPriority = r.dailySortPriority ?? 0;
    out.articleURLString = r.articleURLString ?? null;
    out.featuredContentIdentifier = r.featuredContentIdentifier ?? null;
    out.locationLatitude = r.locationLatitude ?? null;
    out.locationLongitude = r.locationLongitude ?? null;
    out.placemarkTitle = r.placemarkTitle ?? null;
    out.countOfFullContent = r.countOfFullContent ?? null;
    out.fullContentId = r.fullContentId ?? null;
    out.undoTypeInteger = r.undoTypeInteger ?? 0;
    out.placement = r.placement ?? null;
    return out;
  }
}
