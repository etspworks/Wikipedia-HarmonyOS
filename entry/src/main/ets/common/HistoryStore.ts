// svc_history_store — reading history over WMFArticle.viewedDate plus the WMFData
// CDPage/CDPageView page-view log.
// Ported from:
//   WMFData/.../History /WMFHistoryDataController.swift   (sections/items, delete)
//   Wikipedia/Code/SearchViewController.swift:152-215      (recordsProvider fetch)
//   WMF Framework/NSManagedObjectContext+History.swift     (add/remove/clear read history)
//   WMF Framework/WMFArticle+Extensions.m (updateViewedDateWithoutTime)
//   WMFData/.../Shared/WMFPageViewsDataController.swift    (CDPage/CDPageView writes)

import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { WMFArticle } from '../model/WMFArticle';
import { CDPageView } from '../model/CDPageView';

export const ARTICLE_COLUMNS: string =
  'key, variant, savedDate, errorCodeNumber, isDownloaded, downloadRetryDate, ' +
  'downloadAttemptCount, isConversionFromMobileViewNeeded, viewedDate, viewedDateWithoutTime, ' +
  'lastModifiedDate, viewedFragment, viewedScrollPosition, wasSignificantlyViewed, ' +
  'isExcludedFromFeed, newsNotificationDate, placesSortOrder, displayTitle, ' +
  'displayTitleHTMLString, imageURLString, imageHeight, imageWidth, pageViewsJSON, snippet, ' +
  'wikidataDescription, wikidataID, pageID, signedQuadKey, geoDimensionNumber, geoTypeNumber, ' +
  'latitude, longitude, ns, thumbnailURLString, isSavedMigrated';

// Fills EVERY WMFArticle column (shared with SavedStore).
export function mapArticleRow(rs: relationalStore.ResultSet): WMFArticle {
  const out = new WMFArticle();
  out.key = Database.colString(rs, 'key');
  out.variant = Database.colString(rs, 'variant');
  out.savedDate = Database.colLong(rs, 'savedDate');
  out.errorCodeNumber = Database.colLong(rs, 'errorCodeNumber');
  out.isDownloaded = Database.colBool(rs, 'isDownloaded');
  out.downloadRetryDate = Database.colLong(rs, 'downloadRetryDate');
  out.downloadAttemptCount = Database.colLong(rs, 'downloadAttemptCount') ?? 0;
  out.isConversionFromMobileViewNeeded = Database.colBool(rs, 'isConversionFromMobileViewNeeded');
  out.viewedDate = Database.colLong(rs, 'viewedDate');
  out.viewedDateWithoutTime = Database.colLong(rs, 'viewedDateWithoutTime');
  out.lastModifiedDate = Database.colLong(rs, 'lastModifiedDate');
  out.viewedFragment = Database.colString(rs, 'viewedFragment');
  out.viewedScrollPosition = Database.colDouble(rs, 'viewedScrollPosition') ?? 0;
  out.wasSignificantlyViewed = Database.colBool(rs, 'wasSignificantlyViewed');
  out.isExcludedFromFeed = Database.colBool(rs, 'isExcludedFromFeed');
  out.newsNotificationDate = Database.colLong(rs, 'newsNotificationDate');
  out.placesSortOrder = Database.colLong(rs, 'placesSortOrder');
  out.displayTitle = Database.colString(rs, 'displayTitle');
  out.displayTitleHTMLString = Database.colString(rs, 'displayTitleHTMLString');
  out.imageURLString = Database.colString(rs, 'imageURLString');
  out.imageHeight = Database.colLong(rs, 'imageHeight');
  out.imageWidth = Database.colLong(rs, 'imageWidth');
  out.pageViewsJSON = Database.colString(rs, 'pageViewsJSON');
  out.snippet = Database.colString(rs, 'snippet');
  out.wikidataDescription = Database.colString(rs, 'wikidataDescription');
  out.wikidataID = Database.colString(rs, 'wikidataID');
  out.pageID = Database.colLong(rs, 'pageID');
  out.signedQuadKey = Database.colLong(rs, 'signedQuadKey');
  out.geoDimensionNumber = Database.colLong(rs, 'geoDimensionNumber');
  out.geoTypeNumber = Database.colLong(rs, 'geoTypeNumber');
  out.latitude = Database.colDouble(rs, 'latitude') ?? 0;
  out.longitude = Database.colDouble(rs, 'longitude') ?? 0;
  out.ns = Database.colLong(rs, 'ns');
  out.thumbnailURLString = Database.colString(rs, 'thumbnailURLString');
  out.isSavedMigrated = Database.colBool(rs, 'isSavedMigrated');
  return out;
}

// updateViewedDateWithoutTime — local y/m/d, midnight local time.
function localMidnight(epochMs: number): number {
  const d = new Date(epochMs);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

// HistoryItem (WMFHistoryDataController.swift) — view-layer representation of one record.
export class HistoryItem {
  id: string = '';
  articleKey: string = '';                         // WMFArticle.key (article URL database key)
  titleHtml: string = '';
  description: string | null = null;
  shortDescription: string | null = null;
  imageURLString: string | null = null;
  isSaved: boolean = false;
  snippet: string | null = null;
  variant: string | null = null;
  viewedDate: number = 0;                          // epoch ms
}

// HistorySection — one day of history items.
export class HistorySection {
  dateWithoutTime: number = 0;                     // epoch ms, local midnight
  items: HistoryItem[] = [];
}

// AppStorage key set after a page view's reading seconds are written.
export const PAGE_VIEW_SECONDS_SAVED_KEY: string = 'wmfPageViewSecondsSaved';

export class HistoryStore {
  // recordsProvider (SearchViewController.swift:155) — viewedDate != NULL,
  // ORDER BY viewedDateWithoutTime DESC, viewedDate DESC, LIMIT 1000.
  static async fetchHistoryArticles(): Promise<WMFArticle[]> {
    return await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE viewedDate IS NOT NULL ' +
      'ORDER BY viewedDateWithoutTime DESC, viewedDate DESC LIMIT 1000',
      [], mapArticleRow);
  }

  // fetchHistorySections — groups records by day, newest day first. Mapper fills every
  // field the source HistoryItem init fills (id, titleHtml, description, shortDescription,
  // imageURL, isSaved, snippet, variant).
  static async fetchHistorySections(): Promise<HistorySection[]> {
    const articles: WMFArticle[] = await HistoryStore.fetchHistoryArticles();
    const byDay: Map<number, HistoryItem[]> = new Map<number, HistoryItem[]>();
    for (const article of articles) {
      const viewedDate: number | null = article.viewedDate;
      if (viewedDate === null || article.key === null) {
        continue;
      }
      const item = new HistoryItem();
      item.id = article.pageID !== null ? String(article.pageID) : article.key;
      item.articleKey = article.key;
      item.titleHtml = article.displayTitle ?? article.displayTitleHTML;
      // capitalizedWikidataDescriptionOrSnippet
      item.description = article.wikidataDescription ?? article.snippet;
      item.shortDescription = article.snippet;
      item.imageURLString = article.imageURLString ?? article.thumbnailURLString;
      item.isSaved = article.isSaved;
      item.snippet = article.snippet;
      item.variant = article.variant;
      item.viewedDate = viewedDate;

      const day: number = article.viewedDateWithoutTime ?? localMidnight(viewedDate);
      let list: HistoryItem[] | undefined = byDay.get(day);
      if (list === undefined) {
        list = [];
        byDay.set(day, list);
      }
      list.push(item);
    }
    const sections: HistorySection[] = [];
    byDay.forEach((items: HistoryItem[], day: number) => {
      const section = new HistorySection();
      section.dateWithoutTime = day;
      section.items = items;
      sections.push(section);
    });
    sections.sort((a: HistorySection, b: HistorySection): number =>
      b.dateWithoutTime - a.dateWithoutTime);
    return sections;
  }

  // WMFArticle.addToReadHistory — viewedDate = now, viewedDateWithoutTime updated.
  // Upserts the article row so a first visit creates it (fetchOrCreateArticleWithURL).
  static async addToReadHistory(articleKey: string, variant: string | null,
    displayTitle: string | null, wikidataDescription: string | null,
    snippet: string | null, thumbnailURLString: string | null,
    pageID: number | null): Promise<void> {
    const now: number = Date.now();
    // Two plain executeSql statements, no read-modify-write and no RdbStore.insert:
    //  - OR IGNORE creates the row on a first visit and leaves an existing one (and its
    //    savedDate / reading-list state) alone, so no REPLACE can drop columns;
    //  - the UPDATE then always writes viewedDate, and only the optional columns that
    //    actually carry a value — which is what the COALESCE list meant, without binding
    //    a single null.
    await Database.execute('INSERT OR IGNORE INTO WMFArticle (key) VALUES (?)', [articleKey]);
    const columns: string[] = ['viewedDate', 'viewedDateWithoutTime'];
    const args: relationalStore.ValueType[] = [now, localMidnight(now)];
    HistoryStore.setIfPresent(columns, args, 'variant', variant);
    HistoryStore.setIfPresent(columns, args, 'displayTitle', displayTitle);
    HistoryStore.setIfPresent(columns, args, 'wikidataDescription', wikidataDescription);
    HistoryStore.setIfPresent(columns, args, 'snippet', snippet);
    HistoryStore.setIfPresent(columns, args, 'thumbnailURLString', thumbnailURLString);
    HistoryStore.setIfPresent(columns, args, 'pageID', pageID);
    args.push(articleKey);
    await Database.execute('UPDATE WMFArticle SET ' +
      columns.map((column: string): string => column + ' = ?').join(', ') +
      ' WHERE key = ?', args);
  }

  private static setIfPresent(columns: string[], args: relationalStore.ValueType[],
    column: string, value: relationalStore.ValueType): void {
    if (value !== null) {
      columns.push(column);
      args.push(value);
    }
  }

  // removeFromReadHistory — viewedDate nil, wasSignificantlyViewed NO, dateWithoutTime nil.
  static async removeFromReadHistory(articleKey: string): Promise<void> {
    await Database.execute(
      'UPDATE WMFArticle SET viewedDate = NULL, viewedDateWithoutTime = NULL, ' +
      'wasSignificantlyViewed = 0 WHERE key = ?', [articleKey]);
  }

  // clearReadHistory + deleteAllPageViews (Settings > Clear history).
  static async clearReadHistory(): Promise<void> {
    await Database.execute(
      'UPDATE WMFArticle SET viewedDate = NULL, viewedDateWithoutTime = NULL, ' +
      'wasSignificantlyViewed = 0 WHERE viewedDate IS NOT NULL', []);
    await Database.execute('DELETE FROM CDPageView', []);
  }

  // ArticleViewController.saveArticleScrollPosition: the scroll offset and the visible
  // section's anchor, for restoring the reading position later.
  static async saveViewedPosition(articleKey: string, offset: number, fragment: string | null): Promise<void> {
    await Database.execute('UPDATE WMFArticle SET viewedScrollPosition = ?, viewedFragment = ? WHERE key = ?',
      [offset, fragment, articleKey]);
  }

  static async viewedPosition(articleKey: string): Promise<WMFArticle | null> {
    const rows: WMFArticle[] = await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE key = ?', [articleKey], mapArticleRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // ArticleViewController.significantlyViewedTimer: read for 30 s.
  static async markSignificantlyViewed(articleKey: string): Promise<void> {
    await Database.execute('UPDATE WMFArticle SET wasSignificantlyViewed = 1 WHERE key = ?', [articleKey]);
  }

  // WMFRelatedPagesContentSource's seed: the newest read-for-a-while or saved article that has
  // no "Because you read" card yet.
  static async relatedPagesSeed(excludedKeys: string[]): Promise<WMFArticle | null> {
    const rows: WMFArticle[] = await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE isExcludedFromFeed = 0 AND ' +
      '(wasSignificantlyViewed = 1 OR savedDate IS NOT NULL) ' +
      'ORDER BY viewedDate DESC, savedDate DESC LIMIT 50', [], mapArticleRow);
    return rows.find((a: WMFArticle) => excludedKeys.indexOf(a.key ?? '') < 0) ?? null;
  }

  // mostRecentlyReadArticle.
  static async mostRecentlyReadArticle(): Promise<WMFArticle | null> {
    const rows: WMFArticle[] = await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE viewedDate IS NOT NULL ' +
      'ORDER BY viewedDate DESC LIMIT 1', [], mapArticleRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // --- WMFPageViewsDataController (CDPage/CDPageView write path) ---

  // addPageView — fetch-or-create the CDPage (projectID+namespaceID+title unique),
  // refresh its fields, insert a CDPageView linked to it (and the previous view).
  // Returns the new CDPageView rowid (the source returns the objectID for chaining).
  static async addPageView(title: string, namespaceID: number, projectID: string,
    previousPageViewId: number | null): Promise<number> {
    const now: number = Date.now();
    const pageIds: number[] = await Database.query<number>(
      'SELECT id FROM CDPage WHERE projectID = ? AND namespaceID = ? AND title = ?',
      [projectID, namespaceID, title],
      (rs: relationalStore.ResultSet): number => rs.getLong(rs.getColumnIndex('id')));
    let pageId: number;
    if (pageIds.length > 0) {
      pageId = pageIds[0];
      await Database.execute('UPDATE CDPage SET timestamp = ? WHERE id = ?', [now, pageId]);
    } else {
      const pageValues: relationalStore.ValuesBucket = {
        'namespaceID': namespaceID,
        'projectID': projectID,
        'timestamp': now,
        'title': title
      };
      pageId = await Database.insert('CDPage', pageValues);
    }
    const viewValues: relationalStore.ValuesBucket = {
      'numberOfSeconds': 0,
      'timestamp': now,
      'pageId': pageId,
      'previousPageViewId': previousPageViewId
    };
    return await Database.insert('CDPageView', viewValues);
  }

  // addPageViewSeconds — numberOfSeconds += seconds.
  static async addPageViewSeconds(pageViewId: number, seconds: number): Promise<void> {
    await Database.execute(
      'UPDATE CDPageView SET numberOfSeconds = numberOfSeconds + ? WHERE id = ?',
      [Math.floor(seconds), pageViewId]);
  }

  // deletePageView — removes every CDPageView of the page.
  static async deletePageView(title: string, namespaceID: number,
    projectID: string): Promise<void> {
    await Database.execute(
      'DELETE FROM CDPageView WHERE pageId IN ' +
      '(SELECT id FROM CDPage WHERE projectID = ? AND namespaceID = ? AND title = ?)',
      [projectID, namespaceID, title]);
  }

  // fetchPageViewCounts — views per page in [startMs, endMs], most-viewed first.
  static async fetchPageViewCounts(startMs: number, endMs: number): Promise<Map<string, number>> {
    const out: Map<string, number> = new Map<string, number>();
    const rs: relationalStore.ResultSet = await Database.requireStore().querySql(
      'SELECT p.title AS title, COUNT(v.id) AS viewCount FROM CDPageView v ' +
      'JOIN CDPage p ON p.id = v.pageId WHERE v.timestamp >= ? AND v.timestamp <= ? ' +
      'GROUP BY v.pageId ORDER BY viewCount DESC', [startMs, endMs]);
    try {
      while (rs.goToNextRow()) {
        out.set(rs.getString(rs.getColumnIndex('title')),
          rs.getLong(rs.getColumnIndex('viewCount')));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  // fetchPageViewMinutes — total minutes read in the range.
  static async fetchPageViewMinutes(startMs: number, endMs: number): Promise<number> {
    const seconds: number = await Database.queryCount(
      'SELECT COALESCE(SUM(numberOfSeconds), 0) FROM CDPageView ' +
      'WHERE timestamp >= ? AND timestamp <= ?', [startMs, endMs]);
    return Math.floor(seconds / 60);
  }

  // fetchMostRecentTime.
  static async fetchMostRecentPageViewTime(): Promise<number | null> {
    const rows: number[] = await Database.query<number>(
      'SELECT timestamp FROM CDPageView ORDER BY timestamp DESC LIMIT 1', [],
      (rs: relationalStore.ResultSet): number => rs.getLong(rs.getColumnIndex('timestamp')));
    return rows.length > 0 ? rows[0] : null;
  }

  // fetchLinkedPageViews support — all page views, oldest first.
  static async fetchAllPageViews(): Promise<CDPageView[]> {
    return await Database.query<CDPageView>(
      'SELECT id, numberOfSeconds, timestamp, pageId, previousPageViewId FROM CDPageView ' +
      'ORDER BY timestamp ASC', [],
      (rs: relationalStore.ResultSet): CDPageView => {
        const out = new CDPageView();
        out.id = Database.colLong(rs, 'id') ?? 0;
        out.numberOfSeconds = Database.colLong(rs, 'numberOfSeconds') ?? 0;
        out.timestamp = Database.colLong(rs, 'timestamp') ?? 0;
        out.pageId = Database.colLong(rs, 'pageId');
        out.previousPageViewId = Database.colLong(rs, 'previousPageViewId');
        return out;
      });
  }
}
