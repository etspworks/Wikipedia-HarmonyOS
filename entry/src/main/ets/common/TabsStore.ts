// svc_tabs_store — article tabs (CDArticleTab / CDArticleTabItem, WMFData).
// Ported from WMFData/Sources/WMFData/Data Controllers/Article Tabs/
// WMFArticleTabsDataController.swift. Item order (NSOrderedSet) is the orderIndex column.

import { util } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { Prefs, WMFDataPrefKeys } from './Prefs';
import { CDArticleTab } from '../model/CDArticleTab';
import { CDArticleTabItem } from '../model/CDArticleTabItem';

// WMFArticleTabsDataController.WMFArticle — one article inside a tab.
export class TabArticle {
  identifier: string | null = null;                // CDArticleTabItem.identifier
  title: string = '';
  projectID: string = '';                          // e.g. "wikipedia~en"
  articleURL: string = '';
}

// WMFArticleTabsDataController.WMFArticleTab.
export class ArticleTab {
  identifier: string = '';
  timestamp: number = 0;
  isCurrent: boolean = false;
  articles: TabArticle[] = [];
}

// WMFArticleTabsDataController.Identifiers.
export class TabIdentifiers {
  tabIdentifier: string = '';
  tabItemIdentifier: string | null = null;
}

interface TabRestorationJson {
  identifier?: string;
  timestamp?: number;
  isCurrent?: boolean;
  articleIdentifier?: string;
  title?: string;
  projectID?: string;
  articleURL?: string;
}

// WMFProject.id "wikipedia~<lang>[~variant]" -> https://<lang>.wikipedia.org
function siteURLForProjectID(projectID: string): string {
  const parts: string[] = projectID.split('~');
  const lang: string = parts.length > 1 ? parts[1] : 'en';
  return 'https://' + lang + '.wikipedia.org';
}

function articleURLFor(projectID: string, title: string): string {
  return siteURLForProjectID(projectID) + '/wiki/' +
    encodeURIComponent(title.replace(/ /g, '_'));
}

class TabItemRecord {
  identifier: string = '';
  isCurrent: boolean = false;
  pageId: number | null = null;
  orderIndex: number = 0;
  title: string = '';
  projectID: string = '';
}

function mapItemJoinRow(rs: relationalStore.ResultSet): TabItemRecord {
  const out = new TabItemRecord();
  out.identifier = Database.colString(rs, 'identifier') ?? '';
  out.isCurrent = Database.colBool(rs, 'isCurrent');
  out.pageId = Database.colLong(rs, 'pageId');
  out.orderIndex = Database.colLong(rs, 'orderIndex') ?? 0;
  out.title = Database.colString(rs, 'title') ?? '';
  out.projectID = Database.colString(rs, 'projectID') ?? '';
  return out;
}

const ITEM_JOIN_SQL: string =
  'SELECT i.identifier AS identifier, i.isCurrent AS isCurrent, i.pageId AS pageId, ' +
  'i.orderIndex AS orderIndex, p.title AS title, p.projectID AS projectID ' +
  'FROM CDArticleTabItem i LEFT JOIN CDPage p ON p.id = i.pageId ' +
  'WHERE i.tabIdentifier = ? ORDER BY i.orderIndex ASC';

// pageForArticle — fetch-or-create CDPage by (projectID, 0, title), refresh fields.
async function pageForArticle(projectID: string, title: string): Promise<number> {
  const now: number = Date.now();
  const ids: number[] = await Database.query<number>(
    'SELECT id FROM CDPage WHERE projectID = ? AND namespaceID = 0 AND title = ?',
    [projectID, title],
    (rs: relationalStore.ResultSet): number => rs.getLong(rs.getColumnIndex('id')));
  if (ids.length > 0) {
    return ids[0];
  }
  const values: relationalStore.ValuesBucket = {
    'namespaceID': 0,
    'projectID': projectID,
    'timestamp': now,
    'title': title
  };
  return await Database.insert('CDPage', values);
}

async function insertTabItem(tabIdentifier: string, pageId: number, isCurrent: boolean,
  orderIndex: number): Promise<string> {
  const identifier: string = util.generateRandomUUID();
  const values: relationalStore.ValuesBucket = {
    'identifier': identifier,
    'isCurrent': isCurrent ? 1 : 0,
    'pageId': pageId,
    'tabIdentifier': tabIdentifier,
    'orderIndex': orderIndex
  };
  await Database.insert('CDArticleTabItem', values);
  return identifier;
}

async function itemsForTab(tabIdentifier: string): Promise<TabItemRecord[]> {
  return await Database.query<TabItemRecord>(ITEM_JOIN_SQL, [tabIdentifier], mapItemJoinRow);
}

function articleFromRecord(record: TabItemRecord): TabArticle {
  const article = new TabArticle();
  article.identifier = record.identifier;
  article.title = record.title;
  article.projectID = record.projectID;
  article.articleURL = articleURLFor(record.projectID, record.title);
  return article;
}

export class TabsStore {
  // tabsMax: 5 with the forceMaxArticleTabsTo5 developer setting, otherwise 500.
  static get tabsMax(): number {
    return Prefs.getBoolean('dev-settings-article-tab-max-5', false) ? 5 : 500;
  }

  // tabsCount.
  static async tabsCount(): Promise<number> {
    return await Database.queryCount('SELECT COUNT(*) FROM CDArticleTab', []);
  }

  // WMFArticleTabsDataController: the app always holds a current tab. The source seeds one
  // on first launch so the overview shows a single Main Page tab before the reader has
  // opened anything; without it the overview read "0 tabs" on a clean install.
  static async ensureDefaultTab(projectID: string): Promise<void> {
    if (await TabsStore.tabsCount() > 0) {
      return;
    }
    await TabsStore.createArticleTab('Main Page', projectID, true);
  }

  // createArticleTab — optional initial article (defaults to the caller passing Main_Page,
  // per source when nil); optionally becomes the current tab.
  static async createArticleTab(initialTitle: string | null, projectID: string,
    setAsCurrent: boolean): Promise<TabIdentifiers> {
    if (setAsCurrent) {
      await Database.execute('UPDATE CDArticleTab SET isCurrent = 0 WHERE isCurrent = 1', []);
    }
    const tabIdentifier: string = util.generateRandomUUID();
    const tabValues: relationalStore.ValuesBucket = {
      'identifier': tabIdentifier,
      'isCurrent': setAsCurrent ? 1 : 0,
      'timestamp': Date.now()
    };
    await Database.insert('CDArticleTab', tabValues);

    const out = new TabIdentifiers();
    out.tabIdentifier = tabIdentifier;
    if (initialTitle !== null) {
      const pageId: number = await pageForArticle(projectID, initialTitle);
      out.tabItemIdentifier = await insertTabItem(tabIdentifier, pageId, true, 0);
    }
    return out;
  }

  // deleteArticleTab — deleting the current tab promotes the most recent remaining tab.
  // The last tab is deletable: "Close all tabs" already empties the overview, and the
  // overview has an empty state, so refusing the close on the final card just made its X
  // silently do nothing.
  static async deleteArticleTab(tabIdentifier: string): Promise<void> {
    const wasCurrent: number = await Database.queryCount(
      'SELECT COUNT(*) FROM CDArticleTab WHERE identifier = ? AND isCurrent = 1',
      [tabIdentifier]);
    await Database.execute('DELETE FROM CDArticleTabItem WHERE tabIdentifier = ?',
      [tabIdentifier]);
    await Database.execute('DELETE FROM CDArticleTab WHERE identifier = ?', [tabIdentifier]);
    if (wasCurrent > 0) {
      const next: string[] = await Database.query<string>(
        'SELECT identifier FROM CDArticleTab ORDER BY timestamp DESC LIMIT 1', [],
        (rs: relationalStore.ResultSet): string =>
          rs.getString(rs.getColumnIndex('identifier')));
      if (next.length > 0) {
        await Database.execute('UPDATE CDArticleTab SET isCurrent = 1 WHERE identifier = ?',
          [next[0]]);
      }
    }
  }

  // deleteAllTabs.
  static async deleteAllTabs(): Promise<void> {
    await Database.execute('DELETE FROM CDArticleTabItem', []);
    await Database.execute('DELETE FROM CDArticleTab', []);
  }

  // deleteEmptyTabs.
  static async deleteEmptyTabs(): Promise<void> {
    const empty: string[] = await Database.query<string>(
      'SELECT t.identifier FROM CDArticleTab t WHERE NOT EXISTS ' +
      '(SELECT 1 FROM CDArticleTabItem i WHERE i.tabIdentifier = t.identifier)', [],
      (rs: relationalStore.ResultSet): string => rs.getString(rs.getColumnIndex('identifier')));
    for (const identifier of empty) {
      const count: number = await TabsStore.tabsCount();
      if (count <= 1) {
        break;
      }
      await Database.execute('DELETE FROM CDArticleTab WHERE identifier = ?', [identifier]);
    }
  }

  // appendArticle — clears isCurrent on existing items (optionally deleting the "future"
  // items after the current one), then appends — unless the last item is already the same
  // page, which just becomes current again (no duplicate).
  static async appendArticle(tabIdentifier: string, title: string, projectID: string,
    needsCleanoutOfFutureArticles: boolean): Promise<TabIdentifiers> {
    const tabExists: number = await Database.queryCount(
      'SELECT COUNT(*) FROM CDArticleTab WHERE identifier = ?', [tabIdentifier]);
    if (tabExists === 0) {
      throw new Error('missingTab');
    }
    const pageId: number = await pageForArticle(projectID, title);
    const items: TabItemRecord[] = await itemsForTab(tabIdentifier);

    let foundCurrent: boolean = false;
    const kept: TabItemRecord[] = [];
    for (const item of items) {
      if (item.isCurrent) {
        foundCurrent = true;
        kept.push(item);
      } else if (foundCurrent && needsCleanoutOfFutureArticles) {
        await Database.execute('DELETE FROM CDArticleTabItem WHERE identifier = ?',
          [item.identifier]);
      } else {
        kept.push(item);
      }
    }
    await Database.execute(
      'UPDATE CDArticleTabItem SET isCurrent = 0 WHERE tabIdentifier = ?', [tabIdentifier]);

    const out = new TabIdentifiers();
    out.tabIdentifier = tabIdentifier;
    const last: TabItemRecord | null = kept.length > 0 ? kept[kept.length - 1] : null;
    if (last !== null && last.pageId === pageId) {
      await Database.execute('UPDATE CDArticleTabItem SET isCurrent = 1 WHERE identifier = ?',
        [last.identifier]);
      out.tabItemIdentifier = last.identifier;
      return out;
    }
    const nextOrder: number = kept.length > 0 ? kept[kept.length - 1].orderIndex + 1 : 0;
    out.tabItemIdentifier = await insertTabItem(tabIdentifier, pageId, true, nextOrder);
    return out;
  }

  // getAdjacentArticleInTab — the item before/after the current one, or null.
  static async getAdjacentArticleInTab(tabIdentifier: string,
    isPrev: boolean): Promise<TabArticle | null> {
    const items: TabItemRecord[] = await itemsForTab(tabIdentifier);
    for (let index = 0; index < items.length; index++) {
      if (items[index].isCurrent) {
        const adjacent: number = isPrev ? index - 1 : index + 1;
        if (adjacent >= 0 && adjacent < items.length) {
          return articleFromRecord(items[adjacent]);
        }
        return null;
      }
    }
    return null;
  }

  // setTabItemAsCurrent — one current item per tab, and the tab becomes current too.
  static async setTabItemAsCurrent(tabIdentifier: string,
    tabItemIdentifier: string): Promise<void> {
    await Database.execute(
      'UPDATE CDArticleTabItem SET isCurrent = 0 WHERE tabIdentifier = ?', [tabIdentifier]);
    await Database.execute(
      'UPDATE CDArticleTabItem SET isCurrent = 1 WHERE identifier = ?', [tabItemIdentifier]);
    await TabsStore.setTabAsCurrent(tabIdentifier);
  }

  // setTabAsCurrent.
  static async setTabAsCurrent(tabIdentifier: string): Promise<void> {
    await Database.execute('UPDATE CDArticleTab SET isCurrent = 0 WHERE isCurrent = 1', []);
    await Database.execute('UPDATE CDArticleTab SET isCurrent = 1 WHERE identifier = ?',
      [tabIdentifier]);
  }

  // currentTabIdentifier.
  static async currentTabIdentifier(): Promise<string | null> {
    const rows: string[] = await Database.query<string>(
      'SELECT identifier FROM CDArticleTab WHERE isCurrent = 1 LIMIT 1', [],
      (rs: relationalStore.ResultSet): string => rs.getString(rs.getColumnIndex('identifier')));
    return rows.length > 0 ? rows[0] : null;
  }

  // fetchAllArticleTabs — each tab's articles up to (and including) the current item.
  static async fetchAllArticleTabs(): Promise<ArticleTab[]> {
    const tabs: CDArticleTab[] = await Database.query<CDArticleTab>(
      'SELECT identifier, isCurrent, timestamp FROM CDArticleTab ORDER BY timestamp ASC', [],
      (rs: relationalStore.ResultSet): CDArticleTab => {
        const out = new CDArticleTab();
        out.identifier = Database.colString(rs, 'identifier') ?? '';
        out.isCurrent = Database.colBool(rs, 'isCurrent');
        out.timestamp = Database.colLong(rs, 'timestamp') ?? 0;
        return out;
      });
    const out: ArticleTab[] = [];
    for (const tab of tabs) {
      const articleTab = new ArticleTab();
      articleTab.identifier = tab.identifier;
      articleTab.timestamp = tab.timestamp;
      articleTab.isCurrent = tab.isCurrent;
      const items: TabItemRecord[] = await itemsForTab(tab.identifier);
      for (const item of items) {
        articleTab.articles.push(articleFromRecord(item));
        if (item.isCurrent) {
          break;                                   // don't append past the current article
        }
      }
      out.push(articleTab);
    }
    return out;
  }

  // saveCurrentStateForLaterRestoration — the current tab + its current article, to prefs.
  static async saveCurrentStateForLaterRestoration(): Promise<void> {
    const currentTab: string | null = await TabsStore.currentTabIdentifier();
    if (currentTab === null) {
      throw new Error('missingTab');
    }
    const tabs: CDArticleTab[] = await Database.query<CDArticleTab>(
      'SELECT identifier, isCurrent, timestamp FROM CDArticleTab WHERE identifier = ?',
      [currentTab],
      (rs: relationalStore.ResultSet): CDArticleTab => {
        const out = new CDArticleTab();
        out.identifier = Database.colString(rs, 'identifier') ?? '';
        out.isCurrent = Database.colBool(rs, 'isCurrent');
        out.timestamp = Database.colLong(rs, 'timestamp') ?? 0;
        return out;
      });
    const items: TabItemRecord[] = await itemsForTab(currentTab);
    let current: TabItemRecord | null = null;
    for (const item of items) {
      if (item.isCurrent) {
        current = item;
        break;
      }
    }
    if (current === null || tabs.length === 0) {
      throw new Error('missingTabItem');
    }
    const json: TabRestorationJson = {
      identifier: currentTab,
      timestamp: tabs[0].timestamp,
      isCurrent: tabs[0].isCurrent,
      articleIdentifier: current.identifier,
      title: current.title,
      projectID: current.projectID,
      articleURL: articleURLFor(current.projectID, current.title)
    };
    Prefs.putString(WMFDataPrefKeys.articleTabRestoration, JSON.stringify(json));
  }

  // loadCurrentStateForRestoration.
  static loadCurrentStateForRestoration(): ArticleTab | null {
    const text: string = Prefs.getString(WMFDataPrefKeys.articleTabRestoration, '');
    if (text === '') {
      return null;
    }
    const json: TabRestorationJson = JSON.parse(text) as TabRestorationJson;
    const tab = new ArticleTab();
    tab.identifier = json.identifier ?? '';
    tab.timestamp = json.timestamp ?? 0;
    tab.isCurrent = json.isCurrent ?? false;
    const article = new TabArticle();
    article.identifier = json.articleIdentifier ?? null;
    article.title = json.title ?? '';
    article.projectID = json.projectID ?? '';
    article.articleURL = json.articleURL ?? '';
    tab.articles = [article];
    return tab;
  }

  // clearCurrentStateForRestoration.
  static clearCurrentStateForRestoration(): void {
    Prefs.remove(WMFDataPrefKeys.articleTabRestoration);
  }

  // --- Survey counters (userDefaultsStore) ---

  static updateSurveyDataTabsOverviewSeenCount(): void {
    const seen: number = Prefs.getNumber(WMFDataPrefKeys.articleTabsOverviewOpenedCount, 0);
    Prefs.putNumber(WMFDataPrefKeys.articleTabsOverviewOpenedCount, seen + 1);
  }

  static didTapOpenNewTab(): void {
    Prefs.putBoolean(WMFDataPrefKeys.articleTabsDidTapOpenInNewTab, true);
  }
}
