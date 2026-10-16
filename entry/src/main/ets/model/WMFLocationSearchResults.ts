// Ported from Wikipedia/Code/WMFLocationSearchResults.h and MWKLocationSearchResult.h
// (geosearch results scoped to a region).

import { MWKSearchResult, MWKSearchResultJson } from './MWKSearchResult';

export class MWKLocationSearchResult extends MWKSearchResult {
  distanceFromQueryCoordinates: number = 0;        // meters

  static fromJsonWithDistance(j: MWKSearchResultJson, distanceFromQueryCoordinates: number): MWKLocationSearchResult {
    const base = MWKSearchResult.fromJson(j);
    const out = new MWKLocationSearchResult();
    out.articleID = base.articleID;
    out.revID = base.revID;
    out.displayTitle = base.displayTitle;
    out.displayTitleHTML = base.displayTitleHTML;
    out.title = base.title;
    out.wikidataDescription = base.wikidataDescription;
    out.extract = base.extract;
    out.thumbnailURL = base.thumbnailURL;
    out.index = base.index;
    out.titleNamespace = base.titleNamespace;
    out.viewCounts = base.viewCounts;
    out.latitude = base.latitude;
    out.longitude = base.longitude;
    out.geoDimension = base.geoDimension;
    out.geoType = base.geoType;
    out.distanceFromQueryCoordinates = distanceFromQueryCoordinates;
    return out;
  }
}

export class WMFCircularRegion {
  latitude: number = 0;
  longitude: number = 0;
  radius: number = 0;                              // meters
}

export class WMFLocationSearchResults {
  searchSiteURL: string = '';
  region: WMFCircularRegion = new WMFCircularRegion();
  searchTerm: string | null = null;
  results: MWKLocationSearchResult[] = [];
}
