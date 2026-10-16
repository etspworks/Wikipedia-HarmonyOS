// Where a Wikipedia link goes — the source's Router.destination(for:) over
// WikipediaURLTranslations (WMF Framework/Router.swift, Wikipedia/Code/WikipediaURLTranslations.swift).
// The namespace of a /wiki/ title is looked up in the per-language table the source bundles
// (wikipedia-namespaces/<lang>.json, copied to rawfile), so "Help:IPA/English" is a Help page
// on English and "Yardım:..." one on Turkish, not an article.
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

interface NamespaceInfo {
  mainpage?: string;
  namespace?: Record<string, number>;
}

// PageNamespace values the router branches on
export const NS_MAIN: number = 0;
export const NS_TALK: number = 1;
export const NS_USER_TALK: number = 3;
export const NS_SPECIAL: number = -1;
export const NS_PROJECT: number = 4;

// Router.Destination, reduced to the screens this port routes to
export enum LinkKind {
  Article = 'article',
  Talk = 'talk',          // .talk and .userTalk: the native talk page
  History = 'history',    // .articleHistory
  Diff = 'diff',          // .articleDiff
  Login = 'login',        // .login
  Watchlist = 'watchlist', // .watchlist
  Search = 'search',      // .search
  OnThisDay = 'onThisDay', // .onThisDay
  ReadingListsImport = 'readingListsImport', // .readingListsImport
  Web = 'web'             // everything else (Help:, Wikipedia:, File:, the main page ...)
}

export class LinkDestination {
  kind: LinkKind = LinkKind.Web;
  languageCode: string = 'en';
  title: string = '';      // the full title, namespace included, spaces not underscores
  url: string = '';        // https://<lang>.wikipedia.org/wiki/<title>
  fromRevID: number = 0;   // .articleDiff: 0 when the link names only one side
  toRevID: number = 0;
  term: string = '';       // .search
  payload: string = '';    // .readingListsImport: the encoded limport payload
}

const NAMESPACE_RE: RegExp = /^(.+?)_*:_*(.*)$/;

let resourceContext: common.Context | null = null;
const tables: Map<string, NamespaceInfo | null> = new Map<string, NamespaceInfo | null>();

export function initWikiLinks(context: common.Context): void {
  resourceContext = context;
}

// lookupTable(for:) — loaded once per language from rawfile
function lookupTable(languageCode: string): NamespaceInfo | null {
  if (tables.has(languageCode)) {
    return tables.get(languageCode) ?? null;
  }
  let info: NamespaceInfo | null = null;
  try {
    if (resourceContext !== null) {
      const bytes: Uint8Array =
        resourceContext.resourceManager.getRawFileContentSync('wikipedia-namespaces/' + languageCode + '.json');
      const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
      info = JSON.parse(text) as NamespaceInfo;
    }
  } catch (e) {
    info = null;   // a wiki the source ships no table for: every title reads as main
  }
  tables.set(languageCode, info);
  return info;
}

function canonicalized(s: string): string {
  return s.toUpperCase().replace(/_/g, ' ');
}

// namespaceOfWikiResourcePath(with:)
export function namespaceOf(languageCode: string, title: string): number {
  const m: RegExpMatchArray | null = title.match(NAMESPACE_RE);
  if (m === null) {
    return NS_MAIN;
  }
  const ns: number | undefined = lookupTable(languageCode)?.namespace?.[canonicalized(m[1])];
  return ns ?? NS_MAIN;
}

export function isMainPageTitle(languageCode: string, title: string): boolean {
  const main: string | undefined = lookupTable(languageCode)?.mainpage;
  return main !== undefined && main === canonicalized(title);
}

export function wikiURL(languageCode: string, title: string): string {
  return 'https://' + languageCode + '.wikipedia.org/wiki/' +
    encodeURIComponent(title.replace(/ /g, '_')).replace(/%2F/g, '/').replace(/%3A/g, ':');
}

// Router.destination(for:) for a /wiki/<title> link on <lang>.wikipedia.org
export function destinationFor(languageCode: string, rawTitle: string): LinkDestination {
  let title: string = rawTitle;
  try {
    title = decodeURIComponent(rawTitle);
  } catch (e) {
    title = rawTitle;
  }
  title = title.replace(/_/g, ' ');
  const out = new LinkDestination();
  out.languageCode = languageCode;
  out.title = title;
  out.url = wikiURL(languageCode, title);
  const ns: number = namespaceOf(languageCode, title);
  if (ns === NS_MAIN) {
    // the main page is not opened as a native article
    out.kind = isMainPageTitle(languageCode, title) ? LinkKind.Web : LinkKind.Article;
  } else if (ns === NS_TALK || ns === NS_USER_TALK) {
    out.kind = LinkKind.Talk;
  } else if (ns === NS_SPECIAL) {
    specialDestination(out, title.substring(title.indexOf(':') + 1).trim());
  } else if (ns === NS_PROJECT && title.toUpperCase().indexOf('ON THIS DAY') >= 0) {
    // Wikipedia:On_this_day/Today
    out.kind = LinkKind.OnThisDay;
  } else {
    out.kind = LinkKind.Web;
  }
  return out;
}

const MOBILEDIFF_MULTI_RE: RegExp = /^mobilediff\/([0-9]+)\.\.\.([0-9]+)/i;
const MOBILEDIFF_SINGLE_RE: RegExp = /^mobilediff\/([0-9]+)/i;
const HISTORY_RE: RegExp = /^history\/(.*)/i;

// destinationForWikiResourceURL, case .special
function specialDestination(out: LinkDestination, name: string): void {
  const english: boolean = out.languageCode === 'en' || out.languageCode === 'test';
  out.kind = LinkKind.Web;
  if (english && name === 'UserLogin') {
    out.kind = LinkKind.Login;
  } else if (name === 'Watchlist') {
    out.kind = LinkKind.Watchlist;
  } else {
    const multi: RegExpMatchArray | null = name.match(MOBILEDIFF_MULTI_RE);
    const single: RegExpMatchArray | null = name.match(MOBILEDIFF_SINGLE_RE);
    const history: RegExpMatchArray | null = name.match(HISTORY_RE);
    if (multi !== null) {
      out.kind = LinkKind.Diff;
      out.fromRevID = Number.parseInt(multi[1], 10);
      out.toRevID = Number.parseInt(multi[2], 10);
    } else if (single !== null) {
      out.kind = LinkKind.Diff;
      out.toRevID = Number.parseInt(single[1], 10);
    } else if (history !== null && history[1] !== '') {
      out.kind = LinkKind.History;
      out.title = history[1].replace(/_/g, ' ');
    }
  }
}

// destinationForWResourceURL: /w/index.php?search=, ?title=…&action=history, and the diff
// spellings (type=revision, diff=prev|next, diff=<id>, oldid=<id>). null when the query names
// nothing native.
function indexPhpDestination(languageCode: string, query: string): LinkDestination | null {
  const params: Map<string, string> = new Map<string, string>();
  for (const pair of query.split('&')) {
    const eq: number = pair.indexOf('=');
    const key: string = eq >= 0 ? pair.substring(0, eq) : pair;
    let value: string = eq >= 0 ? pair.substring(eq + 1) : '';
    try {
      value = decodeURIComponent(value.replace(/\+/g, ' '));
    } catch (e) {
      // keep the raw value
    }
    params.set(key, value);
  }
  const out = new LinkDestination();
  out.languageCode = languageCode;
  const search: string | undefined = params.get('search');
  if (search !== undefined) {
    out.kind = LinkKind.Search;
    out.term = search;
    return out;
  }
  const title: string | undefined = params.get('title');
  if (title === undefined) {
    return null;
  }
  out.title = title.replace(/_/g, ' ');
  out.url = wikiURL(languageCode, out.title);
  const diff: string = params.get('diff') ?? '';
  const oldid: string = params.get('oldid') ?? '';
  const isInt = (v: string): boolean => /^[0-9]+$/.test(v);
  if ((languageCode === 'en' || languageCode === 'test') && title === 'Special:UserLogin') {
    out.kind = LinkKind.Login;
  } else if (params.get('action') === 'history') {
    out.kind = LinkKind.History;
  } else if (params.get('type') === 'revision' && isInt(diff) && isInt(oldid)) {
    out.kind = LinkKind.Diff;
    out.fromRevID = Number.parseInt(oldid, 10);
    out.toRevID = Number.parseInt(diff, 10);
  } else if (diff === 'prev' && isInt(oldid)) {
    out.kind = LinkKind.Diff;
    out.toRevID = Number.parseInt(oldid, 10);
  } else if (diff === 'next' && isInt(oldid)) {
    out.kind = LinkKind.Diff;
    out.fromRevID = Number.parseInt(oldid, 10);
  } else if (isInt(diff)) {
    out.kind = LinkKind.Diff;
    out.toRevID = Number.parseInt(diff, 10);
    out.fromRevID = isInt(oldid) ? Number.parseInt(oldid, 10) : 0;
  } else if (isInt(oldid)) {
    out.kind = LinkKind.Diff;
    out.toRevID = Number.parseInt(oldid, 10);
  } else {
    return null;
  }
  return out;
}

const WIKI_URL_RE: RegExp = /^https?:\/\/([a-z0-9-]+)(?:\.m)?\.wikipedia\.org\/wiki\/([^?#]+)(?:\?([^#]*))?/i;
const INDEX_PHP_RE: RegExp = /^https?:\/\/([a-z0-9-]+)(?:\.m)?\.wikipedia\.org\/w\/index\.php\?([^#]*)/i;

// A full https link to a Wikipedia /wiki/ page or /w/index.php query, or null for anything
// else (Router.destinationForHostURL).
export function destinationForURL(url: string): LinkDestination | null {
  const m: RegExpMatchArray | null = url.match(WIKI_URL_RE);
  if (m !== null) {
    const d: LinkDestination = destinationFor(m[1].toLowerCase(), m[2]);
    // Special:ReadingLists?limport=<payload>
    const query: string = m[3] ?? '';
    if (d.kind === LinkKind.Web && /^Special:ReadingLists$/i.test(d.title) && query.startsWith('limport=')) {
      d.kind = LinkKind.ReadingListsImport;
      d.payload = query.substring(8).split('&')[0];
    }
    return d;
  }
  const w: RegExpMatchArray | null = url.match(INDEX_PHP_RE);
  if (w !== null) {
    return indexPhpDestination(w[1].toLowerCase(), w[2]);
  }
  return null;
}
