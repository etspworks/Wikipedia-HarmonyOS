// Ported from WMFData.xcdatamodeld entity CDYearInReviewSlide.

export interface CDYearInReviewSlideRow {
  data?: string;
  id?: string;
  year?: number;
  reportYear?: number;
}

export class CDYearInReviewSlide {
  data: string | null = null;                      // source: Binary (serialized slide payload JSON)
  id: string = '';
  year: number | null = null;
  reportYear: number | null = null;                // relation: report (CDYearInReviewReport.year)

  static fromRow(r: CDYearInReviewSlideRow): CDYearInReviewSlide {
    const out = new CDYearInReviewSlide();
    out.data = r.data ?? null;
    out.id = r.id ?? '';
    out.year = r.year ?? null;
    out.reportYear = r.reportYear ?? null;
    return out;
  }
}
