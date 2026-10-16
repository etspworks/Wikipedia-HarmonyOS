// svc_prefs — key-value settings over @kit.ArkData preferences.
// Ported NSUserDefaults keys from Wikipedia/Code/NSUserDefaults+WMFExtensions.swift and
// WMFData/Sources/WMFData/Store/WMFUserDefaultsKey.swift.

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

// --- Keys from NSUserDefaults+WMFExtensions.swift ---
// the Syntax Highlighting switch, mirrored where the open editor watches it
export const SYNTAX_HIGHLIGHTING_KEY: string = 'wmfSyntaxHighlighting';

export class PrefKeys {
  static readonly appResignActiveDate: string = 'WMFAppResignActiveDateKey';
  static readonly shouldRestoreNavigationStackOnResume: string = 'WMFShouldRestoreNavigationStackOnResume';
  static readonly appSite: string = 'Domain';
  static readonly searchURL: string = 'WMFSearchURLKey';
  static readonly feedRefreshDate: string = 'WMFFeedRefreshDateKey';
  static readonly locationAuthorized: string = 'WMFLocationAuthorizedKey';
  static readonly placesDidPromptForLocationAuthorization: string = 'WMFPlacesDidPromptForLocationAuthorization';
  static readonly exploreDidPromptForLocationAuthorization: string = 'WMFExploreDidPromptForLocationAuthorization';
  static readonly placesHasAppeared: string = 'WMFPlacesHasAppeared';
  static readonly appThemeName: string = 'WMFAppThemeName';
  // NSUserDefaults+WMFExtensions.swift: UserDefaults.Key.defaultTabType —
  // WMFAppDefaultTabType.explore = 0, .settings = 1. Turning the Explore tab off swaps the
  // first root tab for Settings, so the tab bar and the app frame both read this.
  static readonly defaultTabType: string = 'WMFDefaultTabTypeKey';
  static readonly isImageDimmingEnabled: string = 'WMFIsImageDimmingEnabled';
  static readonly isAutomaticTableOpeningEnabled: string = 'WMFIsAutomaticTableOpeningEnabled';
  static readonly didShowThemeCardInFeed: string = 'WMFDidShowThemeCardInFeed';
  static readonly didShowReadingListCardInFeed: string = 'WMFDidShowReadingListCardInFeed';
  static readonly didShowEnableReadingListSyncPanel: string = 'WMFDidShowEnableReadingListSyncPanelKey';
  static readonly didShowLoginToSyncSavedArticlesToReadingListPanel: string = 'WMFDidShowLoginToSyncSavedArticlesToReadingListPanelKey';
  static readonly didShowThankRevisionAuthorEducationPanel: string = 'WMFDidShowThankRevisionAuthorEducationPanelKey';
  static readonly didShowLimitHitForUnsortedArticlesPanel: string = 'WMFDidShowLimitHitForUnsortedArticlesPanel';
  static readonly didShowSyncDisabledPanel: string = 'WMFDidShowSyncDisabledPanel';
  static readonly didShowSyncEnabledPanel: string = 'WMFDidShowSyncEnabledPanel';
  static readonly didSplitExistingReadingLists: string = 'WMFDidSplitExistingReadingLists';
  static readonly didShowTitleDescriptionEditingIntro: string = 'WMFDidShowTitleDescriptionEditingIntro';
  static readonly didShowFirstEditPublishedPanel: string = 'WMFDidShowFirstEditPublishedPanelKey';
  static readonly isSyntaxHighlightingEnabled: string = 'WMFIsSyntaxHighlightingEnabled';
  static readonly searchLanguage: string = 'WMFSearchLanguageKey';
  // MoreLanguagesTip.invalidate(reason: .tipClosed) — TipKit keeps this in its own store
  static readonly didCloseMoreLanguagesTip: string = 'WMFDidCloseMoreLanguagesTip';
  // WTip.invalidate(reason: .tipClosed / .actionPerformed) — TipKit keeps this in its own store
  static readonly didInvalidateWTip: string = 'WMFDidInvalidateWTip';
  static readonly appInstallId: string = 'WMFAppInstallId';
  static readonly sendUsageReports: string = 'WMFSendUsageReports';
  static readonly showNotificationsExploreFeedCard: string = 'WMFShowNotificationsExploreFeedCard';
  static readonly userHasOnboardedToNotificationsCenter: string = 'WMFUserHasOnboardedToNotificationsCenter';
  static readonly userHasOnboardedToContributingToTalkPages: string = 'WMFUserHasOnboardedToContributingToTalkPages';
  static readonly userHasOnboardedToWatchlists: string = 'WMFUserHasOnboardedToWatchlists';
  static readonly didShowNotificationsCenterPushOptInPanel: string = 'WMFDidShowNotificationsCenterPushOptInPanel';
  static readonly didShowSearchWidgetFeatureAnnouncement: string = 'WMFDidShowSearchWidgetFeatureAnnouncementKey';
  static readonly subscribedToEchoNotifications: string = 'WMFSubscribedToEchoNotifications';
  static readonly tappedToImportSharedReadingListSurvey: string = 'WMFTappedToImportSharedReadingListSurvey';
  static readonly alwaysDisplayEditNotices: string = 'WMFAlwaysDisplayEditNotices';
  static readonly sessionBackgroundDate: string = 'WMFSessionBackgroundDate';
  static readonly sessionStartDate: string = 'WMFSessionStartDate';
  static readonly yearToSessionSecondsMapping: string = 'WMFYearToSessionSecondsMapping';
}

// --- Keys from WMFUserDefaultsKey.swift (WMFData) ---
export class WMFDataPrefKeys {
  // Developer Settings > Force email auth (WMFUserDefaultsKey.forceEmailAuth)
  static readonly forceEmailAuth: string = 'force-email-auth';
  static readonly watchlistFilterSettings: string = 'watchlist-filter-settings';
  static readonly imageRecommendationsOnboarding: string = 'image-recommendations-onboarding';
  static readonly hasLocallySavedDonations: string = 'donate-history-has-locally-saved-donations';
  static readonly yearInReviewSettingsIsEnabled: string = 'year-in-review-settings-is-enabled-v3';
  static readonly seenYearInReviewFeatureAnnouncement: string = 'year-in-review-feature-announcement-v3';
  static readonly seenYearInReviewIntroSlide: string = 'seen-year-in-review-intro-slide-v3';
  static readonly tappedYIR: string = 'tapped-yir';
  static readonly articleTabRestoration: string = 'article-tab-restoration';
  // WMFAppViewController.shouldShowWelcome / didShowWelcome: the four-page welcome
  // onboarding is presented once, on the first launch that reaches Explore.
  static readonly didShowWelcomeOnboarding: string = 'did-show-welcome-onboarding';
  static readonly articleTabsOverviewOpenedCount: string = 'article-tabs-overview-opened-count';
  static readonly articleTabsDidTapOpenInNewTab: string = 'article-tabs-did-tap-open-in-new-tab';
  static readonly hasSeenActivityTab: string = 'has-seen-activity-tab';
  static readonly activityTabVisitCount: string = 'activity-tab-visit-count';
  static readonly autoSignTalkPageDiscussions: string = 'auto-sign-talk-page-discussions';
  static readonly showSearchLanguageBar: string = 'show-search-language-bar';
  static readonly openAppOnSearchTab: string = 'open-app-on-search-tab';
  static readonly isSubscribedToEchoNotifications: string = 'is-subscribed-to-echo-notifications';
  static readonly hasSeenGamesAnnouncement: string = 'has-seen-games-announcement';
  // WMFReadingListsSyncPromoView — the sign-in-to-sync banner over the Explore feed, shown
  // until the reader either signs in or dismisses it.
  static readonly didDismissReadingListSyncPromo: string = 'did-dismiss-reading-list-sync-promo';
  static readonly needsDailyGameFeedRefresh: string = 'needs-daily-game-feed-refresh';
  static readonly appInstallID: string = 'wmf-app-install-id';
  static readonly sessionID: string = 'wmf-session-id';
  static readonly homeSelectedLanguage: string = 'home-selected-language-code';
  static readonly homeFeedSeeFirst: string = 'home-feed-see-first';
  static readonly homeFeedInterestTopics: string = 'home-feed-interest-topics';
  static readonly homeFeedHiddenCardKeys: string = 'home-feed-hidden-card-keys';
  static readonly allowGestureZoomArticleWebview: string = 'allow-gesture-zoom-article-webview';
  static readonly defaultEditMode: string = 'default-edit-mode';
  // WMFActivityTabCustomizeView's four insight toggles. Each is per-account: the sheet
  // refuses to switch one on while signed out.
  static readonly activityTabTimeSpentReading: string = 'activity-tab-time-spent-reading';
  static readonly activityTabReadingInsights: string = 'activity-tab-reading-insights';
  static readonly activityTabEditingInsights: string = 'activity-tab-editing-insights';
  static readonly activityTabTimelineOfBehavior: string = 'activity-tab-timeline-of-behavior';
}

const STORE_NAME: string = 'wmf_prefs';

export class Prefs {
  private static store: preferences.Preferences | null = null;

  static init(context: common.Context): void {
    if (Prefs.store === null) {
      const options: preferences.Options = { name: STORE_NAME };
      Prefs.store = preferences.getPreferencesSync(context, options);
    }
  }

  private static requireStore(): preferences.Preferences {
    const store = Prefs.store;
    if (store === null) {
      throw new Error('Prefs.init(context) must be called before use');
    }
    return store;
  }

  // Export User Data: every preference as JSON, without the given keys (the login session)
  static exportJSON(excludedKeys: string[]): string {
    const all: Object = Prefs.requireStore().getAllSync();
    const out: Record<string, Object> = {};
    for (const entry of Object.entries(all)) {
      if (excludedKeys.indexOf(entry[0]) < 0) {
        out[entry[0]] = entry[1] as Object;
      }
    }
    return JSON.stringify(out, null, 2);
  }

  static getString(key: string, defValue: string): string {
    return Prefs.requireStore().getSync(key, defValue) as string;
  }

  static getNumber(key: string, defValue: number): number {
    return Prefs.requireStore().getSync(key, defValue) as number;
  }

  static getBoolean(key: string, defValue: boolean): boolean {
    return Prefs.requireStore().getSync(key, defValue) as boolean;
  }

  // A preferences write is not durable until flush() — always flush after putSync.
  static putString(key: string, value: string): void {
    const store = Prefs.requireStore();
    store.putSync(key, value);
    store.flush();
  }

  static putNumber(key: string, value: number): void {
    const store = Prefs.requireStore();
    store.putSync(key, value);
    store.flush();
  }

  static putBoolean(key: string, value: boolean): void {
    const store = Prefs.requireStore();
    store.putSync(key, value);
    store.flush();
  }

  static remove(key: string): void {
    const store = Prefs.requireStore();
    store.deleteSync(key);
    store.flush();
  }
}

// WMFExploreFeedPreferences — one flag per WMFContentGroupKind, seeded ON
// (defaultExploreFeedPreferences). The key was duplicated in the two settings screens while
// the feed itself never consulted it, so switching a card off changed nothing on Explore and
// the card overflow sheet had nowhere to write "Hide all ... cards" to. One owner now.
const EXPLORE_FEED_PREFERENCES_KEY: string = 'WMFExploreFeedPreferencesKey';

export function exploreFeedCardKey(kind: number): string {
  return EXPLORE_FEED_PREFERENCES_KEY + '.' + kind.toString();
}

export function isCardInFeed(kind: number): boolean {
  return Prefs.getBoolean(exploreFeedCardKey(kind), true);
}

export function setCardInFeed(kind: number, isOn: boolean): void {
  Prefs.putBoolean(exploreFeedCardKey(kind), isOn);
}

// FeedCardSettingsViewController's language rows: one card kind switched off for one
// language only (WMFExploreFeedPreferences keeps a per-site set of kinds).
export function exploreFeedCardLanguageKey(kind: number, code: string): string {
  return exploreFeedCardKey(kind) + '.' + code;
}

export function isCardLanguageInFeed(kind: number, code: string): boolean {
  return Prefs.getBoolean(exploreFeedCardLanguageKey(kind, code), true);
}

// WMFExploreFeedPreferences keys a language-specific card by kind AND content language, and
// keeps the global (non-language-specific) kinds under their own flag. The languages section
// of screen_explore_feed_settings writes these; the feed reads them.
export function exploreFeedLanguageKey(code: string): string {
  return EXPLORE_FEED_PREFERENCES_KEY + '.lang.' + code;
}

const EXPLORE_FEED_GLOBAL_KEY: string = EXPLORE_FEED_PREFERENCES_KEY + '.globalCards';

// WMFContentGroupKind.isGlobal — the kinds that carry no language.
const GLOBAL_KINDS: number[] = [1, 3, 5, 16];   // ContinueReading, RelatedPages, PictureOfTheDay, SuggestedEdits

export function isGlobalKind(kind: number): boolean {
  return GLOBAL_KINDS.indexOf(kind) >= 0;
}

export function isLanguageInFeed(code: string): boolean {
  return Prefs.getBoolean(exploreFeedLanguageKey(code), true);
}

export function setLanguageInFeed(code: string, isOn: boolean): void {
  Prefs.putBoolean(exploreFeedLanguageKey(code), isOn);
}

export function isGlobalCardsInFeed(): boolean {
  return Prefs.getBoolean(EXPLORE_FEED_GLOBAL_KEY, true);
}

export function setGlobalCardsInFeed(isOn: boolean): void {
  Prefs.putBoolean(EXPLORE_FEED_GLOBAL_KEY, isOn);
}
