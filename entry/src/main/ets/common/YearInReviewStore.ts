// svc_yir_store — Year in Review reports (CDYearInReviewReport / CDYearInReviewSlide).
// Ported from WMFData/Sources/WMFData/Data Controllers/Year In Review/
// WMFYearInReviewDataController.swift (report CRUD + settings/announcement flags).

import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { Prefs, WMFDataPrefKeys } from './Prefs';
import { CDYearInReviewReport } from '../model/CDYearInReviewReport';
import { CDYearInReviewSlide } from '../model/CDYearInReviewSlide';

// WMFYearInReviewPersonalizedSlideID raw values (WMFYearInReviewSlide.swift).
export class SlideId {
  static readonly readCount: string = 'readCount';
  static readonly editCount: string = 'editCount';
  static readonly donateCount: string = 'donateCount';
  static readonly saveCount: string = 'saveCount';
  static readonly mostReadDate: string = 'mostReadDate';
  static readonly viewCount: string = 'viewCount';
  static readonly topArticles: string = 'topArticles';
  static readonly mostReadCategories: string = 'mostReadCategories';
  static readonly location: string = 'location';
}

// WMFYearInReviewReport — plain report struct (year + slides).
export class YearInReviewReport {
  year: number = 0;
  slides: CDYearInReviewSlide[] = [];
}

function mapSlideRow(rs: relationalStore.ResultSet): CDYearInReviewSlide {
  const out = new CDYearInReviewSlide();
  out.id = Database.colString(rs, 'id') ?? '';
  out.data = Database.colString(rs, 'data');
  out.year = Database.colLong(rs, 'year');
  out.reportYear = Database.colLong(rs, 'reportYear');
  return out;
}

export class YearInReviewStore {
  // fetchYearInReviewReport(forYear:).
  static async fetchReport(year: number): Promise<YearInReviewReport | null> {
    const reports: CDYearInReviewReport[] = await Database.query<CDYearInReviewReport>(
      'SELECT year FROM CDYearInReviewReport WHERE year = ?', [year],
      (rs: relationalStore.ResultSet): CDYearInReviewReport => {
        const out = new CDYearInReviewReport();
        out.year = Database.colLong(rs, 'year') ?? 0;
        return out;
      });
    if (reports.length === 0) {
      return null;
    }
    const slides: CDYearInReviewSlide[] = await Database.query<CDYearInReviewSlide>(
      'SELECT id, data, year, reportYear FROM CDYearInReviewSlide WHERE reportYear = ?',
      [year], mapSlideRow);
    const report = new YearInReviewReport();
    report.year = year;
    report.slides = slides;
    return report;
  }

  // fetchYearInReviewReports.
  static async fetchReports(): Promise<YearInReviewReport[]> {
    const years: number[] = await Database.query<number>(
      'SELECT year FROM CDYearInReviewReport ORDER BY year DESC', [],
      (rs: relationalStore.ResultSet): number => rs.getLong(rs.getColumnIndex('year')));
    const out: YearInReviewReport[] = [];
    for (const year of years) {
      const report: YearInReviewReport | null = await YearInReviewStore.fetchReport(year);
      if (report !== null) {
        out.push(report);
      }
    }
    return out;
  }

  // saveYearInReviewReport — upserts the report row and every slide (fetchOrCreate by id).
  static async saveReport(year: number, slides: CDYearInReviewSlide[]): Promise<void> {
    const reportValues: relationalStore.ValuesBucket = { 'year': year };
    await Database.insert('CDYearInReviewReport', reportValues);
    for (const slide of slides) {
      const slideValues: relationalStore.ValuesBucket = {
        'id': slide.id,
        'data': slide.data,
        'year': slide.year ?? year,
        'reportYear': year
      };
      await Database.insert('CDYearInReviewSlide', slideValues);
    }
  }

  // createNewYearInReviewReport.
  static async createNewReport(year: number, slides: CDYearInReviewSlide[]): Promise<void> {
    await YearInReviewStore.saveReport(year, slides);
  }

  // deleteYearInReviewReport(year:).
  static async deleteReport(year: number): Promise<void> {
    await Database.execute('DELETE FROM CDYearInReviewSlide WHERE reportYear = ?', [year]);
    await Database.execute('DELETE FROM CDYearInReviewReport WHERE year = ?', [year]);
  }

  // deleteAllYearInReviewReports.
  static async deleteAllReports(): Promise<void> {
    await Database.execute('DELETE FROM CDYearInReviewSlide', []);
    await Database.execute('DELETE FROM CDYearInReviewReport', []);
  }

  // deleteAllPersonalizedNetworkData — drops the slides built from network data
  // (edit/donate counts; containsPersonalizedNetworkData in the source).
  static async deletePersonalizedNetworkSlides(): Promise<void> {
    await Database.execute('DELETE FROM CDYearInReviewSlide WHERE id IN (?, ?)',
      [SlideId.editCount, SlideId.donateCount]);
  }

  // --- Settings / announcement flags (WMFUserDefaultsKey) ---

  // yearInReviewSettingsIsEnabled (defaults on).
  static isYearInReviewEnabled(): boolean {
    return Prefs.getBoolean(WMFDataPrefKeys.yearInReviewSettingsIsEnabled, true);
  }

  static setYearInReviewEnabled(enabled: boolean): void {
    Prefs.putBoolean(WMFDataPrefKeys.yearInReviewSettingsIsEnabled, enabled);
  }

  static hasSeenFeatureAnnouncement(): boolean {
    return Prefs.getBoolean(WMFDataPrefKeys.seenYearInReviewFeatureAnnouncement, false);
  }

  static markFeatureAnnouncementSeen(): void {
    Prefs.putBoolean(WMFDataPrefKeys.seenYearInReviewFeatureAnnouncement, true);
  }

  static hasSeenIntroSlide(): boolean {
    return Prefs.getBoolean(WMFDataPrefKeys.seenYearInReviewIntroSlide, false);
  }

  static markIntroSlideSeen(): void {
    Prefs.putBoolean(WMFDataPrefKeys.seenYearInReviewIntroSlide, true);
  }

  // Developer Settings > "Show Year in Review": the entry point outside its season, for QA.
  static isForcedForTesting(): boolean {
    return Prefs.getBoolean('dev-settings-yir-show-v3', false);
  }

  static setForcedForTesting(on: boolean): void {
    Prefs.putBoolean('dev-settings-yir-show-v3', on);
  }

  static markTappedYearInReview(): void {
    Prefs.putBoolean(WMFDataPrefKeys.tappedYIR, true);
  }

  // shouldShowYearInReviewEntryPoint — settings toggle on and a report available for the
  // most recent YiR year (the source additionally gates on country/config).
  static async shouldShowEntryPoint(year: number): Promise<boolean> {
    if (!YearInReviewStore.isYearInReviewEnabled()) {
      return false;
    }
    // The report is only built inside the Year in Review screen, so requiring one first left
    // the entry point (and the feature) unreachable. The source offers it in its December
    // window (remote config); Developer Settings can force it for testing.
    // ponytail: fixed December window instead of the remote feature config
    if (YearInReviewStore.isForcedForTesting() || new Date().getMonth() === 11) {
      return true;
    }
    const report: YearInReviewReport | null = await YearInReviewStore.fetchReport(year);
    return report !== null && report.slides.length > 0;
  }
}
