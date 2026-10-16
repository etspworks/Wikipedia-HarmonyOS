// svc_history — ported from Wikipedia/Code/PageHistoryFetcher.swift:9 (prop=revisions history
// pages of 51) and Wikipedia/Code/DiffFetcher.swift:95 (MediaWiki REST
// /w/rest.php/v1/revision/{from}/compare/{to}) + :44 (fetchWikitext via prop=revisions revids).

import { HttpClient } from './HttpClient';
import { WMFPageHistoryRevision, WMFPageHistoryRevisionJson } from '../model/Revision';
import { DiffResponse, DiffResponseJson } from '../model/DiffResponse';

interface RevisionsPageJson {
  title?: string;
  revisions?: WMFPageHistoryRevisionJson[];
}

interface CompareIdsJson {
  torevid?: number;
}

interface RevisionsQueryJson {
  pages?: RevisionsPageJson[];
}

interface RevisionsContinueJson {
  rvcontinue?: string;
}

interface WikitextRevisionJson {
  slots?: WikitextSlotsJson;
}

interface WikitextSlotsJson {
  main?: WikitextMainJson;
}

interface WikitextMainJson {
  content?: string;
}

interface WikitextPageJson {
  revisions?: WikitextRevisionJson[];
}

interface WikitextQueryJson {
  pages?: WikitextPageJson[];
}

interface WikitextResponseJson {
  query?: WikitextQueryJson;
}

// PageHistoryFetcher.EditCount ({ count, limit }) — the REST counts payload.
interface EditCountJson {
  count?: number;
  limit?: boolean;
}

interface EditMetricsResultJson {
  edits?: number;
}

interface EditMetricsItemJson {
  results?: EditMetricsResultJson[];
}

interface EditMetricsJson {
  items?: EditMetricsItemJson[];
}

// One PageHistoryFilterCountsViewController.Count row (title + image name + count).
export class PageHistoryCountEntry {
  title: string = '';
  // Count.image: "user-edit" | WMFIcon.anonymous | "bot" | "m".
  iconName: string = '';
  count: number = 0;
}

// The counts header's data: totalEditCount + firstEditDate (fetchFirstRevision, whose
// revisionDate the source pairs with the .edits count) + the grouped filter counts.
export class PageHistoryEditCounts {
  totalEditCount: number = -1;
  firstEditDate: string | null = null;
  entries: PageHistoryCountEntry[] = [];
}

export class PageHistoryPage {
  revisions: WMFPageHistoryRevision[] = [];
  continueKey: string | null = null;               // rvcontinue for the next page
}

export class PageHistoryService {
  // Source: PageHistoryFetcher.swift:9 — action=query, prop=revisions,
  // rvprop=ids|timestamp|user|size|parsedcomment|flags, rvlimit=51.
  // revisionSize (the byte delta vs the parent) is computed against the next-older row,
  // the way the source's RevisionsPagingInfo does.
  static async fetchRevisions(host: string, title: string,
    continueKey: string | null): Promise<PageHistoryPage> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'ids|timestamp|user|size|parsedcomment|flags',
      'rvlimit': '51',
      'titles': title,
      'format': 'json',
      'formatversion': '2'
    };
    if (continueKey !== null) {
      params['rvcontinue'] = continueKey;
    }
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    // "continue" is a keyword, so the response is read through a Record view.
    const raw: Record<string, object> = await HttpClient.getJson<Record<string, object>>(url);
    const cont = raw['continue'] as RevisionsContinueJson | undefined;
    const query = raw['query'] as RevisionsQueryJson | undefined;

    const out = new PageHistoryPage();
    out.continueKey = cont?.rvcontinue ?? null;
    const pages: RevisionsPageJson[] = query?.pages ?? [];
    const revisions: WMFPageHistoryRevision[] = [];
    if (pages.length > 0) {
      const rows: WMFPageHistoryRevisionJson[] = pages[0].revisions ?? [];
      for (const row of rows) {
        revisions.push(WMFPageHistoryRevision.fromJson(row));
      }
    }
    for (let i = 0; i < revisions.length; i++) {
      if (i + 1 < revisions.length) {
        revisions[i].revisionSize =
          revisions[i].articleSizeAtRevision - revisions[i + 1].articleSizeAtRevision;
      } else {
        revisions[i].revisionSize = revisions[i].articleSizeAtRevision;
      }
    }
    out.revisions = revisions;
    return out;
  }

  // Source: DiffFetcher.fetchSingleRevisionInfo / the compare header's two revisions —
  // prop=revisions by revids with the same rvprop as the history list.
  static async fetchRevisionsByIds(host: string, ids: number[]): Promise<WMFPageHistoryRevision[]> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'ids|timestamp|user|size|parsedcomment|flags',
      'revids': ids.join('|'),
      'format': 'json',
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const raw: Record<string, object> = await HttpClient.getJson<Record<string, object>>(url);
    const query = raw['query'] as RevisionsQueryJson | undefined;
    const out: WMFPageHistoryRevision[] = [];
    for (const page of query?.pages ?? []) {
      for (const row of page.revisions ?? []) {
        out.push(WMFPageHistoryRevision.fromJson(row));
      }
    }
    return out;
  }

  // A revision's page title (a diff link names only revision ids).
  static async pageTitleForRevision(host: string, revisionId: number): Promise<string> {
    const params: Record<string, string> = {
      'action': 'query', 'prop': 'revisions', 'revids': String(revisionId), 'rvprop': 'ids',
      'format': 'json', 'formatversion': '2'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const raw: Record<string, object> = await HttpClient.getJson<Record<string, object>>(url);
    const query = raw['query'] as RevisionsQueryJson | undefined;
    return query?.pages?.[0]?.title ?? '';
  }

  // The revision after this one (diff=next): action=compare with torelative=next.
  static async nextRevisionId(host: string, revisionId: number): Promise<number> {
    const params: Record<string, string> = {
      'action': 'compare', 'fromrev': String(revisionId), 'torelative': 'next', 'prop': 'ids',
      'format': 'json', 'formatversion': '2'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const raw: Record<string, object> = await HttpClient.getJson<Record<string, object>>(url);
    const compare = raw['compare'] as CompareIdsJson | undefined;
    return compare?.torevid ?? 0;
  }

  // Source: DiffFetcher.swift:95 — /w/rest.php/v1/revision/{from}/compare/{to}.
  static async fetchDiff(host: string, fromRevisionId: number,
    toRevisionId: number): Promise<DiffResponse> {
    const url: string = 'https://' + host + '/w/rest.php/v1/revision/' +
      String(fromRevisionId) + '/compare/' + String(toRevisionId);
    const j: DiffResponseJson = await HttpClient.getJson<DiffResponseJson>(url);
    return DiffResponse.fromJson(j);
  }

  // Source: DiffFetcher.swift:44 — action=query, prop=revisions, revids={id},
  // rvprop=content (slot main carries the wikitext with formatversion=2).
  static async fetchWikitext(host: string, revisionId: number): Promise<string> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'revisions',
      'revids': String(revisionId),
      'rvprop': 'content',
      'rvslots': 'main',
      'format': 'json',
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: WikitextResponseJson = await HttpClient.getJson<WikitextResponseJson>(url);
    const pages: WikitextPageJson[] = resp.query?.pages ?? [];
    if (pages.length > 0) {
      const revisions: WikitextRevisionJson[] = pages[0].revisions ?? [];
      if (revisions.length > 0) {
        return revisions[0].slots?.main?.content ?? '';
      }
    }
    return '';
  }

  // Source: PageHistoryFetcher.swift:129 editCountsURL + :154 fetchEditCounts —
  // /w/rest.php/v1/page/{title}/history/counts/{type}, one request per type.
  // PageHistoryViewController.getEditCounts() asks for .edits, .anonymous, .bot,
  // .temporary, .customLoggedIn, .customUnregistered; the two custom types are not
  // requestable and are derived (loggedIn = edits - anon - temp; unregistered =
  // anon + temp). The first-edit date comes from fetchFirstRevision (rvdir=newer,
  // rvlimit=1), which the source pairs with the .edits count in the same header.
  static async fetchEditCounts(host: string, title: string): Promise<PageHistoryEditCounts> {
    const out = new PageHistoryEditCounts();
    out.firstEditDate = await PageHistoryService.fetchFirstEditDate(host, title);

    const edits: number = await PageHistoryService.editCount(host, title, 'edits');
    const anonymous: number = await PageHistoryService.editCount(host, title, 'anonymous');
    const temporary: number = await PageHistoryService.editCount(host, title, 'temporary');
    const bot: number = await PageHistoryService.editCount(host, title, 'bot');

    out.totalEditCount = edits;

    const entries: PageHistoryCountEntry[] = [];
    if (edits >= 0 && anonymous >= 0 && temporary >= 0) {
      // page-history-logged-in-edits
      const loggedIn = new PageHistoryCountEntry();
      loggedIn.title = 'logged-in';
      loggedIn.iconName = 'user-edit';
      loggedIn.count = edits - anonymous - temporary;
      entries.push(loggedIn);

      // page-history-unregistered-edits
      const unregistered = new PageHistoryCountEntry();
      unregistered.title = 'unregistered';
      unregistered.iconName = 'user-anonymous';
      unregistered.count = anonymous + temporary;
      entries.push(unregistered);
    }
    if (bot >= 0) {
      // page-history-bot-edits
      const botEntry = new PageHistoryCountEntry();
      botEntry.title = 'bot';
      botEntry.iconName = 'bot';
      botEntry.count = bot;
      entries.push(botEntry);
    }
    out.entries = entries;
    return out;
  }

  // Source: PageHistoryFetcher.swift:223 fetchEditMetrics — the metrics API lives only on
  // wikimedia.org: /api/rest_v1/metrics/edits/per-page/{project}/{title}/all-editor-types/
  // monthly/{from}/{to}, from = one year ago, to = today, both yyyyMMdd UTC.
  // The sparkline takes items[0].results[].edits, skipping results with no edits value.
  static async fetchEditMetrics(host: string, title: string): Promise<number[]> {
    const now = new Date();
    const yearAgo = new Date(Date.UTC(now.getUTCFullYear() - 1, now.getUTCMonth(), now.getUTCDate()));
    const url: string = 'https://wikimedia.org/api/rest_v1/metrics/edits/per-page/' +
      encodeURIComponent(host) + '/' + encodeURIComponent(title) +
      '/all-editor-types/monthly/' + PageHistoryService.yyyyMMdd(yearAgo) + '/' +
      PageHistoryService.yyyyMMdd(now);
    const resp: EditMetricsJson = await HttpClient.getJson<EditMetricsJson>(url);
    const items: EditMetricsItemJson[] = resp.items ?? [];
    const out: number[] = [];
    if (items.length > 0) {
      const results: EditMetricsResultJson[] = items[0].results ?? [];
      for (const result of results) {
        const edits: number | undefined = result.edits;
        if (edits !== undefined) {
          out.push(edits);
        }
      }
    }
    return out;
  }

  // One /history/counts/{type} request; -1 when the type is unavailable or rate-limited
  // (the source drops a type whose `limit` is true or whose count is missing).
  private static async editCount(host: string, title: string, type: string): Promise<number> {
    const url: string = 'https://' + host + '/w/rest.php/v1/page/' +
      encodeURIComponent(title) + '/history/counts/' + type;
    try {
      const j: EditCountJson = await HttpClient.getJson<EditCountJson>(url);
      if (j.limit === true || j.count === undefined) {
        return -1;
      }
      return j.count;
    } catch (e) {
      console.error('pageHistory: edit count ' + type + ' failed');
      return -1;
    }
  }

  // Source: PageHistoryFetcher.swift:93 fetchFirstRevision.
  private static async fetchFirstEditDate(host: string, title: string): Promise<string | null> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'revisions',
      'rvlimit': '1',
      'rvdir': 'newer',
      'titles': title,
      'format': 'json',
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    try {
      const raw: Record<string, object> = await HttpClient.getJson<Record<string, object>>(url);
      const query = raw['query'] as RevisionsQueryJson | undefined;
      const pages: RevisionsPageJson[] = query?.pages ?? [];
      if (pages.length > 0) {
        const rows: WMFPageHistoryRevisionJson[] = pages[0].revisions ?? [];
        if (rows.length > 0) {
          return rows[0].timestamp ?? null;
        }
      }
    } catch (e) {
      console.error('pageHistory: first revision failed');
    }
    return null;
  }

  // DateFormatter.wmf_englishUTCNonDelimitedYearMonthDay
  private static yyyyMMdd(d: Date): string {
    const m: number = d.getUTCMonth() + 1;
    const day: number = d.getUTCDate();
    return d.getUTCFullYear().toString() +
      (m < 10 ? '0' + m.toString() : m.toString()) +
      (day < 10 ? '0' + day.toString() : day.toString());
  }
}
