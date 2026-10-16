// svc_db — relationalStore port of the app's three CoreData stores:
//   Wikipedia.xcdatamodeld  (WMFArticle, ReadingList, ReadingListEntry, WMFContentGroup,
//                            WMFContent, WMFKeyValue, RemoteNotification)
//   Cache.xcdatamodeld      (CacheGroup, CacheItem + join tables)
//   WMFData.xcdatamodeld    (CDArticleTab, CDArticleTabItem, CDPage, CDPageView,
//                            CDGameSession, CDYearInReviewReport, CDYearInReviewSlide)
// Dates are stored as INTEGER epoch ms; booleans as INTEGER 0/1; binary/NSCoding payloads as
// serialized JSON TEXT. Relations become foreign-key columns or join tables.

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'wikipedia.db';

const CREATE_TABLES: string[] = [
  // --- Wikipedia store ---
  'CREATE TABLE IF NOT EXISTS WMFArticle (' +
    'key TEXT PRIMARY KEY, variant TEXT, savedDate INTEGER, errorCodeNumber INTEGER, ' +
    'isDownloaded INTEGER NOT NULL DEFAULT 0, downloadRetryDate INTEGER, ' +
    'downloadAttemptCount INTEGER NOT NULL DEFAULT 0, ' +
    'isConversionFromMobileViewNeeded INTEGER NOT NULL DEFAULT 0, ' +
    'viewedDate INTEGER, viewedDateWithoutTime INTEGER, lastModifiedDate INTEGER, ' +
    'viewedFragment TEXT, viewedScrollPosition REAL NOT NULL DEFAULT 0, ' +
    'wasSignificantlyViewed INTEGER NOT NULL DEFAULT 0, ' +
    'isExcludedFromFeed INTEGER NOT NULL DEFAULT 0, newsNotificationDate INTEGER, ' +
    'placesSortOrder INTEGER, displayTitle TEXT, displayTitleHTMLString TEXT, ' +
    'imageURLString TEXT, imageHeight INTEGER, imageWidth INTEGER, pageViewsJSON TEXT, ' +
    'snippet TEXT, wikidataDescription TEXT, wikidataID TEXT, pageID INTEGER, ' +
    'signedQuadKey INTEGER, geoDimensionNumber INTEGER, geoTypeNumber INTEGER, ' +
    'latitude REAL NOT NULL DEFAULT 0, longitude REAL NOT NULL DEFAULT 0, ns INTEGER, ' +
    'thumbnailURLString TEXT, isSavedMigrated INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS ReadingList (' +
    'canonicalName TEXT, color TEXT, countOfEntries INTEGER NOT NULL DEFAULT 0, ' +
    'createdDate INTEGER, errorCode TEXT, iconName TEXT, imageName TEXT, ' +
    'isDefault INTEGER NOT NULL DEFAULT 0, isDeletedLocally INTEGER NOT NULL DEFAULT 0, ' +
    'isUpdatedLocally INTEGER NOT NULL DEFAULT 0, readingListDescription TEXT, ' +
    'readingListID INTEGER, updatedDate INTEGER, sortOrder INTEGER)',
  'CREATE TABLE IF NOT EXISTS ReadingListEntry (' +
    'readingListEntryID INTEGER, createdDate INTEGER, updatedDate INTEGER, ' +
    'displayTitle TEXT, listID INTEGER, articleKey TEXT, variant TEXT, ' +
    'isDeletedLocally INTEGER NOT NULL DEFAULT 0, isUpdatedLocally INTEGER NOT NULL DEFAULT 0, ' +
    'errorCode TEXT)',
  // join: WMFArticle.readingLists <-> ReadingList.articles
  'CREATE TABLE IF NOT EXISTS ReadingListArticle (' +
    'listRowId INTEGER NOT NULL, articleKey TEXT NOT NULL, isPreview INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY (listRowId, articleKey, isPreview))',
  'CREATE TABLE IF NOT EXISTS WMFContentGroup (' +
    'key TEXT PRIMARY KEY, date INTEGER, midnightUTCDate INTEGER, ' +
    'contentMidnightUTCDate INTEGER, contentDate INTEGER, siteURLString TEXT, variant TEXT, ' +
    'contentGroupKindInteger INTEGER NOT NULL DEFAULT 0, ' +
    'contentTypeInteger INTEGER NOT NULL DEFAULT 0, isVisible INTEGER NOT NULL DEFAULT 1, ' +
    'wasDismissed INTEGER NOT NULL DEFAULT 0, contentPreviewJSON TEXT, ' +
    'dailySortPriority INTEGER NOT NULL DEFAULT 0, articleURLString TEXT, ' +
    'featuredContentIdentifier TEXT, locationLatitude REAL, locationLongitude REAL, ' +
    'placemarkTitle TEXT, countOfFullContent INTEGER, fullContentId INTEGER, ' +
    'undoTypeInteger INTEGER NOT NULL DEFAULT 0, placement TEXT)',
  'CREATE TABLE IF NOT EXISTS WMFContent (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, objectJSON TEXT, contentGroupKey TEXT)',
  'CREATE TABLE IF NOT EXISTS WMFKeyValue (' +
    'key TEXT NOT NULL, grp TEXT, date INTEGER, valueJSON TEXT, PRIMARY KEY (key, grp))',
  'CREATE TABLE IF NOT EXISTS RemoteNotification (' +
    'id TEXT, wiki TEXT, key TEXT PRIMARY KEY, agentId TEXT, agentName TEXT, ' +
    'categoryString TEXT, date INTEGER, isRead INTEGER NOT NULL DEFAULT 0, ' +
    'messageBody TEXT, messageHeader TEXT, messageLinksJSON TEXT, section TEXT, ' +
    'titleFull TEXT, titleNamespace TEXT, titleNamespaceKey INTEGER NOT NULL DEFAULT 0, ' +
    'titleText TEXT, typeString TEXT, utcUnixString TEXT, revisionID TEXT)',
  // --- Cache store ---
  'CREATE TABLE IF NOT EXISTS CacheGroup (key TEXT PRIMARY KEY)',
  'CREATE TABLE IF NOT EXISTS CacheItem (' +
    'key TEXT PRIMARY KEY, date INTEGER, isDownloaded INTEGER NOT NULL DEFAULT 0, ' +
    'url TEXT, variant TEXT)',
  'CREATE TABLE IF NOT EXISTS CacheGroupItem (' +
    'groupKey TEXT NOT NULL, itemKey TEXT NOT NULL, mustHave INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY (groupKey, itemKey))',
  // --- WMFData store ---
  'CREATE TABLE IF NOT EXISTS CDArticleTab (' +
    'identifier TEXT PRIMARY KEY, isCurrent INTEGER NOT NULL DEFAULT 0, ' +
    'timestamp INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS CDArticleTabItem (' +
    'identifier TEXT PRIMARY KEY, isCurrent INTEGER NOT NULL DEFAULT 0, ' +
    'pageId INTEGER, tabIdentifier TEXT, orderIndex INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS CDPage (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, namespaceID INTEGER NOT NULL DEFAULT 0, ' +
    'projectID TEXT NOT NULL, timestamp INTEGER NOT NULL DEFAULT 0, title TEXT NOT NULL, ' +
    'UNIQUE (projectID, namespaceID, title))',
  'CREATE TABLE IF NOT EXISTS CDPageView (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, numberOfSeconds INTEGER NOT NULL DEFAULT 0, ' +
    'timestamp INTEGER NOT NULL DEFAULT 0, pageId INTEGER, previousPageViewId INTEGER)',
  'CREATE TABLE IF NOT EXISTS CDGameSession (' +
    'identifier TEXT PRIMARY KEY, completedDate INTEGER, contentData TEXT, ' +
    'currentQuestionIndex INTEGER NOT NULL DEFAULT 0, dailyGameDate TEXT, ' +
    'gameType TEXT NOT NULL, projectID TEXT NOT NULL, score INTEGER NOT NULL DEFAULT 0, ' +
    'status INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS CDYearInReviewReport (year INTEGER PRIMARY KEY)',
  'CREATE TABLE IF NOT EXISTS CDYearInReviewSlide (' +
    'id TEXT NOT NULL, data TEXT, year INTEGER, reportYear INTEGER, ' +
    'PRIMARY KEY (id, reportYear))'
];

export type RowMapper<T> = (rs: relationalStore.ResultSet) => T;

export class Database {
  private static store: relationalStore.RdbStore | null = null;
  // The open is memoized: init() is called from every page (and from a handler right before
  // it writes), so without this two callers that arrive while the store is still opening
  // both open one of their own and the DDL runs twice on the same file.
  private static opening: Promise<void> | null = null;

  // Idempotent "ensure the store is ready". Resolves immediately once it is, so a write path
  // can await it without knowing who opened the store.
  static init(context: common.Context): Promise<void> {
    if (Database.store !== null) {
      return Promise.resolve();
    }
    let opening: Promise<void> | null = Database.opening;
    if (opening === null) {
      opening = Database.open(context);
      Database.opening = opening;
    }
    return opening;
  }

  private static async open(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: STORE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    try {
      const store = await relationalStore.getRdbStore(context, config);
      for (const sql of CREATE_TABLES) {
        await store.executeSql(sql);
      }
      Database.store = store;
    } catch (e) {
      // a failed open must stay retryable, not be cached as "in progress" forever
      Database.opening = null;
      throw e;
    }
  }

  static requireStore(): relationalStore.RdbStore {
    const store = Database.store;
    if (store === null) {
      throw new Error('Database.init(context) must be called before use');
    }
    return store;
  }

  static async execute(sql: string, args?: relationalStore.ValueType[]): Promise<void> {
    await Database.requireStore().executeSql(sql, args);
  }

  // RdbStore.insert does NOT throw on every failure — the SDK documents it as "The row ID if
  // the operation is successful. return -1 otherwise", so a failed row resolves like a good
  // one and every caller's await sails past it. Turn that -1 into the error it is.
  static async insert(table: string, values: relationalStore.ValuesBucket): Promise<number> {
    const rowId: number = await Database.requireStore().insert(table, values,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    if (rowId < 0) {
      throw new Error('insert into ' + table + ' failed (rowId ' + rowId + ')');
    }
    return rowId;
  }

  // Runs the query, walks the cursor through mapRow, ALWAYS closes the ResultSet.
  static async query<T>(sql: string, args: relationalStore.ValueType[], mapRow: RowMapper<T>): Promise<T[]> {
    const rs: relationalStore.ResultSet = await Database.requireStore().querySql(sql, args);
    const out: T[] = [];
    try {
      while (rs.goToNextRow()) {
        out.push(mapRow(rs));
      }
      return out;
    } finally {
      rs.close();
    }
  }

  static async queryCount(sql: string, args: relationalStore.ValueType[]): Promise<number> {
    const rs: relationalStore.ResultSet = await Database.requireStore().querySql(sql, args);
    try {
      if (rs.goToNextRow()) {
        return rs.getLong(0);
      }
      return 0;
    } finally {
      rs.close();
    }
  }

  // --- typed column helpers for RowMappers ---
  // NULL columns are the normal case here: a row created by an upsert that only writes the
  // columns it has (e.g. WMFArticle on a first visit) leaves most of the table NULL. The SDK
  // does NOT promise a quiet read of those — getString/getLong/getDouble AND isColumnNull are
  // each declared "@throws 14800013 - The column value is null or the column type is
  // incompatible", and getString's own text says "the implementation class determines whether
  // to throw an exception if the value ... is null". So the isColumnNull pre-check cannot be
  // the guard: it is one of the calls that throws. Read inside try/catch and treat an
  // unreadable column as absent — one throw here used to abort a whole mapper, which surfaced
  // as an empty list rather than an error.
  static colString(rs: relationalStore.ResultSet, name: string): string | null {
    try {
      const index: number = rs.getColumnIndex(name);
      if (rs.isColumnNull(index)) {
        return null;
      }
      return rs.getString(index);
    } catch (e) {
      return null;
    }
  }

  static colLong(rs: relationalStore.ResultSet, name: string): number | null {
    try {
      const index: number = rs.getColumnIndex(name);
      if (rs.isColumnNull(index)) {
        return null;
      }
      return rs.getLong(index);
    } catch (e) {
      return null;
    }
  }

  static colDouble(rs: relationalStore.ResultSet, name: string): number | null {
    try {
      const index: number = rs.getColumnIndex(name);
      if (rs.isColumnNull(index)) {
        return null;
      }
      return rs.getDouble(index);
    } catch (e) {
      return null;
    }
  }

  static colBool(rs: relationalStore.ResultSet, name: string): boolean {
    return (Database.colLong(rs, name) ?? 0) !== 0;
  }
}
