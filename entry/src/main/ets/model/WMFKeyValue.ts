// Ported from WMF Framework/WMFKeyValue+CoreDataProperties.h (CoreData entity WMFKeyValue).

export interface WMFKeyValueRow {
  key?: string;
  group?: string;
  date?: number;
  valueJSON?: string;
}

export class WMFKeyValue {
  key: string | null = null;
  group: string | null = null;
  date: number | null = null;                      // epoch ms
  valueJSON: string | null = null;                 // serialized `value` (source: id<NSCoding>)

  static fromRow(r: WMFKeyValueRow): WMFKeyValue {
    const out = new WMFKeyValue();
    out.key = r.key ?? null;
    out.group = r.group ?? null;
    out.date = r.date ?? null;
    out.valueJSON = r.valueJSON ?? null;
    return out;
  }
}
