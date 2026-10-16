// svc_saved_store — saved pages (WMFArticle.savedDate) with ReadingList default-list
// semantics. Ported from:
//   Wikipedia/Code/MWKSavedPageList.m                (list fetch/toggle)
//   Wikipedia/Code/ReadingListsController.swift      (userSave/userUnsave,
//     addToDefaultReadingList, unsave marks entries deleted, createReadingList)
//   WMF Framework/ReadingList+CoreDataClass.swift    (updateArticlesAndEntries counts)
// Saving also downloads an offline copy via ArticleCacheStore (SavedArticlesFetcher).

import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { ArticleCacheStore } from './ArticleCacheStore';
import { ArticleService } from './ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { ARTICLE_COLUMNS, mapArticleRow } from './HistoryStore';
import { WMFArticle } from '../model/WMFArticle';
import { ReadingList } from '../model/ReadingList';
import { ReadingListEntry } from '../model/ReadingListEntry';

// wmf_readingListsConfigMaxEntriesPerList: the source's default, which is also the server's
// per-list cap. ponytail: fixed, not read from the lists config; read it if the server changes it.
export const MAX_ENTRIES_PER_LIST: number = 5000;

const LIST_COLUMNS: string =
  'rowid AS listRowId, canonicalName, color, countOfEntries, createdDate, errorCode, ' +
  'iconName, imageName, isDefault, isDeletedLocally, isUpdatedLocally, ' +
  'readingListDescription, readingListID, updatedDate, sortOrder';

const ENTRY_COLUMNS: string =
  'readingListEntryID, createdDate, updatedDate, displayTitle, listID, articleKey, ' +
  'variant, isDeletedLocally, isUpdatedLocally, errorCode';

// Local list handle: the ReadingList row plus its rowid (entries reference it via listID).
// One reading-list tag under a saved article.
export class ReadingListTag {
  articleKey: string = '';
  listRowId: number = 0;
  name: string = '';
}

export class ReadingListWithId {
  listRowId: number = 0;
  list: ReadingList = new ReadingList();
}

function mapListRow(rs: relationalStore.ResultSet): ReadingListWithId {
  const out = new ReadingListWithId();
  out.listRowId = Database.colLong(rs, 'listRowId') ?? 0;
  const list = new ReadingList();
  list.canonicalName = Database.colString(rs, 'canonicalName');
  list.color = Database.colString(rs, 'color');
  list.countOfEntries = Database.colLong(rs, 'countOfEntries') ?? 0;
  list.createdDate = Database.colLong(rs, 'createdDate');
  list.errorCode = Database.colString(rs, 'errorCode');
  list.iconName = Database.colString(rs, 'iconName');
  list.imageName = Database.colString(rs, 'imageName');
  list.isDefault = Database.colBool(rs, 'isDefault');
  list.isDeletedLocally = Database.colBool(rs, 'isDeletedLocally');
  list.isUpdatedLocally = Database.colBool(rs, 'isUpdatedLocally');
  list.readingListDescription = Database.colString(rs, 'readingListDescription');
  list.readingListID = Database.colLong(rs, 'readingListID');
  list.updatedDate = Database.colLong(rs, 'updatedDate');
  list.sortOrder = Database.colLong(rs, 'sortOrder');
  out.list = list;
  return out;
}

function mapEntryRow(rs: relationalStore.ResultSet): ReadingListEntry {
  const out = new ReadingListEntry();
  out.readingListEntryID = Database.colLong(rs, 'readingListEntryID');
  out.createdDate = Database.colLong(rs, 'createdDate');
  out.updatedDate = Database.colLong(rs, 'updatedDate');
  out.displayTitle = Database.colString(rs, 'displayTitle');
  out.listID = Database.colLong(rs, 'listID');
  out.articleKey = Database.colString(rs, 'articleKey');
  out.variant = Database.colString(rs, 'variant');
  out.isDeletedLocally = Database.colBool(rs, 'isDeletedLocally');
  out.isUpdatedLocally = Database.colBool(rs, 'isUpdatedLocally');
  out.errorCode = Database.colString(rs, 'errorCode');
  return out;
}

// The article key is https://{host}/wiki/{title}; the cache hook needs host + title.
function hostFromArticleKey(articleKey: string): string {
  return articleKey.replace('https://', '').replace('http://', '').split('/')[0];
}

function titleFromArticleKey(articleKey: string): string {
  const marker: string = '/wiki/';
  const index: number = articleKey.indexOf(marker);
  if (index < 0) {
    return '';
  }
  return decodeURIComponent(articleKey.substring(index + marker.length));
}

// ArticleError.apiFailed
export const ARTICLE_ERROR_API_FAILED: number = 2;

export class SavedStore {
  // ReadingListsController's change-triggered sync: set by ReadingListSyncService (it imports
  // this file, so the hook keeps the import one-way). Called after every local list change.
  static onLocalChange: (() => void) | null = null;

  // Screens that list reading lists (the Saved tab is a component inside Index, so it gets
  // no onPageShow when a pushed page returns): told after every local list change.
  private static observers: (() => void)[] = [];

  static addObserver(observer: () => void): void {
    SavedStore.observers.push(observer);
  }

  static removeObserver(observer: () => void): void {
    SavedStore.observers = SavedStore.observers.filter((o: () => void) => o !== observer);
  }

  private static changed(): void {
    if (SavedStore.onLocalChange !== null) {
      SavedStore.onLocalChange();
    }
    for (const o of SavedStore.observers) {
      o();
    }
  }

  // --- MWKSavedPageList ---

  // savedPageListFetchRequest — savedDate != NULL, savedDate DESC.
  static async savedArticles(): Promise<WMFArticle[]> {
    return await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE savedDate IS NOT NULL ' +
      'ORDER BY savedDate DESC', [], mapArticleRow);
  }

  // numberOfItems.
  static async numberOfItems(): Promise<number> {
    return await Database.queryCount(
      'SELECT COUNT(*) FROM WMFArticle WHERE savedDate IS NOT NULL', []);
  }

  // mostRecentEntry.
  static async mostRecentEntry(): Promise<WMFArticle | null> {
    const rows: WMFArticle[] = await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE savedDate IS NOT NULL ' +
      'ORDER BY savedDate DESC LIMIT 1', [], mapArticleRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // entryForURL / isAnyVariantSaved.
  static async isSaved(articleKey: string): Promise<boolean> {
    const count: number = await Database.queryCount(
      'SELECT COUNT(*) FROM WMFArticle WHERE key = ? AND savedDate IS NOT NULL', [articleKey]);
    return count > 0;
  }

  // toggleSavedPageForURL — save when unsaved, unsave when saved; returns the new state.
  static async toggleSave(articleKey: string, variant: string | null,
    displayTitle: string | null): Promise<boolean> {
    if (await SavedStore.isSaved(articleKey)) {
      await SavedStore.userUnsave(articleKey);
      return false;
    }
    await SavedStore.userSave(articleKey, variant, displayTitle);
    return true;
  }

  // userSave — savedDate = now on the article (created if new), plus a default-list
  // ReadingListEntry when none exists; then the offline copy download (SavedArticlesFetcher).
  static async userSave(articleKey: string, variant: string | null,
    displayTitle: string | null): Promise<void> {
    const now: number = Date.now();
    const exists: number = await Database.queryCount(
      'SELECT COUNT(*) FROM WMFArticle WHERE key = ?', [articleKey]);
    if (exists > 0) {
      await Database.execute(
        'UPDATE WMFArticle SET savedDate = ?, ' +
        'displayTitle = COALESCE(?, displayTitle), variant = COALESCE(?, variant) ' +
        'WHERE key = ?', [now, displayTitle, variant, articleKey]);
    } else {
      const values: relationalStore.ValuesBucket = {
        'key': articleKey,
        'variant': variant,
        'savedDate': now,
        'displayTitle': displayTitle
      };
      await Database.insert('WMFArticle', values);
    }

    // addToDefaultReadingList — only when no live default-list entry exists for the key.
    const defaultList: ReadingListWithId = await SavedStore.fetchOrCreateDefaultReadingList();
    const existingEntries: number = await Database.queryCount(
      'SELECT COUNT(*) FROM ReadingListEntry WHERE articleKey = ? AND listID = ? ' +
      'AND isDeletedLocally = 0', [articleKey, defaultList.listRowId]);
    if (existingEntries === 0) {
      const entryValues: relationalStore.ValuesBucket = {
        'createdDate': now,
        'updatedDate': now,
        'displayTitle': displayTitle,
        'listID': defaultList.listRowId,
        'articleKey': articleKey,
        'variant': variant,
        'isDeletedLocally': 0,
        'isUpdatedLocally': 1
      };
      await Database.insert('ReadingListEntry', entryValues);
      await SavedStore.updateCountOfEntries(defaultList.listRowId);
    }

    // The save is done once it is stored: the summary fill-in and the offline copy run in the
    // background, so the caller's saved state shows at once instead of after a full download.
    SavedStore.completeInBackground(articleKey);
    SavedStore.changed();
  }

  // Places' saved filter needs each saved article's coordinates; articles saved before they
  // were stored get them here, one prop=coordinates query per wiki (50 titles a request).
  // ponytail: an article with no coordinates is asked again on every Saved filter load.
  static async fillMissingCoordinates(articles: WMFArticle[]): Promise<void> {
    const byHost: Map<string, WMFArticle[]> = new Map<string, WMFArticle[]>();
    for (const a of articles) {
      if (a.key !== null && a.latitude === 0 && a.longitude === 0) {
        const host: string = hostFromArticleKey(a.key);
        byHost.set(host, (byHost.get(host) ?? []).concat([a]));
      }
    }
    for (const entry of byHost.entries()) {
      const host: string = entry[0];
      const list: WMFArticle[] = entry[1].slice(0, 50);
      try {
        const coords: Map<string, number[]> =
          await ArticleService.fetchCoordinates(host, list.map((a: WMFArticle) => titleFromArticleKey(a.key ?? '')));
        for (const a of list) {
          const c: number[] | undefined = coords.get(titleFromArticleKey(a.key ?? '').replace(/_/g, ' '));
          if (c !== undefined) {
            a.latitude = c[0];
            a.longitude = c[1];
            await Database.execute('UPDATE WMFArticle SET latitude = ?, longitude = ? WHERE key = ?',
              [c[0], c[1], a.key]);
          }
        }
      } catch (e) {
        console.warn('SavedStore: coordinates for ' + host + ' unavailable: ' + JSON.stringify(e));
      }
    }
  }

  // ArticleSummary fill-in (WMFArticle update(withSummary:)) - the Saved list's image and
  // description for an article saved without being opened - then SavedArticlesFetcher's
  // offline copy. Neither failure undoes the save.
  private static async completeInBackground(articleKey: string): Promise<void> {
    const host: string = hostFromArticleKey(articleKey);
    const title: string = titleFromArticleKey(articleKey);
    try {
      const summary: ArticleSummary = await ArticleService.fetchSummary(host, title);
      await Database.execute(
        'UPDATE WMFArticle SET imageURLString = COALESCE(imageURLString, ?), ' +
        'thumbnailURLString = COALESCE(thumbnailURLString, ?), ' +
        'wikidataDescription = COALESCE(wikidataDescription, ?) WHERE key = ?',
        [summary.thumbnail !== null ? summary.thumbnail.source : null,
          summary.thumbnail !== null ? summary.thumbnail.source : null, summary.articleDescription, articleKey]);
      if (summary.coordinates !== null) {
        await Database.execute('UPDATE WMFArticle SET latitude = ?, longitude = ? WHERE key = ?',
          [summary.coordinates.lat, summary.coordinates.lon, articleKey]);
      }
    } catch (e) {
      console.warn('SavedStore: summary for saved article unavailable: ' + JSON.stringify(e));
    }
    try {
      await SavedStore.downloadOffline(articleKey);
    } catch (e) {
      console.warn('SavedStore: offline copy download failed, save kept: ' + JSON.stringify(e));
    }
  }

  // userUnsave — marks every list entry for the key deleted locally (any-variant rule),
  // clears savedDate, removes the offline copy.
  static async userUnsave(articleKey: string): Promise<void> {
    const listIds: number[] = await Database.query<number>(
      'SELECT DISTINCT listID FROM ReadingListEntry WHERE articleKey = ? AND listID IS NOT NULL',
      [articleKey],
      (rs: relationalStore.ResultSet): number => rs.getLong(rs.getColumnIndex('listID')));
    await Database.execute(
      'UPDATE ReadingListEntry SET isDeletedLocally = 1, isUpdatedLocally = 1, ' +
      'updatedDate = ? WHERE articleKey = ?', [Date.now(), articleKey]);
    await Database.execute(
      'UPDATE WMFArticle SET savedDate = NULL WHERE key = ?', [articleKey]);
    for (const listId of listIds) {
      await SavedStore.updateCountOfEntries(listId);
    }
    try {
      await ArticleCacheStore.removeArticle(articleKey);
    } catch (e) {
      console.warn('SavedStore: cache removal failed: ' + JSON.stringify(e));
    }
    SavedStore.changed();
  }

  // --- ReadingListsController ---

  // fetchOrCreateDefaultReadingList.
  static async fetchOrCreateDefaultReadingList(): Promise<ReadingListWithId> {
    const rows: ReadingListWithId[] = await Database.query<ReadingListWithId>(
      'SELECT ' + LIST_COLUMNS + ' FROM ReadingList WHERE isDefault = 1 LIMIT 1',
      [], mapListRow);
    if (rows.length > 0) {
      return rows[0];
    }
    const values: relationalStore.ValuesBucket = {
      'canonicalName': ReadingList.defaultListCanonicalName,
      'countOfEntries': 0,
      'createdDate': Date.now(),
      'isDefault': 1,
      'isDeletedLocally': 0,
      'isUpdatedLocally': 0
    };
    const rowId: number = await Database.insert('ReadingList', values);
    const created: ReadingListWithId[] = await Database.query<ReadingListWithId>(
      'SELECT ' + LIST_COLUMNS + ' FROM ReadingList WHERE rowid = ?', [rowId], mapListRow);
    return created[0];
  }

  // SavedArticlesCollectionViewCell tags: for each saved article, the live non-default reading
  // lists it is in (name, list row id), in name order.
  static async listTagsByArticle(): Promise<Map<string, ReadingListTag[]>> {
    const rows: ReadingListTag[] = await Database.query<ReadingListTag>(
      'SELECT e.articleKey AS articleKey, l.rowid AS listRowId, l.canonicalName AS name ' +
      'FROM ReadingListEntry e JOIN ReadingList l ON l.rowid = e.listID ' +
      'WHERE e.isDeletedLocally = 0 AND l.isDeletedLocally = 0 AND l.isDefault = 0 ' +
      'ORDER BY l.canonicalName ASC', [], (rs: relationalStore.ResultSet): ReadingListTag => {
        const tag = new ReadingListTag();
        tag.articleKey = Database.colString(rs, 'articleKey') ?? '';
        tag.listRowId = Database.colLong(rs, 'listRowId') ?? 0;
        tag.name = Database.colString(rs, 'name') ?? '';
        return tag;
      });
    const out: Map<string, ReadingListTag[]> = new Map<string, ReadingListTag[]>();
    for (const tag of rows) {
      const list: ReadingListTag[] = out.get(tag.articleKey) ?? [];
      list.push(tag);
      out.set(tag.articleKey, list);
    }
    return out;
  }

  // SavedArticlesFetcher: the offline copy of a saved article. Articles saved on another device
  // arrive through sync without one, and kept the not-downloaded dot until opened.
  // A failed download records ArticleError.apiFailed on the article (errorCodeNumber 2) for the
  // Saved row's "Unable to sync article"; a successful one clears it.
  static async downloadOffline(articleKey: string): Promise<void> {
    try {
      await ArticleCacheStore.saveArticle(hostFromArticleKey(articleKey), titleFromArticleKey(articleKey));
    } catch (e) {
      await SavedStore.setArticleError(articleKey, ARTICLE_ERROR_API_FAILED);
      throw e as Error;
    }
    await SavedStore.setArticleError(articleKey, null);
  }

  // WMFArticle.error
  static async setArticleError(articleKey: string, code: number | null): Promise<void> {
    await Database.execute('UPDATE WMFArticle SET errorCodeNumber = ? WHERE key = ?', [code, articleKey]);
  }

  // readingLists — the visible lists (not locally deleted), default first then by name.
  static async readingLists(): Promise<ReadingListWithId[]> {
    return await Database.query<ReadingListWithId>(
      'SELECT ' + LIST_COLUMNS + ' FROM ReadingList WHERE isDeletedLocally = 0 ' +
      'ORDER BY isDefault DESC, canonicalName ASC', [], mapListRow);
  }

  // createReadingList:named:description: — name must be unique among live lists.
  static async createReadingList(name: string,
    description: string | null): Promise<ReadingListWithId> {
    const clash: number = await Database.queryCount(
      'SELECT COUNT(*) FROM ReadingList WHERE canonicalName = ? AND isDeletedLocally = 0',
      [name]);
    if (clash > 0) {
      throw new Error('listExistsWithTheSameName');
    }
    const values: relationalStore.ValuesBucket = {
      'canonicalName': name,
      'readingListDescription': description,
      'countOfEntries': 0,
      'createdDate': Date.now(),
      'updatedDate': Date.now(),
      'isDefault': 0,
      'isDeletedLocally': 0,
      'isUpdatedLocally': 1
    };
    const rowId: number = await Database.insert('ReadingList', values);
    const created: ReadingListWithId[] = await Database.query<ReadingListWithId>(
      'SELECT ' + LIST_COLUMNS + ' FROM ReadingList WHERE rowid = ?', [rowId], mapListRow);
    SavedStore.changed();
    return created[0];
  }

  // updateReadingList(_:with:newDescription:) — a non-empty name replaces the old one, the
  // description is replaced as given; the default list cannot be updated.
  static async updateReadingList(listRowId: number, name: string, description: string): Promise<void> {
    if (name.trim() !== '') {
      await Database.execute('UPDATE ReadingList SET canonicalName = ? WHERE rowid = ? AND isDefault = 0',
        [name, listRowId]);
    }
    await Database.execute('UPDATE ReadingList SET readingListDescription = ?, updatedDate = ?, ' +
      'isUpdatedLocally = 1 WHERE rowid = ? AND isDefault = 0', [description, Date.now(), listRowId]);
    SavedStore.changed();
  }

  // delete(readingLists:) — markLocalDeletion for the list and its entries; articles no
  // longer on any live list lose savedDate.
  static async deleteReadingList(listRowId: number): Promise<void> {
    const keys: string[] = await Database.query<string>(
      'SELECT DISTINCT articleKey FROM ReadingListEntry WHERE listID = ? ' +
      'AND articleKey IS NOT NULL', [listRowId],
      (rs: relationalStore.ResultSet): string => rs.getString(rs.getColumnIndex('articleKey')));
    await Database.execute(
      'UPDATE ReadingListEntry SET isDeletedLocally = 1, isUpdatedLocally = 1 ' +
      'WHERE listID = ?', [listRowId]);
    await Database.execute(
      'UPDATE ReadingList SET isDeletedLocally = 1, isUpdatedLocally = 1, countOfEntries = 0 ' +
      'WHERE rowid = ?', [listRowId]);
    // one list fewer: lists the server refused for the list limit are retried
    await Database.execute("UPDATE ReadingList SET errorCode = NULL WHERE errorCode = 'listLimit'", []);
    for (const key of keys) {
      const live: number = await Database.queryCount(
        'SELECT COUNT(*) FROM ReadingListEntry WHERE articleKey = ? AND isDeletedLocally = 0',
        [key]);
      if (live === 0) {
        await Database.execute('UPDATE WMFArticle SET savedDate = NULL WHERE key = ?', [key]);
      }
    }
    SavedStore.changed();
  }

  // add(articles:to:) — entry into a specific list; sets savedDate when first saved.
  static async addArticleToList(listRowId: number, articleKey: string, variant: string | null,
    displayTitle: string | null): Promise<void> {
    const existing: number = await Database.queryCount(
      'SELECT COUNT(*) FROM ReadingListEntry WHERE articleKey = ? AND listID = ? ' +
      'AND isDeletedLocally = 0', [articleKey, listRowId]);
    if (existing > 0) {
      return;
    }
    const now: number = Date.now();
    const entryValues: relationalStore.ValuesBucket = {
      'createdDate': now,
      'updatedDate': now,
      'displayTitle': displayTitle,
      'listID': listRowId,
      'articleKey': articleKey,
      'variant': variant,
      'isDeletedLocally': 0,
      'isUpdatedLocally': 1
    };
    await Database.insert('ReadingListEntry', entryValues);
    await SavedStore.updateCountOfEntries(listRowId);
    const saved: number = await Database.queryCount(
      'SELECT COUNT(*) FROM WMFArticle WHERE key = ? AND savedDate IS NOT NULL', [articleKey]);
    if (saved === 0) {
      await SavedStore.userSave(articleKey, variant, displayTitle);
    }
    SavedStore.changed();
  }

  // remove(articles:readingList:).
  static async removeArticleFromList(listRowId: number, articleKey: string): Promise<void> {
    await Database.execute(
      'UPDATE ReadingListEntry SET isDeletedLocally = 1, isUpdatedLocally = 1, ' +
      'updatedDate = ? WHERE listID = ? AND articleKey = ?',
      [Date.now(), listRowId, articleKey]);
    await SavedStore.updateCountOfEntries(listRowId);
    const live: number = await Database.queryCount(
      'SELECT COUNT(*) FROM ReadingListEntry WHERE articleKey = ? AND isDeletedLocally = 0',
      [articleKey]);
    if (live === 0) {
      await Database.execute('UPDATE WMFArticle SET savedDate = NULL WHERE key = ?', [articleKey]);
    }
    SavedStore.changed();
  }

  // entries(for:) — live entries of a list, newest first.
  static async entriesForList(listRowId: number): Promise<ReadingListEntry[]> {
    return await Database.query<ReadingListEntry>(
      'SELECT ' + ENTRY_COLUMNS + ' FROM ReadingListEntry WHERE listID = ? ' +
      'AND isDeletedLocally = 0 ORDER BY createdDate DESC', [listRowId], mapEntryRow);
  }

  // articles(for:) — the saved articles of one list, savedDate DESC.
  static async articlesForList(listRowId: number): Promise<WMFArticle[]> {
    return await Database.query<WMFArticle>(
      'SELECT ' + ARTICLE_COLUMNS + ' FROM WMFArticle WHERE key IN ' +
      '(SELECT articleKey FROM ReadingListEntry WHERE listID = ? AND isDeletedLocally = 0) ' +
      'ORDER BY savedDate DESC', [listRowId], mapArticleRow);
  }

  // updateArticlesAndEntries — countOfEntries = live entry count. A changed count may bring a
  // list back under the server's entry limit, so entries the server refused are retried.
  private static async updateCountOfEntries(listRowId: number): Promise<void> {
    const count: number = await Database.queryCount(
      'SELECT COUNT(*) FROM ReadingListEntry WHERE listID = ? AND isDeletedLocally = 0',
      [listRowId]);
    await Database.execute(
      'UPDATE ReadingList SET countOfEntries = ? WHERE rowid = ?', [count, listRowId]);
    await Database.execute(
      "UPDATE ReadingListEntry SET errorCode = NULL WHERE listID = ? AND errorCode = 'entryLimit'", [listRowId]);
  }
}
