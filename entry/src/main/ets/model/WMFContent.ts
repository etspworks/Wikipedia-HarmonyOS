// Ported from WMF Framework/WMFContent+CoreDataProperties.h (CoreData entity WMFContent).

export interface WMFContentRow {
  id?: number;
  objectJSON?: string;
  contentGroupKey?: string;
}

export class WMFContent {
  id: number | null = null;
  objectJSON: string | null = null;                // serialized `object` (source: id<NSCoding>)
  contentGroupKey: string | null = null;           // relation: contentGroup (WMFContentGroup.key)

  static fromRow(r: WMFContentRow): WMFContent {
    const out = new WMFContent();
    out.id = r.id ?? null;
    out.objectJSON = r.objectJSON ?? null;
    out.contentGroupKey = r.contentGroupKey ?? null;
    return out;
  }
}
