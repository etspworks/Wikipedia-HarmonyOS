// Ported from Wikipedia/Code/WMFFeedArticlePreview.h/.m (MTLJSONSerializing key paths).

interface FeedThumbnailJson {
  source?: string;
}

interface FeedOriginalImageJson {
  source?: string;
  width?: number;
  height?: number;
}

interface FeedDesktopUrlsJson {
  page?: string;
}

interface FeedContentUrlsJson {
  desktop?: FeedDesktopUrlsJson;
}

export interface WMFFeedArticlePreviewJson {
  normalizedtitle?: string;
  displaytitle?: string;
  titles?: FeedTitlesJson;
  description?: string;
  extract?: string;
  thumbnail?: FeedThumbnailJson;
  originalimage?: FeedOriginalImageJson;
  content_urls?: FeedContentUrlsJson;
  lang?: string;
  views?: number;
  rank?: number;
}

interface FeedTitlesJson {
  normalized?: string;
  display?: string;
}

export class WMFFeedArticlePreview {
  displayTitle: string = '';                       // JSON: normalizedtitle
  displayTitleHTML: string = '';                   // JSON: displaytitle ?? normalizedtitle
  wikidataDescription: string | null = null;       // JSON: description
  snippet: string | null = null;                   // JSON: extract
  thumbnailURL: string | null = null;              // JSON: thumbnail.source
  imageURLString: string | null = null;            // JSON: originalimage.source
  imageWidth: number | null = null;
  imageHeight: number | null = null;
  articleURL: string = '';                         // JSON: content_urls.desktop.page
  language: string | null = null;                  // JSON: lang
  numberOfViews: number | null = null;             // JSON: views (top-read)
  rank: number | null = null;                      // JSON: rank (top-read)
  // the place, for the nearby card's distance and compass (not in the feed JSON)
  latitude: number | null = null;
  longitude: number | null = null;

  static fromJson(j: WMFFeedArticlePreviewJson): WMFFeedArticlePreview {
    const out = new WMFFeedArticlePreview();
    const normalized: string = j.normalizedtitle ?? j.titles?.normalized ?? '';
    out.displayTitle = normalized;
    out.displayTitleHTML = j.displaytitle ?? j.titles?.display ?? normalized;
    out.wikidataDescription = j.description ?? null;
    out.snippet = j.extract ?? null;
    out.thumbnailURL = j.thumbnail?.source ?? null;
    out.imageURLString = j.originalimage?.source ?? null;
    out.imageWidth = j.originalimage?.width ?? null;
    out.imageHeight = j.originalimage?.height ?? null;
    out.articleURL = j.content_urls?.desktop?.page ?? '';
    out.language = j.lang ?? null;
    out.numberOfViews = j.views ?? null;
    out.rank = j.rank ?? null;
    return out;
  }
}
