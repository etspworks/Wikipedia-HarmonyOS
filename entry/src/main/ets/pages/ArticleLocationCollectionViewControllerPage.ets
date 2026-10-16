// screen_article_location_collection — presentation: page.
// Ported from Wikipedia/Code/ArticleLocationCollectionViewController.swift: a single-section
// columnar collection of ArticleLocationCollectionViewCell rows, one per article URL
// (numberOfItems = articleURLs.count), each configured with .pageWithLocation display type —
// compass view + circular thumbnail + title + 2-line description + a distance label kept
// current from LocationManager (update(userLocation:heading:)). The nav bar title is hidden
// (WMFNavigationBarTitleConfig alignment .hidden); selecting a row opens the article
// (ArticleCoordinator).
// Rows are rendered by the shared cell component comp_article_location_cell.
// S3: structure only — styling in S5.
import { BackToExploreFeedButton } from '../components/BackToExploreFeedButton';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { MWKLocationSearchResult, WMFLocationSearchResults } from '../model/WMFLocationSearchResults';
import { GeoService } from '../common/GeoService';
import { LanguageStore } from '../common/LanguageStore';
import { HistoryStore } from '../common/HistoryStore';
import { Database } from '../common/Database';
import { Prefs } from '../common/Prefs';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { ArticleLocationCollectionViewCell } from '../components/ArticleLocationCollectionViewCell';

// WMFLocationSearchResults.results — the nearby articles for the current coordinates.
class LocationResultDataSource implements IDataSource {
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
    const i = this.listeners.indexOf(l);
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

@Entry
@Component
struct ArticleLocationCollectionViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // spec stateVar: items <- svc_geo (geosearch)
  @State items: MWKLocationSearchResult[] = [];
  // locationManager.location / .heading — the compass + distance labels track these.
  @State userLatitude: number = 0;
  @State userLongitude: number = 0;
  @State userHeading: number = 0;
  // S6: the visual states of the geosearch S4 already wired — in flight, and the two ways
  // it comes back with nothing (no location authorization / no fix, and an empty result set).
  @State isLoading: boolean = true;
  @State loadError: string = '';
  private itemsSource: LocationResultDataSource = new LocationResultDataSource();
  // searchSiteURL — the app-language wiki the geosearch runs against
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    this.itemsSource.reload(this.items);
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        console.error('nearby: load failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('nearby: db init failed: ' + e.message);
    });
  }

  // startMonitoringLocation + WMFLocationSearchFetcher.fetchArticles(withSiteURL:location:)
  // ponytail: one location fix, not a continuous subscription — the row distances are
  // computed from it; upgrade to geoLocationManager.on('locationChange') if the list has to
  // track the user while it is open.
  private async load(): Promise<void> {
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.host = lang.languageCode + '.wikipedia.org';
    } catch (e) {
      console.warn('nearby: app language unavailable, defaulting to en');
    }
    let location: geoLocationManager.Location;
    try {
      location = await geoLocationManager.getCurrentLocation();
    } catch (e) {
      // no authorization / no fix — configureForUnknownDistance() and an empty list
      console.error('nearby: location unavailable: ' + this.describeError(e));
      this.loadError = 'Location access is off, so nearby articles cannot be found.';
      this.isLoading = false;
      return;
    }
    this.userLatitude = location.latitude;
    this.userLongitude = location.longitude;
    this.userHeading = location.direction;
    try {
      const results: WMFLocationSearchResults = await GeoService.searchNearby(
        this.host, location.latitude, location.longitude, 10000, 50);
      this.items = results.results;
      this.itemsSource.reload(this.items);
    } catch (e) {
      console.error('nearby: geosearch failed: ' + this.describeError(e));
      this.loadError = 'Nearby articles could not be loaded. Check your connection.';
    } finally {
      this.isLoading = false;
    }
  }

  // ColumnarCollectionViewController.emptyViewType copy for this list.
  private emptyMessage(): string {
    if (this.loadError !== '') {
      return this.loadError;
    }
    return 'No nearby articles found.';
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // didSelectItemAt -> ArticleCoordinator.start() — the article's read-history row is
  // written on the way in, as the coordinator does.
  private openArticle(item: MWKLocationSearchResult): void {
    const articleTitle: string = item.title ?? item.displayTitle ?? '';
    const articleKey: string =
      'https://' + this.host + '/wiki/' + articleTitle.replace(/ /g, '_');
    HistoryStore.addToReadHistory(articleKey, null, articleTitle, item.wikidataDescription,
      null, item.thumbnailURL, item.articleID)
      .catch((e: Error): void => {
        console.error('nearby: history write failed: ' + e.message);
      });
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  // NSString.wmf_localizedString(forDistance:) / configureForUnknownDistance()
  private distanceText(item: MWKLocationSearchResult): string {
    if (this.userLatitude === 0 && this.userLongitude === 0) {
      return 'unknown distance';
    }
    const meters: number = item.distanceFromQueryCoordinates;
    if (meters >= 1000) {
      return (Math.round(meters / 100) / 10).toString() + ' km';
    }
    return Math.round(meters).toString() + ' m';
  }

  // userLocation.wmf_bearing(to:forCurrentHeading:) — bearing to the article, less the heading
  private bearingTo(item: MWKLocationSearchResult): number {
    if (item.latitude === null || item.longitude === null ||
      (this.userLatitude === 0 && this.userLongitude === 0)) {
      return 0;
    }
    const rad: number = Math.PI / 180;
    const dLon: number = (item.longitude - this.userLongitude) * rad;
    const lat1: number = this.userLatitude * rad;
    const lat2: number = item.latitude * rad;
    const y: number = Math.sin(dLon) * Math.cos(lat2);
    const x: number = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
    const deg: number = Math.atan2(y, x) / rad - this.userHeading;
    return (deg + 360) % 360;
  }

  build() {
    Column() {
      if (this.isLoading) {
        // S6 loading visual — the location fix + geosearch are in flight.
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('article_location_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        // S6 empty/error visual — no authorization, no fix, or nothing within range.
        Column() {
          Text(this.emptyMessage())
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .id('article_location_empty')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
      List() {
        LazyForEach(this.itemsSource, (item: MWKLocationSearchResult) => {
          ListItem() {
            ArticleLocationCollectionViewCell({
              title: item.displayTitle ?? item.title ?? '',
              articleDescription: item.wikidataDescription ?? '',
              imageURL: item.thumbnailURL ?? '',
              distanceText: this.distanceText(item),
              bearing: this.bearingTo(item)
            })
          }
          // one row of a repeated list — shared id, index-resolved by replay (Rule 12)
          .id('article_location_itemroot')
          .onClick(() => {
            this.openArticle(item);
          })
        }, (item: MWKLocationSearchResult) => item.articleID.toString())
        // footerButtonTitle: the last row of the detail list
        ListItem() {
          BackToExploreFeedButton()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 1, color: $r('app.color.gray200'), startMargin: 16 })
      }
    }
    .id('ArticleLocationCollectionViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
