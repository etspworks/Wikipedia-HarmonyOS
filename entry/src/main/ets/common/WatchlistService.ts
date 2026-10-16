// svc_watchlist — ported from
// WMFData/Sources/WMFData/Data Controllers/Watchlist/WMFWatchlistDataController.swift:
// :113 fetchWatchlist (list=watchlist), :314 watch / :345 unwatch (action=watch, watch token)
// and WMFData/.../Shared/WMFArticleDataController.swift:80 (prop=info inprop=watched +
// meta=userinfo uiprop=rights — the watch-status probe).

import { HttpClient } from './HttpClient';
import { AuthService, TokenType, mediaWikiApiURL } from './AuthService';
import { WMFWatchlist, WMFWatchlistItem, WMFWatchlistItemJson } from '../model/WMFWatchlistItem';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { LanguageStore } from './LanguageStore';
import { Prefs, WMFDataPrefKeys } from './Prefs';

// Source: WMFWatchlistExpiryType raw values.
export class WatchlistExpiry {
  static readonly never: string = 'never';
  static readonly oneWeek: string = '1 week';
  static readonly oneMonth: string = '1 month';
  static readonly threeMonths: string = '3 months';
  static readonly sixMonths: string = '6 months';
  static readonly oneYear: string = '1 year';
}

interface WatchlistQueryJson {
  watchlist?: WMFWatchlistItemJson[];
}

interface WatchlistResponseJson {
  query?: WatchlistQueryJson;
  errors?: object[];
}

interface WatchPageResultJson {
  watched?: boolean;
  unwatched?: boolean;
}

interface WatchResponseJson {
  watch?: WatchPageResultJson[];
}

interface InfoPageJson {
  watched?: boolean;
  watchlistexpiry?: string;
}

interface UserInfoRightsJson {
  rights?: string[];
}

interface InfoQueryJson {
  pages?: InfoPageJson[];
  userinfo?: UserInfoRightsJson;
}

interface InfoResponseJson {
  query?: InfoQueryJson;
}

export class WatchStatus {
  watched: boolean = false;
  watchlistExpiry: string | null = null;
  userHasRollbackRights: boolean = false;
}

// Source: WMFWatchlistFilterSettings (Codable, saved under watchlistFilterSettings). Enum
// values are the source's raw values; projects are hosts ("en.wikipedia.org").
export class WatchlistFilterSettings {
  offProjects: string[] = [];
  latestRevisions: number = 1;        // 0 latestRevision, 1 notTheLatestRevision
  activity: number = 0;               // 0 all, 1 unseenChanges, 2 seenChanges
  automatedContributions: number = 0; // 0 all, 1 bot, 2 human
  significance: number = 0;           // 0 all, 1 minorEdits, 2 nonMinorEdits
  userRegistration: number = 0;       // 0 all, 1 unregistered, 2 registered
  offTypes: number[] = [];            // 0 pageEdits, 1 pageCreations, 2 categoryChanges,
                                      // 3 wikidataEdits, 4 loggedActions
}

export const COMMONS_HOST: string = 'commons.wikimedia.org';
export const WIKIDATA_HOST: string = 'www.wikidata.org';

// One watchlist project: a Wikipedia of an app language, Commons or Wikidata.
export class WatchlistProject {
  host: string = '';
  languageCode: string = '';          // '' for Commons and Wikidata
  variant: string = '';
  name: string = '';                  // "English Wikipedia", "Wikimedia Commons", "Wikidata"
}

export class WatchlistService {
  static loadFilterSettings(): WatchlistFilterSettings {
    const out = new WatchlistFilterSettings();
    try {
      const raw: string = Prefs.getString(WMFDataPrefKeys.watchlistFilterSettings, '');
      if (raw !== '') {
        const j: WatchlistFilterSettings = HttpClient.parseJson<WatchlistFilterSettings>(raw);
        out.offProjects = j.offProjects ?? [];
        out.latestRevisions = j.latestRevisions ?? 1;
        out.activity = j.activity ?? 0;
        out.automatedContributions = j.automatedContributions ?? 0;
        out.significance = j.significance ?? 0;
        out.userRegistration = j.userRegistration ?? 0;
        out.offTypes = j.offTypes ?? [];
      }
    } catch (e) {
      console.warn('watchlist: unreadable filter settings, using defaults');
    }
    return out;
  }

  static saveFilterSettings(settings: WatchlistFilterSettings): void {
    Prefs.putString(WMFDataPrefKeys.watchlistFilterSettings, JSON.stringify(settings));
  }

  // allWatchlistProjects(): the app languages' Wikipedias, then Commons and Wikidata.
  static async allProjects(): Promise<WatchlistProject[]> {
    const out: WatchlistProject[] = [];
    const languages: MWKLanguageLink[] = await LanguageStore.preferredLanguages();
    for (const lang of languages) {
      const p = new WatchlistProject();
      p.host = lang.languageCode + '.wikipedia.org';
      p.languageCode = lang.languageCode;
      p.variant = lang.languageVariantCode ?? '';
      p.name = (lang.localizedName !== '' ? lang.localizedName : lang.name) + ' Wikipedia';
      out.push(p);
    }
    const commons = new WatchlistProject();
    commons.host = COMMONS_HOST;
    commons.name = 'Wikimedia Commons';
    const wikidata = new WatchlistProject();
    wikidata.host = WIKIDATA_HOST;
    wikidata.name = 'Wikidata';
    out.push(commons, wikidata);
    return out;
  }

  // activeFilterCount()
  static activeFilterCount(settings: WatchlistFilterSettings, all: WatchlistProject[]): number {
    let n: number = all.filter((p: WatchlistProject) => settings.offProjects.indexOf(p.host) >= 0).length;
    n += settings.latestRevisions === 0 ? 1 : 0;
    n += settings.activity !== 0 ? 1 : 0;
    n += settings.automatedContributions !== 0 ? 1 : 0;
    n += settings.significance !== 0 ? 1 : 0;
    n += settings.userRegistration !== 0 ? 1 : 0;
    n += settings.offTypes.filter((t: number) => t >= 0 && t <= 4).length;
    return n;
  }

  // apply(filterSettings:to:)
  static filterParams(settings: WatchlistFilterSettings, params: Record<string, string>): void {
    if (settings.latestRevisions === 1) {
      params['wlallrev'] = '1';
    }
    const show: string[] = [];
    const ACTIVITY: string[] = ['', 'unread', '!unread'];
    const BOT: string[] = ['', 'bot', '!bot'];
    const MINOR: string[] = ['', 'minor', '!minor'];
    const ANON: string[] = ['', 'anon', '!anon'];
    for (const v of [ACTIVITY[settings.activity], BOT[settings.automatedContributions],
      MINOR[settings.significance], ANON[settings.userRegistration]]) {
      if (v !== undefined && v !== '') {
        show.push(v);
      }
    }
    const type: string[] = [];
    // ChangeType raw value per wltype, in the order the source appends them
    const TYPE_IDS: number[] = [0, 1, 2, 4, 3];
    const TYPE_NAMES: string[] = ['edit', 'new', 'categorize', 'log', 'external'];
    for (let i: number = 0; i < TYPE_IDS.length; i++) {
      if (settings.offTypes.indexOf(TYPE_IDS[i]) < 0) {
        type.push(TYPE_NAMES[i]);
      }
    }
    params['wlshow'] = show.join('|');
    params['wltype'] = type.join('|');
  }

  // Source: WMFWatchlistDataController.fetchWatchlist — list=watchlist on every project that is
  // switched on in the filter, merged. A project that fails is skipped; only when every
  // project fails is the fetch an error.
  static async fetchWatchlist(): Promise<WMFWatchlist> {
    const settings: WatchlistFilterSettings = WatchlistService.loadFilterSettings();
    const all: WatchlistProject[] = await WatchlistService.allProjects();
    const on: WatchlistProject[] = all.filter((p: WatchlistProject) => settings.offProjects.indexOf(p.host) < 0);
    const out = new WMFWatchlist();
    out.activeFilterCount = WatchlistService.activeFilterCount(settings, all);
    if (on.length === 0) {
      return out;
    }
    const results: (WMFWatchlistItem[] | null)[] = await Promise.all(on.map(
      (p: WatchlistProject): Promise<WMFWatchlistItem[] | null> =>
        WatchlistService.fetchProject(p, settings).catch((e: Error): null => {
          console.warn('watchlist: ' + p.host + ' failed: ' + e.message);
          return null;
        })));
    let failed: number = 0;
    for (const r of results) {
      if (r === null) {
        failed++;
      } else {
        out.items.push(...r);
      }
    }
    if (failed === on.length) {
      throw new Error('every watchlist project failed');
    }
    return out;
  }

  private static async fetchProject(project: WatchlistProject,
    settings: WatchlistFilterSettings): Promise<WMFWatchlistItem[]> {
    const params: Record<string, string> = {
      'action': 'query',
      'list': 'watchlist',
      'wllimit': '500',
      'wlprop': 'ids|title|flags|comment|parsedcomment|timestamp|sizes|user|loginfo',
      'errorsuselocal': '1',
      'errorformat': 'html',
      'format': 'json',
      'formatversion': '2'
    };
    WatchlistService.filterParams(settings, params);
    if (project.variant !== '') {
      params['variant'] = project.variant;
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(project.host), params);
    const resp: WatchlistResponseJson = await HttpClient.getJson<WatchlistResponseJson>(url);
    if (resp.query === undefined) {
      throw new Error('no query in response' + ((resp.errors ?? []).length > 0 ? ' (API error)' : ''));
    }
    const items: WMFWatchlistItem[] = [];
    for (const row of resp.query.watchlist ?? []) {
      items.push(WMFWatchlistItem.fromJson(row, project.host));
    }
    return items;
  }

  // WMFWatchlistController thank: action=thank for a revision (csrf token).
  static async thank(host: string, revisionID: number): Promise<boolean> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'thank',
      'rev': revisionID.toString(),
      'source': 'diff',
      'format': 'json',
      'formatversion': '2',
      'token': token
    };
    const text: string = await HttpClient.postForm(mediaWikiApiURL(host), form);
    const root: Record<string, object> = HttpClient.parseJson<Record<string, object>>(text);
    return root['result'] !== undefined;
  }

  // Source: WMFWatchlistDataController.swift:314 — action=watch (watch token).
  static async watch(host: string, title: string, expiry: string): Promise<boolean> {
    const token: string = await AuthService.fetchToken(host, TokenType.watch);
    const form: Record<string, string> = {
      'action': 'watch',
      'titles': title,
      'expiry': expiry,
      'format': 'json',
      'formatversion': '2',
      'errorformat': 'html',
      'errorsuselocal': '1',
      'token': token
    };
    const resp: WatchResponseJson =
      await HttpClient.postFormJson<WatchResponseJson>(mediaWikiApiURL(host), form);
    const pages: WatchPageResultJson[] = resp.watch ?? [];
    return pages.length > 0 && pages[0].watched === true;
  }

  // Source: WMFWatchlistDataController.swift:345 — action=watch with unwatch=1.
  static async unwatch(host: string, title: string): Promise<boolean> {
    const token: string = await AuthService.fetchToken(host, TokenType.watch);
    const form: Record<string, string> = {
      'action': 'watch',
      'unwatch': '1',
      'titles': title,
      'format': 'json',
      'formatversion': '2',
      'errorformat': 'html',
      'errorsuselocal': '1',
      'token': token
    };
    const resp: WatchResponseJson =
      await HttpClient.postFormJson<WatchResponseJson>(mediaWikiApiURL(host), form);
    const pages: WatchPageResultJson[] = resp.watch ?? [];
    return pages.length > 0 && pages[0].unwatched === true;
  }

  // Source: WMFArticleDataController.swift:80 — prop=info inprop=watched
  // (+ meta=userinfo uiprop=rights when rollback rights are needed).
  static async fetchWatchStatus(host: string, title: string,
    needsRollbackRights: boolean): Promise<WatchStatus> {
    const params: Record<string, string> = {
      'action': 'query',
      'titles': title,
      'prop': 'info',
      'inprop': 'watched',
      'format': 'json',
      'formatversion': '2',
      'errorformat': 'html',
      'errorsuselocal': '1'
    };
    if (needsRollbackRights) {
      params['meta'] = 'userinfo';
      params['uiprop'] = 'rights';
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: InfoResponseJson = await HttpClient.getJson<InfoResponseJson>(url);
    const out = new WatchStatus();
    const pages: InfoPageJson[] = resp.query?.pages ?? [];
    if (pages.length > 0) {
      out.watched = pages[0].watched ?? false;
      out.watchlistExpiry = pages[0].watchlistexpiry ?? null;
    }
    const rights: string[] = resp.query?.userinfo?.rights ?? [];
    out.userHasRollbackRights = rights.indexOf('rollback') >= 0;
    return out;
  }

  // Source: WMFWatchlistDataController.undo — action=edit undo=<rev>, the summary prefixed with
  // the wiki's own "undo-summary" message; the old and new revision ids for the resulting diff.
  static async undo(host: string, title: string, revisionID: number, summary: string,
    username: string): Promise<UndoOrRollbackResult | null> {
    const msgParams: Record<string, string> = {
      'action': 'query', 'meta': 'allmessages', 'amenableparser': '1', 'ammessages': 'undo-summary',
      'amargs': revisionID.toString() + '|' + username, 'errorsuselocal': '1', 'errorformat': 'html',
      'format': 'json', 'formatversion': '2'
    };
    const msgs: AllMessagesResponseJson =
      await HttpClient.getJson<AllMessagesResponseJson>(HttpClient.buildURL(mediaWikiApiURL(host), msgParams));
    const prefix: string = (msgs.query?.allmessages ?? [])
      .find((m: AllMessageJson) => m.name === 'undo-summary')?.content ?? '';
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'edit',
      'title': title,
      'summary': prefix + ' ' + summary,
      'undo': revisionID.toString(),
      'matags': 'app-undo',                        // WMFEditTag.appUndo
      'format': 'json',
      'formatversion': '2',
      'errorformat': 'html',
      'errorsuselocal': '1',
      'token': token
    };
    const resp: UndoResponseJson = await HttpClient.postFormJson<UndoResponseJson>(mediaWikiApiURL(host), form);
    const edit: UndoEditJson | undefined = resp.edit;
    if (edit === undefined || edit.result !== 'Success' || edit.newrevid === undefined || edit.oldrevid === undefined) {
      return null;
    }
    return { newRevisionID: edit.newrevid, oldRevisionID: edit.oldrevid };
  }

  // Source: WMFWatchlistDataController rollback (:449 region) — action=rollback; the old and new
  // revision ids for the resulting diff, null when the wiki refused it.
  static async rollback(host: string, title: string, username: string): Promise<UndoOrRollbackResult | null> {
    const token: string = await AuthService.fetchToken(host, TokenType.rollback);
    const form: Record<string, string> = {
      'action': 'rollback',
      'title': title,
      'user': username,
      'matags': 'app-rollback',                    // WMFEditTag.appRollback
      'format': 'json',
      'formatversion': '2',
      'errorformat': 'html',
      'errorsuselocal': '1',
      'token': token
    };
    const resp: RollbackResponseJson = await HttpClient.postFormJson<RollbackResponseJson>(mediaWikiApiURL(host), form);
    const r: RollbackJson | undefined = resp.rollback;
    if (r === undefined || r.revid === undefined || r.old_revid === undefined) {
      return null;
    }
    return { newRevisionID: r.revid, oldRevisionID: r.old_revid };
  }
}

// WMFUndoOrRollbackResult
export interface UndoOrRollbackResult {
  newRevisionID: number;
  oldRevisionID: number;
}

interface AllMessageJson {
  name?: string;
  content?: string;
}

interface AllMessagesQueryJson {
  allmessages?: AllMessageJson[];
}

interface AllMessagesResponseJson {
  query?: AllMessagesQueryJson;
}

interface UndoEditJson {
  result?: string;
  newrevid?: number;
  oldrevid?: number;
}

interface UndoResponseJson {
  edit?: UndoEditJson;
}

interface RollbackJson {
  revid?: number;
  old_revid?: number;
}

interface RollbackResponseJson {
  rollback?: RollbackJson;
}
