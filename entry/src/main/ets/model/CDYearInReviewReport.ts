// Ported from WMFData.xcdatamodeld entity CDYearInReviewReport.

export interface CDYearInReviewReportRow {
  year?: number;
}

export class CDYearInReviewReport {
  year: number = 0;
  slideIds: string[] = [];                         // relation: slides (CDYearInReviewSlide.id)

  static fromRow(r: CDYearInReviewReportRow): CDYearInReviewReport {
    const out = new CDYearInReviewReport();
    out.year = r.year ?? 0;
    return out;
  }
}
