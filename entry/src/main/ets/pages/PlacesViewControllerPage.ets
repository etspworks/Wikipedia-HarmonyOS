// screen_places — presentation: page, hosted by comp_root_tab_bar (root tab 1).
//
// S3 structure from Wikipedia/Code/PlacesViewController.swift + its .xib, section by section:
//   nav bar        — the large "Places" title, the filter UIBarButtonItem
//                    (accessibilityIdentifier "places_filter", an action sheet titled
//                    "Filter articles" with Top read articles / Saved articles), plus the
//                    root Tabs and Profile buttons the app view controller adds.
//   searchBar      — placeholder "Search Places"; typing drives PlaceSearchSuggestionController,
//                    whose table is a list of PlacesSearchSuggestionTableViewCell
//                    (comp_places_suggestion_cell).
//   scope bar      — the Map / List segmented control (UISearchBar scopeButtonTitles).
//   mapContainer   — the map with one annotation per geosearch article, the
//                    recenterOnUserLocationButton over it, and (when authorization is
//                    missing) the enable-location panel.
//   listView       — the same articles as ArticleLocationCollectionViewCell rows
//                    (comp_article_location_cell), shown when the List scope is selected.
//   tab bar        — comp_root_tab_bar, visible in every captured root state.
// It also HOSTS the screen_article_popover overlay: selecting a map annotation presents
// ArticlePopoverViewController over the map (deferral from an earlier batch, closed here).
//
// S4: annotations and rows both come from svc_geo (GeoService.searchNearby — the
// WMFLocationSearchFetcher geosearch), never from a literal; the suggestion list comes from
// svc_search (SearchService.prefixSearch); recenter re-requests the location fix through
// @kit.LocationKit and reloads; the scope bar drives viewMode; the filter action sheet
// switches between the top-read and saved-article searches (svc_saved_store).
//
// feat_map: the map is Huawei Map Kit's MapComponent (Petal Maps), the peer of the source's
// MKMapView. It needs the app signed with a profile that has Map Kit enabled (DevEco Studio >
// Project Structure > Signing Configs > Enable open capabilities > Map Kit); without that the
// map stays blank. The pins, their grouping and the article callout stay the app's own.
//
// S5: capture base.ui.json (402x874) — "Places" 28pt at [16,69], Filter/Tabs/Profile at
// x237/290/345 y66, the search field [16,117][386,161] with the leading magnifier at x28,
// the Map|List segmented control [75,178][327,210], and the tab bar from y791.
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { distanceText, bearingDegrees } from '../common/DistanceFormat';
import { router, KeyboardAvoidMode, display } from '@kit.ArkUI';
import { PLACES_FOCUS_KEY } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { common, abilityAccessCtrl, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { geoLocationManager } from '@kit.LocationKit';
import { sensor } from '@kit.SensorServiceKit';
import { i18n } from '@kit.LocalizationKit';
import { stripTags } from '../common/WebDocument';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ArticlePopoverView } from './ArticlePopoverViewControllerPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { WMFArticle } from '../model/WMFArticle';
import { MWKSearchResult } from '../model/MWKSearchResult';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { MWKLocationSearchResult, WMFLocationSearchResults } from '../model/WMFLocationSearchResults';
import { GeoService } from '../common/GeoService';
import { SearchService, WMFSearchResults } from '../common/SearchService';
import { SavedStore } from '../common/SavedStore';
import { HistoryStore } from '../common/HistoryStore';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { Prefs } from '../common/Prefs';
import { RootTabBar, isRootTabSwitch, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { ArticleLocationCollectionViewCell } from '../components/ArticleLocationCollectionViewCell';
import { PlacesSearchSuggestionTableViewCell } from '../components/PlacesSearchSuggestionTableViewCell';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE, ROOT_BAR_HEIGHT, navIconTint } from '../components/NavButton';

// WMFLocationSearchResults.results — the annotations AND the list rows.
class NearbyDataSource implements IDataSource {
  private items: MWKLocationSearchResult[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): MWKLocationSearchResult {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i: number = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: MWKLocationSearchResult[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// The "Nearby matching “term”" row's marker title (a .text PlaceSearch, not an article).
const MATCHING_ROW: string = '\u0000matching';

// PlaceSearchSuggestionController's recent section: what the reader searched, newest first.
const RECENT_SEARCHES_KEY: string = 'wmfPlacesRecentSearches';
const MAX_RECENT_SEARCHES: number = 10;

interface RecentPlaceSearch {
  title: string;
  detail: string;
  term: string;        // a "Nearby matching" search; '' for a place
  lat: number;
  lon: number;
}

// PlaceSearchSuggestionController.searches — the completion section.
class SuggestionDataSource implements IDataSource {
  private items: MWKSearchResult[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): MWKSearchResult {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i: number = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: MWKSearchResult[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// ArticleLocationCollectionViewController — PlacesViewController embeds one as its List
// scope (`var listViewController: ArticleLocationCollectionViewController!`). It owns the
// article-location rows; the host owns the search, the scope bar and the map.
@Component
struct ArticleLocationCollectionView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // An IDataSource notifies LazyForEach through its own DataChangeListener, so it needs no
  // state decorator to keep the rows live.
  source: NearbyDataSource = new NearbyDataSource();
  distanceOf: (item: MWKLocationSearchResult) => string = (item: MWKLocationSearchResult): string => '';
  bearingOf: (item: MWKLocationSearchResult) => number = (item: MWKLocationSearchResult): number => 0;
  onSelect: (item: MWKLocationSearchResult) => void = (item: MWKLocationSearchResult): void => {};

  build() {
    List() {
      LazyForEach(this.source, (item: MWKLocationSearchResult) => {
        ListItem() {
          ArticleLocationCollectionViewCell({
            title: item.displayTitle ?? item.title ?? '',
            articleDescription: item.wikidataDescription ?? '',
            imageURL: item.thumbnailURL ?? '',
            distanceText: this.distanceOf(item),
            bearing: this.bearingOf(item)
          })
        }
        .id('places_list_itemroot')
        .onClick(() => {
          this.onSelect(item);
        })
      }, (item: MWKLocationSearchResult, index: number) => (item.title ?? '') + '_' + index)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}

// One annotation on the map: a single article, or a cluster of the articles drawn within
// CLUSTER_CELL vp of each other at the current zoom (the source groups by quadkey).
class PlaceGroup {
  key: string = '';
  // Position on the map view, in vp.
  x: number = 0;
  y: number = 0;
  latitude: number = 0;
  longitude: number = 0;
  items: MWKLocationSearchResult[] = [];
}

const CLUSTER_CELL: number = 36;
// Street level, for a single place picked from search or the list.
const DEFAULT_ZOOM: number = 14;
// PlacesViewController.zoomAndPanMapView(toLocation:): the reader's own position opens on a
// region 10 km across (wmf_boundingRegion(with: 10000)), so the geosearch covers the same
// ground as the source's (up to 50 articles within its 10 km cap).
const READER_REGION_METERS: number = 10000;
// 3 shows a continent; 18 is close enough to tell neighbouring buildings apart.
const MIN_ZOOM: number = 3;
const MAX_ZOOM: number = 18;
// Web-Mercator tile edge in vp at zoom 0, for the visible-radius estimate.
const TILE_SIZE: number = 256;
// The list overlay's collapsed height: drag handle plus its header row.
const PANEL_MIN: number = 56;
const LAST_LATITUDE_KEY: string = 'WMFPlacesLastLatitude';
const LAST_LONGITUDE_KEY: string = 'WMFPlacesLastLongitude';
const NO_LAST_LOCATION: number = 999;

@Entry
@Component
export struct PlacesViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfIsDark') @Watch('onThemeChanged') wmfIsDark: boolean = false;
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  @StorageProp('wmfChromeBg') wmfChromeBg: string = '';

  // spec stateVars
  @State @Watch('onPinsChanged') nearby: MWKLocationSearchResult[] = [];
  @State viewMode: string = 'map';
  @State locationPermissionGranted: boolean = true;
  // currentSearchFilter: .top | .saved
  @State searchFilter: string = 'top';
  // the term the search key submitted; the list and map show only places matching it
  @State committedTerm: string = '';
  @State searchText: string = '';
  // showArticleURL: the focused article's title stands in the field (PlaceSearch
  // localizedDescription), not a search term; editing the field drops it
  @State focusLabel: string = '';
  @State suggestions: MWKSearchResult[] = [];
  // True once a completion query for the current term has come back. Without it the empty
  // overlay would flash between the keystroke and the response.
  @State suggestionsLoaded: boolean = false;
  // PlaceSearchSuggestionController's "Did you mean" row. prefixSearch already piggybacks the
  // API's suggestion; nothing surfaced it, so a misspelled place just produced an empty list.
  @State searchSuggestion: string = '';
  // An empty, focused search field shows the recent searches (or the empty overlay).
  @State searchFocused: boolean = false;
  @State recentSearches: RecentPlaceSearch[] = [];
  @State isLoading: boolean = true;
  @State loadError: string = '';
  // Index hosts this page as a tab, so its own onPageShow never fires; Index bumps this
  // instead. Returning from device Settings is how a denied location permission gets granted.
  @Prop @Watch('onHostShow') showTick: number = 0;
  // The root Tabs and Profile buttons present hosted @Component overlays, not routes:
  // WMFArticleTabsView / WMFProfileViewSheet are unregistered by design, exactly as
  // SettingsTabViewControllerPage hosts them.
  @State showTabsCover: boolean = false;
  @State showProfileSheet: boolean = false;
  // The selected annotation and its callout (screen_article_popover, drawn over the map).
  @State @Watch('onPinsChanged') selectedPlace: MWKLocationSearchResult | null = null;
  @State selectedIsSaved: boolean = false;
  @State calloutHeight: number = 150;
  // The enable-location panel is shown on first load and after an explicit request; the
  // reader can dismiss it and keep using the map around the default region.
  @State showEnableLocation: boolean = false;
  @State showRedoSearch: boolean = false;
  @State areaSearching: boolean = false;
  @State panelHeight: number = PANEL_MIN;

  private nearbySource: NearbyDataSource = new NearbyDataSource();
  private suggestionSource: SuggestionDataSource = new SuggestionDataSource();
  // mapRegion / currentUserLocation — the camera the geosearch is centred on.
  private camera: mapCommon.LatLng = { latitude: 0, longitude: 0 };
  private hasCamera: boolean = false;
  private zoom: number = DEFAULT_ZOOM;
  private panelDragStart: number = PANEL_MIN;
  private savingInFlight: boolean = false;
  private lastOpenAt: number = 0;
  // The map (PlacesViewController.mapView). Its controller exists only while the Map scope is
  // shown: the List scope tears the map down, and the camera above carries over to the next one.
  private mapController: map.MapComponentController | null = null;
  private markers: map.Marker[] = [];
  private markerGroups: PlaceGroup[] = [];
  private markerGeneration: number = 0;
  private lastMarkerClickAt: number = 0;
  private markerIcons: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  // Set while the app moves the camera itself, so only the reader's own pan or pinch offers
  // "Results in this area".
  private appMovingCamera: boolean = false;
  private userFix: geoLocationManager.Location | null = null;
  @State mapWidth: number = 0;
  @State mapHeight: number = 0;
  // The selected pin's point on the map view, which the callout hangs from.
  @State calloutAnchorX: number = 0;
  @State calloutAnchorY: number = 0;
  private userLatitude: number = 0;
  private userLongitude: number = 0;
  // ArticleLocationCollectionViewController follows locationManager's heading and location
  // updates while it is on screen: the compass needles turn with the phone, and bearings and
  // distances follow the reader. Degrees clockwise from true north, unwrapped (it runs past 360
  // and below 0) so a needle never spins the long way round when the heading crosses north.
  // Published to AppStorage, not passed down as a prop: only the needles redraw for it, not the
  // rows and their distance text.
  private heading: number = 0;
  private declination: number = 0;
  private tracking: boolean = false;
  private rotationListener: Callback<sensor.RotationVectorResponse> =
    (d: sensor.RotationVectorResponse): void => {
      this.onRotation(d);
    };
  private locationListener: Callback<geoLocationManager.Location> =
    (l: geoLocationManager.Location): void => {
      this.onLocationUpdate(l);
    };
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // The search field is near the top but the results fill the rest of the screen: shrink
    // the layout for the keyboard instead of translating the page out from under it.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    Prefs.init(ctx);
    this.loadRecentSearches();
    this.nearbySource.reload(this.nearby);
    this.suggestionSource.reload(this.suggestions);
    Database.init(ctx).then(() => {
      if (!this.focusedArticle) {
        this.recenterOnUserLocation();
      }
    }).catch((e: Error) => {
      console.error('places: db init failed: ' + e.message);
      if (!this.focusedArticle) {
        this.recenterOnUserLocation();
      }
    });
  }

  // MARK: - svc_geo

  // The root tab bar pushes this page as a route, so its own onPageShow fires too (returning
  // from device Settings brings the app, and this page, back to the foreground).
  onPageShow(): void {
    this.onHostShow();
  }

  onPageHide(): void {
    this.stopTracking();
  }

  aboutToDisappear(): void {
    this.stopTracking();
  }

  private startTracking(): void {
    if (this.tracking) {
      return;
    }
    this.tracking = true;
    try {
      sensor.on(sensor.SensorId.ROTATION_VECTOR, this.rotationListener, { interval: 'ui' });
    } catch (e) {
      console.warn('places: no compass heading: ' + this.describeError(e));
    }
    if (this.locationPermissionGranted) {
      try {
        geoLocationManager.on('locationChange',
          { priority: geoLocationManager.LocationRequestPriority.ACCURACY, timeInterval: 5, distanceInterval: 10 },
          this.locationListener);
      } catch (e) {
        console.warn('places: no location updates: ' + this.describeError(e));
      }
    }
  }

  private stopTracking(): void {
    if (!this.tracking) {
      return;
    }
    this.tracking = false;
    try {
      sensor.off(sensor.SensorId.ROTATION_VECTOR, this.rotationListener);
    } catch (e) {
      console.warn('places: compass off failed: ' + this.describeError(e));
    }
    try {
      geoLocationManager.off('locationChange', this.locationListener);
    } catch (e) {
      console.warn('places: location updates off failed: ' + this.describeError(e));
    }
  }

  // Rotation vector -> azimuth (magnetic north, radians), plus the local declination for true
  // north, as CLHeading.trueHeading. The azimuth is getOrientation's, read straight off the
  // quaternion (atan2(R[1], R[4]) of its rotation matrix) instead of two promise round trips per
  // sample; on the device both give the same value. It is already clockwise from north (checked
  // against the system Compass app). Sub-degree jitter is ignored.
  private onRotation(d: sensor.RotationVectorResponse): void {
    const azimuth: number = Math.atan2(2 * (d.x * d.y - d.z * d.w), 1 - 2 * (d.x * d.x + d.z * d.z));
    const heading: number = azimuth * 180 / Math.PI + this.declination;
    // the shortest turn from the last heading, in (-180, 180]
    const delta: number = ((heading - this.heading) % 360 + 540) % 360 - 180;
    if (Math.abs(delta) >= 1) {
      this.heading += delta;
      AppStorage.setOrCreate<number>('wmfPlacesHeading', this.heading);
    }
  }

  private onLocationUpdate(location: geoLocationManager.Location): void {
    this.userLatitude = location.latitude;
    this.userLongitude = location.longitude;
    this.showUserLocation(location);
    this.updateDeclination(location);
    // distances and bearings are read when a row is built
    this.nearbySource.reload(this.nearby);
  }

  private updateDeclination(location: geoLocationManager.Location): void {
    sensor.getGeomagneticInfo({ latitude: location.latitude, longitude: location.longitude, altitude: 0 },
      Date.now()).then((g: sensor.GeomagneticResponse) => {
      this.declination = g.deflectionAngle;
    }).catch((e: Error) => {
      console.warn('places: no magnetic declination: ' + e.message);
    });
  }

  onHostShow(): void {
    this.startTracking();
    if (this.showFocusedArticle()) {
      return;
    }
    // Back from device Settings with location now allowed: pick it up without a relaunch.
    if (!this.locationPermissionGranted) {
      this.loadNearby(false).catch((e: Error) => {
        console.error('places: nearby reload failed: ' + e.message);
      });
    }
  }

  // "View on a map" (wmf_URLForActivity(of: .places, withArticleURL:)): centre on that article
  // and open its callout instead of the reader's own location.
  private focusedArticle: boolean = false;
  // bumped by every focus: a nearby load already under way (the tab's own first load, started
  // before the focus arrived) then leaves the camera where the focus put it
  private focusSeq: number = 0;

  private showFocusedArticle(): boolean {
    const raw: string = AppStorage.get<string>(PLACES_FOCUS_KEY) ?? '';
    if (raw === '') {
      return false;
    }
    AppStorage.setOrCreate<string>(PLACES_FOCUS_KEY, '');
    const f: Record<string, string | number> = JSON.parse(raw) as Record<string, string | number>;
    const title: string = String(f['title']).replace(/_/g, ' ');
    this.focusedArticle = true;
    this.focusSeq++;
    this.showEnableLocation = false;
    this.searchFilter = 'top';
    this.committedTerm = '';
    this.searchText = title;
    this.focusLabel = title;
    this.viewMode = 'map';
    this.moveCamera(Number(f['lat']), Number(f['lon']), DEFAULT_ZOOM);
    // the reader's own position still feeds the callout's distance, without moving the map
    geoLocationManager.getCurrentLocation().then((l: geoLocationManager.Location) => {
      this.userLatitude = l.latitude;
      this.userLongitude = l.longitude;
      this.locationPermissionGranted = true;
    }).catch(() => {
    });
    this.searchAtCamera().then(() => {
      let item: MWKLocationSearchResult | undefined =
        this.nearby.find((r: MWKLocationSearchResult) => (r.title ?? '') === title);
      if (item === undefined) {
        item = new MWKLocationSearchResult();
        item.title = title;
        item.displayTitle = title;
        item.wikidataDescription = String(f['description'] ?? '');
        item.thumbnailURL = String(f['thumbnail'] ?? '');
        item.latitude = Number(f['lat']);
        item.longitude = Number(f['lon']);
        this.nearby = [item].concat(this.nearby);
        this.nearbySource.reload(this.nearby);
      }
      this.selectPlace(item);
    }).catch((e: Error) => {
      console.error('places: focused article search failed: ' + e.message);
    });
    return true;
  }

  // recenterOnUserLocation(_:) — take a fresh fix, move the camera, re-run the geosearch.
  private recenterOnUserLocation(showPanelOnDenied: boolean = true): void {
    // back to the default search: the focused article's title leaves the field
    if (this.focusLabel !== '' && this.searchText === this.focusLabel) {
      this.searchText = '';
      this.focusLabel = '';
    }
    this.isLoading = !this.hasCamera;
    this.loadError = '';
    this.loadNearby(showPanelOnDenied).catch((e: Error) => {
      console.error('places: nearby load failed: ' + e.message);
      this.isLoading = false;
    });
  }

  // enableLocationButtonPressed — PlacesViewController asks CLLocationManager for
  // when-in-use authorization here; the ArkTS peer is the runtime permission request. The
  // permissions themselves are declared in module.json5.
  private async requestLocationAuthorization(): Promise<void> {
    const perms: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    try {
      const mgr: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const res: PermissionRequestResult = await mgr.requestPermissionsFromUser(ctx, perms);
      // Location service itself off: the system sheet to switch it on (iOS asks via Settings).
      if (res.authResults.some((r: number) => r === 0) && !geoLocationManager.isLocationEnabled()) {
        await mgr.requestGlobalSwitch(ctx, abilityAccessCtrl.SwitchType.LOCATION);
      }
    } catch (e) {
      console.warn('places: location authorization request failed: ' + this.describeError(e));
    }
    await this.loadNearby(true);
  }

  // showPanelOnDenied: the first load and the reader's own request raise the enable-location
  // panel. A recenter tap after a denial does not: the OS will not ask again, the fix is in
  // Settings, and the map simply stays where it is.
  private async loadNearby(showPanelOnDenied: boolean): Promise<void> {
    const seq: number = this.focusSeq;
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.host = lang.languageCode + '.wikipedia.org';
    } catch (e) {
      console.warn('places: app language unavailable, defaulting to en');
    }
    let location: geoLocationManager.Location;
    try {
      location = await geoLocationManager.getCurrentLocation();
    } catch (e) {
      // No authorization / no fix — a normal first-run state, not a failure: info, so it is
      // not read as a crash.
      console.info('places: no location authorization: ' + this.describeError(e));
      this.locationPermissionGranted = false;
      this.showEnableLocation = showPanelOnDenied && seq === this.focusSeq;
      if (!this.hasCamera && seq === this.focusSeq) {
        await this.showDefaultRegion();
      }
      this.isLoading = false;
      return;
    }
    this.locationPermissionGranted = true;
    this.showEnableLocation = false;
    this.userLatitude = location.latitude;
    this.userLongitude = location.longitude;
    this.showUserLocation(location);
    this.updateDeclination(location);
    // permission may only now be granted: (re)start the location updates with it
    this.stopTracking();
    this.startTracking();
    Prefs.putNumber(LAST_LATITUDE_KEY, location.latitude);
    Prefs.putNumber(LAST_LONGITUDE_KEY, location.longitude);
    if (seq !== this.focusSeq) {
      return;
    }
    this.moveCamera(location.latitude, location.longitude, this.readerZoom(location.latitude));
    await this.searchAtCamera();
  }

  // Without a location the map opens on the last place a fix was taken, or the whole world
  // when there never was one; no user-location dot is drawn either way.
  private async showDefaultRegion(): Promise<void> {
    const lat: number = Prefs.getNumber(LAST_LATITUDE_KEY, NO_LAST_LOCATION);
    const lon: number = Prefs.getNumber(LAST_LONGITUDE_KEY, NO_LAST_LOCATION);
    if (lat === NO_LAST_LOCATION || lon === NO_LAST_LOCATION) {
      this.moveCamera(20, 0, MIN_ZOOM);
      return;
    }
    this.moveCamera(lat, lon, this.readerZoom(lat));
    await this.searchAtCamera();
  }

  // The zoom at which READER_REGION_METERS spans the map's width (Web Mercator).
  private readerZoom(latitude: number): number {
    let width: number = this.mapWidth;
    if (width <= 0) {
      try {
        width = px2vp(display.getDefaultDisplaySync().width);
      } catch (e) {
        width = 360;
      }
    }
    const zoom: number = Math.log2(40075016.686 * Math.cos(latitude * Math.PI / 180) * width /
      (TILE_SIZE * READER_REGION_METERS));
    return Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom));
  }

  private moveCamera(latitude: number, longitude: number, zoom: number): void {
    this.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom));
    this.camera = { latitude: latitude, longitude: ((longitude + 540) % 360) - 180 };
    this.hasCamera = true;
    const c: map.MapComponentController | null = this.mapController;
    if (c !== null) {
      this.appMovingCamera = true;
      c.animateCamera(map.newLatLng(this.camera, this.zoom), 300);
    }
  }

  // The geosearch around the camera; "Results in this area" re-runs it after a pan or zoom.
  private async searchAtCamera(): Promise<void> {
    this.showRedoSearch = false;
    this.selectedPlace = null;
    if (this.searchFilter === 'saved') {
      await this.loadSavedPlaces();
      return;
    }
    try {
      const results: WMFLocationSearchResults = await GeoService.searchNearby(
        this.host, this.camera.latitude, this.camera.longitude, this.visibleRadiusMeters(), 50, this.committedTerm);
      this.nearby = results.results;
      this.nearbySource.reload(this.nearby);
      this.loadError = '';
      // WMFLocationSearchErrorCode.noResults: the source toasts "No results found" - a term
      // search that came back empty left a bare map with nothing to say why.
      if (this.committedTerm !== '' && results.results.length === 0) {
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.empty_no_search_results_message'), duration: 3000
        });
        this.loadError = this.text($r('app.string.empty_no_search_results_message'));
      }
    } catch (e) {
      console.error('places: geosearch failed: ' + this.describeError(e));
      this.loadError = 'Nearby articles could not be loaded. Check your connection.';
    } finally {
      this.isLoading = false;
    }
  }

  // mapRegion: the circle around the visible map (half its diagonal), at least 1 km. A fixed
  // 10 km left a zoomed-out "Results in this area" with a few pins near the centre or none.
  // The first search runs before the map has been laid out (no size yet): it then covers the
  // reader's 10 km region the camera was just framed to, not the 1 km floor, which had left the
  // opening list with a handful of places.
  private visibleRadiusMeters(): number {
    if (this.mapWidth <= 0 || this.mapHeight <= 0) {
      return READER_REGION_METERS;
    }
    const metersPerVp: number = 40075016.686 * Math.cos(this.camera.latitude * Math.PI / 180) /
      (TILE_SIZE * Math.pow(2, this.zoom));
    return Math.max(1000, Math.sqrt(this.mapWidth * this.mapWidth + this.mapHeight * this.mapHeight) / 2 * metersPerVp);
  }

  // The button turns into a spinner until the area's results are drawn; a failed search says
  // so instead of leaving the old pins as if nothing had been asked.
  private redoSearchInThisArea(): void {
    this.areaSearching = true;
    this.searchAtCamera().then(() => {
      if (this.loadError !== '') {
        this.getUIContext().getPromptAction().showToast({ message: this.loadError });
      }
    }).catch((e: Error) => {
      console.error('places: redo search failed: ' + e.message);
    }).finally(() => {
      this.areaSearching = false;
    });
  }

  // The .saved filter searches the user's saved articles instead of the geosearch.
  private async loadSavedPlaces(): Promise<void> {
    this.loadError = '';
    try {
      const saved: WMFArticle[] = await SavedStore.savedArticles();
      // the coordinates were never stored for older saves; fill them in before filtering
      await SavedStore.fillMissingCoordinates(saved);
      const out: MWKLocationSearchResult[] = [];
      for (const a of saved) {
        if (a.latitude === 0 && a.longitude === 0) {
          continue;
        }
        const r: MWKLocationSearchResult = new MWKLocationSearchResult();
        r.title = a.displayTitle;
        r.displayTitle = a.displayTitle;
        r.wikidataDescription = a.wikidataDescription;
        r.thumbnailURL = a.imageURLString;
        r.latitude = a.latitude;
        r.longitude = a.longitude;
        out.push(r);
      }
      this.nearby = out;
      this.nearbySource.reload(this.nearby);
      if (out.length === 0) {
        this.loadError = 'None of your saved articles have location information';
      }
    } catch (e) {
      console.error('places: saved places failed: ' + this.describeError(e));
      this.loadError = 'Saved places could not be loaded.';
    } finally {
      this.isLoading = false;
    }
  }

  // MARK: - svc_search (PlaceSearchSuggestionController completions)

  private onSearchTextChanged(value: string): void {
    if (value === this.focusLabel) {
      return;
    }
    this.focusLabel = '';
    this.searchText = value;
    // clearing a submitted term brings the full nearby list back
    if (value.trim() === '' && this.committedTerm !== '') {
      this.committedTerm = '';
      this.searchAtCamera().catch((e: Error) => {
        console.error('places: search reset failed: ' + e.message);
      });
    }
    this.suggestionsLoaded = false;
    this.searchSuggestion = '';
    if (value.trim() === '') {
      this.suggestions = [];
      this.suggestionSource.reload(this.suggestions);
      return;
    }
    this.loadSuggestions(value).catch((e: Error) => {
      console.error('places: suggestions failed: ' + e.message);
    });
  }

  private submitSearch(): void {
    const term: string = this.searchText.trim();
    if (term === '') {
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.committedTerm = term;
    this.rememberSearch({
      title: this.text($r('app.string.places_search_articles_that_match'))
        .replace(/\\?\$1/, this.text($r('app.string.places_search_top_articles_that_match_scope')))
        .replace(/\\?\$2/, term),
      detail: '', term: term, lat: 0, lon: 0
    });
    this.suggestions = [];
    this.suggestionSource.reload(this.suggestions);
    this.searchAtCamera().catch((e: Error) => {
      console.error('places: term search failed: ' + e.message);
    });
  }

  // handleCompletion: only results with a location are completions. Under ten of them, a
  // world-wide nearcoord search for the term fills in (so a term that names no place still
  // offers the places that match it), then the "Nearby matching" row goes second.
  private async loadSuggestions(term: string): Promise<void> {
    const results: WMFSearchResults = await SearchService.prefixSearch(this.host, term, 24);
    if (this.searchText.trim() !== term.trim()) {
      return;
    }
    const places: MWKSearchResult[] = results.results.filter((r: MWKSearchResult) => r.latitude !== null);
    if (places.length < 10) {
      try {
        const lat: number = this.userLatitude !== 0 ? this.userLatitude : this.camera.latitude;
        const lon: number = this.userLongitude !== 0 ? this.userLongitude : this.camera.longitude;
        const world: WMFLocationSearchResults = await GeoService.searchNearby(this.host, lat, lon, 40075000, 24, term);
        if (this.searchText.trim() !== term.trim()) {
          return;
        }
        const seen: Set<string> = new Set<string>(places.map((r: MWKSearchResult) => r.title ?? ''));
        for (const r of world.results) {
          if (r.latitude !== null && !seen.has(r.title ?? '')) {
            seen.add(r.title ?? '');
            places.push(r);
          }
        }
      } catch (e) {
        console.warn('places: world completion search failed: ' + this.describeError(e));
      }
    }
    if (places.length > 0) {
      const match: MWKSearchResult = new MWKSearchResult();
      match.title = MATCHING_ROW;
      match.displayTitle = this.text($r('app.string.places_search_articles_that_match'))
        .replace(/\\?\$1/, this.text($r('app.string.places_search_top_articles_that_match_scope')))
        .replace(/\\?\$2/, term.trim());
      places.splice(1, 0, match);
    }
    this.suggestions = places;
    this.suggestionSource.reload(this.suggestions);
    const suggestion: string = results.searchSuggestion ?? '';
    this.searchSuggestion = suggestion === term.trim() ? '' : suggestion;
    this.suggestionsLoaded = true;
  }

  // Re-run the search with the corrected term.
  private applySearchSuggestion(): void {
    const corrected: string = this.searchSuggestion;
    if (corrected === '') {
      return;
    }
    this.searchSuggestion = '';
    this.onSearchTextChanged(corrected);
  }

  // A completion with coordinates recentres the map on that place (the source searches the
  // chosen region); one without coordinates can only be read.
  private selectSuggestion(item: MWKSearchResult): void {
    if (item.title === MATCHING_ROW) {
      this.submitSearch();
      return;
    }
    // Picking a completion ends the search: the field gives up focus and the keyboard goes.
    this.getUIContext().getFocusController().clearFocus();
    this.searchText = '';
    this.committedTerm = '';
    this.suggestions = [];
    this.suggestionSource.reload(this.suggestions);
    if (item.latitude === null || item.longitude === null) {
      this.openArticle(item.title ?? item.displayTitle ?? '');
      return;
    }
    this.rememberSearch({
      title: stripTags(item.displayTitle ?? item.title ?? ''), detail: item.wikidataDescription ?? '',
      term: '', lat: item.latitude, lon: item.longitude
    });
    this.viewMode = 'map';
    this.moveCamera(item.latitude, item.longitude, DEFAULT_ZOOM);
    this.searchAtCamera().catch((e: Error) => {
      console.error('places: suggestion search failed: ' + e.message);
    });
  }

  private loadRecentSearches(): void {
    try {
      this.recentSearches = JSON.parse(Prefs.getString(RECENT_SEARCHES_KEY, '[]')) as RecentPlaceSearch[];
    } catch (e) {
      this.recentSearches = [];
    }
  }

  private rememberSearch(r: RecentPlaceSearch): void {
    const rest: RecentPlaceSearch[] = this.recentSearches.filter((x: RecentPlaceSearch) => x.title !== r.title);
    this.recentSearches = [r].concat(rest).slice(0, MAX_RECENT_SEARCHES);
    Prefs.putString(RECENT_SEARCHES_KEY, JSON.stringify(this.recentSearches));
  }

  private clearRecentSearches(): void {
    this.recentSearches = [];
    Prefs.putString(RECENT_SEARCHES_KEY, '[]');
  }

  private selectRecentSearch(r: RecentPlaceSearch): void {
    if (r.term !== '') {
      this.searchText = r.term;
      this.submitSearch();
      return;
    }
    const item: MWKSearchResult = new MWKSearchResult();
    item.title = r.title;
    item.displayTitle = r.title;
    item.wikidataDescription = r.detail;
    item.latitude = r.lat;
    item.longitude = r.lon;
    this.selectSuggestion(item);
  }

  // "Your current location" / "All top articles": back to the plain top-articles search.
  private searchStart(fromUser: boolean): void {
    this.getUIContext().getFocusController().clearFocus();
    this.committedTerm = '';
    this.searchFilter = 'top';
    if (fromUser) {
      this.recenterOnUserLocation(false);
    } else {
      this.searchAtCamera().catch((e: Error) => {
        console.error('places: top articles search failed: ' + e.message);
      });
    }
  }

  // MARK: - filter action sheet

  // Re-picking the filter already in force changes nothing, so it must not reload either.
  private setFilter(filter: string): void {
    if (this.searchFilter === filter) {
      return;
    }
    this.searchFilter = filter;
    // The source re-runs the current search with the new filter over the same region. Going
    // through the location fix instead did nothing at all without location access.
    this.isLoading = true;
    this.searchAtCamera().catch((e: Error) => {
      console.error('places: filter search failed: ' + e.message);
    });
  }

  // PlacesViewController.filterButtonPressed raises a UIAlertController titled "Filter
  // articles" whose current option carries a checkmark.
  private showFilterSheet(): void {
    // showActionMenu, not ActionSheet: the ActionSheet squeezed its rows together.
    this.getUIContext().getPromptAction().showActionMenu({
      title: $r('app.string.places_filter_articles_action_sheet_title'),
      buttons: [
        { text: this.filterRowTitle('top', this.text($r('app.string.places_filter_top_read_articles'))),
          color: $r('app.color.theme_link') },
        { text: this.filterRowTitle('saved', this.text($r('app.string.places_filter_saved_articles'))),
          color: $r('app.color.theme_link') }
      ]
    }).then((r) => {
      this.setFilter(r.index === 0 ? 'top' : 'saved');
    }).catch(() => {
      // cancelled
    });
  }

  // ArkUI's action menu rows carry no selected state of their own, so the checkmark is part
  // of the row title, exactly as the source's checkmark accessory reads out.
  private filterRowTitle(filter: string, label: string): string {
    return (this.searchFilter === filter ? '✓  ' : '    ') + label;
  }

  private text(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res.id);
    } catch (e) {
      return '';
    }
  }

  // MARK: - navigation

  // One push per tap burst: a double tap on Read (or a row) used to stack the article twice.
  private openArticle(articleTitle: string): void {
    const now: number = Date.now();
    if (now - this.lastOpenAt < 1000) {
      return;
    }
    this.lastOpenAt = now;
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  private openArticleFromRow(item: MWKLocationSearchResult): void {
    const articleTitle: string = item.title ?? item.displayTitle ?? '';
    HistoryStore.addToReadHistory(this.articleKeyFor(item), null, articleTitle, item.wikidataDescription,
      null, item.thumbnailURL, item.articleID)
      .catch((e: Error): void => {
        console.error('places: history write failed: ' + e.message);
      });
    this.openArticle(articleTitle);
  }

  private articleKeyFor(item: MWKLocationSearchResult): string {
    const articleTitle: string = item.title ?? item.displayTitle ?? '';
    return 'https://' + this.host + '/wiki/' + articleTitle.replace(/ /g, '_');
  }

  @Builder
  tabsCoverBuilder() {
    WMFArticleTabsView({
      onClose: (): void => {
        this.showTabsCover = false;
      }
    })
  }

  @Builder
  profileSheetBuilder() {
    WMFProfileViewSheet({
      onClose: (): void => {
        this.showProfileSheet = false;
      }
    })
  }

  // MARK: - selected place callout (screen_article_popover)

  // didSelect(annotation:): the pin grows and its callout opens; a different pin moves the
  // selection, an empty spot on the map clears it.
  private selectPlace(item: MWKLocationSearchResult): void {
    this.selectedPlace = item;
    this.selectedIsSaved = false;
    const key: string = this.articleKeyFor(item);
    SavedStore.isSaved(key).then((saved: boolean) => {
      if (this.isSelected(item)) {
        this.selectedIsSaved = saved;
      }
    }).catch((e: Error) => {
      console.error('places: saved lookup failed: ' + e.message);
    });
  }

  // By title: @State hands back an observed proxy, so identity never matches the raw row.
  private isSelected(item: MWKLocationSearchResult): boolean {
    const p: MWKLocationSearchResult | null = this.selectedPlace;
    return p !== null && (p.title ?? '') === (item.title ?? '');
  }

  // Taps that land while a toggle is still being written are dropped, so a burst of taps
  // can never race two writes for the same article.
  private toggleSelectedSaved(): void {
    const item: MWKLocationSearchResult | null = this.selectedPlace;
    if (item === null || this.savingInFlight) {
      return;
    }
    this.savingInFlight = true;
    SavedStore.toggleSave(this.articleKeyFor(item), null, item.title ?? item.displayTitle ?? '')
      .then((saved: boolean) => {
        if (this.isSelected(item)) {
          this.selectedIsSaved = saved;
        }
      }).catch((e: Error) => {
        console.error('places: toggleSave failed: ' + e.message);
      }).finally(() => {
        this.savingInFlight = false;
      });
  }

  private shareSelected(): void {
    const item: MWKLocationSearchResult | null = this.selectedPlace;
    if (item === null) {
      return;
    }
    const record: systemShare.SharedRecord = {
      utd: 'general.hyperlink',
      content: this.articleKeyFor(item),
      title: item.displayTitle ?? item.title ?? '',
      description: item.wikidataDescription ?? ''
    };
    try {
      const controller: systemShare.ShareController =
        new systemShare.ShareController(new systemShare.SharedData(record));
      controller.show(getContext(this) as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      }).catch((e: Error): void => {
        console.error('places: share panel failed: ' + e.message);
      });
    } catch (e) {
      console.error('places: share panel unavailable: ' + this.describeError(e));
    }
  }

  // MARK: - helpers

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // NSString.wmf_localizedString(forDistance:) / configureForUnknownDistance(). Measured from
  // the reader, not from the search centre: after "Results in this area" those differ.
  private distanceText(item: MWKLocationSearchResult): string {
    if (!this.locationPermissionGranted || (this.userLatitude === 0 && this.userLongitude === 0) ||
      item.latitude === null || item.longitude === null) {
      return this.text($r('app.string.places_unknown_distance'));
    }
    return distanceText(this.userLatitude, this.userLongitude, item.latitude, item.longitude);
  }

  private bearingTo(item: MWKLocationSearchResult): number {
    if (item.latitude === null || item.longitude === null ||
      (this.userLatitude === 0 && this.userLongitude === 0)) {
      return 0;
    }
    return bearingDegrees(this.userLatitude, this.userLongitude, item.latitude, item.longitude);
  }


  // MARK: - map (Map Kit)

  // The map as it should open: the current camera, or the whole world before there is one.
  private mapOptions(): mapCommon.MapOptions {
    return {
      position: {
        target: this.hasCamera ? this.camera : { latitude: 20, longitude: 0 },
        zoom: this.hasCamera ? this.zoom : MIN_ZOOM
      },
      minZoom: MIN_ZOOM,
      maxZoom: MAX_ZOOM,
      // The source map has neither; the recenter button over the map is the app's own.
      zoomControlsEnabled: false,
      myLocationControlsEnabled: false,
      compassControlsEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      dayNightMode: this.wmfIsDark ? mapCommon.DayNightMode.NIGHT : mapCommon.DayNightMode.DAY
    };
  }

  private onMapReady(err: BusinessError, controller: map.MapComponentController): void {
    if (err) {
      // An app whose signing profile lacks Map Kit lands here, and the map stays blank.
      console.error('places: map unavailable: ' + err.code + ' ' + err.message);
      return;
    }
    this.mapController = controller;
    this.markers = [];
    // the first idle is the map settling on its opening camera, not a reader's move
    this.appMovingCamera = true;
    controller.on('cameraIdle', () => {
      this.onCameraIdle();
    });
    controller.on('cameraMove', () => {
      this.updateCalloutAnchor();
    });
    controller.on('markerClick', (marker: map.Marker) => {
      this.lastMarkerClickAt = Date.now();
      const group: PlaceGroup | undefined = this.markerGroups[marker.getTag() as number];
      if (group !== undefined) {
        this.onGroupTapped(group);
      }
    });
    // Map Kit does not always report a tap on a canvas-drawn marker as a markerClick (seen on
    // device: only mapClick arrived), so a tap is matched to the pin drawn under it here.
    // Anywhere else, the tap clears the selection.
    controller.on('mapClick', (at: mapCommon.LatLng) => {
      if (Date.now() - this.lastMarkerClickAt < 400) {
        return;
      }
      const group: PlaceGroup | undefined = this.groupAt(at);
      if (group !== undefined) {
        this.onGroupTapped(group);
      } else {
        this.selectedPlace = null;
      }
    });
    if (this.userFix !== null) {
      this.showUserLocation(this.userFix);
    }
    this.refreshMarkers();
  }

  private onCameraIdle(): void {
    const c: map.MapComponentController | null = this.mapController;
    if (c === null) {
      return;
    }
    const position: mapCommon.CameraPosition = c.getCameraPosition();
    this.camera = position.target;
    this.zoom = position.zoom;
    this.hasCamera = true;
    if (!this.appMovingCamera) {
      this.showRedoSearch = true;
    }
    this.appMovingCamera = false;
    this.refreshMarkers();
  }

  // The reader's own position: Map Kit's location dot, fed the fix the geosearch used.
  private showUserLocation(location: geoLocationManager.Location): void {
    this.userFix = location;
    const c: map.MapComponentController | null = this.mapController;
    if (c === null) {
      return;
    }
    try {
      c.setMyLocationEnabled(true);
      c.setMyLocation(location);
    } catch (e) {
      console.warn('places: location dot unavailable: ' + this.describeError(e));
    }
  }

  onThemeChanged(): void {
    const c: map.MapComponentController | null = this.mapController;
    if (c !== null) {
      c.setDayNightMode(this.wmfIsDark ? mapCommon.DayNightMode.NIGHT : mapCommon.DayNightMode.DAY);
    }
  }

  onPinsChanged(): void {
    this.refreshMarkers();
  }

  // A point's position on the map view, in vp.
  private screenPoint(latitude: number, longitude: number): number[] | null {
    const c: map.MapComponentController | null = this.mapController;
    if (c === null) {
      return null;
    }
    const p: mapCommon.MapPoint = c.getProjection().toScreenLocation({ latitude: latitude, longitude: longitude });
    return [px2vp(p.positionX), px2vp(p.positionY)];
  }

  // The annotations at the current zoom: an article closer than CLUSTER_CELL vp on screen to a
  // group's first pin joins that group's cluster badge. Distance, not a fixed grid, so two
  // touching pins on either side of a cell edge still merge. Recomputed whenever the camera
  // settles, so zooming in splits them.
  // ponytail: O(pins x groups) - fine for the 50-result geosearch; a grid index if that grows.
  private annotationGroups(): PlaceGroup[] {
    const out: PlaceGroup[] = [];
    for (const item of this.nearby) {
      // Saved articles without coordinates have no place on the map.
      if (item.latitude === null || item.longitude === null) {
        continue;
      }
      const pt: number[] | null = this.screenPoint(item.latitude, item.longitude);
      if (pt === null) {
        return [];
      }
      let group: PlaceGroup | undefined = out.find((g: PlaceGroup) =>
        Math.hypot(g.x - pt[0], g.y - pt[1]) < CLUSTER_CELL);
      if (group === undefined) {
        group = new PlaceGroup();
        group.x = pt[0];
        group.y = pt[1];
        out.push(group);
      }
      group.items.push(item);
    }
    for (const g of out) {
      let lat: number = 0;
      let lon: number = 0;
      for (const item of g.items) {
        lat += item.latitude ?? 0;
        lon += item.longitude ?? 0;
      }
      // A lone article sits exactly on its coordinate; a cluster on the centroid.
      g.latitude = g.items.length === 1 ? (g.items[0].latitude ?? 0) : lat / g.items.length;
      g.longitude = g.items.length === 1 ? (g.items[0].longitude ?? 0) : lon / g.items.length;
      // where the marker is drawn, for matching a tap to it
      const at: number[] | null = this.screenPoint(g.latitude, g.longitude);
      if (at !== null) {
        g.x = at[0];
        g.y = at[1];
      }
    }
    return out;
  }

  // Tapping a cluster zooms in on it until its articles come apart.
  private zoomIntoGroup(group: PlaceGroup): void {
    this.selectedPlace = null;
    this.moveCamera(group.latitude, group.longitude, Math.min(MAX_ZOOM, this.zoom + 2));
  }

  // The pin group drawn under a tap, if any: the nearest within a pin's radius.
  private groupAt(at: mapCommon.LatLng): PlaceGroup | undefined {
    const pt: number[] | null = this.screenPoint(at.latitude, at.longitude);
    if (pt === null) {
      return undefined;
    }
    let best: PlaceGroup | undefined = undefined;
    let bestDistance: number = CLUSTER_CELL / 2 + 4;
    for (const g of this.markerGroups) {
      const d: number = Math.hypot(g.x - pt[0], g.y - pt[1]);
      if (d < bestDistance) {
        best = g;
        bestDistance = d;
      }
    }
    return best;
  }

  private onGroupTapped(group: PlaceGroup): void {
    if (group.items.length > 1) {
      this.zoomIntoGroup(group);
    } else {
      this.selectPlace(group.items[0]);
    }
  }

  // One Map Kit marker per annotation group, redrawn when the camera settles, the results
  // change or the selection moves. A stale batch still being added is dropped.
  private refreshMarkers(): void {
    const c: map.MapComponentController | null = this.mapController;
    if (c === null) {
      return;
    }
    for (const m of this.markers) {
      m.remove();
    }
    this.markers = [];
    const generation: number = ++this.markerGeneration;
    const groups: PlaceGroup[] = this.annotationGroups();
    this.markerGroups = groups;
    groups.forEach((g: PlaceGroup, i: number) => {
      const selected: boolean = g.items.length === 1 && this.isSelected(g.items[0]);
      const kind: string = g.items.length > 1 ? String(g.items.length) : (selected ? 'selected' : 'dot');
      c.addMarker({
        position: { latitude: g.latitude, longitude: g.longitude },
        icon: this.markerIcon(kind),
        anchorU: 0.5,
        anchorV: 0.5,
        clickable: true,
        // the selected pin and the clusters stay above the plain pins
        zIndex: selected ? 3 : (g.items.length > 1 ? 2 : 1)
      }).then((m: map.Marker) => {
        if (generation !== this.markerGeneration) {
          m.remove();
          return;
        }
        m.setTag(i);
        this.markers.push(m);
      }).catch((e: Error) => {
        console.error('places: marker not added: ' + e.message);
      });
    });
    this.updateCalloutAnchor();
  }

  // The source's annotation views, drawn once per kind: a green dot with a white rim, the
  // enlarged selected dot, and the orange cluster disc carrying its article count.
  private markerIcon(kind: string): image.PixelMap {
    const hit: image.PixelMap | undefined = this.markerIcons.get(kind);
    if (hit !== undefined) {
      return hit;
    }
    const size: number = kind === 'selected' ? 44 : (kind === 'dot' ? 24 : 30);
    const r: number = size / 2;
    const canvas: OffscreenCanvas = new OffscreenCanvas(size, size);
    const ctx: OffscreenCanvasRenderingContext2D = canvas.getContext('2d');
    ctx.beginPath();
    ctx.arc(r, r, r, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
    ctx.beginPath();
    ctx.arc(r, r, r - (kind === 'selected' ? 5 : 2.5), 0, Math.PI * 2);
    ctx.fillStyle = kind === 'dot' || kind === 'selected' ? '#00AF89' : '#FF9500';
    ctx.fill();
    if (kind !== 'dot' && kind !== 'selected') {
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 13vp sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(kind, r, r + 0.5);
    }
    const pm: image.PixelMap = ctx.getPixelMap(0, 0, size, size);
    this.markerIcons.set(kind, pm);
    return pm;
  }

  // MARK: - list overlay panel

  private panelMax(): number {
    return Math.max(PANEL_MIN, this.mapHeight * 0.9);
  }

  // A flick goes all the way in its direction; a slow drag settles on the nearest stop.
  private settlePanel(velocityY: number): void {
    const stops: number[] = [PANEL_MIN, this.mapHeight * 0.45, this.panelMax()];
    let target: number = stops[0];
    if (Math.abs(velocityY) > 600) {
      target = velocityY < 0 ? this.panelMax() : PANEL_MIN;
    } else {
      for (const stop of stops) {
        if (Math.abs(stop - this.panelHeight) < Math.abs(target - this.panelHeight)) {
          target = stop;
        }
      }
    }
    animateTo({ duration: 250, curve: Curve.Friction }, () => {
      this.panelHeight = target;
    });
  }

  private scopeSelected(mode: string): boolean {
    return this.viewMode === mode;
  }

  // MARK: - builders

  @Builder
  scopeButton(rowId: string, label: Resource, mode: string) {
    Text(label)
      .id(rowId)
      .layoutWeight(1)
      .height(28)
      .textAlign(TextAlign.Center)
      .fontSize(13)
      .fontWeight(this.scopeSelected(mode) ? FontWeight.Medium : FontWeight.Normal)
      .fontColor($r('app.color.theme_text'))
      .backgroundColor(this.scopeSelected(mode)
        ? (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')) : Color.Transparent)
      .borderRadius(7)
      .margin(2)
      .onClick(() => {
        this.viewMode = mode;
        // still no location access: switching scope asks again, as the first load did
        if (!this.locationPermissionGranted) {
          this.showEnableLocation = true;
        }
      })
  }

  // The map surface with one annotation per geosearch result.
  // WMFPlacesEnableLocationView. It used to live inside the map surface only, so the List
  // scope answered a missing authorization with "No nearby articles found." - a wrong
  // answer: there is nothing wrong with the area, the app was never allowed to look.
  @Builder
  enableLocationPanel() {

        Column() {
          Text($r('app.string.places_enable_location_title'))
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_text'))
          Text($r('app.string.places_enable_location_description'))
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 12 })
          Button($r('app.string.places_enable_location_action_button_title'))
            .id('enable_location')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(48)
            .fontSize(17)
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .backgroundColor($r('app.color.theme_link'))
            .margin({ top: 20 })
            .onClick(() => {
              this.requestLocationAuthorization();
            })
          Button($r('app.string.cancel'))
            .id('cancel_enable_location')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(48)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
            .margin({ top: 8 })
            .onClick(() => {
              this.showEnableLocation = false;
            })
        }
        .width(320)
        .padding(30)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(14)
        .shadow({ radius: 20, color: '#33000000', offsetY: 4 })
        }

  @Builder
  calloutView() {
    if (this.selectedPlace !== null) {
      Column() {
        ArticlePopoverView({
          articleTitle: this.selectedPlace.displayTitle ?? this.selectedPlace.title ?? '',
          subtitle: '',
          wikidataDescription: this.selectedPlace.wikidataDescription ?? '',
          isSaved: this.selectedIsSaved,
          distanceText: this.distanceText(this.selectedPlace),
          onRead: (): void => {
            const item: MWKLocationSearchResult | null = this.selectedPlace;
            if (item !== null) {
              this.openArticleFromRow(item);
            }
          },
          onSave: (): void => {
            this.toggleSelectedSaved();
          },
          onShare: (): void => {
            this.shareSelected();
          }
        })
      }
      .id('places_callout')
      .width(this.calloutWidth())
      .borderRadius(10)
      .shadow({ radius: 12, color: '#33000000', offsetY: 3 })
      .position({ x: this.calloutLeft(), y: this.calloutTop() })
      .onAreaChange((_o: Area, n: Area) => {
        this.calloutHeight = Number(n.height);
      })
    }
  }

  // Follows the pin while the map moves under it.
  private updateCalloutAnchor(): void {
    const p: MWKLocationSearchResult | null = this.selectedPlace;
    if (p === null || p.latitude === null || p.longitude === null) {
      return;
    }
    const pt: number[] | null = this.screenPoint(p.latitude, p.longitude);
    if (pt !== null) {
      this.calloutAnchorX = pt[0];
      this.calloutAnchorY = pt[1];
    }
  }

  private calloutWidth(): number {
    return Math.min(340, this.mapWidth - 32);
  }

  private calloutLeft(): number {
    const p: MWKLocationSearchResult | null = this.selectedPlace;
    if (p === null) {
      return 0;
    }
    const x: number = this.calloutAnchorX - this.calloutWidth() / 2;
    return Math.max(16, Math.min(this.mapWidth - this.calloutWidth() - 16, x));
  }

  // Above the pin when it fits, otherwise below it.
  private calloutTop(): number {
    const p: MWKLocationSearchResult | null = this.selectedPlace;
    if (p === null) {
      return 0;
    }
    const y: number = this.calloutAnchorY;
    const above: number = y - 28 - this.calloutHeight;
    return above >= 8 ? above : y + 28;
  }

  // The list/search overlay: a drag handle over the same article rows as the List scope.
  @Builder
  placesPanel() {
    Column() {
      Column() {
        Row()
          .width(36)
          .height(5)
          .borderRadius(2.5)
          .backgroundColor($r('app.color.theme_secondary_text'))
          .opacity(0.5)
      }
      .id('places_panel_handle')
      .width('100%')
      .height(24)
      .justifyContent(FlexAlign.Center)
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 2 })
          .onActionStart(() => {
            this.panelDragStart = this.panelHeight;
          })
          .onActionUpdate((e: GestureEvent) => {
            this.panelHeight = Math.max(PANEL_MIN, Math.min(this.panelMax(), this.panelDragStart - e.offsetY));
          })
          .onActionEnd((e: GestureEvent) => {
            this.settlePanel(e.velocityY);
          })
          .onActionCancel(() => {
            this.settlePanel(0);
          }))
      Text(this.searchFilter === 'saved' ? $r('app.string.places_filter_saved_articles')
        : $r('app.string.places_filter_top_read_articles'))
        .width('100%')
        .height(32)
        .padding({ left: 16, right: 16 })
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      this.nearbyList()
    }
    .id('places_panel')
    .width('100%')
    .height(this.panelHeight)
    .position({ x: 0, y: this.mapHeight - this.panelHeight })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius({ topLeft: 12, topRight: 12 })
    .shadow({ radius: 10, color: '#26000000', offsetY: -2 })
    .clip(true)
  }

  @Builder
  mapSurface() {
    Stack() {
      // PlacesViewController.mapView: Map Kit draws the map, the location dot and the pins.
      MapComponent({
        mapOptions: this.mapOptions(),
        mapCallback: (err: BusinessError, controller: map.MapComponentController): void => {
          this.onMapReady(err, controller);
        }
      })
        .id('places_map')
        .width('100%')
        .height('100%')
        .onDisAppear(() => {
          // the List scope tears the map down; its markers go with it
          this.mapController = null;
          this.markers = [];
        })

      this.calloutView()

      // "Results in this area" once the camera has left the searched region.
      if (this.areaSearching) {
        Row() {
          LoadingProgress()
            .id('places_redo_search_progress')
            .width(36)
            .height(36)
            .padding(6)
            .color($r('app.color.theme_link'))
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            .borderRadius(18)
            .shadow({ radius: 6, color: '#1F000000', offsetY: 2 })
        }
        .width('100%')
        .margin({ top: 19 })
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      } else if (this.showRedoSearch) {
        Row() {
          Button($r('app.string.places_search_this_area'))
            .id('places_redo_search')
            .type(ButtonType.Capsule)
            .height(36)
            .padding({ left: 16, right: 16 })
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            .shadow({ radius: 6, color: '#1F000000', offsetY: 2 })
            .onClick(() => {
              this.redoSearchInThisArea();
            })
        }
        .width('100%')
        .margin({ top: 19 })
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // recenterOnUserLocationButton. It stays tappable without permission: the tap then
      // leaves the map where it is instead of re-raising any permission prompt.
      Button() {
        Image($r('app.media.places_location_arrow'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
      }
      .id('recenter_on_your_location')
      .accessibilityText($r('app.string.places_accessibility_recenter_map_on_user_location'))
      .type(ButtonType.Circle)
      .width(40)
      .height(40)
      .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
      .shadow({ radius: 6, color: '#1F000000', offsetY: 2 })
      .margin({ top: 17, right: 16 })
      .onClick(() => {
        this.recenterOnUserLocation(false);
      })

      this.placesPanel()

      if (this.showEnableLocation) {
        Column() {
          this.enableLocationPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#33000000')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignContent(Alignment.TopEnd)
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    .clip(true)
    // The panel's stops and the callout's width follow the map's size.
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const w: number = Number(newValue.width);
      const h: number = Number(newValue.height);
      if (w === this.mapWidth && h === this.mapHeight) {
        return;
      }
      this.mapWidth = w;
      this.mapHeight = h;
    })
  }

  @Builder
  nearbyList() {
    // PlacesViewController.listViewController — the List scope is an embedded
    // ArticleLocationCollectionViewController child (PlacesViewController.swift:28,123),
    // so it is a real child component here, not an inlined list.
    ArticleLocationCollectionView({
      source: this.nearbySource,
      distanceOf: (item: MWKLocationSearchResult): string => this.distanceText(item),
      bearingOf: (item: MWKLocationSearchResult): number => this.bearingTo(item),
      onSelect: (item: MWKLocationSearchResult): void => {
        this.openArticleFromRow(item);
      }
    })
  }

  @Builder
  didYouMeanRow() {
    if (this.searchSuggestion !== '') {
      Button($r('app.string.places_did_you_mean_format', this.searchSuggestion))
        .id('places_did_you_mean')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(15)
        .fontColor($r('app.color.theme_link'))
        .width('100%')
        .height(44)
        .onClick(() => {
          this.applySearchSuggestion();
        })
    }
  }

  // PlacesViewController's emptySearchOverlayView: a search that matches nothing has to say
  // so, and an empty field with nothing searched yet shows the same explainer.
  @Builder
  emptySearchOverlay() {
    Column() {
      Image($r('app.media.places_search_empty_state_overlay'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
        .opacity(0.5)
      Text($r('app.string.places_empty_search_title'))
        .id('places_empty_search_title')
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
        .margin({ top: 20 })
      Text($r('app.string.places_empty_search_description'))
        .width('100%')
        .fontSize(15)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 8 })
    }
    .id('places_empty_search_overlay')
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 32, right: 32 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // The empty, focused field: current location, all top articles, then the recent searches
  // under a header whose x clears them. With no recents, the explainer instead.
  @Builder
  searchStartList() {
    if (this.recentSearches.length === 0) {
      this.emptySearchOverlay()
    } else {
      List() {
        ListItem() {
          PlacesSearchSuggestionTableViewCell({
            title: this.text($r('app.string.places_search_your_current_location')), detail: '', iconKind: 'arrow'
          })
        }
        .id('places_search_current_location')
        .onClick(() => {
          this.searchStart(true);
        })
        ListItem() {
          PlacesSearchSuggestionTableViewCell({
            title: this.text($r('app.string.places_search_top_articles')), detail: '', iconKind: 'text'
          })
        }
        .id('places_search_top_articles')
        .onClick(() => {
          this.searchStart(false);
        })
        ListItemGroup({ header: this.recentHeader() }) {
          ForEach(this.recentSearches, (r: RecentPlaceSearch) => {
            ListItem() {
              PlacesSearchSuggestionTableViewCell({
                title: r.title, detail: r.detail, iconKind: r.term !== '' ? 'text' : 'location'
              })
            }
            .id('places_recent_search_itemroot')
            .swipeAction({ end: this.deleteRecentSearchAction(r) })
            .onClick(() => {
              this.selectRecentSearch(r);
            })
          }, (r: RecentPlaceSearch) => r.title)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    }
  }

  // PlaceSearchSuggestionController trailingSwipeActions on a recent row: the destructive
  // Delete -> didDeleteSearch, which removes that one search and refreshes the suggestions.
  @Builder
  deleteRecentSearchAction(r: RecentPlaceSearch) {
    Button($r('app.string.article_delete'))
      .id('places_recent_search_delete')
      .type(ButtonType.Normal)
      .height('100%')
      .fontSize(15)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.theme_destructive'))
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.recentSearches = this.recentSearches.filter((x: RecentPlaceSearch) => x.title !== r.title);
        Prefs.putString(RECENT_SEARCHES_KEY, JSON.stringify(this.recentSearches));
      })
  }

  @Builder
  recentHeader() {
    Row() {
      Text($r('app.string.places_search_recently_searched_header'))
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .id('places_clear_recent_searches')
        .fontSize(18)
        .fontColor([$r('app.color.theme_secondary_text')])
        .onClick(() => {
          this.clearRecentSearches();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 24, bottom: 8 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  @Builder
  suggestionList() {
    this.didYouMeanRow()
    if (this.suggestionsLoaded && this.suggestions.length === 0) {
      this.emptySearchOverlay()
    } else {
    List() {
      LazyForEach(this.suggestionSource, (item: MWKSearchResult) => {
        ListItem() {
          PlacesSearchSuggestionTableViewCell({
            // displayTitle is search-index HTML; rendered raw it showed "<i>Feldwebel</i>".
            title: stripTags(item.displayTitle ?? item.title ?? ''),
            detail: item.wikidataDescription ?? '',
            iconKind: item.latitude === null ? 'text' : 'location'
          })
        }
        .id('places_suggestion_itemroot')
        .onClick(() => {
          this.selectSuggestion(item);
        })
      }, (item: MWKSearchResult, index: number) => (item.title ?? '') + '_' + index)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    }
  }

  // a root-tab switch is instant, like UITabBarController; other routes keep the slide
  pageTransition() {
    if (isRootTabSwitch()) {
      PageTransitionEnter({ duration: 0 })
      PageTransitionExit({ duration: 0 })
    }
  }

  build() {
    Column() {
      // nav bar: large "Places" title + round filter / tabs / profile title-bar buttons
      Row() {
        Text($r('app.string.places_title'))
          .fontSize(ROOT_TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        Blank()
        Row({ space: NAV_BUTTON_GAP }) {
          Button() {
            // places_slider.png is a plain grey pill and read as a stray dash in the bar; the
            // control is an icon-only lines/hamburger button. menu.png is a white raster, so
            // its colour is rebuilt from the alpha channel.
            Image($r('app.media.menu'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              // text colour, like every other bar glyph (it was link blue, the only coloured one)
              .colorFilter(navIconTint(this.wmfIsDark))
          }
          .id('places_filter')
          .accessibilityText('Filter')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.showFilterSheet();
          })
          Button() {
            Image($r('app.media.article_tabs_square'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.theme_text'))
          }
          .id('Tabs Button')
          .accessibilityText('Tabs')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
              console.error('article tabs push failed: ' + e.message);
            });
          })
          Button() {
            Stack({ alignContent: Alignment.BottomStart }) {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                .fontSize(NAV_BUTTON_SYMBOL_SIZE)
                .fontColor([$r('app.color.theme_text')])
              // unread notifications: the source's badge on the profile button
              UnreadNotificationsDot()
            }
          }
          .id('profile-button')
          .accessibilityText('Profile')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.showProfileSheet = true;
          })
        }
      }
      .width('100%')
      .height(ROOT_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      // searchBar
      Row() {
        Image($r('app.media.search'))
          .width(20)
          .height(19)
          .objectFit(ImageFit.Contain)
        TextInput({ text: this.searchText, placeholder: $r('app.string.places_search_default_text') })
          .id('Search Field')
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .fontSize(17)
          .placeholderColor($r('app.color.theme_secondary_text'))
          .onChange((value: string) => {
            this.onSearchTextChanged(value);
          })
          // the search key runs "Nearby matching <term>" on the map / list
          .onSubmit(() => {
            this.submitSearch();
          })
          .cancelButton({ style: CancelButtonStyle.INPUT })
          .onEditChange((editing: boolean) => {
            this.searchFocused = editing;
          })
      }
      .width('100%')
      .height(44)
      .margin({ top: 15, left: 16, right: 16 })
      .padding({ left: 12, right: 12 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      .borderRadius(10)
      .alignItems(VerticalAlign.Center)

      // scope bar (UISearchBar scopeButtonTitles: Map | List)
      Row() {
        this.scopeButton('scopeBar', $r('app.string.places_map_title'), 'map')
        this.scopeButton('list', $r('app.string.places_list_title'), 'list')
      }
      .width(252)
      .height(32)
      .margin({ top: 17 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      .borderRadius(9)

      // content: suggestions while searching, otherwise the map or the list scope
      if (this.searchFocused && this.searchText.trim() === '') {
        this.searchStartList()
      } else if (this.searchText.trim() !== '' && this.searchText.trim() !== this.committedTerm &&
        this.searchText !== this.focusLabel) {
        this.suggestionList()
      } else if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('places_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.committedTerm !== '' && this.nearby.length === 0 && this.searchFilter === 'top') {
        // a submitted term that matched nothing keeps the empty-search overlay up
        this.emptySearchOverlay()
      } else if (this.viewMode === 'list') {
        // conditionalVariant: viewMode == 'list'
        // the panel's Cancel puts it away (showEnableLocation) and leaves the empty list
        if (!this.locationPermissionGranted && this.showEnableLocation) {
          Column() {
            this.enableLocationPanel()
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.nearby.length === 0) {
          Column() {
            Text(this.loadError !== '' ? this.loadError : 'No nearby articles found.')
              .fontSize(17)
              .lineHeight(24)
              .textAlign(TextAlign.Center)
              .fontColor($r('app.color.theme_secondary_text'))
              .padding({ left: 32, right: 32 })
          }
          .id('places_list_empty')
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.nearbyList()
        }
      } else {
        this.mapSurface()
      }

      RootTabBar({ selected: 1 })
    }
    .id('PlacesViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindContentCover($$this.showTabsCover, this.tabsCoverBuilder())
    .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(),
      { height: SheetSize.LARGE, dragBar: false, showClose: false })
  }
}
