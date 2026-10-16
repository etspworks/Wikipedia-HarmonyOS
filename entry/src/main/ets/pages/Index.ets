// screen_root_tab_bar — the app frame. Source: WMFAppViewController (UITabBarController),
// Wikipedia/Code/WMFAppViewController.swift.
// Holds the five root children in source order (setViewControllers([nav1..nav5])):
// Explore(main=0), Places(1), Saved(2), Activity(3), Search(4); default selectedIndex =
// WMFAppTabType.main (Explore, 0).
// Index does NOT render its own RootTabBar — each root page renders the bar, so a second
// one here would duplicate the tab ids and break the control matcher.
// S4: launch-tab routing only. Source setViewControllers(...) tail:
//   shouldOpenAppOnSearchTab() -> selectedIndex = .search, else .main.
// The source keeps NO persisted last-selected tab (no UserDefaults write of selectedIndex),
// so nothing is persisted here either.
// Re-select behavior (shouldSelect: tapping the ACTIVE tab scrolls Explore to top /
// focuses the search bar) lives on the tab bar, which Index does not render — it belongs
// to comp_root_tab_bar (owned by screen_explore).
import common from '@ohos.app.ability.common';
import { Prefs, PrefKeys, WMFDataPrefKeys } from '../common/Prefs';
import { ENTRIES_LIMIT_REACHED_LIST_KEY } from '../common/ReadingListSyncService';
import { ExploreViewControllerPage } from './ExploreViewControllerPage';
import { SettingsTabViewControllerPage } from './SettingsTabViewControllerPage';
import { PlacesViewControllerPage } from './PlacesViewControllerPage';
import { SavedViewControllerPage } from './SavedViewControllerPage';
import { WMFActivityTabViewControllerPage } from './WMFActivityTabViewControllerPage';
import { SearchViewControllerPage } from './SearchViewControllerPage';
import { isExploreTabEnabled, isRootTabSwitch } from '../components/RootTabBar';
import { LAUNCH_INTENT_KEY, LaunchIntent } from '../entryability/RouteTable';
import { TabsStore, ArticleTab } from '../common/TabsStore';
import { AuthService } from '../common/AuthService';
import { SessionStore } from '../common/SessionStore';
import { WMFCurrentUser, WMFCurrentUserAuthState } from '../model/WMFCurrentUser';

import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';

// WMFAppViewController kTemporaryAccountAlertShownKey
const TEMPORARY_ACCOUNT_ALERT_SHOWN_KEY: string = 'TemporaryAccountAlertShown';

@Entry
@Component
struct Index {
  // UITabBarController.selectedIndex — source default WMFAppTabType.main (Explore, 0)
  @State selectedTab: number = 0;
  @State showTempAccountToast: boolean = false;
  @StorageLink(ENTRIES_LIMIT_REACHED_LIST_KEY) @Watch('entriesLimitReached') limitReachedListRowId: number = 0;
  // defaultTabType: turning the Explore tab off replaces slot 0 with the Settings tab.
  @State exploreTabEnabled: boolean = true;

  // WMFAppViewController.shouldOpenAppOnSearchTab() — UserDefaults openAppOnSearchTab
  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const openOnSearch: boolean = Prefs.getBoolean(WMFDataPrefKeys.openAppOnSearchTab, false);
    if (openOnSearch) {
      this.selectedTab = 4;
    }
    this.exploreTabEnabled = isExploreTabEnabled();
    // resumeApp: a link or quick action wins; otherwise the article the reader left
    // (shouldRestoreNavigationStackOnResume, which the source turns off with Open on Search).
    if (!this.applyLaunchIntent() && !openOnSearch) {
      this.restoreLastArticle();
    }
    this.showLoggedOutPanelIfNeeded();
    this.showTemporaryAccountAlertIfNeeded();
  }

  // entriesLimitReachedWithNotification -> ReadingListsAlertController
  // .showLimitHitForDefaultListPanelIfNecessary: once, "Limit hit for unsorted articles" with
  // Sort articles (the Saved list) and Cancel.
  entriesLimitReached(): void {
    if (this.limitReachedListRowId === 0 || Prefs.getBoolean(PrefKeys.didShowLimitHitForUnsortedArticlesPanel, false)) {
      return;
    }
    const listRowId: number = this.limitReachedListRowId;
    this.getUIContext().showAlertDialog({
      title: $r('app.string.reading_list_limit_hit_for_unsorted_articles_title'),
      message: $r('app.string.reading_list_limit_hit_for_unsorted_articles_subtitle'),
      autoCancel: false,
      buttons: [
        { value: $r('app.string.cancel'), action: () => {} },
        { value: $r('app.string.reading_list_limit_hit_for_unsorted_articles_button_title'), action: () => {
          const params: Record<string, string> = { 'listRowId': String(listRowId) };
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ReadingListDetailViewControllerPage', params: params });
        } }
      ]
    });
    Prefs.putBoolean(PrefKeys.didShowLimitHitForUnsortedArticlesPanel, true);
  }

  // resumeApp: once per temporary account, a 10-second toast "You are using a temporary
  // account. Account will expire in 90 days." whose tap opens TempAccountExpiryViewController.
  private showTemporaryAccountAlertIfNeeded(): void {
    const user: WMFCurrentUser | null = SessionStore.currentUser.value;
    if (user === null || user.authState !== WMFCurrentUserAuthState.temporary ||
      Prefs.getBoolean(TEMPORARY_ACCOUNT_ALERT_SHOWN_KEY, false)) {
      return;
    }
    this.showTempAccountToast = true;
    Prefs.putBoolean(TEMPORARY_ACCOUNT_ALERT_SHOWN_KEY, true);
    setTimeout(() => {
      this.showTempAccountToast = false;
    }, 10000);
  }

  // finishResumingApp -> showLoggedOutPanelIfNeeded: the stored session is checked, and a
  // logout the reader did not ask for gets "You have been logged out" with Log back in /
  // Continue without logging in.
  private showLoggedOutPanelIfNeeded(): void {
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) =>
      AuthService.checkStoredSession(lang.languageCode + '.wikipedia.org')
    ).then(() => {
      if (!AuthService.isUserUnawareOfLogout) {
        return;
      }
      this.getUIContext().showAlertDialog({
        title: $r('app.string.logged_out_title'),
        message: $r('app.string.logged_out_subtitle'),
        autoCancel: false,
        buttonDirection: DialogButtonDirection.VERTICAL,
        buttons: [
          { value: $r('app.string.logged_out_log_back_in_button_title'), action: () => {
            AuthService.userDidAcknowledgeUnintentionalLogout();
            this.getUIContext().getRouter().pushUrl({ url: 'pages/WMFLoginViewControllerPage' });
          } },
          { value: $r('app.string.logged_out_continue_without_logging_in_button_title'), action: () => {
            AuthService.userDidAcknowledgeUnintentionalLogout();
          } }
        ]
      });
    }).catch((e: Error) => {
      console.error('index: session check failed: ' + e.message);
    });
  }

  private applyLaunchIntent(): boolean {
    const raw: string = AppStorage.get<string>(LAUNCH_INTENT_KEY) ?? '';
    if (raw === '') {
      return false;
    }
    AppStorage.setOrCreate<string>(LAUNCH_INTENT_KEY, '');
    const intent: LaunchIntent = JSON.parse(raw) as LaunchIntent;
    if (intent.route.length === 0) {
      this.selectedTab = intent.tab;
    } else {
      this.pushAfterAppear(intent.route, intent.params);
    }
    return true;
  }

  // NavigationStateController.restoreLastArticle: push the top article of the current tab,
  // then forget it, so the next launch starts from the tab root again.
  private restoreLastArticle(): void {
    const tab: ArticleTab | null = TabsStore.loadCurrentStateForRestoration();
    if (tab === null || tab.articles.length === 0) {
      return;
    }
    const article = tab.articles[tab.articles.length - 1];
    TabsStore.clearCurrentStateForRestoration();
    if (article.title === '') {
      return;
    }
    // WMFProject.id "wikipedia~<lang>" (the default tab is seeded as "wikipedia.<lang>")
    const parts: string[] = article.projectID.split(/[~.]/);
    this.pushAfterAppear('pages/ArticleViewControllerPage', {
      'articleTitle': article.title,
      'languageCode': parts.length > 1 ? parts[1] : '',
      // NavigationStateController: isRestoringState, back to the reading position
      'restoreScroll': 'true'
    });
  }

  private pushAfterAppear(url: string, params: Record<string, string>): void {
    setTimeout(() => {
      this.getUIContext().getRouter().pushUrl({ url: url, params: params }).catch((e: Error) => {
        console.error('index: launch route failed: ' + e.message);
      });
    }, 0);
  }

  // Bumped whenever this page comes back on screen; Explore watches it.
  @State showTick: number = 0;

  // Coming back from Settings, where the preference may have just been flipped.
  onPageShow(): void {
    this.exploreTabEnabled = isExploreTabEnabled();
    // Explore rides inside this page rather than being routed, so its own onPageShow never
    // fires: returning from the feed settings left the feed exactly as it was, preferences
    // and all. The tick is what tells it the host came back on screen.
    this.showTick += 1;
  }

  // a root-tab switch is instant, like UITabBarController; other routes keep the slide
  pageTransition() {
    if (isRootTabSwitch()) {
      PageTransitionEnter({ duration: 0 })
      PageTransitionExit({ duration: 0 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      if (this.selectedTab === 0) {
        if (this.exploreTabEnabled) {
          ExploreViewControllerPage({ showTick: this.showTick })
        } else {
          SettingsTabViewControllerPage()
        }
      } else if (this.selectedTab === 1) {
        PlacesViewControllerPage({ showTick: this.showTick })
      } else if (this.selectedTab === 2) {
        SavedViewControllerPage()
      } else if (this.selectedTab === 3) {
        WMFActivityTabViewControllerPage()
      } else {
        SearchViewControllerPage()
      }
    }
    .width('100%')
    .height('100%')

      if (this.showTempAccountToast) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
          Text($r('app.string.alert_temporary_account'))
            .layoutWeight(1)
            .fontSize(15)
            .fontColor($r('app.color.theme_text'))
          Text($r('app.string.alert_temporary_account_learn_more'))
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
        }
        .id('temp_account_toast')
        .width('94%')
        .padding(14)
        .margin({ bottom: 110 })
        .borderRadius(12)
        .backgroundColor($r('app.color.theme_paper_background'))
        .shadow({ radius: 16, color: '#33000000', offsetY: 4 })
        .onClick(() => {
          this.showTempAccountToast = false;
          this.getUIContext().getRouter().pushUrl({ url: 'pages/TempAccountExpiryViewControllerPage' });
        })
      }
    }
    .id('WMFAppViewController')
    .width('100%')
    .height('100%')
  }
}
