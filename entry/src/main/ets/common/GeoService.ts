// svc_geo — ported from Wikipedia/Code/WMFLocationSearchFetcher.m:135 (generator=geosearch
// around a coordinate; the search-term variant at :100 uses nearcoord: in gsrsearch).
// formatversion=2 is requested so query.pages is an array. The per-result distance comes from
// coordinates[0].dist (codistancefrompoint), which the source feeds MWKLocationSearchResult.

import { HttpClient } from './HttpClient';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { MWKSearchResultJson } from '../model/MWKSearchResult';
import {
  MWKLocationSearchResult,
  WMFCircularRegion,
  WMFLocationSearchResults
} from '../model/WMFLocationSearchResults';

interface GeoCoordinateJson {
  lat?: number;
  lon?: number;
  dim?: number;
  type?: string;
  primary?: boolean;
  dist?: number;
}

interface GeoPageJson extends MWKSearchResultJson {
  coordinates?: GeoCoordinateJson[];
}

interface GeoQueryJson {
  pages?: GeoPageJson[];
}

interface GeoSearchResponseJson {
  query?: GeoQueryJson;
}

export class GeoService {
  // LocationManager.isAuthorized: location services on and this app allowed to read the
  // location (either accuracy). Off when the services switch is off, as iOS reports .denied.
  static isLocationAuthorized(): boolean {
    try {
      if (!geoLocationManager.isLocationEnabled()) {
        return false;
      }
      const token: number = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId;
      const mgr: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      return mgr.checkAccessTokenSync(token, 'ohos.permission.APPROXIMATELY_LOCATION') ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      return false;
    }
  }

  // Source: WMFLocationSearchFetcher.m:137 — action=query, generator=geosearch,
  // ggscoord/codistancefrompoint "{lat}|{lon}", ggsradius, ggslimit.
  // term: WMFLocationSearchFetcher's search-term variant ("Nearby matching ..."), a full-text
  // search limited to the circle with CirrusSearch's nearcoord keyword.
  static async searchNearby(host: string, latitude: number, longitude: number,
    radiusMeters: number, numberOfResults: number, term: string = ''): Promise<WMFLocationSearchResults> {
    const coords: string = String(latitude) + '|' + String(longitude);
    const limit: string = String(numberOfResults);
    const params: Record<string, string> = {
      'action': 'query',
      'prop': 'coordinates|pageimages|description|pageprops|extracts',
      'coprop': 'type|dim',
      'colimit': limit,
      'pithumbsize': '320',
      'pilimit': limit,
      'ppprop': 'displaytitle',
      'generator': 'geosearch',
      'ggscoord': coords,
      'codistancefrompoint': coords,
      'ggsradius': String(radiusMeters),
      'ggslimit': limit,
      'exintro': '1',
      'exlimit': limit,
      'explaintext': '',
      'format': 'json',
      'formatversion': '2'
    };
    // WMFLocationSearchFetcher: geosearch serves at most a 10 km radius, so a term search or
    // a region wider than that (a zoomed-out map) goes through search with nearcoord instead.
    params['ggsradius'] = String(Math.min(10000, Math.max(10, Math.round(radiusMeters))));
    if (term !== '' || radiusMeters > 10000) {
      delete params['ggscoord'];
      delete params['ggsradius'];
      delete params['ggslimit'];
      params['generator'] = 'search';
      params['gsrsearch'] = (term !== '' ? term + ' ' : '') + 'nearcoord:' + String(Math.round(radiusMeters)) + 'm,' +
        coords.replace('|', ',');
      params['gsrnamespace'] = '0';
      params['gsrlimit'] = limit;
    }
    const url: string = HttpClient.buildURL('https://' + host + '/w/api.php', params);
    const resp: GeoSearchResponseJson = await HttpClient.getJson<GeoSearchResponseJson>(url);

    const out = new WMFLocationSearchResults();
    out.searchSiteURL = 'https://' + host;
    const region = new WMFCircularRegion();
    region.latitude = latitude;
    region.longitude = longitude;
    region.radius = radiusMeters;
    out.region = region;
    out.searchTerm = term !== '' ? term : null;

    const results: MWKLocationSearchResult[] = [];
    const pages: GeoPageJson[] = resp.query?.pages ?? [];
    for (const page of pages) {
      let distance: number = 0;
      const coordinates: GeoCoordinateJson[] = page.coordinates ?? [];
      if (coordinates.length > 0) {
        distance = coordinates[0].dist ?? 0;
      }
      results.push(MWKLocationSearchResult.fromJsonWithDistance(page, distance));
    }
    // Source: nearby results are ordered by distance from the query coordinates.
    results.sort((a: MWKLocationSearchResult, b: MWKLocationSearchResult): number =>
      a.distanceFromQueryCoordinates - b.distanceFromQueryCoordinates);
    out.results = results;
    return out;
  }
}
