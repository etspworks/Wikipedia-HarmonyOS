// svc_commons — ported from Wikipedia/Code/WMFSearchFetcher.m:140 (fetchFilesForSearchTerm,
// commons.wikimedia.org file search, namespace 6) and Wikipedia/Code/MWKImageInfoFetcher.m:196
// (prop=imageinfo with extmetadata). formatversion=2 is requested so query.pages is an array
// (the source walks the indexed-object form, which ArkTS cannot).

import { HttpClient } from './HttpClient';
import { MWKSearchResult, MWKSearchResultJson } from '../model/MWKSearchResult';
import { MWKImageInfo, MWKImageInfoJson } from '../model/MWKImageInfo';

const COMMONS_HOST: string = 'commons.wikimedia.org';

interface CommonsQueryJson {
  pages?: MWKSearchResultJson[];
}

interface CommonsSearchResponseJson {
  query?: CommonsQueryJson;
}

interface ImageInfoPageJson {
  title?: string;
  imageinfo?: MWKImageInfoJson[];
}

interface ImageInfoQueryJson {
  pages?: ImageInfoPageJson[];
}

interface ImageInfoResponseJson {
  query?: ImageInfoQueryJson;
}

export class CommonsService {
  // Source: WMFSearchFetcher fetchFilesForSearchTerm — prefix (generator=prefixsearch) or
  // full-text (generator=search) file search on Commons, namespace 6.
  static async searchFiles(searchTerm: string, resultLimit: number,
    fullTextSearch: boolean): Promise<MWKSearchResult[]> {
    const limit: string = String(resultLimit);
    let params: Record<string, string>;
    if (!fullTextSearch) {
      params = {
        'action': 'query',
        'generator': 'prefixsearch',
        'gpssearch': searchTerm,
        'gpsnamespace': '6',
        'gpslimit': limit,
        'prop': 'description|pageprops|pageimages|revisions',
        'coprop': 'type|dim',
        'piprop': 'thumbnail',
        'ppprop': 'displaytitle',
        'pithumbsize': '320',
        'pilimit': limit,
        'rvprop': 'ids',
        'list': 'search',
        'srsearch': searchTerm,
        'srnamespace': '6',
        'srwhat': 'text',
        'srinfo': 'suggestion',
        'srprop': '',
        'sroffset': '0',
        'srlimit': '1',
        'redirects': '1',
        'continue': '',
        'format': 'json',
        'formatversion': '2'
      };
    } else {
      params = {
        'action': 'query',
        'prop': 'description|pageprops|pageimages|revisions',
        'coprop': 'type|dim',
        'ppprop': 'displaytitle',
        'generator': 'search',
        'gsrsearch': searchTerm,
        'gsrnamespace': '6',
        'gsrwhat': 'text',
        'gsrinfo': '',
        'gsrprop': 'redirecttitle',
        'gsroffset': '0',
        'gsrlimit': limit,
        'piprop': 'thumbnail',
        'pithumbsize': '320',
        'pilimit': limit,
        'rvprop': 'ids',
        'continue': '',
        'format': 'json',
        'formatversion': '2',
        'redirects': '1'
      };
    }
    const url: string = HttpClient.buildURL('https://' + COMMONS_HOST + '/w/api.php', params);
    const resp: CommonsSearchResponseJson =
      await HttpClient.getJson<CommonsSearchResponseJson>(url);
    const out: MWKSearchResult[] = [];
    const pages: MWKSearchResultJson[] = resp.query?.pages ?? [];
    for (const page of pages) {
      out.push(MWKSearchResult.fromJson(page));
    }
    out.sort((a: MWKSearchResult, b: MWKSearchResult): number => (a.index ?? 0) - (b.index ?? 0));
    return out;
  }

  // Source: MWKImageInfoFetcher.m:196 — action=query, prop=imageinfo,
  // iiprop=url|extmetadata|dimensions, iiextmetadatamultilang=1, iiurlwidth={thumb}.
  static async fetchImageInfo(host: string, titles: string[],
    thumbnailWidth: number): Promise<MWKImageInfo[]> {
    const params: Record<string, string> = {
      'format': 'json',
      'formatversion': '2',
      'action': 'query',
      'titles': titles.join('|'),
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata|dimensions',
      'iiextmetadatafilter': 'ImageDescription|License|LicenseShortName|LicenseUrl|Artist',
      'iiextmetadatalanguage': HttpClient.acceptLanguage,
      'iiurlwidth': String(thumbnailWidth)
    };
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: ImageInfoResponseJson = await HttpClient.getJson<ImageInfoResponseJson>(url);
    const out: MWKImageInfo[] = [];
    const pages: ImageInfoPageJson[] = resp.query?.pages ?? [];
    for (const page of pages) {
      const infos: MWKImageInfoJson[] = page.imageinfo ?? [];
      if (infos.length === 0) {
        continue;
      }
      const first: MWKImageInfoJson = infos[0];
      const info: MWKImageInfo = MWKImageInfo.fromJson(first);
      // Source: canonicaltitle falls back to the page title.
      if (info.canonicalPageTitle === null) {
        info.canonicalPageTitle = page.title ?? null;
      }
      out.push(info);
    }
    return out;
  }

  // Convenience for gallery detail: image info for one Commons file title.
  // MWKImageInfoFetcher for a gallery: many files in one imageinfo request (50 a call).
  static async fetchCommonsImageInfos(fileTitles: string[], thumbnailWidth: number): Promise<MWKImageInfo[]> {
    const out: MWKImageInfo[] = [];
    for (let i: number = 0; i < fileTitles.length; i += 50) {
      const chunk: string[] = fileTitles.slice(i, i + 50).filter((t: string): boolean => t !== '');
      if (chunk.length > 0) {
        out.push(...await CommonsService.fetchImageInfo(COMMONS_HOST, chunk, thumbnailWidth));
      }
    }
    return out;
  }

  static async fetchCommonsImageInfo(fileTitle: string,
    thumbnailWidth: number): Promise<MWKImageInfo | null> {
    const infos: MWKImageInfo[] =
      await CommonsService.fetchImageInfo(COMMONS_HOST, [fileTitle], thumbnailWidth);
    if (infos.length === 0) {
      return null;
    }
    return infos[0];
  }
}
