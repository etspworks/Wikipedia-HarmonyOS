// svc_article — ported from Wikipedia/Code/ArticleFetcher.swift (mobile-html / media-list /
// summary REST endpoints), Wikipedia/Code/RandomArticleFetcher.swift (page/random/summary)
// and WMF Framework/RelatedSearchFetcher.swift (morelike generator=search action API).
// All PCS/RESTBase endpoints live at https://{host}/api/rest_v1/ (Configuration.swift:238).

import { HttpClient } from './HttpClient';
import { ArticleSummary, ArticleSummaryJson } from '../model/ArticleSummary';
import { MediaList, MediaListJson } from '../model/MediaList';

// Source: SinglePageWebViewController.swift:406 — dev bypass-donation thank-you page.
export class WebViewURLs {
  static readonly donationThankYou: string = 'https://thankyou.wikipedia.org/wiki/Thank_You/en?country=US';
}

// Source: ArticleFetcher percent-encodes the title with spaces denormalized to underscores.
export function percentEncodedTitle(title: string): string {
  return encodeURIComponent(title.replace(/ /g, '_'));
}

function restBase(host: string): string {
  return 'https://' + host + '/api/rest_v1';
}

// RelatedSearchFetcher.swift response envelope (query.pages rows, formatversion=2).
interface RelatedPageJson {
  pageid?: number;
  ns?: number;
  title?: string;
  index?: number;
  description?: string;
  extract?: string;
  thumbnail?: RelatedThumbnailJson;
}

interface RelatedThumbnailJson {
  source?: string;
  width?: number;
  height?: number;
}

interface RelatedQueryJson {
  pages?: RelatedPageJson[];
}

interface RelatedResponseJson {
  query?: RelatedQueryJson;
}

interface CoordinateJson {
  lat?: number;
  lon?: number;
}

interface CoordinatesPageJson {
  title?: string;
  coordinates?: CoordinateJson[];
}

interface TitleMapJson {
  from?: string;
  to?: string;
}

interface CoordinatesQueryJson {
  pages?: CoordinatesPageJson[];
  normalized?: TitleMapJson[];
  redirects?: TitleMapJson[];
}

interface CoordinatesResponseJson {
  query?: CoordinatesQueryJson;
}

export class ArticleService {
  // Source: ArticleFetcher.mobileHTMLURL — /page/mobile-html/{title} (ArticleFetcher.swift:288).
  static mobileHtmlURL(host: string, title: string): string {
    return restBase(host) + '/page/mobile-html/' + percentEncodedTitle(title);
  }

  static async fetchMobileHtml(host: string, title: string): Promise<string> {
    return await HttpClient.getText(ArticleService.mobileHtmlURL(host, title), null);
  }

  // Source: ArticleFetcher.wikitextToMobileHTMLPreviewRequest — POST {wikitext} to
  // /transform/wikitext/to/mobile-html/{title}, with output-mode editPreview.
  static async fetchPreviewMobileHtml(host: string, title: string, wikitext: string): Promise<string> {
    const url: string = restBase(host) + '/transform/wikitext/to/mobile-html/' + percentEncodedTitle(title);
    const body: Record<string, string> = { 'wikitext': wikitext };
    const headers: Record<string, string> = { 'output-mode': 'editPreview', 'Accept': 'text/html; charset=utf-8' };
    return await HttpClient.postJsonForText(url, body, headers);
  }

  // Source: ArticleFetcher.mediaListURL — /page/media-list/{title} (ArticleFetcher.swift:309).
  static async fetchMediaList(host: string, title: string): Promise<MediaList> {
    const url: string = restBase(host) + '/page/media-list/' + percentEncodedTitle(title);
    const j: MediaListJson = await HttpClient.getJson<MediaListJson>(url);
    return MediaList.fromJson(j);
  }

  // Source: ArticleFetcher.summaryURL — /page/summary/{title} (ArticleFetcher.swift:508).
  static async fetchSummary(host: string, title: string): Promise<ArticleSummary> {
    const url: string = restBase(host) + '/page/summary/' + percentEncodedTitle(title);
    const j: ArticleSummaryJson = await HttpClient.getJson<ArticleSummaryJson>(url);
    return ArticleSummary.fromJson(j);
  }

  // Source: RandomArticleFetcher.swift:6 — pathComponents ["page", "random", "summary"].
  static async fetchRandomSummary(host: string): Promise<ArticleSummary> {
    const url: string = restBase(host) + '/page/random/summary';
    const j: ArticleSummaryJson = await HttpClient.getJson<ArticleSummaryJson>(url);
    return ArticleSummary.fromJson(j);
  }

  // prop=coordinates for up to 50 titles: normalized title -> [lat, lon] (primary coordinate)
  static async fetchCoordinates(host: string, titles: string[]): Promise<Map<string, number[]>> {
    const out: Map<string, number[]> = new Map<string, number[]>();
    if (titles.length === 0) {
      return out;
    }
    const params: Record<string, string> = {
      'action': 'query', 'format': 'json', 'formatversion': '2', 'prop': 'coordinates',
      'redirects': '1', 'titles': titles.join('|')
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: CoordinatesResponseJson = await HttpClient.getJson<CoordinatesResponseJson>(url);
    // a redirected or normalized title answers under its target name; map it back
    const alias: Map<string, string> = new Map<string, string>();
    for (const n of (resp.query?.normalized ?? []).concat(resp.query?.redirects ?? [])) {
      alias.set(n.to ?? '', alias.get(n.from ?? '') ?? n.from ?? '');
    }
    for (const page of resp.query?.pages ?? []) {
      const c: CoordinateJson | undefined = (page.coordinates ?? [])[0];
      if (c !== undefined && page.title !== undefined) {
        out.set(alias.get(page.title) ?? page.title, [c.lat ?? 0, c.lon ?? 0]);
        out.set(page.title, [c.lat ?? 0, c.lon ?? 0]);
      }
    }
    return out;
  }

  // Source: RelatedSearchFetcher.fetchRelatedArticles — generator=search morelike:{title}
  // (RelatedSearchFetcher.swift:23-42). Related pages are mapped onto ArticleSummary the way
  // ArticleSummary(relatedPage:) does in the source.
  // keepOrder: the article footer's Read more (PCS Footer readMore) lists the pages in the
  // order the API returns them, not by search index.
  static async fetchRelatedArticles(host: string, title: string, limit: number,
    keepOrder: boolean = false): Promise<ArticleSummary[]> {
    const params: Record<string, string> = {
      'action': 'query',
      'formatversion': '2',
      'generator': 'search',
      'gsrlimit': String(limit),
      'gsrnamespace': '0',
      'gsrqiprofile': 'classic_noboostlinks',
      'gsrsearch': 'morelike:' + title,
      'origin': '*',
      'pilimit': '20',
      'piprop': 'thumbnail',
      'pithumbsize': '160',
      'prop': 'pageimages|description|info|extracts',
      'inprop': 'varianttitles',
      'smaxage': '86400',
      'maxage': '86400',
      'format': 'json',
      'exintro': '1',
      'explaintext': '1'
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: RelatedResponseJson = await HttpClient.getJson<RelatedResponseJson>(url);
    const out: ArticleSummary[] = [];
    const pages: RelatedPageJson[] = resp.query?.pages ?? [];
    for (const page of pages) {
      const summaryJson: ArticleSummaryJson = {
        pageid: page.pageid,
        title: page.title,
        displaytitle: page.title,
        description: page.description,
        extract: page.extract,
        index: page.index,
        thumbnail: page.thumbnail
      };
      const summary: ArticleSummary = ArticleSummary.fromJson(summaryJson);
      out.push(summary);
    }
    // Source: related results are ordered by their search index.
    if (!keepOrder) {
      out.sort((a: ArticleSummary, b: ArticleSummary): number => (a.index ?? 0) - (b.index ?? 0));
    }
    return out;
  }
}
