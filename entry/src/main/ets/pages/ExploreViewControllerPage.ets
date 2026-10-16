// screen_explore — presentation: page. Start screen (nav graph root).
// Ported from Wikipedia/Code/ExploreViewController.swift: nav bar (W logo "explore_logo",
// profile-button, Tabs Button) + collection of ExploreCardViewController cards, one per
// WMFContentGroup, content dispatched per contentGroupKindInteger
// (ExploreCardViewController.configure(cell:forItemAt:with:)).
// S4: state + wiring. Feed WRITE path = updateFeedSources (per
// WMFExploreFeedContentController.updateFeedSources: each content source fetches and
// persists its WMFContentGroup via FeedStore, then the page re-reads allGroups).
// Hosts overlays: WMFProfileViewSheet (sheet), WMFArticleTabsView,
// DescriptionWelcomeInitialView, EditingWelcomeView, FundraisingAnnouncementPanelView,
// WMFGamesSplashScreenView, WMFImageGalleryView, WMFWelcomeInitialView (modal covers).
import { NotificationsService } from '../common/NotificationsService';
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { distanceText, bearingDegrees } from '../common/DistanceFormat';
import { ArticleLocationCollectionViewCell } from '../components/ArticleLocationCollectionViewCell';
import { formatString } from '../common/Plural';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';
import { geoLocationManager } from '@kit.LocationKit';
import workScheduler from '@ohos.resourceschedule.workScheduler';
import { BusinessError } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { DescriptionWelcomeInitialView } from './DescriptionWelcomeInitialViewControllerPage';
import { EditingWelcomeView } from './EditingWelcomeViewControllerPage';
import { WMFWelcomeInitialView } from './WMFWelcomeInitialViewControllerPage';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFFeedArticlePreview } from '../model/WMFFeedArticlePreview';
import { WMFFeedNewsStory } from '../model/WMFFeedNewsStory';
import { WMFFeedOnThisDayEvent } from '../model/WMFFeedOnThisDayEvent';
import { WMFFeedDayResponse, WMFFeedImage } from '../model/WMFFeedDayResponse';
import { WMFAnnouncement } from '../model/WMFAnnouncement';
import { ArticleSummary } from '../model/ArticleSummary';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { CDGameSession } from '../model/CDGameSession';
import { WMFLocationSearchResults } from '../model/WMFLocationSearchResults';
import { FeedStore, ContentGroupKind, midnightUTCFromLocal } from '../common/FeedStore';
import { FeedService } from '../common/FeedService';
import { SavedStore } from '../common/SavedStore';
import { HistoryStore } from '../common/HistoryStore';
import { WMFArticle } from '../model/WMFArticle';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { ArticleService } from '../common/ArticleService';
import { GeoService } from '../common/GeoService';
import {
  GameStore,
  WHICH_CAME_FIRST_GAME_TYPE,
  WhichCameFirstEvent,
  WhichCameFirstGameState,
  WhichCameFirstQuestion,
  makeWhichCameFirstQuestions
} from '../common/GameStore';
import { i18n } from '@kit.LocalizationKit';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { SessionStore } from '../common/SessionStore';
import { GrowthTasksService, meetsSuggestedEditsEditCount } from '../common/GrowthTasksService';
import { WMFCurrentUser } from '../model/WMFCurrentUser';
import { Prefs, PrefKeys, WMFDataPrefKeys, isCardInFeed, setCardInFeed, isGlobalKind, isCardLanguageInFeed,
  isLanguageInFeed, isGlobalCardsInFeed } from '../common/Prefs';
import { RootTabBar, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { FEED_CARD_KINDS, DEFAULT_TAB_TYPE_SETTINGS } from './ExploreFeedSettingsViewControllerPage';
import { ExploreCardViewController } from '../components/ExploreCardViewController';
import { ArticleRightAlignedImageCollectionViewCell } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { RankedArticleCollectionViewCell } from '../components/RankedArticleCollectionViewCell';
import { NewsCollectionViewCell } from '../components/NewsCollectionViewCell';
import { OnThisDayCollectionViewCell } from '../components/OnThisDayCollectionViewCell';
import { ScrollableEducationPanelViewController } from '../components/ScrollableEducationPanelViewController';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE, ROOT_BAR_HEIGHT } from '../components/NavButton';
import { FundraisingCampaignStore } from '../common/FundraisingCampaignStore';

const MS_PER_DAY: number = 24 * 60 * 60 * 1000;

// 'https://tr.wikipedia.org' -> 'tr'. The content language a card belongs to; the languages
// section stores one flag per code.
// WMFContentGroup+Extensions.m updateDailySortPriorityWithSortOrderByContentLanguageCode: the
// order of a day's cards. Each kind has a fixed slot; a language-specific card moves down 14
// slots per preferred language before its own, so a language's cards stay together in
// preferred-language order. The port had its own numbers, which put the games ahead of the
// featured article and mixed the languages.
function dailySortPriority(g: WMFContentGroup, preferred: string[]): number {
  const L: number = 14 * Math.max(0, preferred.indexOf(languageCodeOf(g.siteURLString)));
  switch (g.contentGroupKindInteger) {
    case ContentGroupKind.Announcement: return -2;
    case ContentGroupKind.ContinueReading: return 0;
    case ContentGroupKind.RelatedPages: return 1;
    case ContentGroupKind.ReadingList: return L + 2;
    case ContentGroupKind.Theme: return L + 3;
    case ContentGroupKind.FeaturedArticle: return L + 4;
    case ContentGroupKind.DailyGame: return L + 5;
    case ContentGroupKind.TopRead: return L + 6;
    case ContentGroupKind.News: return L + 7;
    case ContentGroupKind.PictureOfTheDay: return 8;
    case ContentGroupKind.OnThisDay: return L + 9;
    case ContentGroupKind.LocationPlaceholder: return L + 10;
    case ContentGroupKind.Location: return L + 11;
    case ContentGroupKind.Random: return L + 12;
    case ContentGroupKind.MainPage: return L + 13;
    default: return 0;
  }
}

function languageCodeOf(siteURLString: string | null): string {
  if (siteURLString === null || siteURLString === '') {
    return '';
  }
  return siteURLString.replace('https://', '').replace('http://', '').split('.')[0];
}
// How many calendar days of feed the Explore list carries. Source: WMFFeedContentSource
// fetches a multi-day window; three days is enough for Today / Yesterday / a dated header.
const FEED_DAYS: number = 3;
// WMFExploreFeedMaximumNumberOfDays
const EXPLORE_FEED_MAXIMUM_NUMBER_OF_DAYS: number = 30;

// The preferred-language set the stored feed was fetched for.
const FEED_REFRESH_LANGUAGES_KEY: string = 'WMFFeedRefreshLanguagesKey';

// Tint black template PNG (save.png) to the app link blue #3366CC (iOS template-image tint).
const BLUE_TINT: number[] = [
  0, 0, 0, 0, 0.2,
  0, 0, 0, 0, 0.4,
  0, 0, 0, 0, 0.8,
  0, 0, 0, 1, 0
];

// The REST summary endpoint returns `displaytitle` as markup; the card shows plain text.
function stripTags(html: string): string {
  return html.replace(/<[^>]*>/g, '').trim();
}

// One feed card: the persisted group + its parsed per-kind preview payload
// (WMFContentGroup.contentPreviewJSON, written by updateFeedSources below in the
// serialized MODEL shape — parseCardItem is the matching reader).
class ExploreCardItem {
  group: WMFContentGroup = new WMFContentGroup();
  // Day heading shown above this card, '' when the card belongs to the same day as the one
  // before it (or to today, which the large title already names).
  dayHeader: ResourceStr = '';
  // How many days back this card's block is from today. It is part of the LazyForEach key:
  // when the clock crosses midnight the cards do not change but their headings do, and a key
  // that did not move would keep the children ArkUI had already built.
  dayKey: string = '';
  previews: WMFFeedArticlePreview[] = [];
  newsStories: WMFFeedNewsStory[] = [];
  events: WMFFeedOnThisDayEvent[] = [];
  gameOptions: WhichCameFirstEvent[] = [];
  potd: WMFFeedImage | null = null;
  announcement: WMFAnnouncement | null = null;
}

// IDataSource over the feed's cards (ambient IDataSource/DataChangeListener).
class ExploreCardDataSource implements IDataSource {
  private items: ExploreCardItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ExploreCardItem {
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

  reload(items: ExploreCardItem[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// W logo tint: unchanged in the light themes, gray100 in the dark ones.
const IDENTITY_LOGO_FILTER: number[] = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
const LIGHT_LOGO_FILTER: number[] = [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0];

@Entry
@Component
export struct ExploreViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // Bumped by pages/Index on its onPageShow — see onHostShow.
  @Prop @Watch('onHostShow') showTick: number = 0;
  @State showProfileSheet: boolean = false;
  // ONE bindContentCover per node: repeated bindContentCover calls override each other,
  // so the 8 covers share one flag + a kind discriminator branched in coverBuilder.
  @State showCover: boolean = false;
  @State activeCover: string = '';
  // saved-state of featured-article cards (SaveButtonsController state), keyed by articleURL
  @State savedKeys: string[] = [];
  // spec stateVars: contentGroups (svc_feed_store load + svc_feed daily refresh),
  // isLoading (fetch lifecycle), theme (AppStorage token, Prefs.appThemeName key)
  @State contentGroups: WMFContentGroup[] = [];
  @State isLoading: boolean = false;
  // pull-to-refresh spinner (Refresh), cleared when the forced update has reloaded the feed
  @State isRefreshing: boolean = false;
  // reachabilityNotifier.isReachable (showOfflineEmptyViewIfNeeded)
  @State isNetworkAvailable: boolean = true;
  @StorageProp('WMFAppThemeName') theme: string = 'light';
  @StorageProp('wmfIsDark') isDark: boolean = false;
  // WMFReadingListToastManager.toggle(presenter:article:theme:): saving an article raises
  // the "Add "<title>" to a reading list?" toast (WMFReadingListToastConfig duration 13s);
  // un-saving dismisses it. Empty title == hidden.
  @State readingListToastTitle: string = '';
  // the article the toast is about - the one AddArticlesToReadingListViewController adds
  private readingListToastKey: string = '';
  private readingListToastArticle: string = '';
  // WMFReadingListsSyncPromoView: shown on the Explore feed until the reader signs in or
  // dismisses it. The port had no banner at all, so four cases that start from it were
  // unreachable.
  @State showSyncPromo: boolean = false;
  // today's Which Came First session (svc_game_store), shown on the games splash
  private gamesOpenedAt: number = 0;
  // picture-of-the-day gallery target (the gallery resolves its own Commons imageinfo)
  private readingListToastTimer: number = -1;
  // explore-feed-preferences-card-hidden-title — the undo bar the source raises after a card
  // is hidden. Empty title == hidden. `undoGroupKey` is the single card to restore;
  // `undoKind` is set instead when a whole kind was hidden.
  @State hiddenToastTitle: ResourceStr = '';
  private undoGroupKey: string = '';
  private undoKind: number = -1;
  private hiddenToastTimer: number = -1;
  // ExploreViewController.isLoadingNewContent
  private isLoadingNewContent: boolean = false;
  private isOpeningRandom: boolean = false;
  // The card set the data source currently holds, as an ordered key list.
  private cardsSignature: string = '';
  private cardsSource: ExploreCardDataSource = new ExploreCardDataSource();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    this.refreshSyncPromo();
    // SavedArticlesFetcher's offline copy lives under filesDir; without this the cache
    // dir stays unset and every write lands at '/' (fileIo 13900012).
    ArticleCacheStore.init(ctx);
    Database.init(ctx).then(() => {
      this.isNetworkAvailable = this.checkNetwork();
      // cached groups first (offline shows cached), then the daily network refresh. The
      // refresh guard compares the reader's languages against the set the stored feed was
      // fetched for, so they are read before it runs.
      LanguageStore.preferredLanguages().then((links: MWKLanguageLink[]): void => {
        const codes: string[] = [];
        for (const link of links) {
          codes.push(link.languageCode);
        }
        this.preferredCodes = codes.join(',');
        this.updateFeedSources();
      }).catch((e: Error): void => {
        console.error('explore: preferred languages unavailable: ' + e.message);
        this.updateFeedSources();
      });
      // the fundraising campaign is the article screen's modal (showFundraisingCampaign
      // AnnouncementIfNeeded); a fundraising feed announcement stays an inline card here
      this.loadFeed();
      this.registerBackgroundFeedRefresh(ctx);
    }).catch((e: Error) => {
      console.error('explore: db init failed: ' + e.message);
    });
  }

  private checkNetwork(): boolean {
    try {
      return connection.hasDefaultNetSync();
    } catch (e) {
      return true;
    }
  }

  // READ path — FeedStore.allGroups (fetchedResultsController over WMFContentGroup).
  private loadFeed(): Promise<void> {
    this.isLoading = true;
    return Promise.all([FeedStore.allGroups(), LanguageStore.readPreferredCodes()])
      .then((res: [WMFContentGroup[], string[]]) => {
      const groups: WMFContentGroup[] = res[0];
      const preferred: string[] = res[1];
      const visible: WMFContentGroup[] = [];
      // Every preferred language's feed day carries the same Picture of the day, so a global
      // kind is stored once per language; the feed shows it once per day.
      const globalSeen: Set<string> = new Set<string>();
      const locationAuthorized: boolean = GeoService.isLocationAuthorized();
      for (const g of groups) {
        // The Explore feed preferences were written by the two settings screens and read by
        // nobody, so switching a card off left it on the feed. Honour them here, which is
        // also what the card sheet's "Hide all ... cards" writes to.
        if (g.wasDismissed || !isCardInFeed(g.contentGroupKindInteger)) {
          continue;
        }
        // WMFNearbyContentSource: without location authorization there is no nearby card
        if (g.contentGroupKindInteger === ContentGroupKind.Location && !locationAuthorized) {
          continue;
        }
        // The languages section of screen_explore_feed_settings: a card carries the site it
        // came from, so a language switched off there drops its cards here, and the global
        // (non-language-specific) kinds ride on their own switch.
        if (isGlobalKind(g.contentGroupKindInteger)) {
          const dayKey: string = g.contentGroupKindInteger + '/' +
            (g.midnightUTCDate ?? midnightUTCFromLocal(g.date ?? 0));
          if (!isGlobalCardsInFeed() || globalSeen.has(dayKey)) {
            continue;
          }
          globalSeen.add(dayKey);
        } else if (!isLanguageInFeed(languageCodeOf(g.siteURLString)) ||
          // FeedCardSettingsViewController: this card switched off for this language only
          !isCardLanguageInFeed(g.contentGroupKindInteger, languageCodeOf(g.siteURLString)) ||
          // Groups stay stored after their language is removed from the app languages.
          preferred.indexOf(languageCodeOf(g.siteURLString)) < 0) {
          continue;
        }
        visible.push(g);
      }
      // exploreFeedSortDescriptors: midnightUTCDate DESC, dailySortPriority ASC, date DESC
      const dayOf = (g: WMFContentGroup): number => g.midnightUTCDate ?? midnightUTCFromLocal(g.date ?? 0);
      visible.sort((x: WMFContentGroup, y: WMFContentGroup): number =>
        (dayOf(y) - dayOf(x)) || (dailySortPriority(x, preferred) - dailySortPriority(y, preferred)) ||
          ((y.date ?? 0) - (x.date ?? 0)));
      // WMFExploreFeedContentController: the Suggested Edits card is always the second card
      const se: number = visible.findIndex((g: WMFContentGroup) =>
        g.contentGroupKindInteger === ContentGroupKind.SuggestedEdits);
      if (se >= 0 && se !== 1 && visible.length > 1) {
        const card: WMFContentGroup = visible.splice(se, 1)[0];
        visible.splice(1, 0, card);
      }
      this.contentGroups = visible;
      const items: ExploreCardItem[] = [];
      const signature: string[] = [];
      let lastDay: number = -1;
      for (const g of visible) {
        const item: ExploreCardItem = this.parseCardItem(g);
        const day: number = g.midnightUTCDate ?? midnightUTCFromLocal(g.date ?? Date.now());
        item.dayHeader = day === lastDay ? '' : this.dayHeaderText(day);
        item.dayKey = String(Math.round((midnightUTCFromLocal(Date.now()) - day) / MS_PER_DAY));
        lastDay = day;
        items.push(item);
        // The heading is part of the signature: it is derived from today's date, so a load
        // that happens after the clock has rolled past midnight has to rebuild the rows even
        // though the card set itself did not change.
        signature.push((g.key ?? String(g.contentGroupKindInteger)) + '@' + item.dayKey);
      }
      // Reload the data source only when the card set actually changed. Returning from
      // another tab re-runs this, and an unconditional reload rebuilt every row and sent the
      // feed back to the top - the reader lost their place every time they looked at Places.
      const next: string = signature.join('|');
      if (next !== this.cardsSignature) {
        this.cardsSignature = next;
        this.cardsSource.reload(items);
      }
      this.seedSavedKeys(items);
      this.isLoading = false;
    }).catch(() => {
      this.isLoading = false;
    });
  }

  // WRITE path — updateFeedSources (WMFExploreFeedContentController): every content
  // source fetches its payload and persists a WMFContentGroup, then the page reloads.
  private updateFeedSources(force: boolean = false): void {
    if (this.isLoadingNewContent) {
      this.isRefreshing = false;
      return;
    }
    // daily granularity: skip the network when today's feed is already stored. The check
    // also compares the languages that feed was fetched for: adding a language to My
    // languages has to bring its cards in, and "already refreshed today" alone kept the new
    // language out of the feed until the next calendar day.
    const lastRefresh: number = Prefs.getNumber(PrefKeys.feedRefreshDate, 0);
    if (!force && lastRefresh > 0 && this.daysInFeed() > 1 &&
      midnightUTCFromLocal(lastRefresh) === midnightUTCFromLocal(Date.now()) &&
      Prefs.getString(FEED_REFRESH_LANGUAGES_KEY, '') === this.preferredCodes) {
      return;
    }
    this.isLoadingNewContent = true;
    this.isLoading = true;
    this.runFeedUpdate(force).then(() => {
      this.isLoadingNewContent = false;
      this.isNetworkAvailable = this.checkNetwork();
      this.loadFeed().finally(() => {
        this.isRefreshing = false;
      });
    }).catch(() => {
      this.isLoadingNewContent = false;
      this.isNetworkAvailable = this.checkNetwork();
      this.loadFeed().finally(() => {
        this.isRefreshing = false;
      });
    });
  }

  // How many calendar days the stored feed covers. The daily-refresh guard reads this: a
  // store holding only today still needs the earlier days fetched, so "already refreshed
  // today" alone is not enough to skip the network.
  private daysInFeed(): number {
    const days: number[] = [];
    for (const g of this.contentGroups) {
      const day: number = g.midnightUTCDate ?? midnightUTCFromLocal(g.date ?? Date.now());
      if (days.indexOf(day) < 0) {
        days.push(day);
      }
    }
    return days.length;
  }

  // The preferred language codes, joined — compared against the set the stored feed was
  // fetched for.
  private preferredCodes: string = '';

  private async runFeedUpdate(force: boolean = false): Promise<void> {
    const lang: MWKLanguageLink = await LanguageStore.appLanguage();
    const host: string = lang.languageCode + '.wikipedia.org';
    const site: string = 'https://' + host;
    let anySourceSucceeded: boolean = false;
    // WMFExploreFeedContentController runs the language-specific sources once per preferred
    // language, which is what the languages section of the feed settings switches between.
    // Only the primary language was ever fetched, so a second language had no cards to hide.
    try {
      const preferred: MWKLanguageLink[] = await LanguageStore.preferredLanguages();
      const codes: string[] = [];
      for (const link of preferred) {
        codes.push(link.languageCode);
      }
      this.preferredCodes = codes.join(',');
      for (const other of preferred) {
        if (other.languageCode !== lang.languageCode) {
          const done: boolean = await this.fetchLanguageSources(other);
          anySourceSucceeded = anySourceSucceeded || done;
        }
      }
    } catch (e) {
      console.error('explore: preferred languages unavailable: ' + this.describeError(e));
    }
    // WMFFeedContentSource — feed/featured/{y}/{m}/{d}: tfa, mostread, image, news
    try {
      const feed: WMFFeedDayResponse = await FeedService.fetchTodayFeed(host);
      await this.persistFeedDay(feed, site);
      anySourceSucceeded = true;
    } catch (e) {
      console.error('explore: feed day fetch failed: ' + this.describeError(e));
    }
    // WMFFeedContentSource loads a window of days, not just today — the feed is grouped by
    // calendar day and only today was ever fetched, so there was no "Yesterday" block to
    // label. Each day is persisted under its own date, which is what the day headers and the
    // midnight rollover both read.
    for (let back: number = 1; back < FEED_DAYS; back++) {
      const dayMs: number = Date.now() - back * MS_PER_DAY;
      const day = new Date(dayMs);
      try {
        const past: WMFFeedDayResponse = await FeedService.fetchFeedDay(host,
          day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate());
        await this.persistFeedDay(past, site, dayMs);
        anySourceSucceeded = true;
      } catch (e) {
        console.error('explore: feed day -' + back + ' fetch failed: ' + this.describeError(e));
      }
    }
    // WMFOnThisDayContentSource
    try {
      const now = new Date();
      const events: WMFFeedOnThisDayEvent[] = await FeedService.fetchOnThisDayEvents(
        host, lang.languageCode, now.getUTCMonth() + 1, now.getUTCDate());
      if (events.length > 0) {
        const group: WMFContentGroup = this.makeGroup(ContentGroupKind.OnThisDay, site, 5);
        await this.persistGroup(group, JSON.stringify(events.slice(0, 3)),
          JSON.stringify(events), events.length);
      }
      anySourceSucceeded = true;
    } catch (e) {
      console.error('explore: on-this-day fetch failed: ' + this.describeError(e));
    }
    // WMFSuggestedEditsContentSource: the old card goes, and a new one only for a permanent,
    // unblocked account with more than 50 edits on a wiki that has image recommendations
    try {
      await FeedStore.removeAllGroupsOfKind(ContentGroupKind.SuggestedEdits);
      const user: WMFCurrentUser | null = SessionStore.currentUser.value;
      if (SessionStore.isLoggedIn && user !== null && !user.isBlocked &&
        meetsSuggestedEditsEditCount(user.editCount, false) && await GrowthTasksService.hasRecommendations(host)) {
        const group: WMFContentGroup = this.makeGroup(ContentGroupKind.SuggestedEdits, site, 0);
        group.key = FeedStore.suggestedEditsKey();
        await this.persistGroup(group, '[]', '[]', 1);
      }
    } catch (e) {
      console.error('explore: suggested edits card failed: ' + this.describeError(e));
    }
    // WMFAnnouncementsContentSource
    try {
      // WMFAnnouncementsContentSource: the fundraising campaign config is fetched with the
      // announcements, for the article screen's campaign modal
      FundraisingCampaignStore.fetchConfig().catch((e: Error) => {
        console.error('explore: campaign config fetch failed: ' + e.message);
      });
      const announcements: WMFAnnouncement[] = await FeedService.fetchAnnouncements(host);
      for (const a of announcements) {
        const group: WMFContentGroup = this.makeGroup(ContentGroupKind.Announcement, site, 0);
        group.key = FeedStore.announcementKey(site, a.identifier ?? '');
        await this.persistGroup(group, JSON.stringify(a), JSON.stringify(a), 1);
      }
      anySourceSucceeded = true;
    } catch (e) {
      console.error('explore: announcements fetch failed: ' + this.describeError(e));
    }
    // WMFGamesContentSource — the daily game card. The kind, its content type, its group key
    // and its footer route all existed; nothing ever PERSISTED a group for it, so the feed
    // never showed a Games card on any day.
    try {
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.DailyGame, site, 0);
      const json: string = JSON.stringify(await this.dailyGamePreview(host, lang.languageCode));
      await this.persistGroup(group, json, json, 1);
      anySourceSucceeded = true;
    } catch (e) {
      console.error('explore: daily game card failed: ' + this.describeError(e));
    }
    // WMFRandomContentSource — page/random/summary
    try {
      const summary: ArticleSummary = await ArticleService.fetchRandomSummary(host);
      const preview: WMFFeedArticlePreview = this.previewFromSummary(summary);
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.Random, site, 6);
      const json: string = JSON.stringify([preview]);
      await this.persistGroup(group, json, json, 1);
      anySourceSucceeded = true;
    } catch (e) {
      console.error('explore: random fetch failed: ' + this.describeError(e));
    }
    // WMFContinueReadingContentSource / WMFRelatedPagesContentSource: local history, so they
    // run whatever the network did. Neither card was ever created, so switching them off in
    // the feed settings had nothing to remove.
    try {
      await this.updateContinueReading(force);
    } catch (e) {
      console.error('explore: continue reading failed: ' + this.describeError(e));
    }
    try {
      await this.updateRelatedPages();
    } catch (e) {
      console.error('explore: related pages failed: ' + this.describeError(e));
    }
    // WMFNearbyContentSource — only when location access is already granted; the source
    // shows no nearby card without authorization and Places owns the prompt.
    try {
      const location: geoLocationManager.Location = await geoLocationManager.getCurrentLocation();
      const results: WMFLocationSearchResults = await GeoService.searchNearby(
        host, location.latitude, location.longitude, 1000, 3);
      if (results.results.length > 0) {
        const previews: WMFFeedArticlePreview[] = [];
        for (const r of results.results) {
          const p: WMFFeedArticlePreview = new WMFFeedArticlePreview();
          p.displayTitle = r.displayTitle ?? r.title ?? '';
          p.displayTitleHTML = p.displayTitle;
          p.wikidataDescription = r.wikidataDescription;
          p.thumbnailURL = r.thumbnailURL;
          p.articleURL = r.articleURLForSiteHost(host) ?? '';
          p.latitude = r.latitude;
          p.longitude = r.longitude;
          previews.push(p);
        }
        // The key is the fix's coordinates, so each refresh would add another nearby card
        // beside the last one; the newest fix replaces it.
        await FeedStore.removeAllGroupsOfKind(ContentGroupKind.Location);
        const group: WMFContentGroup = this.makeGroup(ContentGroupKind.Location, site, 7);
        group.key = FeedStore.locationKey(location.latitude, location.longitude);
        group.locationLatitude = location.latitude;
        group.locationLongitude = location.longitude;
        await this.persistGroup(group, JSON.stringify(previews),
          JSON.stringify(previews), previews.length);
      }
    } catch (e) {
      // no location permission / no fix — no nearby card, matching the source, which also
      // removes the stored Location groups when it is not authorized
      console.warn('explore: nearby card skipped: ' + this.describeError(e));
      if (!GeoService.isLocationAuthorized()) {
        await FeedStore.removeAllGroupsOfKind(ContentGroupKind.Location);
      }
    }
    if (anySourceSucceeded) {
      Prefs.putNumber(PrefKeys.feedRefreshDate, Date.now());
      Prefs.putString(FEED_REFRESH_LANGUAGES_KEY, this.preferredCodes);
    }
  }

  // ExploreViewController.scrollViewDidScroll -> feedContentController.updateFeedSources(with:
  // nextOldestDate): the featured feed of the day before the oldest day shown, for every
  // preferred language, back to WMFExploreFeedMaximumNumberOfDays.
  private isLoadingOlderContent: boolean = false;

  private loadOlderContent(): void {
    if (this.isLoadingOlderContent || this.isLoading || this.contentGroups.length === 0) {
      return;
    }
    let oldest: number = Number.MAX_SAFE_INTEGER;
    for (const g of this.contentGroups) {
      oldest = Math.min(oldest, g.midnightUTCDate ?? midnightUTCFromLocal(g.date ?? Date.now()));
    }
    const days: number = Math.round((midnightUTCFromLocal(Date.now()) - oldest) / MS_PER_DAY);
    if (days >= EXPLORE_FEED_MAXIMUM_NUMBER_OF_DAYS) {
      return;
    }
    this.isLoadingOlderContent = true;
    const next: Date = new Date(oldest - MS_PER_DAY);
    // the local noon of that calendar day, which the stored group's midnightUTCDate is cut from
    const localDayMs: number = new Date(next.getUTCFullYear(), next.getUTCMonth(), next.getUTCDate(), 12).getTime();
    LanguageStore.preferredLanguages().then(async (preferred: MWKLanguageLink[]) => {
      for (const lang of preferred) {
        const host: string = lang.languageCode + '.wikipedia.org';
        try {
          const feed: WMFFeedDayResponse = await FeedService.fetchFeedDay(host,
            next.getUTCFullYear(), next.getUTCMonth() + 1, next.getUTCDate());
          await this.persistFeedDay(feed, 'https://' + host, localDayMs);
        } catch (e) {
          console.error('explore: older day fetch failed: ' + this.describeError(e));
        }
      }
      await this.loadFeed();
    }).catch((e: Error) => {
      console.error('explore: older content failed: ' + e.message);
    }).finally(() => {
      this.isLoadingOlderContent = false;
    });
  }

  // The sources WMFExploreFeedContentController runs per preferred language: the feed days
  // (featured / top read / picture of the day / news), On this day and the randomizer.
  private async fetchLanguageSources(lang: MWKLanguageLink): Promise<boolean> {
    const host: string = lang.languageCode + '.wikipedia.org';
    const site: string = 'https://' + host;
    let ok: boolean = false;
    // WMFExploreFeedContentController adds a WMFDailyGameContentSource per preferred site, so
    // every language's Games card previews its own day's events.
    try {
      const game: WMFContentGroup = this.makeGroup(ContentGroupKind.DailyGame, site, 0);
      const json: string = JSON.stringify(await this.dailyGamePreview(host, lang.languageCode));
      await this.persistGroup(game, json, json, 1);
    } catch (e) {
      console.error('explore: ' + lang.languageCode + ' daily game card failed: ' + this.describeError(e));
    }
    for (let back: number = 0; back < FEED_DAYS; back++) {
      const dayMs: number = Date.now() - back * MS_PER_DAY;
      const day = new Date(dayMs);
      try {
        const feed: WMFFeedDayResponse = await FeedService.fetchFeedDay(host,
          day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate());
        await this.persistFeedDay(feed, site, dayMs);
        ok = true;
      } catch (e) {
        console.error('explore: ' + lang.languageCode + ' feed day -' + back +
          ' fetch failed: ' + this.describeError(e));
      }
    }
    try {
      const now = new Date();
      const events: WMFFeedOnThisDayEvent[] = await FeedService.fetchOnThisDayEvents(
        host, lang.languageCode, now.getUTCMonth() + 1, now.getUTCDate());
      if (events.length > 0) {
        const group: WMFContentGroup = this.makeGroup(ContentGroupKind.OnThisDay, site, 5);
        await this.persistGroup(group, JSON.stringify(events.slice(0, 3)),
          JSON.stringify(events), events.length);
        ok = true;
      }
    } catch (e) {
      console.error('explore: ' + lang.languageCode + ' on-this-day fetch failed: ' +
        this.describeError(e));
    }
    try {
      const summary: ArticleSummary = await ArticleService.fetchRandomSummary(host);
      const preview: WMFFeedArticlePreview = this.previewFromSummary(summary);
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.Random, site, 6);
      const json: string = JSON.stringify([preview]);
      await this.persistGroup(group, json, json, 1);
      ok = true;
    } catch (e) {
      console.error('explore: ' + lang.languageCode + ' random fetch failed: ' +
        this.describeError(e));
    }
    return ok;
  }

  // The day a card belongs to, as a heading: "Today", "Yesterday" or the date, computed from
  // the card's own date against the current date, so the labels stay right when the clock
  // crosses midnight.
  private dayHeaderText(midnightUTCMs: number): ResourceStr {
    const today: number = midnightUTCFromLocal(Date.now());
    if (midnightUTCMs >= today) {
      return $r('app.string.today_title');
    }
    if (midnightUTCMs === today - MS_PER_DAY) {
      return $r('app.string.yesterday_title');
    }
    try {
      // midnightUTCDate is the local y/m/d stamped at UTC midnight, so read it back in UTC.
      return new Intl.DateTimeFormat(i18n.System.getSystemLocale(), {
        year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC'
      }).format(new Date(midnightUTCMs));
    } catch (e) {
      return new Date(midnightUTCMs).toDateString();
    }
  }

  // Renders the caught value diagnosable in hilog: message + stack for Errors,
  // String(e) otherwise (a throw is not guaranteed to be an Error).
  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message + (e.stack !== undefined ? ' | ' + e.stack : '');
    }
    return String(e);
  }

  private async persistFeedDay(feed: WMFFeedDayResponse, site: string,
    dateMs: number = Date.now()): Promise<void> {
    const featured: WMFFeedArticlePreview | null = feed.featuredArticle;
    if (featured !== null) {
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.FeaturedArticle, site, 1, dateMs);
      const json: string = JSON.stringify([featured]);
      await this.persistGroup(group, json, json, 1);
    }
    const topRead = feed.topRead;
    console.info('explore: topRead=' + (topRead === null ? 'null' : topRead.articlePreviews.length.toString()));
    if (topRead !== null && topRead.articlePreviews.length > 0) {
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.TopRead, site, 2, dateMs);
      // previewRange for topRead is 5 (WMFContentGroup+Extensions)
      await this.persistGroup(group, JSON.stringify(topRead.articlePreviews.slice(0, 5)),
        JSON.stringify(topRead.articlePreviews), topRead.articlePreviews.length);
    }
    const potd: WMFFeedImage | null = feed.pictureOfTheDay;
    if (potd !== null) {
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.PictureOfTheDay, site, 3, dateMs);
      const json: string = JSON.stringify(potd);
      await this.persistGroup(group, json, json, 1);
    }
    if (feed.newsStories.length > 0) {
      const group: WMFContentGroup = this.makeGroup(ContentGroupKind.News, site, 4, dateMs);
      await this.persistGroup(group, JSON.stringify(feed.newsStories.slice(0, 3)),
        JSON.stringify(feed.newsStories), feed.newsStories.length);
    }
  }

  // The last article read, once the app has been away for a day (wmf_appResignActiveDate) or
  // on a pull to refresh (force). Inside that day the card is removed again, as the source does.
  private async updateContinueReading(force: boolean): Promise<void> {
    const resignedAt: number = Prefs.getNumber(PrefKeys.appResignActiveDate, 0);
    const show: boolean = force || (resignedAt > 0 && Date.now() - resignedAt >= MS_PER_DAY);
    if (!show) {
      await FeedStore.removeAllGroupsOfKind(ContentGroupKind.ContinueReading);
      return;
    }
    const last: WMFArticle | null = await HistoryStore.mostRecentlyReadArticle();
    if (last === null || last.key === null || last.isExcludedFromFeed || last.key.indexOf('/wiki/') < 0) {
      return;
    }
    const site: string = last.key.substring(0, last.key.indexOf('/wiki/'));
    const key: string = FeedStore.continueReadingKey(site, this.titleOfKey(last.key));
    // the same article already has its card (shown or dismissed): leave it
    if (await FeedStore.groupForKey(key) !== null) {
      return;
    }
    await FeedStore.removeAllGroupsOfKind(ContentGroupKind.ContinueReading);
    const group: WMFContentGroup = this.makeGroup(ContentGroupKind.ContinueReading, site, -2,
      last.viewedDate ?? Date.now());
    group.key = key;
    group.articleURLString = last.key;
    group.midnightUTCDate = midnightUTCFromLocal(group.date ?? Date.now());
    const json: string = JSON.stringify([this.previewFromArticle(last)]);
    await this.persistGroup(group, json, json, 1);
  }

  // The newest article read for 30 s or saved, within the last three days, that has no card yet:
  // its morelike results under "Because you read".
  private async updateRelatedPages(): Promise<void> {
    const existing: string[] = (await FeedStore.groupsOfKind(ContentGroupKind.RelatedPages))
      .map((g: WMFContentGroup) => g.articleURLString ?? '');
    const seed: WMFArticle | null = await HistoryStore.relatedPagesSeed(existing);
    if (seed === null || seed.key === null || seed.key.indexOf('/wiki/') < 0) {
      return;
    }
    const when: number = Math.max(seed.viewedDate ?? 0, seed.savedDate ?? 0);
    if (midnightUTCFromLocal(Date.now()) - midnightUTCFromLocal(when) > 3 * MS_PER_DAY) {
      return;
    }
    const site: string = seed.key.substring(0, seed.key.indexOf('/wiki/'));
    const title: string = this.titleOfKey(seed.key);
    // RelatedSearchFetcher's 20 results: the card shows three, "Additional related articles"
    // opens all of them
    const related: ArticleSummary[] =
      await ArticleService.fetchRelatedArticles(site.replace('https://', ''), title, 20);
    if (related.length < 3) {
      return;
    }
    const all: WMFFeedArticlePreview[] = related.map((r: ArticleSummary): WMFFeedArticlePreview => {
      const p: WMFFeedArticlePreview = this.previewFromSummary(r);
      p.articleURL = site + '/wiki/' + encodeURIComponent((r.title ?? '').replace(/ /g, '_'));
      return p;
    });
    const previews: WMFFeedArticlePreview[] = [this.previewFromArticle(seed)].concat(all.slice(0, 3));
    const group: WMFContentGroup = this.makeGroup(ContentGroupKind.RelatedPages, site, -1, when);
    group.key = FeedStore.relatedPagesKey(site, title);
    group.articleURLString = seed.key;
    group.midnightUTCDate = midnightUTCFromLocal(group.date ?? Date.now());
    await this.persistGroup(group, JSON.stringify(previews), JSON.stringify(all), related.length);
  }

  private titleOfKey(key: string): string {
    const raw: string = key.substring(key.indexOf('/wiki/') + 6);
    try {
      return decodeURIComponent(raw).replace(/_/g, ' ');
    } catch (e) {
      return raw.replace(/_/g, ' ');
    }
  }

  private previewFromArticle(a: WMFArticle): WMFFeedArticlePreview {
    const p: WMFFeedArticlePreview = new WMFFeedArticlePreview();
    p.displayTitle = a.displayTitle ?? this.titleOfKey(a.key ?? '');
    p.displayTitleHTML = p.displayTitle;
    p.wikidataDescription = a.wikidataDescription;
    p.snippet = a.snippet;
    p.thumbnailURL = a.thumbnailURLString ?? a.imageURLString;
    p.articleURL = a.key ?? '';
    return p;
  }

  private makeGroup(kind: number, site: string, sortPriority: number,
    dateMs: number = Date.now()): WMFContentGroup {
    const g: WMFContentGroup = new WMFContentGroup();
    g.contentGroupKindInteger = kind;
    g.siteURLString = site;
    // The group's own day, not "now": the feed carries several days at once and each day's
    // cards must key and sort under the date they belong to.
    g.date = dateMs;
    g.isVisible = true;
    g.dailySortPriority = sortPriority;
    return g;
  }

  // fetchOrCreateGroup, but a group the user dismissed today stays dismissed
  // (ON_CONFLICT_REPLACE would otherwise resurrect it on every refresh).
  private async persistGroup(group: WMFContentGroup, previewJSON: string,
    fullJSON: string | null, count: number | null): Promise<void> {
    if (group.key === null && group.siteURLString !== null && group.date !== null) {
      group.midnightUTCDate = midnightUTCFromLocal(group.date);
      group.key = FeedStore.keyForKind(group.contentGroupKindInteger as ContentGroupKind,
        group.siteURLString, group.midnightUTCDate, group.articleURLString);
    }
    if (group.key !== null) {
      const existing: WMFContentGroup | null = await FeedStore.groupForKey(group.key);
      if (existing !== null && existing.wasDismissed) {
        return;
      }
    }
    group.contentPreviewJSON = previewJSON;
    await FeedStore.fetchOrCreateGroup(group, fullJSON, count);
  }

  private previewFromSummary(s: ArticleSummary): WMFFeedArticlePreview {
    const p: WMFFeedArticlePreview = new WMFFeedArticlePreview();
    // The summary endpoint's `displaytitle` is MARKUP ("<span lang=\"en\" dir=\"ltr\">...").
    // Feeding it to the card's Text() rendered the raw tags as the Randomizer card's title,
    // and handing it to the article route asked the API for a title that does not exist.
    // `title` is the plain, canonical one - the same field every other feed source uses.
    p.displayTitle = s.title ?? stripTags(s.displayTitle ?? '');
    p.displayTitleHTML = s.displayTitle ?? p.displayTitle;
    p.wikidataDescription = s.articleDescription;
    p.snippet = s.extract;
    p.thumbnailURL = s.thumbnail !== null ? (s.thumbnail?.source ?? null) : null;
    p.articleURL = s.articleURL ?? '';
    return p;
  }

  // WorkScheduler deferred task — daily background feed refresh
  // (iOS BGTaskScheduler "org.wikimedia.wikipedia.appRefresh" analogue).
  // WorkInfo per <sdk>/ets/api/@ohos.resourceschedule.workScheduler.d.ts: workId, bundleName
  // and abilityName are the mandatory fields, and abilityName must name a DECLARED
  // WorkSchedulerExtensionAbility — pointing it at EntryAbility failed the OS-side
  // CheckExtensionInfos ("extension info is error", errCode 970000501). At least one trigger
  // condition is required (networkType), and a cyclic task's interval must be >= 2 hours.
  private registerBackgroundFeedRefresh(ctx: common.UIAbilityContext): void {
    try {
      const info: workScheduler.WorkInfo = {
        workId: 1,
        bundleName: ctx.abilityInfo.bundleName,
        abilityName: 'FeedRefreshExtension',
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isRepeat: true,
        repeatCycleTime: 24 * 60 * 60 * 1000,
        isPersisted: true
      };
      workScheduler.startWork(info);
      console.info('explore: background feed-refresh work registered');
    } catch (e) {
      // 9700005 on a relaunch means the deferred task is already registered (workId 1 is
      // stable across launches) — the desired end state, not a failure. The thrown value does
      // not always carry a readable `code`, so the rendered message is checked too.
      const detail: string = this.describeError(e);
      if (String((e as BusinessError).code) === '9700005' || detail.indexOf('9700005') >= 0) {
        console.info('explore: background feed-refresh work already registered');
      } else {
        console.error('explore: workScheduler registration failed: ' + detail);
      }
    }
  }

  // contentPreviewJSON is written by runFeedUpdate in serialized-model shape; parse by cast.
  private parseCardItem(group: WMFContentGroup): ExploreCardItem {
    const item: ExploreCardItem = new ExploreCardItem();
    item.group = group;
    const json: string | null = group.contentPreviewJSON;
    if (json === null || json === '') {
      return item;
    }
    const kind: number = group.contentGroupKindInteger;
    try {
      if (kind === ContentGroupKind.News) {
        item.newsStories = JSON.parse(json) as WMFFeedNewsStory[];
      } else if (kind === ContentGroupKind.OnThisDay) {
        item.events = JSON.parse(json) as WMFFeedOnThisDayEvent[];
      } else if (kind === ContentGroupKind.PictureOfTheDay) {
        item.potd = JSON.parse(json) as WMFFeedImage;
      } else if (kind === ContentGroupKind.Announcement) {
        item.announcement = JSON.parse(json) as WMFAnnouncement;
      } else if (kind === ContentGroupKind.DailyGame) {
        item.gameOptions = JSON.parse(json) as WhichCameFirstEvent[];
      } else {
        item.previews = JSON.parse(json) as WMFFeedArticlePreview[];
      }
    } catch (e) {
      // malformed preview payload — the card renders header-only
    }
    return item;
  }

  @Builder
  profileSheetBuilder() {
    WMFProfileViewSheet({
      onClose: (): void => {
        this.showProfileSheet = false;
      }
    })
  }

  // All hosted modal covers behind the single bindContentCover, branched by activeCover.
  @Builder
  coverBuilder() {
    if (this.activeCover === 'tabs') {
      WMFArticleTabsView({
        onClose: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'descriptionWelcome') {
      // DescriptionWelcomePageViewController dismisses itself (Skip / last-page Start
      // editing); the host owns the cover, so it closes it here.
      DescriptionWelcomeInitialView({
        onDismiss: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'editingWelcome') {
      EditingWelcomeView({
        onDismiss: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'welcomeInitial') {
      WMFWelcomeInitialView({
        onDismiss: (): void => {
          this.showCover = false;
        }
      })
    }
  }

  // WMFReadingListToastPresenter card: 16pt side insets, white card, 8pt-offset shadow,
  // plus.circle leading glyph. Source capture (402x874): box [16,693][386,767],
  // icon [36,715][66,745], title [82,711][298,749].
  @Builder
  readingListToastBuilder() {
    if (this.readingListToastTitle !== '') {
      Column() {
        Row({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.plus_circle'))
            .fontSize(30)
            .fontColor([$r('app.color.theme_secondary_text')])
          Text(this.readingListToastTitle)
            .fontSize(15)
            .lineHeight(19)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.theme_text'))
            .layoutWeight(1)
        }
        .id('add')
        .width('100%')
        .height(74)
        .padding({ left: 20, right: 16 })
        .alignItems(VerticalAlign.Center)
        .borderRadius(10)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .shadow({ radius: 16, color: '#1F000000', offsetY: 8 })
        .onClick(() => {
          this.dismissReadingListToast();
          // WMFReadingListToastManager.performDefaultAction ->
          // AddArticlesToReadingListViewController. A routed page: as a content cover its
          // lists never drew (the empty state showed with lists present).
          const params: Record<string, string> = {
            'articleKey': this.readingListToastKey, 'articleTitle': this.readingListToastArticle };
          router.pushUrl({ url: 'pages/AddArticlesToReadingListViewControllerPage', params: params });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      // absolute inside the root Column so the toast floats over the feed instead of
      // pushing the tab bar; 693/874 of the source screen height.
      .position({ x: 0, y: '79.3%' })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  // WMFReadingListsSyncPromoView — title, explanation, the sign-in action and a dismiss X.
  @Builder
  syncPromoBanner() {
    Column() {
      Row() {
        Text($r('app.string.reading_list_login_title'))
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        Button() {
          Image($r('app.media.close'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
        }
        .id('reading_list_sync_promo_dismiss')
        .accessibilityText('Dismiss')
        .type(ButtonType.Circle)
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.dismissSyncPromo();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text($r('app.string.reading_list_login_subtitle'))
        .id('reading_list_sync_promo_body')
        .width('100%')
        .fontSize(15)
        .lineHeight(20)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 4 })

      Button($r('app.string.reading_list_login_button_title'))
        .id('reading_list_sync_promo_login')
        .type(ButtonType.Capsule)
        .width('100%')
        // The Turkish label is half again as long as the English one; a fixed 44vp row
        // ellipsised it. The button grows to fit instead.
        .constraintSize({ minHeight: 44 })
        .padding({ top: 10, bottom: 10, left: 16, right: 16 })
        .labelStyle({ maxLines: 2, overflow: TextOverflow.Ellipsis })
        .fontSize(15)
        .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .backgroundColor($r('app.color.theme_link'))
        .margin({ top: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
            console.error('explore: sync promo login route failed: ' + e.message);
          });
        })
    }
    .id('reading_list_sync_promo')
    .width('100%')
    .padding(16)
    .margin({ top: 8, bottom: 4 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(10)
    .shadow({ radius: 10, color: '#1F000000', offsetY: 2 })
  }

  // Shown while there is no session and the reader has not dismissed it. Signing in or
  // dismissing both take it away for good.
  private refreshSyncPromo(): void {
    if (SessionStore.isLoggedIn) {
      this.showSyncPromo = false;
      return;
    }
    this.showSyncPromo = !Prefs.getBoolean(WMFDataPrefKeys.didDismissReadingListSyncPromo, false);
  }

  private dismissSyncPromo(): void {
    Prefs.putBoolean(WMFDataPrefKeys.didDismissReadingListSyncPromo, true);
    this.showSyncPromo = false;
  }

  // The undo bar the source raises after a card (or a whole card kind) is hidden: the
  // "Card hidden" title with an Undo control, auto-dismissing after 8s.
  @Builder
  hiddenToastBuilder() {
    if (this.hiddenToastTitle !== '') {
      Column() {
        Row() {
          Text(this.hiddenToastTitle)
            .fontSize(15)
            .fontColor(Color.White)
            .layoutWeight(1)
          Button() {
            Text($r('app.string.action_undo'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .id('undo')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.undoHide();
          })
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 12 })
        .alignItems(VerticalAlign.Center)
        .borderRadius(10)
        // Opaque: at 87% the card caption underneath bled through the title.
        .backgroundColor('#FF202122')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .position({ x: 0, y: '79.3%' })
      // The bar floats over the feed, so it has to swallow the tap: without the zIndex the
      // Undo press also reached the card underneath and opened it. HitTestMode.Block would
      // swallow it one level too early — the Undo button inside would never see the press.
      .zIndex(20)
      .hitTestBehavior(HitTestMode.Default)
    }
  }

  // SaveButton of the full-width hero cards (featured article, random article).
  @Builder
  saveForLaterButton(p: WMFFeedArticlePreview) {
    Button() {
      Row() {
        Image(this.isSavedPreview(p) ? $r('app.media.save_filled') : $r('app.media.save'))
          .height(18)
          .objectFit(ImageFit.Contain)
          .colorFilter(new ColorFilter(BLUE_TINT))
        Text(this.isSavedPreview(p) ? $r('app.string.button_saved_for_later') : $r('app.string.button_save_for_later'))
          .fontSize(17)
          .fontColor($r('app.color.theme_link'))
          .margin({ left: 8 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .id('save_for_later')
    .type(ButtonType.Normal)
    .backgroundColor(Color.Transparent)
    .margin({ top: 14, left: 16, bottom: 16 })
    .onClick(() => {
      this.saveForLater(p);
    })
    // SaveButtonsController.saveButtonDidReceiveLongPress -> Add to reading list
    .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
      router.pushUrl({ url: 'pages/AddArticlesToReadingListViewControllerPage',
        params: { 'articleKey': p.articleURL ?? '', 'articleTitle': p.displayTitle } as Record<string, string> });
    }))
  }

  // cardContent — ExploreCardViewController.configure(cell:forItemAt:with:): one row form
  // per WMFContentGroupKind (conditionalVariant boundTo contentGroupKindInteger).
  // ArticleFullWidthImageCollectionViewCell: lead image, title, description, snippet.
  @Builder
  heroArticle(p: WMFFeedArticlePreview, showSave: boolean) {
    Column() {
      if (p.thumbnailURL !== null) {
        Image(p.thumbnailURL ?? '')
          .width('100%')
          .height(181)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('app.color.gray200'))
      }
      Text(p.displayTitle)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontFamily('serif')
        .fontColor($r('app.color.theme_text'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 14, left: 16, right: 16 })
      if ((p.wikidataDescription ?? '') !== '') {
        Text(p.wikidataDescription ?? '')
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2, left: 16, right: 16 })
      }
      if ((p.snippet ?? '') !== '') {
        Text(p.snippet ?? '')
          .fontSize(15)
          .lineHeight(19.5)
          .fontColor($r('app.color.theme_text'))
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 10, left: 16, right: 16 })
      }
      if (showSave) {
        this.saveForLaterButton(p)
      } else {
        Blank().height(14)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      // Tapping the card opens the article the card is showing (a new random article is
      // only the Random card's footer).
      this.openArticle(p);
    })
  }

  @Builder
  cardContent(item: ExploreCardItem) {
    if (item.group.contentGroupKindInteger === ContentGroupKind.FeaturedArticle) {
      // ArticleFullWidthImageExploreCollectionViewCell — large image + title + description + save.
      // Sizes taken from the source capture's own frames (results/traversal-source .../
      // explore_logo.ui.json, 402pt-wide screen): image 196pt on a 370pt-wide card (0.53
      // aspect -> 181vp here), article title box 23pt, description one line at 15pt, extract
      // 4 lines at ~19.5pt line height. The card measured 624vp instead of the source's 492pt,
      // which pushed the whole Top read card below the fold at scroll top.
      Column() {
        if (item.previews.length > 0) {
          if (item.previews[0].thumbnailURL !== null) {
            Image(item.previews[0].thumbnailURL ?? '')
              .width('100%')
              .height(181)
              .objectFit(ImageFit.Cover)
              .backgroundColor($r('app.color.gray200'))
          }
          Text(item.previews[0].displayTitle)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontFamily('serif')
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 14, left: 16, right: 16 })
          Text(item.previews[0].wikidataDescription ?? '')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 4, left: 16, right: 16 })
          // extract paragraph (WMFFeedArticlePreview.snippet <- JSON extract; capture shows
          // a 4-line snippet with ellipsis under the description)
          if (item.previews[0].snippet !== null) {
            Text(item.previews[0].snippet ?? '')
              .fontSize(16)
              .fontColor($r('app.color.theme_text'))
              .lineHeight(20)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 10, left: 16, right: 16 })
          }
          this.saveForLaterButton(item.previews[0])
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .id('Explore Article Cell')
      .onClick(() => {
        if (item.previews.length > 0) {
          this.openArticle(item.previews[0]);
        }
      })
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.TopRead) {
      Column() {
        ForEach(item.previews, (p: WMFFeedArticlePreview, index: number) => {
          RankedArticleCollectionViewCell({
            rank: index + 1,
            title: p.displayTitle,
            description: p.wikidataDescription ?? '',
            imageURL: p.thumbnailURL ?? '',
            onTap: (): void => {
              this.openArticle(p);
            }
          })
        }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
      }
      .width('100%')
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.PictureOfTheDay) {
      // ImageCollectionViewCell — full-bleed image with the caption over a dark scrim at its
      // foot. The card carried the photo alone, so the reader was given a picture of the day
      // with nothing saying what it was.
      Stack({ alignContent: Alignment.Bottom }) {
        if (item.potd !== null) {
          Image(item.potd?.imageThumbURL ?? '')
            .width('100%')
            .height(320)
            .objectFit(ImageFit.Cover)
            .backgroundColor($r('app.color.gray200'))
          if ((item.potd?.imageDescription ?? '') !== '') {
            Text(stripTags(item.potd?.imageDescription ?? ''))
              .id('potd_caption')
              .width('100%')
              .fontSize(14)
              .lineHeight(18)
              .fontColor(Color.White)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 16, right: 16, top: 10, bottom: 12 })
              .backgroundColor('#B3000000')
          }
        }
      }
      .width('100%')
      .height(320)
      .clip(true)
      .onClick(() => {
        this.openImageGallery(item.potd);
      })
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.OnThisDay) {
      Column() {
        ForEach(item.events, (e: WMFFeedOnThisDayEvent) => {
          OnThisDayCollectionViewCell({
            event: e,
            onSelectArticle: (articleTitle: string): void => {
              this.openArticleByTitle(articleTitle);
            },
            onTap: (): void => {
              this.openOnThisDay();
            }
          })
        }, (e: WMFFeedOnThisDayEvent, index: number) => String(e.year ?? 0) + '_' + index)
      }
      .width('100%')
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.News) {
      Column() {
        ForEach(item.newsStories, (s: WMFFeedNewsStory) => {
          NewsCollectionViewCell({
            story: s,
            onSelectArticle: (articleTitle: string): void => {
              this.openArticleByTitle(articleTitle);
            }
          })
        }, (s: WMFFeedNewsStory, index: number) => (s.storyHTML ?? '') + '_' + index)
      }
      .width('100%')
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.SuggestedEdits) {
      // SuggestedEditsExploreCell: "Add an image" over its explanation, photo.badge.plus trailing
      Row({ space: 16 }) {
        Column({ space: 5 }) {
          Text($r('app.string.explore_suggested_edits_image_recs_title'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_text'))
          Text($r('app.string.explore_suggested_edits_image_recs_body'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .layoutWeight(1)
        Image($r('app.media.photo_badge_plus'))
          .width(44)
          .height(44)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.theme_link'))
      }
      .id('explore_suggested_edits_cell')
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.openImageRecommendations(item.group.siteURLString ?? '');
      })
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.DailyGame) {
      // WMFDailyGameExploreCell (not started): calendar glyph + "Which came first?", the two
      // events of today's first question with their thumbnails, and a "Play today's game" link
      // button. Without preview events the card shows the game description instead.
      Column() {
        Row() {
          Image($r('app.media.settings_calendar'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.theme_text'))
            .objectFit(ImageFit.Contain)
          Text($r('app.string.games_wcf_explore_title'))
            .id('games_card_title')
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 6 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (item.gameOptions.length >= 2) {
          ForEach(item.gameOptions.slice(0, 2), (option: WhichCameFirstEvent, index: number) => {
            Row() {
              Text(option.text ?? '')
                .layoutWeight(1)
                .fontSize(15)
                .lineHeight(20)
                .fontColor($r('app.color.theme_text'))
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (option.thumbnailURL !== undefined) {
                Image(option.thumbnailURL)
                  .width(40)
                  .height(40)
                  .borderRadius(2)
                  .objectFit(ImageFit.Cover)
                  .margin({ left: 16 })
              }
            }
            .id('games_card_event_' + index)
            .width('100%')
            .constraintSize({ minHeight: 40 })
            .alignItems(VerticalAlign.Center)
            .margin({ top: index === 0 ? 12 : 16 })
          }, (option: WhichCameFirstEvent, index: number) => index + '_' + (option.text ?? ''))
        } else {
          Text($r('app.string.which_came_first_splash_subtitle'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 12 })
        }

        Text($r('app.string.games_wcf_button_play_title'))
          .id('games_card_play')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_link'))
          .padding({ top: 8, bottom: 8 })
          .margin({ top: 8 })
          .onClick(() => {
            this.openGamesSplash(item.group.siteURLString).catch((e: Error) => {
              console.error('explore: games splash failed: ' + e.message);
            });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openGamesSplash(item.group.siteURLString).catch((e: Error) => {
          console.error('explore: games splash failed: ' + e.message);
        });
      })
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.Random ||
      item.group.contentGroupKindInteger === ContentGroupKind.ContinueReading) {
      // WMFRandomContentSource's card is the FULL-WIDTH hero form
      // (ArticleFullWidthImageCollectionViewCell), same as Featured article - not the
      // right-aligned thumbnail row this port had it sharing with the generic kinds.
      // WMFFeedDisplayTypeContinueReading is the same hero, without the save button.
      if (item.previews.length > 0) {
        this.heroArticle(item.previews[0], item.group.contentGroupKindInteger === ContentGroupKind.Random)
      }
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.RelatedPages) {
      // WMFFeedDisplayTypeRelatedPagesSourceArticle first, then the related rows.
      Column() {
        if (item.previews.length > 0) {
          this.heroArticle(item.previews[0], false)
        }
        ForEach(item.previews.slice(1), (p: WMFFeedArticlePreview) => {
          ArticleRightAlignedImageCollectionViewCell({
            title: p.displayTitle,
            description: p.wikidataDescription ?? '',
            imageURL: p.thumbnailURL ?? '',
            onTap: (): void => {
              this.openArticle(p);
            }
          })
        }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
      }
      .width('100%')
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.Announcement) {
      ScrollableEducationPanelViewController({
        imageURL: item.announcement !== null ? (item.announcement?.imageURL ?? '') : '',
        heading: item.announcement !== null ? (item.announcement?.text ?? '') : '',
        subheading: '',
        primaryButtonTitle: item.announcement !== null ? (item.announcement?.actionTitle ?? '') : '',
        secondaryButtonTitle: item.announcement !== null ? (item.announcement?.negativeText ?? '') : '',
        footerText: item.announcement !== null ? (item.announcement?.captionHTML ?? '') : '',
        showCloseButton: false,
        onPrimary: (): void => {
          this.openAnnouncementAction(item.announcement);
        },
        onSecondary: (): void => {
          this.dismissCard(item.group.key ?? '');
        }
      })
    } else if (item.group.contentGroupKindInteger === ContentGroupKind.Location) {
      // ArticleLocationExploreCollectionViewCell: compass + round thumbnail (green W when the
      // place has none), description and the distance from where the card was fetched
      Column() {
        ForEach(item.previews, (p: WMFFeedArticlePreview) => {
          ArticleLocationCollectionViewCell({
            title: p.displayTitle,
            articleDescription: p.wikidataDescription ?? '',
            imageURL: p.thumbnailURL ?? '',
            distanceText: this.nearbyDistance(item.group, p),
            bearing: this.nearbyBearing(item.group, p)
          })
            .onClick((): void => {
              this.openArticle(p);
            })
        }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
      }
      .width('100%')
    } else {
      // page / relatedPages / continueReading / random — right-aligned rows
      Column() {
        ForEach(item.previews, (p: WMFFeedArticlePreview) => {
          ArticleRightAlignedImageCollectionViewCell({
            title: p.displayTitle,
            description: p.wikidataDescription ?? '',
            imageURL: p.thumbnailURL ?? '',
            onTap: (): void => {
              this.openArticle(p);
            }
          })
        }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      // navigation bar: W-logo button (left), Tabs and Profile buttons (right)
      Row() {
        Button() {
          Image($r('app.media.w'))
            .width(27)
            .height(18)
            .objectFit(ImageFit.Contain)
            // the logo PNG is black: in the dark themes it vanished into the button
            .colorFilter(new ColorFilter(this.isDark ? LIGHT_LOGO_FILTER : IDENTITY_LOGO_FILTER))
        }
        .id('explore_logo')
        .accessibilityText('Wikipedia, scroll to top of Explore')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          this.scroller.scrollEdge(Edge.Top);
        })
        Blank()
        Row({ space: NAV_BUTTON_GAP }) {
          Button() {
            Image($r('app.media.article_tabs_square'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.theme_text'))
          }
          .id('Tabs Button')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.openArticleTabs();
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
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.openProfile();
          })
        }
      }
      .width('100%')
      .height(ROOT_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      // bindContentCover lives HERE (nav bar Row), NOT on the root Column: the root already
      // carries bindSheet, and chaining both modal bindings on one node leaves the
      // bindContentCover dead on device (sheet opens, cover never mounts — pass-5 evidence).
      // A full-screen modal covers the window regardless of which node hosts it.
      .bindContentCover($$this.showCover, this.coverBuilder())

      // showOfflineEmptyViewIfNeeded: empty feed + unreachable -> .noFeed empty view,
      // otherwise the card list (never both).
      if (!this.isNetworkAvailable && this.contentGroups.length === 0) {
        Column() {
          Text('You can see your recommended articles when you have internet')
            .fontSize(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .textAlign(TextAlign.Center)
            .lineHeight(24)
            .padding({ left: 32, right: 32 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.isLoading && this.contentGroups.length === 0) {
        // feed loading visual — spinner while the first refresh is in flight (S6 task 2)
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.theme_secondary_text'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // explore feed card list — one ExploreCardViewController per WMFContentGroup
        // UIRefreshControl: pull down to fetch the feed again, with the system spinner
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            // The promo scrolls with the feed rather than pinning above it: pinned, it ate the
            // top third of every screen for as long as the reader stayed signed out.
            if (this.showSyncPromo) {
              // the cards' own 16vp side margins, so the banner lines up with them
              ListItem() {
                this.syncPromoBanner()
              }
              .padding({ left: 16, right: 16 })
            }
            LazyForEach(this.cardsSource, (item: ExploreCardItem) => {
              ListItem() {
                Column() {
                  // Day heading: the feed carries several calendar days and each block names
                  // its own ("Today", "Yesterday", a date). It scrolls with the cards, as the
                  // source's large title does; pinned above the list it ate the top of every
                  // screen and the cards slid under it.
                  if (item.dayHeader !== '') {
                    Text(item.dayHeader)
                      .id(item.dayKey === '0' ? 'explore_day_title' : 'explore_day_header_itemroot')
                      .fontSize(ROOT_TITLE_FONT_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.theme_text'))
                      .width('100%')
                      .padding({ left: 16, top: item.dayKey === '0' ? 2 : 16, bottom: 2 })
                  }
                  ExploreCardViewController({
                    group: item.group,
                    content: (): void => {
                      this.cardContent(item);
                    },
                    onFooterTap: (): void => {
                      this.openFooterForGroup(item.group);
                    },
                    onDismissCard: (groupKey: string): void => {
                      this.dismissCard(groupKey);
                    },
                    onHideAllCards: (kind: number, cardName: string): void => {
                      this.hideAllCards(kind, cardName);
                    },
                    onCustomizeFeed: (): void => {
                      this.openExploreFeedSettings();
                    }
                  })
                }
                .width('100%')
              }
              .id('explore_card_itemroot_' + item.dayKey + '_' + item.group.contentGroupKindInteger)
            }, (item: ExploreCardItem, index: number) => (item.group.key ?? String(item.group.contentGroupKindInteger)) + '_' + index + '_' + item.dayKey)
          }
          .layoutWeight(1)
          .width('100%')
          .cachedCount(4)
          .scrollBar(BarState.Off)
          // scrollViewDidScroll: past 80% of the feed, the day before the oldest one loads
          .onScrollIndex((start: number, end: number) => {
            if (end >= Math.floor(this.cardsSource.totalCount() * 0.8)) {
              this.loadOlderContent();
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .onRefreshing(() => {
          this.updateFeedSources(true);
        })
      }

      // reading-list toast (WMFReadingListToastManager) — floats above the tab bar
      this.readingListToastBuilder()

      // "Card hidden" undo bar (explore-feed-preferences-card-hidden-title)
      this.hiddenToastBuilder()

      // persistent root tab bar (UITabBarController) — Explore is tab 0
      RootTabBar({ selected: 0 })
    }
    .id('ExploreViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    // WMFProfileHostingController is presented as a near-full-height sheet (capture S0181:
    // the profile view starts 62pt below a 874pt screen); the page draws its own X close,
    // so the framework's close button and grabber stay off.
    .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(),
      { height: SheetSize.LARGE, dragBar: false, showClose: false })
  }

  private text(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res.id);
    } catch (e) {
      return '';
    }
  }

  private nearbyDistance(group: WMFContentGroup, p: WMFFeedArticlePreview): string {
    if (group.locationLatitude === null || group.locationLongitude === null || p.latitude === null ||
      p.longitude === null || p.latitude === undefined || p.longitude === undefined) {
      return this.text($r('app.string.places_unknown_distance'));
    }
    return distanceText(group.locationLatitude, group.locationLongitude, p.latitude, p.longitude);
  }

  private nearbyBearing(group: WMFContentGroup, p: WMFFeedArticlePreview): number {
    if (group.locationLatitude === null || group.locationLongitude === null || p.latitude === null ||
      p.longitude === null || p.latitude === undefined || p.longitude === undefined) {
      return 0;
    }
    return bearingDegrees(group.locationLatitude, group.locationLongitude, p.latitude, p.longitude);
  }

  private openArticle(p: WMFFeedArticlePreview): void {
    // the article page reads 'articleKey' (the URL) to open the card's own wiki; under the old
    // 'articleURL' name it was ignored and every card opened on the app language's wiki
    const params: Record<string, string> = {
      'articleTitle': p.displayTitle,
      'articleKey': p.articleURL
    };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  // detailViewControllerWithDataStore (.imageRecommendations)
  private openImageRecommendations(site: string): void {
    const host: string = site.replace('https://', '');
    router.pushUrl({ url: 'pages/WMFImageRecommendationsViewControllerPage',
      params: { 'host': host !== '' ? host : 'en.wikipedia.org' } });
  }

  private openArticleByTitle(articleTitle: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  // SaveButtonsController.saveButtonPressed — toggleSavedPage(forKey: databaseKey),
  // the databaseKey being the article URL.
  // Seed saved-state from the store so a second run's toggle still flips the label
  // (without this, an already-saved article un-saves with no visible change).
  private seedSavedKeys(items: ExploreCardItem[]): void {
    const keys: string[] = [];
    for (const item of items) {
      for (const p of item.previews) {
        keys.push(this.savedKeyOf(p));
      }
    }
    const found: string[] = [];
    let pending: number = keys.length;
    if (pending === 0) {
      return;
    }
    for (const k of keys) {
      SavedStore.isSaved(k).then((saved: boolean) => {
        if (saved) {
          found.push(k);
        }
        pending -= 1;
        if (pending === 0) {
          this.savedKeys = found;
        }
      }).catch(() => {
        pending -= 1;
        if (pending === 0) {
          this.savedKeys = found;
        }
      });
    }
  }

  private savedKeyOf(p: WMFFeedArticlePreview): string {
    return p.articleURL !== '' ? p.articleURL : p.displayTitle;
  }

  private isSavedPreview(p: WMFFeedArticlePreview): boolean {
    return this.savedKeys.indexOf(this.savedKeyOf(p)) >= 0;
  }

  // Taps that land while this article's save is still being written are dropped, so a burst
  // of taps cannot race two writes for the same key.
  private savingKeys: string[] = [];

  private saveForLater(p: WMFFeedArticlePreview): void {
    const articleKey: string = this.savedKeyOf(p);
    if (this.savingKeys.indexOf(articleKey) >= 0) {
      return;
    }
    this.savingKeys.push(articleKey);
    // the button flips on tap; the stored state follows and puts it back if the write fails
    const wasSaved: boolean = this.savedKeys.indexOf(articleKey) >= 0;
    this.setSavedKey(articleKey, !wasSaved);
    SavedStore.toggleSave(articleKey, null, p.displayTitle).finally(() => {
      this.savingKeys = this.savingKeys.filter((k: string) => k !== articleKey);
    }).then((saved: boolean) => {
      this.setSavedKey(articleKey, saved);
      // WMFReadingListToastManager.toggle: didSave -> showDefaultToast, else dismiss.
      if (saved) {
        this.readingListToastKey = articleKey;
        this.readingListToastArticle = p.displayTitle;
        this.showReadingListToast(p.displayTitle);
      } else {
        this.dismissReadingListToast();
      }
    }).catch((e: Error) => {
      this.setSavedKey(articleKey, wasSaved);
      console.error('[explore-save] toggleSave failed: ' + e.message);
    });
  }

  // replace the array so @State notifies (member mutation would not re-render)
  private setSavedKey(articleKey: string, saved: boolean): void {
    const next: string[] = this.savedKeys.filter((k: string) => k !== articleKey);
    if (saved) {
      next.push(articleKey);
    }
    this.savedKeys = next;
  }

  // WMFReadingListToastManager.toastButtonTitle(for:): the saved article's display title,
  // falling back to the generic hint when it has none.
  private readingListToastText(articleTitle: string): string {
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    try {
      if (articleTitle.trim() === '') {
        return rm.getStringSync($r('app.string.reading_list_add_generic_hint_title').id);
      }
      // formatString, not .replace('$1'): the catalogue escapes it as \$1, and a plain
      // replace left the backslash on screen ('Add "\Santa Teresa..."').
      return formatString(getContext(this), $r('app.string.reading_list_add_hint_title'), [articleTitle]);
    } catch (e) {
      const err = e as BusinessError;
      console.error('[explore-save] hint string failed: ' + err.message);
      return '';
    }
  }

  private showReadingListToast(articleTitle: string): void {
    const text: string = this.readingListToastText(articleTitle);
    if (text === '') {
      return;
    }
    if (this.readingListToastTimer !== -1) {
      clearTimeout(this.readingListToastTimer);
    }
    this.readingListToastTitle = text;
    // WMFReadingListToastConfig(duration: 13)
    this.readingListToastTimer = setTimeout(() => {
      this.readingListToastTitle = '';
      this.readingListToastTimer = -1;
    }, 13000);
  }

  private dismissReadingListToast(): void {
    if (this.readingListToastTimer !== -1) {
      clearTimeout(this.readingListToastTimer);
      this.readingListToastTimer = -1;
    }
    this.readingListToastTitle = '';
  }

  // Returning from Explore feed settings has to re-read the card preferences: the feed is
  // filtered by them now, so a card switched off there must be gone on the way back.
  onPageShow(): void {
    this.onHostShow();
  }

  // pages/Index owns the route; it bumps showTick when it comes back on screen.
  onHostShow(): void {
    this.isOpeningRandom = false;
    this.loadFeed();
    this.refreshSyncPromo();
    // the profile buttons' unread dot (the source's background notifications sync)
    NotificationsService.refreshUnreadCount();
  }

  aboutToDisappear(): void {
    this.dismissReadingListToast();
    this.dismissHiddenToast();
  }

  private dismissCard(groupKey: string): void {
    if (groupKey === '') {
      return;
    }
    FeedStore.markDismissed(groupKey).then(() => {
      this.undoGroupKey = groupKey;
      this.undoKind = -1;
      this.presentHiddenToast($r('app.string.explore_card_hidden_toast'));
      this.loadFeed();
    });
  }

  // "Hide all \"<card>\" cards" — the feed preference for the whole kind, undoable the same
  // way the single hide is.
  private hideAllCards(kind: number, cardName: string): void {
    // ExploreFeedPreferencesUpdateCoordinator: hiding the last card type left on the feed
    // would empty it, so the source asks first and turns the Explore tab off instead.
    const othersOn: boolean = FEED_CARD_KINDS.some((k: number) => k !== kind && isCardInFeed(k));
    if (!othersOn) {
      // stacked buttons: side by side, "Keşfet akışını kapat" was cut to "Keşfet ..."
      this.getUIContext().showAlertDialog({
        title: $r('app.string.explore_feed_preferences_turn_off_explore_feed_alert_title'),
        message: $r('app.string.explore_feed_preferences_turn_off_explore_feed_alert_message'),
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          {
            value: $r('app.string.explore_feed_preferences_turn_off_explore_feed_alert_action_title'),
            fontColor: $r('app.color.theme_destructive'),
            action: (): void => {
              setCardInFeed(kind, false);
              Prefs.putNumber(PrefKeys.defaultTabType, DEFAULT_TAB_TYPE_SETTINGS);
              // pages/Index hosts slot 0; rebuilding it swaps Explore for the Settings tab
              router.replaceUrl({ url: 'pages/Index' });
            }
          },
          {
            value: $r('app.string.action_cancel'),
            action: (): void => {
            }
          }
        ]
      });
      return;
    }
    setCardInFeed(kind, false);
    this.undoGroupKey = '';
    this.undoKind = kind;
    // Names the kind, as the source's toast does: "All \"Top read\" cards hidden".
    this.presentHiddenToast($r('app.string.explore_all_cards_hidden_toast', cardName));
    this.loadFeed();
  }

  private openExploreFeedSettings(): void {
    router.pushUrl({ url: 'pages/ExploreFeedSettingsViewControllerPage' }).catch((e: Error) => {
      console.error('explore: feed settings route failed: ' + e.message);
    });
  }

  private presentHiddenToast(title: ResourceStr): void {
    if (this.hiddenToastTimer !== -1) {
      clearTimeout(this.hiddenToastTimer);
    }
    this.hiddenToastTitle = title;
    this.hiddenToastTimer = setTimeout(() => {
      this.hiddenToastTitle = '';
      this.hiddenToastTimer = -1;
    }, 8000);
  }

  private dismissHiddenToast(): void {
    if (this.hiddenToastTimer !== -1) {
      clearTimeout(this.hiddenToastTimer);
      this.hiddenToastTimer = -1;
    }
    this.hiddenToastTitle = '';
  }

  // Undo restores exactly what the hide changed, then reloads so the card returns to its
  // original position (the feed is ordered by the stored groups, not by hide order).
  private undoHide(): void {
    const key: string = this.undoGroupKey;
    const kind: number = this.undoKind;
    this.dismissHiddenToast();
    if (kind >= 0) {
      setCardInFeed(kind, true);
      this.undoKind = -1;
      this.loadFeed();
      return;
    }
    if (key === '') {
      return;
    }
    this.undoGroupKey = '';
    FeedStore.markUndismissed(key).then(() => {
      this.loadFeed();
    }).catch((e: Error) => {
      console.error('explore: undo hide failed: ' + e.message);
    });
  }

  private openAnnouncementAction(announcement: WMFAnnouncement | null): void {
    if (announcement === null) {
      return;
    }
    const actionURL: string = announcement.actionURLString ?? '';
    if (actionURL === '') {
      return;
    }
    const params: Record<string, string> = { 'url': actionURL };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private openFooterForGroup(group: WMFContentGroup): void {
    // footer routes per card kind (TopRead -> article list, OnThisDay, News, Random)
    if (group.contentGroupKindInteger === ContentGroupKind.SuggestedEdits) {
      this.openImageRecommendations(group.siteURLString ?? '');
    } else if (group.contentGroupKindInteger === ContentGroupKind.DailyGame) {
      this.openGamesSplash(group.siteURLString).catch((e: Error) => {
        console.error('explore: games splash failed: ' + e.message);
      });
    } else if (group.contentGroupKindInteger === ContentGroupKind.OnThisDay) {
      this.openOnThisDay();
    } else if (group.contentGroupKindInteger === ContentGroupKind.News) {
      this.openNews();
    } else if (group.contentGroupKindInteger === ContentGroupKind.Random) {
      this.openRandomArticle();
    } else if (group.contentGroupKindInteger === ContentGroupKind.Location) {
      // "More places near your location" -> the Places tab
      router.pushUrl({ url: 'pages/PlacesViewControllerPage' });
    } else if (group.contentGroupKindInteger === ContentGroupKind.RelatedPages) {
      // moreLikeTitle: "More like <the article read>"
      const title: string = this.titleOfKey(group.articleURLString ?? '');
      router.pushUrl({ url: 'pages/ArticleURLListViewControllerPage', params: {
        'contentGroupKey': group.key ?? '',
        'listTitle': formatString(getContext(this) as common.Context, $r('app.string.home_more_like_footer'), [title])
      } as Record<string, string> });
    } else {
      // the tapped card's own day and wiki, not whichever Top read group is newest
      router.pushUrl({ url: 'pages/ArticleURLListViewControllerPage',
        params: { 'contentGroupKey': group.key ?? '' } as Record<string, string> });
    }
  }

  private openNews(): void {
    router.pushUrl({ url: 'pages/NewsViewControllerPage' });
  }

  private openOnThisDay(): void {
    router.pushUrl({ url: 'pages/OnThisDayViewControllerPage' });
  }

  // Rapid taps on "Another random article" each pushed their own page, so the reader ended
  // up several screens deep on the way back. The latch clears when the feed is shown again.
  private openRandomArticle(): void {
    if (this.isOpeningRandom) {
      return;
    }
    this.isOpeningRandom = true;
    router.pushUrl({ url: 'pages/RandomArticleViewControllerPage' }).catch((e: Error) => {
      console.error('explore: random route failed: ' + e.message);
      this.isOpeningRandom = false;
    });
  }

  private openProfile(): void {
    this.showProfileSheet = true;
  }

  private openArticleTabs(): void {
    router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
      console.error('article tabs push failed: ' + e.message);
    });
  }

  private openCover(kind: string): void {
    this.activeCover = kind;
    this.showCover = true;
  }


  // WMFGamesDataController.fetchWhichCameFirstDailyPreviewEvents: the card previews the two
  // events of today's first question — from the day's session once one exists, otherwise
  // generated the same way the game will generate it. Empty when neither is available; the
  // card then shows its description instead.
  private async dailyGamePreview(host: string, languageCode: string): Promise<WhichCameFirstEvent[]> {
    const now = new Date();
    const date: string = now.toISOString().substring(0, 10);
    try {
      let first: WhichCameFirstQuestion | undefined = undefined;
      const session: CDGameSession | null =
        await GameStore.fetchSession(WHICH_CAME_FIRST_GAME_TYPE, 'wikipedia.' + languageCode, date);
      if (session !== null) {
        const state: WhichCameFirstGameState = JSON.parse(session.contentData) as WhichCameFirstGameState;
        first = (state.questions ?? [])[0];
      } else {
        const events: WMFFeedOnThisDayEvent[] = await FeedService.fetchOnThisDayEvents(host, languageCode,
          now.getMonth() + 1, now.getDate());
        first = makeWhichCameFirstQuestions(events, now.getMonth() + 1, now.getDate(),
          now.getFullYear(), 1)[0];
      }
      if (first !== undefined && first.optionA !== undefined && first.optionB !== undefined) {
        return [first.optionA, first.optionB];
      }
    } catch (e) {
      console.error('explore: daily game preview unavailable: ' + this.describeError(e));
    }
    return [];
  }

  // WhichCameFirstCoordinator.makeSplashViewController: entering the daily game raises the
  // splash, which is marked seen as soon as it is displayed (never shown twice).
  // WhichCameFirstCoordinator takes the card's siteURL: each language's card plays that
  // language's game.
  private async openGamesSplash(site: string | null): Promise<void> {
    // Repeated taps while the splash is coming up must open it once.
    if (Date.now() - this.gamesOpenedAt < 1000) {
      return;
    }
    this.gamesOpenedAt = Date.now();
    const code: string = site !== null && site !== ''
      ? site.replace('https://', '').split('.')[0]
      : (await LanguageStore.appLanguage()).languageCode;
    GameStore.markAnnouncementSeen();
    // a routed page (as the article's invitation already is): a full-screen cover drew the
    // game blue off-colour and tore down the splash's navigation bar
    const params: Record<string, string> = { 'languageCode': code };
    router.pushUrl({ url: 'pages/WMFGamesSplashScreenViewControllerPage', params: params });
  }


  // Tapping the POTD card opens the gallery on that image; its description and license
  // come from Commons imageinfo, with the feed's own copy as the offline fallback.
  private openImageGallery(potd: WMFFeedImage | null): void {
    if (potd === null) {
      return;
    }
    const params: Record<string, string> = {
      'fileTitle': potd.canonicalPageTitle,
      'fallbackImageURL': potd.imageURL !== '' ? potd.imageURL : potd.imageThumbURL,
      'fallbackDescription': potd.imageDescription ?? ''
    };
    router.pushUrl({ url: 'pages/WMFImageGalleryViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('explore: image gallery route failed: ' + e.message);
      });
  }


}
