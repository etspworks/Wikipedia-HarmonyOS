// svc_talk — ported from Wikipedia/Code/TalkPageFetcher.swift:
// :90 fetchTalkPageContent (action=discussiontoolspageinfo, prop=threaditemshtml),
// :195 reply (discussiontoolsedit paction=addcomment, matags app-talk-reply),
// :218 postTopic (discussiontoolsedit paction=addtopic, matags app-talk-topic),
// :116 subscribe (discussiontoolssubscribe).

import { HttpClient } from './HttpClient';
import { AuthService, TokenType, mediaWikiApiURL } from './AuthService';
import { TalkPageItem, TalkPageAPIResponseJson } from '../model/TalkPageItem';
import { Prefs, WMFDataPrefKeys } from './Prefs';

interface DiscussionToolsEditJson {
  result?: string;
}

interface DiscussionToolsEditResponseJson {
  discussiontoolsedit?: DiscussionToolsEditJson;
}

interface SubscribeResponseJson {
  discussiontoolssubscribe?: object;
}

interface SubscriptionsJson {
  subscriptions?: Record<string, number>;
}

interface RevisionIdJson {
  revid?: number;
}

interface RevisionPageJson {
  revisions?: RevisionIdJson[];
}

interface RevisionPagesJson {
  pages?: RevisionPageJson[];
}

interface RevisionQueryJson {
  query?: RevisionPagesJson;
}

interface ArchivePageJson {
  pageid?: number;
  title?: string;
  displaytitle?: string;
}

interface ArchiveQueryJson {
  pages?: ArchivePageJson[];
}

interface ArchiveContinueJson {
  gpsoffset?: number;
}

interface ArchivesResponseJson {
  query?: ArchiveQueryJson;
  continue?: ArchiveContinueJson;
}

// TalkPageArchivesItem: an archive subpage; displayTitle is HTML.
export interface TalkPageArchive {
  pageID: number;
  title: string;
  displayTitle: string;
}

export interface TalkPageArchivesPage {
  items: TalkPageArchive[];
  // gpsoffset of the next page, -1 when there is none
  nextOffset: number;
}

// Change language: the routed languages page writes its pick here for the talk page.
export const TALK_LANGUAGE_PICK_KEY: string = 'talkLanguagePick';

export interface TalkLanguagePick {
  languageCode: string;
  // the article's title on the picked wiki ('' for a user talk page)
  articleTitle: string;
}

export class TalkPageService {
  // Source: TalkPageFetcher.swift:90 — the thread items of a talk page.
  static async fetchTalkPageItems(host: string, talkPageTitle: string): Promise<TalkPageItem[]> {
    const params: Record<string, string> = {
      'action': 'discussiontoolspageinfo',
      'page': talkPageTitle,
      'format': 'json',
      'prop': 'threaditemshtml',
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: TalkPageAPIResponseJson = await HttpClient.getJson<TalkPageAPIResponseJson>(url);
    TalkPageService.lastCoffeeRoll = TalkPageItem.coffeeRollFromResponse(resp);
    return TalkPageItem.threadItemsFromResponse(resp);
  }

  // Source: TalkPageDataController.fetchLatestRevisionID — the newest revision of the talk
  // page, for its Permanent link. 0 when the page has none.
  static async fetchLatestRevisionID(host: string, talkPageTitle: string): Promise<number> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'ids',
      'titles': talkPageTitle,
      'format': 'json',
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: RevisionQueryJson = await HttpClient.getJson<RevisionQueryJson>(url);
    return resp.query?.pages?.[0]?.revisions?.[0]?.revid ?? 0;
  }

  // the lead-section text of the page the last fetchTalkPageItems call read
  // ponytail: one slot, the talk page asks right after its own fetch
  static lastCoffeeRoll: string = '';

  // TalkPageDataController String.signed: the Auto-sign discussions setting (on unless
  // turned off) appends the signature to replies and new topics.
  static autoSignTalkPageDiscussions(): boolean {
    return Prefs.getBoolean(WMFDataPrefKeys.autoSignTalkPageDiscussions, true);
  }

  private static signed(text: string): string {
    return TalkPageService.autoSignTalkPageDiscussions() ? text + ' ~~~~' : text;
  }

  // Source: TalkPageFetcher.swift:195 — reply to a comment (csrf-tokenized).
  static async postReply(host: string, talkPageTitle: string, commentId: string,
    wikitext: string): Promise<void> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'discussiontoolsedit',
      'paction': 'addcomment',
      'page': talkPageTitle,
      'matags': 'app-talk-reply',                  // WMFEditTag.appTalkReply
      'format': 'json',
      'formatversion': '2',
      'commentid': commentId,
      'wikitext': TalkPageService.signed(wikitext),
      'token': token
    };
    await TalkPageService.postAndEvaluate(host, form);
  }

  // Source: TalkPageFetcher.swift:218 — new topic (csrf-tokenized).
  static async postTopic(host: string, talkPageTitle: string, topicTitle: string,
    topicBody: string): Promise<void> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'discussiontoolsedit',
      'paction': 'addtopic',
      'page': talkPageTitle,
      'matags': 'app-talk-topic',                  // WMFEditTag.appTalkTopic
      'format': 'json',
      'formatversion': '2',
      'sectiontitle': topicTitle,
      'wikitext': TalkPageService.signed(topicBody),
      'token': token
    };
    await TalkPageService.postAndEvaluate(host, form);
  }

  // Source: TalkPageFetcher.getSubscribedTopics — which of these topic names (the heading
  // items' name) the reader is subscribed to.
  static async fetchSubscribedTopics(host: string, topicNames: string[]): Promise<string[]> {
    if (topicNames.length === 0) {
      return [];
    }
    const params: Record<string, string> = {
      'action': 'discussiontoolsgetsubscriptions',
      'format': 'json',
      'commentname': topicNames.join('|'),
      'formatversion': '2'
    };
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: SubscriptionsJson = await HttpClient.getJson<SubscriptionsJson>(url);
    const subs: Record<string, number> = resp.subscriptions ?? {};
    return Object.keys(subs).filter((name: string) => subs[name] === 1);
  }

  // Source: TalkPageArchivesFetcher.fetchArchives — the subpages of the talk page found by
  // prefix search: 30 on the first page, then 10 per page from the returned offset.
  static async fetchArchives(host: string, talkPageTitle: string, offset: number): Promise<TalkPageArchivesPage> {
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'info',
      'generator': 'prefixsearch',
      'inprop': 'varianttitles|displaytitle',
      'gpssearch': talkPageTitle + '/',
      'gpslimit': offset >= 0 ? '10' : '30',
      'errorformat': 'html',
      'errorsuselocal': '1',
      'format': 'json',
      'formatversion': '2'
    };
    if (offset >= 0) {
      params['gpsoffset'] = offset.toString();
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: ArchivesResponseJson = await HttpClient.getJson<ArchivesResponseJson>(url);
    const items: TalkPageArchive[] = [];
    for (const p of resp.query?.pages ?? []) {
      if (p.pageid !== undefined && p.title !== undefined && p.displaytitle !== undefined) {
        items.push({ pageID: p.pageid, title: p.title, displayTitle: p.displaytitle });
      }
    }
    return { items: items, nextOffset: resp.continue?.gpsoffset ?? -1 };
  }

  // Source: TalkPageFetcher.swift:116 — subscribe/unsubscribe to a topic.
  static async subscribe(host: string, talkPageTitle: string, commentName: string,
    shouldSubscribe: boolean): Promise<void> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'discussiontoolssubscribe',
      'page': talkPageTitle,
      'commentname': commentName,
      'format': 'json',
      'formatversion': '2',
      'token': token
    };
    if (shouldSubscribe) {
      form['subscribe'] = '1';
    }
    // an API error comes back as a 200 without the discussiontoolssubscribe result
    const text: string = await HttpClient.postForm(mediaWikiApiURL(host), form);
    const root: SubscribeResponseJson = HttpClient.parseJson<SubscribeResponseJson>(text);
    if (root.discussiontoolssubscribe === undefined) {
      throw new Error('discussiontoolssubscribe: ' + text);
    }
  }

  // Source: evaluateResponse (:232) — a response without a result field is a failure.
  private static async postAndEvaluate(host: string,
    form: Record<string, string>): Promise<void> {
    const text: string = await HttpClient.postForm(mediaWikiApiURL(host), form);
    const root: DiscussionToolsEditResponseJson =
      HttpClient.parseJson<DiscussionToolsEditResponseJson>(text);
    const result: string = root.discussiontoolsedit?.result ?? '';
    if (result !== 'success') {
      throw new Error('discussiontoolsedit result: ' + text);
    }
  }
}
