// The Activity tab's network-backed insights (WMFActivityTabViewModel): the categories of the
// articles read this month, and the account's edit count across all Wikimedia projects.
import { HttpClient } from './HttpClient';

interface CategoryJson {
  title?: string;
}

interface CategoryPageJson {
  categories?: CategoryJson[];
}

interface CategoriesResponseJson {
  query?: CategoryPagesJson;
}

interface CategoryPagesJson {
  pages?: CategoryPageJson[];
}

interface GlobalUserInfoJson {
  editcount?: number;
}

interface GlobalUserInfoQueryJson {
  globaluserinfo?: GlobalUserInfoJson;
}

interface GlobalUserInfoResponseJson {
  query?: GlobalUserInfoQueryJson;
}

interface UserContribJson {
  timestamp?: string;
}

interface UserContribsQueryJson {
  usercontribs?: UserContribJson[];
}

interface UserContribsResponseJson {
  query?: UserContribsQueryJson;
}

export class MonthlyContributions {
  thisMonth: number = 0;
  lastMonth: number = 0;
  lastEditMs: number = 0;
}

export class ActivityInsightsService {
  // The most frequent visible (non-hidden) categories over the given titles, most common first,
  // without the namespace prefix ("Kategori:" / "Category:").
  // ponytail: first 50 titles only (one API page); enough for a month's top three.
  static async topCategories(host: string, titles: string[], count: number): Promise<string[]> {
    if (titles.length === 0) {
      return [];
    }
    const params: Record<string, string> = {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'prop': 'categories',
      'clshow': '!hidden',
      'cllimit': 'max',
      'titles': titles.slice(0, 50).join('|')
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: CategoriesResponseJson = await HttpClient.getJson<CategoriesResponseJson>(url);
    const counts: Map<string, number> = new Map<string, number>();
    for (const page of resp.query?.pages ?? []) {
      for (const c of page.categories ?? []) {
        const full: string = c.title ?? '';
        const name: string = full.indexOf(':') >= 0 ? full.substring(full.indexOf(':') + 1) : full;
        if (name !== '') {
          counts.set(name, (counts.get(name) ?? 0) + 1);
        }
      }
    }
    return Array.from(counts.entries())
      .sort((a: [string, number], b: [string, number]): number => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, count)
      .map((e: [string, number]): string => e[0]);
  }

  // ContributionsViewModel: the user's edits on the app's wiki this calendar month and last,
  // and the time of the latest one (list=usercontribs, newest first, back to the start of last
  // month). ponytail: 500 contributions max per call; a heavier editor's last month is cut there.
  static async monthlyContributions(host: string, userName: string): Promise<MonthlyContributions> {
    const now: Date = new Date();
    const thisMonth: number = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    const lastMonth: number = new Date(now.getFullYear(), now.getMonth() - 1, 1).getTime();
    const params: Record<string, string> = {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'list': 'usercontribs',
      'ucuser': userName,
      'ucprop': 'timestamp',
      'uclimit': '500',
      'ucend': new Date(lastMonth).toISOString()
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: UserContribsResponseJson = await HttpClient.getJson<UserContribsResponseJson>(url);
    const out = new MonthlyContributions();
    for (const c of resp.query?.usercontribs ?? []) {
      const t: number = Date.parse(c.timestamp ?? '');
      if (Number.isNaN(t)) {
        continue;
      }
      out.lastEditMs = Math.max(out.lastEditMs, t);
      if (t >= thisMonth) {
        out.thisMonth++;
      } else if (t >= lastMonth) {
        out.lastMonth++;
      }
    }
    return out;
  }

  // meta=globaluserinfo editcount: edits across every project of the global account
  static async globalEditCount(host: string, userName: string): Promise<number> {
    const params: Record<string, string> = {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'meta': 'globaluserinfo',
      'guiuser': userName,
      'guiprop': 'editcount'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: GlobalUserInfoResponseJson = await HttpClient.getJson<GlobalUserInfoResponseJson>(url);
    return resp.query?.globaluserinfo?.editcount ?? 0;
  }
}
