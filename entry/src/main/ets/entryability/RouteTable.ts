// Data-driven deep-link route table: source screen name -> router url.
// Later S2 batches only add entries here.
import { destinationForURL, LinkDestination, LinkKind } from '../common/WikiLinks';
export const DEFAULT_ROUTE: string = 'pages/ExploreViewControllerPage';
// Cold-launch route: the splash runs the blocking setup, then hands off to pages/Index.
// Kept separate from DEFAULT_ROUTE, which stays the fallback for an UNKNOWN deep-link
// target — falling back to the splash would swallow the target and land on Explore anyway.
export const SPLASH_ROUTE: string = 'pages/SplashScreenViewControllerPage';

const routes: Map<string, string> = new Map<string, string>([
  ['ExploreViewController', 'pages/ExploreViewControllerPage'],
  ['ArticleViewController', 'pages/ArticleViewControllerPage'],
  ['NewsViewController', 'pages/NewsViewControllerPage'],
  ['OnThisDayViewController', 'pages/OnThisDayViewControllerPage'],
  ['RandomArticleViewController', 'pages/RandomArticleViewControllerPage'],
  ['PageHistoryViewController', 'pages/PageHistoryViewControllerPage'],
  ['SinglePageWebViewController', 'pages/SinglePageWebViewControllerPage'],
  ['TalkPageViewController', 'pages/TalkPageViewControllerPage'],
  ['NotificationsCenterViewController', 'pages/NotificationsCenterViewControllerPage'],
  ['SettingsTabViewController', 'pages/SettingsTabViewControllerPage'],
  ['NotificationsCenterDetailViewController', 'pages/NotificationsCenterDetailViewControllerPage'],
  ['AboutViewController', 'pages/AboutViewControllerPage'],
  ['AppearanceSettingsViewController', 'pages/AppearanceSettingsViewControllerPage'],
  ['ExploreFeedSettingsViewController', 'pages/ExploreFeedSettingsViewControllerPage'],
  ['HelpViewController', 'pages/HelpViewControllerPage'],
  ['WMFPushNotificationsSettingsView', 'pages/WMFPushNotificationsSettingsViewPage'],
  ['WMFYearInReviewSettingsView', 'pages/WMFYearInReviewSettingsViewPage'],
  ['LibrariesUsedViewController', 'pages/LibrariesUsedViewControllerPage'],
  ['FeedCardSettingsViewController', 'pages/FeedCardSettingsViewControllerPage'],
  ['WMFActivityTabViewController', 'pages/WMFActivityTabViewControllerPage'],
  ['ArticleLocationCollectionViewController', 'pages/ArticleLocationCollectionViewControllerPage'],
  ['ArticleURLListViewController', 'pages/ArticleURLListViewControllerPage'],
  ['DisambiguationPagesViewController', 'pages/DisambiguationPagesViewControllerPage'],
  ['WMFHomeFeedSettingsView', 'pages/WMFHomeFeedSettingsViewPage'],
  ['PlacesViewController', 'pages/PlacesViewControllerPage'],
  ['ReadingListDetailViewController', 'pages/ReadingListDetailViewControllerPage'],
  ['ReadingListsViewController', 'pages/ReadingListsViewControllerPage'],
  ['SavedViewController', 'pages/SavedViewControllerPage'],
  ['SearchViewController', 'pages/SearchViewControllerPage'],
  ['SearchResultsViewController', 'pages/SearchResultsViewControllerPage'],
  ['SplashScreenViewController', 'pages/SplashScreenViewControllerPage'],
  ['TempAccountsSettingsViewController', 'pages/TempAccountsSettingsViewControllerPage'],
  ['WMFWatchlistView', 'pages/WMFWatchlistViewPage'],
  ['WMFWhichCameFirstView', 'pages/WMFWhichCameFirstViewPage'],
  // Overlays are @Components mounted on their HOST page (bindContentCover/bindPopup),
  // not routes. A deep link to one loads the host, which reads LAUNCH_OVERLAY_KEY and
  // presents it; without these two rows the link fell through to DEFAULT_ROUTE.
  ['AddArticlesToReadingListViewController', 'pages/ArticleViewControllerPage'],
  ['ReadingThemesControlsViewController', 'pages/ArticleViewControllerPage']
]);

export function registerRoute(name: string, url: string): void {
  routes.set(name, url);
}

export function resolveRoute(targetPage: string): string {
  if (targetPage.length === 0) {
    return DEFAULT_ROUTE;
  }
  if (targetPage.startsWith('pages/')) {
    return targetPage;
  }
  const url: string | undefined = routes.get(targetPage);
  return url !== undefined ? url : DEFAULT_ROUTE;
}

// Root tab indices (WMFAppTabType): Explore, Places, Saved, Activity, Search.
export const TAB_EXPLORE: number = 0;
export const TAB_PLACES: number = 1;
export const TAB_SAVED: number = 2;
export const TAB_ACTIVITY: number = 3;
export const TAB_SEARCH: number = 4;

// The link or quick action a cold start was opened with: EntryAbility writes it (JSON), Index
// applies it once the splash has handed over.
export const LAUNCH_INTENT_KEY: string = 'wmfLaunchIntent';

// Where an incoming URL lands: a root tab (route '') or a page pushed with params (tab -1).
export class LaunchIntent {
  tab: number = -1;
  route: string = '';
  params: Record<string, string> = {};
}

function tabIntent(tab: number): LaunchIntent {
  const out = new LaunchIntent();
  out.tab = tab;
  return out;
}

function routeIntent(route: string, params: Record<string, string>): LaunchIntent {
  const out = new LaunchIntent();
  out.route = route;
  out.params = params;
  return out;
}

// Router.Destination -> the page that shows it
export function intentForDestination(d: LinkDestination): LaunchIntent {
  if (d.kind === LinkKind.Article) {
    return routeIntent('pages/ArticleViewControllerPage', { 'articleTitle': d.title, 'languageCode': d.languageCode });
  }
  if (d.kind === LinkKind.Talk) {
    return routeIntent('pages/TalkPageViewControllerPage', { 'talkPageTitle': d.title, 'languageCode': d.languageCode });
  }
  if (d.kind === LinkKind.History) {
    return routeIntent('pages/PageHistoryViewControllerPage', { 'articleTitle': d.title, 'languageCode': d.languageCode });
  }
  if (d.kind === LinkKind.Diff) {
    // a side the link leaves out (diff=prev / diff=next) is resolved by the diff screen
    return routeIntent('pages/DiffContainerViewControllerPage', {
      'host': d.languageCode + '.wikipedia.org', 'articleTitle': d.title,
      'fromID': d.fromRevID.toString(), 'toID': d.toRevID.toString(), 'mode': 'single', 'resolveRevisions': 'true'
    });
  }
  if (d.kind === LinkKind.Login) {
    return routeIntent('pages/WMFLoginViewControllerPage', {});
  }
  if (d.kind === LinkKind.Watchlist) {
    return routeIntent('pages/WMFWatchlistViewPage', {});
  }
  if (d.kind === LinkKind.Search) {
    return routeIntent('pages/SearchResultsViewControllerPage', { 'term': d.term });
  }
  if (d.kind === LinkKind.OnThisDay) {
    return routeIntent('pages/OnThisDayViewControllerPage', {});
  }
  // .readingListsImport(encodedPayload:) -> CreateReadingListViewController(encodedPageIds:)
  if (d.kind === LinkKind.ReadingListsImport) {
    return routeIntent('pages/CreateReadingListViewControllerPage', { 'encodedPageIds': d.payload });
  }
  return routeIntent('pages/SinglePageWebViewControllerPage', { 'url': d.url });
}

const SCHEME_RE: RegExp = /^(wikipedia|wikipedia-official):\/\/([^\/?#]*)([^?#]*)(?:\?([^#]*))?/i;
const HTTPS_RE: RegExp = /^https?:\/\/([a-z0-9-]+)(?:\.m)?\.wikipedia\.org(\/[^?#]*)?/i;

// NSUserActivity.wmf_activityForWikipediaScheme / wmf_activityForURL: wikipedia://explore,
// places, saved, activity, search, random, wikipedia://<lang>.wikipedia.org/wiki/<title>, and
// https://<lang>.wikipedia.org/wiki/<title>. null when the URL names nothing the app opens.
export function intentForUri(uri: string): LaunchIntent | null {
  if (uri.length === 0) {
    return null;
  }
  const scheme: RegExpMatchArray | null = uri.match(SCHEME_RE);
  if (scheme !== null) {
    const host: string = scheme[2].toLowerCase();
    if (host === 'explore') {
      return tabIntent(TAB_EXPLORE);
    } else if (host === 'places') {
      return tabIntent(TAB_PLACES);
    } else if (host === 'saved') {
      return tabIntent(TAB_SAVED);
    } else if (host === 'activity') {
      return tabIntent(TAB_ACTIVITY);
    } else if (host === 'search') {
      return tabIntent(TAB_SEARCH);
    } else if (host === 'random') {
      return routeIntent('pages/RandomArticleViewControllerPage', {});
    } else if (host === 'settings') {
      // wmf_settingsViewActivity
      return routeIntent('pages/SettingsTabViewControllerPage', {});
    }
    // wikipedia://en.wikipedia.org/wiki/Earth reads as the https URL, query included
    return intentForUri('https://' + scheme[2] + scheme[3] + (scheme[4] !== undefined ? '?' + scheme[4] : ''));
  }
  const https: RegExpMatchArray | null = uri.match(HTTPS_RE);
  if (https === null) {
    return null;
  }
  // /wiki/<title> and /w/index.php?… (history, diffs, search, login …)
  const d: LinkDestination | null = destinationForURL(uri);
  if (d === null) {
    return tabIntent(TAB_EXPLORE);     // the wiki itself, or nothing native: open the app
  }
  return intentForDestination(d);
}
