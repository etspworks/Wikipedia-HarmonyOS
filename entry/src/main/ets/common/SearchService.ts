// svc_search — ported from Wikipedia/Code/WMFSearchFetcher.m:49 (prefix search:
// generator=prefixsearch + list=search suggestion) and :79 (full-text: generator=search).
// formatversion=2 is requested so query.pages is an array (the source walks the
// indexed-object form, which ArkTS cannot).

import { HttpClient } from './HttpClient';
import { MWKSearchResult, MWKSearchResultJson } from '../model/MWKSearchResult';

interface SearchInfoJson {
  suggestion?: string;
}

interface SearchQueryJson {
  pages?: MWKSearchResultJson[];
  searchinfo?: SearchInfoJson;
}

interface SearchResponseJson {
  query?: SearchQueryJson;
}

// Source: WMFSearchResults.h — results plus the "did you mean" suggestion.
export class WMFSearchResults {
  searchTerm: string = '';
  results: MWKSearchResult[] = [];
  searchSuggestion: string | null = null;
}

export class SearchService {
  static readonly maxResultLimit: number = 24;     // Source: WMFMaxSearchResultLimit

  // Source: WMFSearchFetcher.m:49 — prefix search with piggybacked suggestion lookup.
  static async prefixSearch(host: string, searchTerm: string,
    resultLimit: number): Promise<WMFSearchResults> {
    const limit: number = Math.min(resultLimit, SearchService.maxResultLimit);
    const params: Record<string, string> = {
      'action': 'query',
      'generator': 'prefixsearch',
      'gpssearch': searchTerm,
      'gpsnamespace': '0',
      'gpslimit': String(limit),
      'prop': 'description|pageprops|pageimages|revisions|coordinates',
      'coprop': 'type|dim',
      'piprop': 'thumbnail',
      'ppprop': 'displaytitle',
      'pithumbsize': '320',
      'pilimit': String(limit),
      'rvprop': 'ids',
      'list': 'search',
      'srsearch': searchTerm,
      'srnamespace': '0',
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
    return await SearchService.runSearch(host, searchTerm, params);
  }

  // Source: WMFSearchFetcher.m:79 — full-text search (the prefix-search fallback).
  static async fullTextSearch(host: string, searchTerm: string,
    resultLimit: number): Promise<WMFSearchResults> {
    const limit: number = Math.min(resultLimit, SearchService.maxResultLimit);
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'description|pageprops|pageimages|revisions|coordinates',
      'coprop': 'type|dim',
      'ppprop': 'displaytitle',
      'generator': 'search',
      'gsrsearch': searchTerm,
      'gsrnamespace': '0',
      'gsrwhat': 'text',
      'gsrinfo': '',
      'gsrprop': 'redirecttitle',
      'gsroffset': '0',
      'gsrlimit': String(limit),
      'piprop': 'thumbnail',
      'pithumbsize': '320',
      'pilimit': String(limit),
      'rvprop': 'ids',
      'continue': '',
      'format': 'json',
      'formatversion': '2',
      'redirects': '1'
    };
    return await SearchService.runSearch(host, searchTerm, params);
  }

  private static async runSearch(host: string, searchTerm: string,
    params: Record<string, string>): Promise<WMFSearchResults> {
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: SearchResponseJson = await HttpClient.getJson<SearchResponseJson>(url);
    const out = new WMFSearchResults();
    out.searchTerm = searchTerm;
    out.searchSuggestion = resp.query?.searchinfo?.suggestion ?? null;
    const results: MWKSearchResult[] = [];
    const pages: MWKSearchResultJson[] = resp.query?.pages ?? [];
    for (const page of pages) {
      results.push(MWKSearchResult.fromJson(page));
    }
    // Source: results are ordered by their prefix/search index.
    results.sort((a: MWKSearchResult, b: MWKSearchResult): number =>
      (a.index ?? 0) - (b.index ?? 0));
    out.results = results;
    return out;
  }
}
