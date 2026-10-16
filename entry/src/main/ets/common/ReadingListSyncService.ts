// svc_reading_lists — ported from WMF Framework/ReadingListsAPIController.swift.
// REST base: https://en.wikipedia.org/api/rest_v1/data/lists (builder at :134-135).
// Writes carry a csrf_token query parameter fetched via meta=tokens (requestWithCSRF, :156).
// Synced lists/entries are persisted into the ReadingList / ReadingListEntry tables so the
// saved screens read local rows (the CoreData sync split in the source).
// PUT/DELETE are not exposed by HttpClient, so requests go over @ohos.net.http directly,
// reusing HttpClient's cookie jar and default headers semantics; destroyed in finally.

import { http } from '@kit.NetworkKit';
import { relationalStore } from '@kit.ArkData';
import { HttpClient, HttpError, versionedUserAgent } from './HttpClient';
import { AuthService, TokenType } from './AuthService';
import { Database } from './Database';
import { SavedStore } from './SavedStore';
import { SessionStore } from './SessionStore';
import { Prefs } from './Prefs';
import { ReadingList, ReadingListRow } from '../model/ReadingList';
import { ReadingListEntry, ReadingListEntryRow } from '../model/ReadingListEntry';

const SYNC_HOST: string = 'en.wikipedia.org';
const BASE_URL: string = 'https://en.wikipedia.org/api/rest_v1/data/lists';
// Settings > Article storage and syncing ("Sync saved articles and lists"); local changes are
// only sent while it is on, as the source's ReadingListsSyncOperation only runs then.
const SYNC_ENABLED_KEY: string = 'WMFIsSyncEnabled';

// Row errorCode values (the source's APIReadingListError cases kept on the row).
export const ENTRY_LIMIT_ERROR: string = 'entryLimit';
// AppStorage: the local row id of the default list that just hit its entry limit
export const ENTRIES_LIMIT_REACHED_LIST_KEY: string = 'WMFEntriesLimitReachedReadingList';
export const LIST_LIMIT_ERROR: string = 'listLimit';

// The API's error key ("title" of the problem JSON), e.g. readinglists-db-error-entry-limit.
function apiErrorKey(e: Error): string {
  const m: RegExpMatchArray | null = e.message.match(/readinglists-[a-z-]+/);
  return m !== null ? m[0] : '';
}

// Keys arrive both percent-encoded and raw, with spaces or underscores; compare one form.
function normalizedKey(key: string): string {
  let out: string = key;
  try {
    out = decodeURIComponent(key);
  } catch (e) {
    // a bare % in a title: keep the raw text
  }
  return out.replace(/ /g, '_');
}

// https://tr.wikipedia.org/wiki/İstanbul -> project https://tr.wikipedia.org, title İstanbul.
function projectAndTitle(key: string): string[] {
  const i: number = key.indexOf('/wiki/');
  return i < 0 ? [] : [key.substring(0, i), normalizedKey(key.substring(i + 6)).replace(/_/g, ' ')];
}

class LocalEntryRow {
  rid: number = 0;
  articleKey: string = '';
  entryID: number = 0;
  listID: number = 0;
  deleted: boolean = false;
}

class LocalListRow {
  rid: number = 0;
  name: string = '';
  description: string = '';
  listID: number = 0;
}

function mapEntry(rs: relationalStore.ResultSet): LocalEntryRow {
  const r = new LocalEntryRow();
  r.rid = Database.colLong(rs, 'rid') ?? 0;
  r.articleKey = Database.colString(rs, 'articleKey') ?? '';
  r.entryID = Database.colLong(rs, 'entryID') ?? 0;
  r.listID = Database.colLong(rs, 'lid') ?? 0;
  r.deleted = Database.colBool(rs, 'isDeletedLocally');
  return r;
}

function mapList(rs: relationalStore.ResultSet): LocalListRow {
  const r = new LocalListRow();
  r.rid = Database.colLong(rs, 'rid') ?? 0;
  r.name = Database.colString(rs, 'canonicalName') ?? '';
  r.description = Database.colString(rs, 'readingListDescription') ?? '';
  r.listID = Database.colLong(rs, 'lid') ?? 0;
  return r;
}

interface CreateListBody {
  name: string;
  description: string;
}

interface CreateEntryBody {
  project: string;
  title: string;
}

// APIReadingList (ReadingListsAPIController.swift:49) — the JSON key "default" is a keyword,
// so it is renamed to isDefault in the response text before parsing.
interface ApiReadingListJson {
  id?: number;
  name?: string;
  description?: string;
  created?: string;
  updated?: string;
  deleted?: boolean;
  isDefault?: boolean;                             // JSON: "default" (renamed pre-parse)
}

// APIReadingListEntry (ReadingListsAPIController.swift:74).
interface ApiReadingListEntryJson {
  id?: number;
  project?: string;
  title?: string;
  created?: string;
  updated?: string;
  listId?: number;
  deleted?: boolean;
}

// APIReadingLists / APIReadingListEntries / APIReadingListChanges envelopes.
interface ApiListsResponseJson {
  lists?: ApiReadingListJson[];
  entries?: ApiReadingListEntryJson[];
  next?: string;
  since?: string;
}

interface ApiCreateResponseJson {
  id?: number;
}

function renameDefaultKey(text: string): string {
  return text.split('"default":').join('"isDefault":');
}

export class ReadingListSyncResult {
  lists: ReadingList[] = [];
  entries: ReadingListEntry[] = [];
  nextSince: string | null = null;
}

function parseIsoDate(value: string | undefined): number {
  if (value === undefined || value === '') {
    return 0;
  }
  return new Date(value).getTime();
}

function listFromApiItem(item: ApiReadingListJson): ReadingList {
  const row: ReadingListRow = {
    canonicalName: item.name ?? '',
    color: '',
    countOfEntries: 0,
    createdDate: parseIsoDate(item.created),
    errorCode: '',
    iconName: '',
    imageName: '',
    isDefault: item.isDefault === true ? 1 : 0,
    isDeletedLocally: 0,
    isUpdatedLocally: 0,
    readingListDescription: item.description ?? '',
    readingListID: item.id ?? 0,
    updatedDate: parseIsoDate(item.updated),
    sortOrder: 0
  };
  return ReadingList.fromRow(row);
}

function entryFromApiItem(item: ApiReadingListEntryJson): ReadingListEntry {
  const project: string = item.project ?? '';
  const title: string = item.title ?? '';
  const row: ReadingListEntryRow = {
    readingListEntryID: item.id ?? 0,
    createdDate: parseIsoDate(item.created),
    updatedDate: parseIsoDate(item.updated),
    displayTitle: title.replace(/_/g, ' '),
    listID: item.listId ?? 0,
    articleKey: project + '/wiki/' + title,
    variant: '',
    isDeletedLocally: 0,
    isUpdatedLocally: 0,
    errorCode: ''
  };
  return ReadingListEntry.fromRow(row);
}

export class ReadingListSyncService {
  // Raw request against the reading-lists REST API. Body (when present) is JSON.
  private static async request(url: string, method: http.RequestMethod,
    bodyJson: string | null): Promise<string> {
    const req = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Accept': 'application/json; charset=utf-8',
        'User-Agent': versionedUserAgent()
      };
      const cookie: string = HttpClient.cookieJar.headerValue();
      if (cookie !== '') {
        headers['Cookie'] = cookie;
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      };
      if (bodyJson !== null) {
        headers['Content-Type'] = 'application/json';
        options.extraData = bodyJson;
      }
      const resp: http.HttpResponse = await req.request(url, options);
      if (resp.responseCode >= 400) {
        // the body carries the API's error key (readinglists-db-error-entry-limit, ...)
        throw new HttpError('HTTP ' + resp.responseCode + ' for ' + url + ': ' + String(resp.result),
          resp.responseCode);
      }
      return resp.result as string;
    } finally {
      req.destroy();
    }
  }

  // Source: requestWithCSRF (:156) — the csrf token rides as a csrf_token query parameter.
  private static async writeURL(path: string): Promise<string> {
    const token: string = await AuthService.fetchToken(SYNC_HOST, TokenType.csrf);
    return BASE_URL + path + (path.indexOf('?') >= 0 ? '&' : '?') +
      'csrf_token=' + encodeURIComponent(token);
  }

  // Source: setupReadingLists (:202) — POST data/lists/setup.
  static async setup(): Promise<void> {
    const url: string = await ReadingListSyncService.writeURL('/setup');
    // an empty JSON body: a body-less POST goes out without Content-Length and the API
    // answers 411 Length Required, so sync could never be turned on or off
    await ReadingListSyncService.request(url, http.RequestMethod.POST, '{}');
  }

  // Source: teardownReadingLists (:210) — POST data/lists/teardown.
  static async teardown(): Promise<void> {
    const url: string = await ReadingListSyncService.writeURL('/teardown');
    // an empty JSON body: a body-less POST goes out without Content-Length and the API
    // answers 411 Length Required, so sync could never be turned on or off
    await ReadingListSyncService.request(url, http.RequestMethod.POST, '{}');
    await ReadingListSyncService.forgetServerIds();
  }

  // Source: getAllReadingLists (:517) — GET data/lists/ (paged by next).
  static async fetchAllLists(): Promise<ReadingList[]> {
    const out: ReadingList[] = [];
    let next: string | null = null;
    do {
      let url: string = BASE_URL + '/';
      if (next !== null) {
        url = url + '?next=' + encodeURIComponent(next);
      }
      const text: string = await ReadingListSyncService.request(url, http.RequestMethod.GET, null);
      const root: ApiListsResponseJson =
        HttpClient.parseJson<ApiListsResponseJson>(renameDefaultKey(text));
      const listsJson: ApiReadingListJson[] = root.lists ?? [];
      for (const item of listsJson) {
        out.push(listFromApiItem(item));
      }
      next = root.next ?? null;
    } while (next !== null);
    return out;
  }

  // Source: getAllEntriesForReadingListWithID (:539) — GET data/lists/{id}/entries/.
  static async fetchEntries(readingListID: number): Promise<ReadingListEntry[]> {
    const out: ReadingListEntry[] = [];
    let next: string | null = null;
    do {
      let url: string = BASE_URL + '/' + String(readingListID) + '/entries/';
      if (next !== null) {
        url = url + '?next=' + encodeURIComponent(next);
      }
      const text: string = await ReadingListSyncService.request(url, http.RequestMethod.GET, null);
      const root: ApiListsResponseJson = HttpClient.parseJson<ApiListsResponseJson>(text);
      const entriesJson: ApiReadingListEntryJson[] = root.entries ?? [];
      for (const item of entriesJson) {
        out.push(entryFromApiItem(item));
      }
      next = root.next ?? null;
    } while (next !== null);
    return out;
  }

  // Source: updatedListsAndEntries (:477) — GET data/lists/changes/since/{date}.
  static async fetchChangesSince(since: string): Promise<ReadingListSyncResult> {
    const out = new ReadingListSyncResult();
    const url: string = BASE_URL + '/changes/since/' + encodeURIComponent(since);
    const text: string = await ReadingListSyncService.request(url, http.RequestMethod.GET, null);
    const root: ApiListsResponseJson =
      HttpClient.parseJson<ApiListsResponseJson>(renameDefaultKey(text));
    const listsJson: ApiReadingListJson[] = root.lists ?? [];
    for (const item of listsJson) {
      out.lists.push(listFromApiItem(item));
    }
    const entriesJson: ApiReadingListEntryJson[] = root.entries ?? [];
    for (const item of entriesJson) {
      out.entries.push(entryFromApiItem(item));
    }
    out.nextSince = root.since ?? null;
    return out;
  }

  // Source: createList (:228) — POST data/lists/ with {name, description}; returns the id.
  static async createList(name: string, description: string): Promise<number> {
    const body: CreateListBody = { name: name, description: description };
    const url: string = await ReadingListSyncService.writeURL('/');
    const text: string = await ReadingListSyncService.request(url, http.RequestMethod.POST,
      JSON.stringify(body));
    const root: ApiCreateResponseJson = HttpClient.parseJson<ApiCreateResponseJson>(text);
    return root.id ?? 0;
  }

  // Source: deleteList (:434) — DELETE data/lists/{id}.
  static async deleteList(listID: number): Promise<void> {
    const url: string = await ReadingListSyncService.writeURL('/' + String(listID));
    await ReadingListSyncService.request(url, http.RequestMethod.DELETE, null);
  }

  // Source: addEntryToList (:308) — POST data/lists/{id}/entries/ with {project, title}.
  static async addEntry(listID: number, project: string, title: string): Promise<number> {
    const body: CreateEntryBody = { project: project, title: title };
    const url: string = await ReadingListSyncService.writeURL('/' + String(listID) + '/entries/');
    const text: string = await ReadingListSyncService.request(url, http.RequestMethod.POST,
      JSON.stringify(body));
    const root: ApiCreateResponseJson = HttpClient.parseJson<ApiCreateResponseJson>(text);
    return root.id ?? 0;
  }

  // Source: removeEntry (:416) — DELETE data/lists/{id}/entries/{entryId}.
  static async removeEntry(listID: number, entryID: number): Promise<void> {
    const url: string = await ReadingListSyncService.writeURL(
      '/' + String(listID) + '/entries/' + String(entryID));
    await ReadingListSyncService.request(url, http.RequestMethod.DELETE, null);
  }

  // Two-way sync (the source's ReadingListsSyncOperation, without its changes/since shortcut).
  // It used to only download: lists and articles saved here never reached the account, and a
  // list deleted here came back on the next sync. Order matters:
  //   1. local deletions go up first, so the download below cannot bring them back;
  //   2. the server's lists map onto local rows (the default list gets its server id);
  //   3. lists created here are created on the server;
  //   4. the server's entries map onto local rows by article (they get their entry ids);
  //   5. entries still without an id are new here and are added on the server.
  // ponytail: one request per change; the API's entries/batch endpoint when volumes need it.
  // A local change syncs about a second later (bursts coalesce). A change made while a sync
  // is running is not dropped: it marks the sync pending, and one more sync runs when the
  // current one ends (its own writes can mark it too; that follow-up finds nothing new and
  // stops). Callers asking for a sync during one share the running sync.
  private static running: Promise<ReadingListSyncResult> | null = null;
  private static pending: boolean = false;
  private static syncTimer: number = -1;

  static scheduleSync(): void {
    if (!SessionStore.isLoggedIn || !Prefs.getBoolean(SYNC_ENABLED_KEY, false)) {
      console.info('reading lists: change not synced (logged in ' + SessionStore.isLoggedIn + ', sync ' +
        Prefs.getBoolean(SYNC_ENABLED_KEY, false) + ')');
      return;
    }
    if (ReadingListSyncService.running !== null) {
      ReadingListSyncService.pending = true;
      return;
    }
    clearTimeout(ReadingListSyncService.syncTimer);
    ReadingListSyncService.syncTimer = setTimeout(() => {
      ReadingListSyncService.syncToDatabase().catch((e: Error) => {
        console.error('reading lists: change sync failed: ' + e.message);
      });
    }, 1000);
  }

  static syncToDatabase(): Promise<ReadingListSyncResult> {
    if (ReadingListSyncService.running !== null) {
      ReadingListSyncService.pending = true;
      return ReadingListSyncService.running;
    }
    ReadingListSyncService.pending = false;
    const run: Promise<ReadingListSyncResult> = ReadingListSyncService.syncOnce().finally(() => {
      ReadingListSyncService.running = null;
      if (ReadingListSyncService.pending) {
        ReadingListSyncService.pending = false;
        ReadingListSyncService.scheduleSync();
      }
    });
    ReadingListSyncService.running = run;
    return run;
  }

  private static async syncOnce(): Promise<ReadingListSyncResult> {
    await ReadingListSyncService.removeSyncDuplicates();
    const push: boolean = Prefs.getBoolean(SYNC_ENABLED_KEY, false);
    const out = new ReadingListSyncResult();
    if (push) {
      await ReadingListSyncService.pushDeletions();
    }
    // fetched after the deletions went up, so lists just deleted are not stored back
    out.lists = await ReadingListSyncService.fetchAllLists();
    // a list that has a server id the server no longer has was deleted on another device (or
    // by a teardown elsewhere): the server is the source of truth, so it goes here too
    await ReadingListSyncService.dropListsGoneFromServer(out.lists);
    const rowIds: number[] = [];
    for (const list of out.lists) {
      rowIds.push(await ReadingListSyncService.upsertList(list));
    }
    if (push) {
      await ReadingListSyncService.pushCreatedLists();
    }
    for (let i: number = 0; i < out.lists.length; i++) {
      const listID: number = out.lists[i].readingListID ?? 0;
      if (listID === 0) {
        continue;
      }
      const entries: ReadingListEntry[] = await ReadingListSyncService.fetchEntries(listID);
      for (const entry of entries) {
        await ReadingListSyncService.storeServerEntry(rowIds[i], entry);
        out.entries.push(entry);
      }
    }
    if (push) {
      await ReadingListSyncService.pushNewEntries();
    }
    return out;
  }

  private static async dropListsGoneFromServer(serverLists: ReadingList[]): Promise<void> {
    const live: string = serverLists.map((l: ReadingList): string => String(l.readingListID ?? -1)).join(',');
    const gone: number[] = await ReadingListSyncService.rowIds(
      'SELECT rowid AS rid FROM ReadingList WHERE isDefault = 0 AND readingListID IS NOT NULL' +
        (live !== '' ? ' AND readingListID NOT IN (' + live + ')' : ''), []);
    for (const rid of gone) {
      const keys: string[] = await Database.query<string>(
        'SELECT DISTINCT articleKey FROM ReadingListEntry WHERE listID = ? AND articleKey IS NOT NULL', [rid],
        (rs: relationalStore.ResultSet): string => rs.getString(rs.getColumnIndex('articleKey')));
      await Database.execute('DELETE FROM ReadingListEntry WHERE listID = ?', [rid]);
      await Database.execute('DELETE FROM ReadingList WHERE rowid = ?', [rid]);
      // an article on no other list is no longer saved (delete(readingLists:))
      for (const key of keys) {
        const live2: number = await Database.queryCount(
          'SELECT COUNT(*) FROM ReadingListEntry WHERE articleKey = ? AND isDeletedLocally = 0', [key]);
        if (live2 === 0) {
          await Database.execute('UPDATE WMFArticle SET savedDate = NULL WHERE key = ?', [key]);
        }
      }
    }
  }

  // After a teardown the server holds none of these ids: forget them, so turning sync back on
  // uploads the local lists and entries as new instead of addressing deleted ones.
  static async forgetServerIds(): Promise<void> {
    await Database.execute('DELETE FROM ReadingListEntry WHERE isDeletedLocally = 1');
    await Database.execute('DELETE FROM ReadingList WHERE isDeletedLocally = 1');
    await Database.execute('UPDATE ReadingListEntry SET readingListEntryID = NULL, isUpdatedLocally = 1');
    await Database.execute('UPDATE ReadingList SET readingListID = NULL, isUpdatedLocally = 1');
  }

  // A server entry onto the local list row: the matching local entry takes its id (and is no
  // longer a local change); one the device lacks is added. One deleted here is left alone,
  // its deletion goes up on the next sync.
  private static async storeServerEntry(listRowId: number, entry: ReadingListEntry): Promise<void> {
    const key: string = entry.articleKey ?? '';
    if (key === '') {
      return;
    }
    const want: string = normalizedKey(key);
    const local: LocalEntryRow[] = await Database.query<LocalEntryRow>(
      'SELECT rowid AS rid, articleKey, readingListEntryID AS entryID, listID AS lid, isDeletedLocally ' +
        'FROM ReadingListEntry WHERE listID = ?', [listRowId], mapEntry);
    const match: LocalEntryRow | undefined =
      local.find((r: LocalEntryRow): boolean => normalizedKey(r.articleKey) === want && !r.deleted) ??
        local.find((r: LocalEntryRow): boolean => normalizedKey(r.articleKey) === want);
    if (match !== undefined && match.deleted) {
      return;
    }
    if (match === undefined) {
      await SavedStore.addArticleToList(listRowId, key, entry.variant, entry.displayTitle);
    }
    await Database.execute('UPDATE ReadingListEntry SET readingListEntryID = ?, isUpdatedLocally = 0, ' +
      'errorCode = NULL WHERE listID = ? AND articleKey = ? AND isDeletedLocally = 0',
      [entry.readingListEntryID ?? null, listRowId, match !== undefined ? match.articleKey : key]);
  }

  // Lists and entries deleted here: removed on the server, then dropped locally. An entry
  // saved before entries kept their server id is looked up in its list's entries.
  private static async pushDeletions(): Promise<void> {
    const lists: LocalListRow[] = await Database.query<LocalListRow>(
      'SELECT rowid AS rid, canonicalName, readingListDescription, readingListID AS lid FROM ReadingList ' +
        'WHERE isDeletedLocally = 1', [], mapList);
    for (const l of lists) {
      if (l.listID !== 0) {
        await ReadingListSyncService.ignoringGone(ReadingListSyncService.deleteList(l.listID));
      }
      await Database.execute('DELETE FROM ReadingListEntry WHERE listID = ?', [l.rid]);
      await Database.execute('DELETE FROM ReadingList WHERE rowid = ?', [l.rid]);
    }
    const entries: LocalEntryRow[] = await Database.query<LocalEntryRow>(
      'SELECT e.rowid AS rid, e.articleKey, e.readingListEntryID AS entryID, l.readingListID AS lid, ' +
        'e.isDeletedLocally FROM ReadingListEntry e LEFT JOIN ReadingList l ON e.listID = l.rowid ' +
        'WHERE e.isDeletedLocally = 1', [], mapEntry);
    const serverEntries: Map<number, ReadingListEntry[]> = new Map<number, ReadingListEntry[]>();
    for (const e of entries) {
      let entryID: number = e.entryID;
      if (entryID === 0 && e.listID !== 0) {
        if (!serverEntries.has(e.listID)) {
          serverEntries.set(e.listID, await ReadingListSyncService.fetchEntries(e.listID));
        }
        const want: string = normalizedKey(e.articleKey);
        const found: ReadingListEntry | undefined = (serverEntries.get(e.listID) ?? [])
          .find((s: ReadingListEntry): boolean => normalizedKey(s.articleKey ?? '') === want);
        entryID = found !== undefined ? (found.readingListEntryID ?? 0) : 0;
      }
      if (entryID !== 0 && e.listID !== 0) {
        await ReadingListSyncService.ignoringGone(ReadingListSyncService.removeEntry(e.listID, entryID));
      }
      await Database.execute('DELETE FROM ReadingListEntry WHERE rowid = ?', [e.rid]);
    }
  }

  // Lists made here (no server id yet). The server's list limit is kept on the row for the
  // "List not synced, limit exceeded" label; a list the server already has by that name was
  // matched to it by the download above, so it never gets here.
  private static async pushCreatedLists(): Promise<void> {
    const lists: LocalListRow[] = await Database.query<LocalListRow>(
      'SELECT rowid AS rid, canonicalName, readingListDescription, readingListID AS lid FROM ReadingList ' +
        'WHERE isDefault = 0 AND isDeletedLocally = 0 AND readingListID IS NULL ' +
        "AND (errorCode IS NULL OR errorCode = '')", [], mapList);
    for (const l of lists) {
      try {
        const id: number = await ReadingListSyncService.createList(l.name, l.description);
        await Database.execute('UPDATE ReadingList SET readingListID = ?, isUpdatedLocally = 0, errorCode = NULL ' +
          'WHERE rowid = ?', [id, l.rid]);
      } catch (e) {
        await ReadingListSyncService.recordRowError('ReadingList', l.rid, e as Error,
          'readinglists-db-error-list-limit', LIST_LIMIT_ERROR);
      }
    }
  }

  // Entries added here, in lists the server knows. The per-list entry limit is kept on the row
  // for "Article limit exceeded, unable to sync article"; such rows are not retried until the
  // list loses an entry (SavedStore clears the codes then).
  private static async pushNewEntries(): Promise<void> {
    const entries: LocalEntryRow[] = await Database.query<LocalEntryRow>(
      'SELECT e.rowid AS rid, e.articleKey, e.readingListEntryID AS entryID, l.readingListID AS lid, ' +
        'e.isDeletedLocally FROM ReadingListEntry e JOIN ReadingList l ON e.listID = l.rowid ' +
        'WHERE e.isDeletedLocally = 0 AND e.readingListEntryID IS NULL AND l.readingListID IS NOT NULL ' +
        "AND l.isDeletedLocally = 0 AND (e.errorCode IS NULL OR e.errorCode = '')", [], mapEntry);
    for (const e of entries) {
      const parts: string[] = projectAndTitle(e.articleKey);
      if (parts.length === 0) {
        continue;
      }
      try {
        const id: number = await ReadingListSyncService.addEntry(e.listID, parts[0], parts[1]);
        await Database.execute('UPDATE ReadingListEntry SET readingListEntryID = ?, isUpdatedLocally = 0, ' +
          'errorCode = NULL WHERE rowid = ?', [id, e.rid]);
      } catch (err) {
        await ReadingListSyncService.recordRowError('ReadingListEntry', e.rid, err as Error,
          'readinglists-db-error-entry-limit', ENTRY_LIMIT_ERROR);
        await ReadingListSyncService.announceDefaultListLimit(e.rid);
      }
    }
  }

  // ReadingList.entriesLimitReachedNotification: an entry the default list refused for its
  // limit tells the app frame, which shows "Limit hit for unsorted articles" once.
  private static async announceDefaultListLimit(entryRowId: number): Promise<void> {
    const rows: LocalEntryRow[] = await Database.query<LocalEntryRow>(
      'SELECT e.rowid AS rid, e.articleKey, e.readingListEntryID AS entryID, l.rowid AS lid, ' +
        'e.isDeletedLocally FROM ReadingListEntry e JOIN ReadingList l ON e.listID = l.rowid ' +
        'WHERE e.rowid = ? AND e.errorCode = ? AND l.isDefault = 1', [entryRowId, ENTRY_LIMIT_ERROR], mapEntry);
    if (rows.length > 0) {
      AppStorage.setOrCreate<number>(ENTRIES_LIMIT_REACHED_LIST_KEY, rows[0].listID);
    }
  }

  // A limit answer is kept on the row; any other API refusal is logged and retried next sync;
  // a transport failure stops the sync so nothing is marked wrongly.
  private static async recordRowError(table: string, rowId: number, e: Error, limitKey: string,
    code: string): Promise<void> {
    const key: string = apiErrorKey(e);
    if (key === limitKey) {
      await Database.execute('UPDATE ' + table + ' SET errorCode = ? WHERE rowid = ?', [code, rowId]);
      return;
    }
    if (!(e instanceof HttpError)) {
      throw e;
    }
    console.error('reading lists: server refused ' + table + ' ' + rowId + ': ' + (key !== '' ? key : e.message));
  }

  // Deleting what the server no longer has (404, or a gone list/entry) counts as done.
  private static async ignoringGone(call: Promise<void>): Promise<void> {
    try {
      await call;
    } catch (e) {
      if (!(e instanceof HttpError) || (e.responseCode !== 404 && apiErrorKey(e).indexOf('deleted') < 0 &&
        apiErrorKey(e).indexOf('not-found') < 0 && apiErrorKey(e).indexOf('no-such') < 0)) {
        throw e;
      }
    }
  }

  private static rowIds(sql: string, args: relationalStore.ValueType[]): Promise<number[]> {
    return Database.query<number>(sql, args, (rs: relationalStore.ResultSet): number =>
      Database.colLong(rs, 'rid') ?? 0);
  }

  // The local row a server list maps to: the default list for the server's default, otherwise
  // the list with its server id or its name; a list the store does not have yet is inserted.
  private static async upsertList(list: ReadingList): Promise<number> {
    const found: number[] = list.isDefault
      ? await ReadingListSyncService.rowIds(
        'SELECT rowid AS rid FROM ReadingList WHERE isDefault = 1 ORDER BY rowid LIMIT 1', [])
      : await ReadingListSyncService.rowIds(
        'SELECT rowid AS rid FROM ReadingList WHERE isDeletedLocally = 0 AND ' +
          '(readingListID = ? OR canonicalName = ?) ORDER BY rowid LIMIT 1',
        [list.readingListID ?? -1, list.canonicalName ?? '']);
    if (found.length > 0) {
      await Database.execute('UPDATE ReadingList SET readingListID = ?, updatedDate = ? WHERE rowid = ?',
        [list.readingListID ?? null, list.updatedDate ?? Date.now(), found[0]]);
      return found[0];
    }
    const listValues: relationalStore.ValuesBucket = {
      'canonicalName': list.canonicalName,
      'color': list.color,
      'countOfEntries': 0,
      'createdDate': list.createdDate,
      'errorCode': list.errorCode,
      'iconName': list.iconName,
      'imageName': list.imageName,
      'isDefault': list.isDefault ? 1 : 0,
      'isDeletedLocally': 0,
      'isUpdatedLocally': 0,
      'readingListDescription': list.readingListDescription,
      'readingListID': list.readingListID,
      'updatedDate': list.updatedDate,
      'sortOrder': list.sortOrder
    };
    return Database.insert('ReadingList', listValues);
  }

  // Cleans what the old insert-only sync left behind: extra default lists, repeated server
  // lists, and entries filed under list ids that are not local rows.
  private static async removeSyncDuplicates(): Promise<void> {
    await Database.execute('DELETE FROM ReadingList WHERE isDefault = 1 AND rowid NOT IN ' +
      '(SELECT MIN(rowid) FROM ReadingList WHERE isDefault = 1)');
    await Database.execute('DELETE FROM ReadingList WHERE isDefault = 0 AND readingListID IS NOT NULL ' +
      'AND rowid NOT IN (SELECT MIN(rowid) FROM ReadingList WHERE isDefault = 0 AND readingListID IS NOT NULL ' +
      'GROUP BY readingListID)');
    await Database.execute('DELETE FROM ReadingListEntry WHERE listID NOT IN (SELECT rowid FROM ReadingList)');
  }

}

// every local list change (save, unsave, add, remove, create, delete) schedules a sync
SavedStore.onLocalChange = (): void => {
  ReadingListSyncService.scheduleSync();
};
