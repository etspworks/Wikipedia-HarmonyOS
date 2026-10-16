// Ported from Wikipedia/Code/MWKSearchResult.h/.m (MTLJSONSerializing key paths).

interface SearchThumbnailJson {
  source?: string;
}

interface SearchPagePropsJson {
  displaytitle?: string;
}

interface SearchRevisionJson {
  revid?: number;
}

interface SearchCoordinateJson {
  lat?: number;
  lon?: number;
  dim?: number;
  type?: string;
  primary?: boolean;
}

export interface MWKSearchResultJson {
  pageid?: number;
  ns?: number;
  title?: string;
  index?: number;
  description?: string;
  extract?: string;
  thumbnail?: SearchThumbnailJson;
  pageprops?: SearchPagePropsJson;
  revisions?: SearchRevisionJson[];
  coordinates?: SearchCoordinateJson[];
}

export class MWKSearchResult {
  articleID: number = 0;                           // JSON: pageid
  revID: number = 0;                               // JSON: revisions[0].revid
  displayTitle: string | null = null;              // JSON: pageprops.displaytitle ?? title
  displayTitleHTML: string | null = null;
  title: string | null = null;
  wikidataDescription: string | null = null;       // JSON: description
  extract: string | null = null;
  thumbnailURL: string | null = null;              // JSON: thumbnail.source
  index: number | null = null;
  titleNamespace: number | null = null;            // JSON: ns
  viewCounts: number[] = [];
  latitude: number | null = null;                  // JSON: coordinates[0].lat
  longitude: number | null = null;                 // JSON: coordinates[0].lon
  geoDimension: number | null = null;              // JSON: coordinates[0].dim
  geoType: string | null = null;                   // JSON: coordinates[0].type

  // Source: displayTitleHTML falls back to displayTitle when empty.
  get effectiveDisplayTitleHTML(): string {
    if (this.displayTitleHTML !== null && this.displayTitleHTML !== '') {
      return this.displayTitleHTML;
    }
    return this.displayTitle ?? '';
  }

  // Source: articleURLForSiteURL — https://<host>/wiki/<title>.
  articleURLForSiteHost(siteHost: string): string | null {
    if (this.title === null) {
      return null;
    }
    return 'https://' + siteHost + '/wiki/' + encodeURIComponent(this.title.replace(/ /g, '_'));
  }

  static fromJson(j: MWKSearchResultJson): MWKSearchResult {
    const out = new MWKSearchResult();
    out.articleID = j.pageid ?? 0;
    const revisions = j.revisions;
    if (revisions !== undefined && revisions.length > 0) {
      out.revID = revisions[0].revid ?? 0;
    }
    out.title = j.title ?? null;
    const displayTitle: string | null = j.pageprops?.displaytitle ?? j.title ?? null;
    out.displayTitle = displayTitle;
    out.displayTitleHTML = displayTitle;
    out.wikidataDescription = j.description ?? null;
    out.extract = j.extract ?? null;
    out.thumbnailURL = j.thumbnail?.source ?? null;
    out.index = j.index ?? null;
    out.titleNamespace = j.ns ?? null;
    const coordinates = j.coordinates;
    if (coordinates !== undefined && coordinates.length > 0) {
      out.latitude = coordinates[0].lat ?? null;
      out.longitude = coordinates[0].lon ?? null;
      out.geoDimension = coordinates[0].dim ?? null;
      out.geoType = coordinates[0].type ?? null;
    }
    return out;
  }
}
