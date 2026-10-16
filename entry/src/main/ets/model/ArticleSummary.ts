// Ported from WMF Framework/ArticleSummary.swift (/page/summary response).

export class ArticleSummaryNamespace {
  id: number | null = null;
  text: string | null = null;
}

export class ArticleSummaryImage {
  source: string = '';
  width: number = 0;
  height: number = 0;

  get url(): string {
    return this.source;
  }
}

export class ArticleSummaryURLs {
  page: string | null = null;
  revisions: string | null = null;
  edit: string | null = null;
  talk: string | null = null;
}

export class ArticleSummaryContentURLs {
  desktop: ArticleSummaryURLs | null = null;
  mobile: ArticleSummaryURLs | null = null;
}

export class ArticleSummaryCoordinates {
  lat: number = 0;
  lon: number = 0;
}

interface ArticleSummaryNamespaceJson {
  id?: number;
  text?: string;
}

interface ArticleSummaryImageJson {
  source?: string;
  width?: number;
  height?: number;
}

interface ArticleSummaryURLsJson {
  page?: string;
  revisions?: string;
  edit?: string;
  talk?: string;
}

interface ArticleSummaryContentURLsJson {
  desktop?: ArticleSummaryURLsJson;
  mobile?: ArticleSummaryURLsJson;
}

interface ArticleSummaryCoordinatesJson {
  lat?: number;
  lon?: number;
}

export interface ArticleSummaryJson {
  pageid?: number;
  wikibase_item?: string;
  revision?: string;
  timestamp?: string;
  index?: number;
  namespace?: ArticleSummaryNamespaceJson;
  title?: string;
  displaytitle?: string;
  description?: string;
  extract?: string;
  extract_html?: string;
  thumbnail?: ArticleSummaryImageJson;
  originalimage?: ArticleSummaryImageJson;
  coordinates?: ArticleSummaryCoordinatesJson;
  content_urls?: ArticleSummaryContentURLsJson;
}

function imageFromJson(j: ArticleSummaryImageJson): ArticleSummaryImage {
  const out = new ArticleSummaryImage();
  out.source = j.source ?? '';
  out.width = j.width ?? 0;
  out.height = j.height ?? 0;
  return out;
}

function urlsFromJson(j: ArticleSummaryURLsJson): ArticleSummaryURLs {
  const out = new ArticleSummaryURLs();
  out.page = j.page ?? null;
  out.revisions = j.revisions ?? null;
  out.edit = j.edit ?? null;
  out.talk = j.talk ?? null;
  return out;
}

export class ArticleSummary {
  id: number | null = null;                        // JSON: pageid
  wikidataID: string | null = null;                // JSON: wikibase_item
  revision: string | null = null;
  timestamp: string | null = null;
  index: number | null = null;
  namespace: ArticleSummaryNamespace | null = null;
  title: string | null = null;
  displayTitle: string | null = null;              // JSON: displaytitle
  articleDescription: string | null = null;        // JSON: description
  extract: string | null = null;
  extractHTML: string | null = null;               // JSON: extract_html
  thumbnail: ArticleSummaryImage | null = null;
  original: ArticleSummaryImage | null = null;     // JSON: originalimage
  coordinates: ArticleSummaryCoordinates | null = null;
  languageVariantCode: string | null = null;
  contentURLs: ArticleSummaryContentURLs = new ArticleSummaryContentURLs();

  get articleURL(): string | null {
    return this.contentURLs.desktop?.page ?? null;
  }

  get key(): string | null {
    return this.articleURL;
  }

  static fromJson(j: ArticleSummaryJson): ArticleSummary {
    const out = new ArticleSummary();
    out.id = j.pageid ?? null;
    out.wikidataID = j.wikibase_item ?? null;
    out.revision = j.revision ?? null;
    out.timestamp = j.timestamp ?? null;
    out.index = j.index ?? null;
    const namespaceJson = j.namespace;
    if (namespaceJson !== undefined) {
      const ns = new ArticleSummaryNamespace();
      ns.id = namespaceJson.id ?? null;
      ns.text = namespaceJson.text ?? null;
      out.namespace = ns;
    }
    out.title = j.title ?? null;
    out.displayTitle = j.displaytitle ?? null;
    out.articleDescription = j.description ?? null;
    out.extract = j.extract ?? null;
    out.extractHTML = j.extract_html ?? null;
    const thumbnailJson = j.thumbnail;
    if (thumbnailJson !== undefined) {
      out.thumbnail = imageFromJson(thumbnailJson);
    }
    const originalJson = j.originalimage;
    if (originalJson !== undefined) {
      out.original = imageFromJson(originalJson);
    }
    const coordinatesJson = j.coordinates;
    if (coordinatesJson !== undefined) {
      const c = new ArticleSummaryCoordinates();
      c.lat = coordinatesJson.lat ?? 0;
      c.lon = coordinatesJson.lon ?? 0;
      out.coordinates = c;
    }
    const contentUrlsJson = j.content_urls;
    if (contentUrlsJson !== undefined) {
      const cu = new ArticleSummaryContentURLs();
      const desktopJson = contentUrlsJson.desktop;
      if (desktopJson !== undefined) {
        cu.desktop = urlsFromJson(desktopJson);
      }
      const mobileJson = contentUrlsJson.mobile;
      if (mobileJson !== undefined) {
        cu.mobile = urlsFromJson(mobileJson);
      }
      out.contentURLs = cu;
    }
    return out;
  }
}
