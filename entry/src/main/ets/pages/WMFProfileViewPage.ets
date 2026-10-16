// screen_profile — presentation: sheet, hosted by ExploreViewControllerPage (.bindSheet).
// NOT a routed page; never registered in main_pages.json.
// Structure from WMFComponents/Components/Profile/WMFProfileView.swift +
// WMFProfileViewModel.swift (ProfileState.sections): a sectioned List of profile rows
// (icon + title, optional notification count/dot, optional donate spinner), branched on
// the session state (logged in / temporary account / logged out). Nav bar: leading
// Cancel close button + "Account" large title (WMFProfileHostingController).
// Hosts overlay: WMFYearInReviewView (modal cover). Login is a routed page, pushed after
// this sheet closes - one node carries only one bindContentCover.
// Behavior from ProfileCoordinator.swift: every action dismisses the profile sheet first
// (dismissProfile) — except donate, which keeps it up while the configs load.
import { router } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { WMFYearInReviewView } from './WMFYearInReviewViewPage';
import { WMFCurrentUser, WMFCurrentUserAuthState } from '../model/WMFCurrentUser';
import { WMFDonateConfig, WMFDonateConfigJson } from '../model/WMFDonateConfig';
import { SessionStore } from '../common/SessionStore';
import { NotificationsService, UNREAD_NOTIFICATIONS_KEY } from '../common/NotificationsService';
import { HttpClient } from '../common/HttpClient';
import { Subscription } from '../common/Reactive';
import { YearInReviewStore } from '../common/YearInReviewStore';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';

// URL.donateConfigURL() + donateConfigParameters (action=raw) — WMFDonateDataController.
const DONATE_CONFIG_URL: string =
  'https://donate.wikimedia.org/wiki/MediaWiki:AppsDonationConfig.json?action=raw';
// WMFDonateConfigResponse.currentVersion — the response is an array of versioned configs.
const DONATE_CONFIG_VERSION: number = 1;
// loadConfigs(): a persisted config is reused for seven days before refetching.
const DONATE_CONFIG_MAX_AGE_MS: number = 7 * 24 * 60 * 60 * 1000;

// ProfileListItem (WMFProfileViewModel.swift) — UI-local row model, page-scoped.
class ProfileListItem {
  readonly slug: string;
  readonly title: ResourceStr;
  readonly symbol: Resource;
  readonly hasNotifications: boolean;
  readonly needsNotificationCount: boolean;
  readonly isDonate: boolean;
  readonly action: () => void;
  // profileBarItem: RoundedRectangle(cornerRadius: 6).fill(item.imageColor ?? theme.border);
  // default systemGray = UIColor(Color.gray) resolved per palette.json.
  readonly badgeColor: ResourceColor;

  constructor(slug: string, title: ResourceStr, symbol: Resource, action: () => void,
    hasNotifications: boolean = false, needsNotificationCount: boolean = false,
    isDonate: boolean = false, badgeColor: ResourceColor = '#8E8E93') {
    this.slug = slug;
    this.title = title;
    this.symbol = symbol;
    this.action = action;
    this.hasNotifications = hasNotifications;
    this.needsNotificationCount = needsNotificationCount;
    this.isDonate = isDonate;
    this.badgeColor = badgeColor;
  }
}

// ProfileSection (WMFProfileViewModel.swift) — rows + optional footer subtext.
class ProfileSection {
  readonly key: string;
  readonly items: ProfileListItem[];
  readonly subtext: ResourceStr | null;

  constructor(key: string, items: ProfileListItem[], subtext: ResourceStr | null = null) {
    this.key = key;
    this.items = items;
    this.subtext = subtext;
  }
}

@Component
export struct WMFProfileViewSheet {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  @StorageProp('wmfChromeBg') wmfChromeBg: string = '';

  @State showYearInReview: boolean = false;
  @State currentUser: WMFCurrentUser | null = null;
  // ProfileState.sections(...) output below the notifications row — rebuilt when the
  // session, the Year in Review entry point or the donate loading flag changes.
  @State items: ProfileSection[] = [];
  // ProfileCoordinator: remoteNotificationsController.numberOfUnreadNotifications().
  @StorageProp(UNREAD_NOTIFICATIONS_KEY) inboxCount: number = 0;
  @State isLoadingDonateConfigs: boolean = false;
  // shouldShowYearInReviewEntryPoint(countryCode:) — async (reads the stored report).
  @State showYiREntryPoint: boolean = false;
  // shouldShowYiRNotification — the red dot, cleared once the profile item is tapped.
  @State needsYiRNotification: boolean = false;
  @State logoutConfirmVisible: boolean = false;
  private appLangCode: string = 'en';
  // WMFDonateDataController.donateConfig — held between taps, refetched past seven days.
  private donateConfig: WMFDonateConfig | null = null;
  private userSub: Subscription | null = null;
  // Host closes the sheet (bindSheet flag lives on the host). Fallback flips the
  // shared AppStorage flag for hosts wired through it.
  onClose: () => void = (): void => {
    AppStorage.setOrCreate<boolean>('showProfileSheet', false);
  };

  aboutToAppear(): void {
    this.currentUser = SessionStore.currentUser.value;
    this.rebuildSections();
    this.userSub = SessionStore.currentUser.subscribe((user: WMFCurrentUser | null): void => {
      this.currentUser = user;
      this.rebuildSections();
    });
    LanguageStore.readPreferredCodes().then((codes: string[]): void => {
      if (codes.length > 0) {
        this.appLangCode = codes[0];
      }
    });
    NotificationsService.refreshUnreadCount().then((): void => {
      this.rebuildSections();
    });
    this.loadYearInReviewEntryPoint().catch((e: Object): void => {
      this.showYiREntryPoint = false;
      this.rebuildSections();
    });
  }

  aboutToDisappear(): void {
    if (this.userSub !== null) {
      this.userSub.dispose();
      this.userSub = null;
    }
  }

  @Builder
  yearInReviewBuilder() {
    WMFYearInReviewView()
  }

  // profileBarItem(item:) — icon + title + optional count/dot + optional donate spinner.
  @Builder
  profileRow(item: ProfileListItem) {
    Row() {
      // 16pt glyph tinted chromeBackground on a 32x32 r6 badge (profileBarItem).
      SymbolGlyph(item.symbol)
        .fontSize(16)
        .fontColor([(this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background'))])
        .padding(8)
        .backgroundColor(item.badgeColor)
        .borderRadius(6)
        .margin({ right: 16 })
      Text(item.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (item.hasNotifications) {
        if (item.needsNotificationCount) {
          Text(`${this.inboxCount}`)
            .fontSize(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ right: 10 })
        }
        Circle()
          .width(10)
          .height(10)
          .fill($r('app.color.theme_destructive'))
      }
      if (item.isDonate && this.isLoadingDonateConfigs) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color($r('app.color.theme_secondary_text'))
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick((): void => {
      item.action();
    })
    .id(item.slug)
  }

  // A section's rows share one rounded container with hairlines between them (the source's
  // grouped List section; a HarmonyOS grouped list), instead of one capsule per row.
  @Builder
  sectionGroup(section: ProfileSection) {
    ListItemGroup() {
      ForEach(section.items, (item: ProfileListItem) => {
        ListItem() {
          this.profileRow(item)
        }
      }, (item: ProfileListItem): string => item.slug)
    }
    .divider({ strokeWidth: 0.5, color: $r('app.color.theme_border'), startMargin: 64, endMargin: 16 })
    .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
    .borderRadius(20)
    .clip(true)
    .margin({ bottom: section.subtext !== null ? 0 : 17 })
    // Section footer subtext (sectionView footer:), under the group, outside its box.
    if (section.subtext !== null) {
      ListItem() {
        Text(section.subtext ?? '')
          .fontSize(15)
          .lineHeight(22)
          .fontColor($r('app.color.theme_secondary_text'))
          .padding({ left: 16, right: 16, top: 8 })
      }
      .margin({ bottom: 17 })
    }
  }

  build() {
    Column() {
      // WMFNavigationBar: leading plain-X/Cancel close + leadingLarge "Account" title.
      Row() {
        // WMFLargeCloseButtonConfig(imageType: .plainX) — X glyph in a 36pt chrome circle
        // (accessibility label "Cancel"); glyph = WMFIcon .close -> sys.symbol.multiply (exact).
        Button() {
          SymbolGlyph($r('sys.symbol.multiply'))
            .fontSize(17)
            .fontColor([$r('app.color.theme_text')])
        }
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
        .onClick((): void => {
          this.onClose();
        })
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFProfileView.close_button')
        // the capture surfaces this glyph-only button by its iOS accessibility label
        .accessibilityText('Cancel')
      }
      .width('100%')
      .padding({ left: 20, top: 20 })
      Text(this.pageTitle())
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 23, bottom: 10 })
      List() {
        // ProfileState.sections: the notifications row exists only for a signed-in
        // account (permanent or temporary); logged out it is absent entirely.
        if (this.currentUser !== null) {
          this.sectionGroup(this.notificationsSection())
        }
        ForEach(this.items, (section: ProfileSection) => {
          this.sectionGroup(section)
        }, (section: ProfileSection): string => section.key)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
    .id('WMFProfileView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    .bindContentCover($$this.showYearInReview, this.yearInReviewBuilder())
  }

  // ProfileCoordinator.start finalPageTitle: the username when logged in, "Temporary account"
  // for a temporary one, "Account" otherwise.
  private pageTitle(): ResourceStr {
    const user: WMFCurrentUser | null = this.currentUser;
    if (user !== null && user.isPermanent && user.name !== '') {
      return user.name;
    }
    if (user !== null && user.authState === WMFCurrentUserAuthState.temporary) {
      return $r('app.string.profile_temp_account_title');
    }
    return $r('app.string.settings_account');
  }

  private notificationsSection(): ProfileSection {
    return new ProfileSection('notifications', [this.notificationsItem()]);
  }

  private notificationsItem(): ProfileListItem {
    return new ProfileListItem(
      'notifications', $r('app.string.notifications_center_title'), $r('sys.symbol.bell_fill'),
      (): void => { this.openNotificationsCenter(); },
      this.inboxCount > 0, true, false, '#0088FF');
  }

  // ProfileState.sections — three branches on session state (the notifications section
  // is rendered by build() so the logged-out branch is a real condition on currentUser).
  private rebuildSections(): void {
    const user: WMFCurrentUser | null = this.currentUser;
    const isLoggedIn: boolean = user !== null && user.authState === WMFCurrentUserAuthState.permanent;
    const isTemporary: boolean = user !== null && user.authState === WMFCurrentUserAuthState.temporary;
    const showYiR: boolean = this.showYiREntryPoint;

    const donateItem: ProfileListItem = new ProfileListItem(
      'donate', $r('app.string.settings_donate'), $r('sys.symbol.heart_fill'),
      (): void => { this.openDonate().catch((e: Object): void => { this.isLoadingDonateConfigs = false; }); },
      false, false, true, '#FF383C');
    const settingsItem: ProfileListItem = new ProfileListItem(
      'settings', $r('app.string.settings_title'), $r('sys.symbol.gearshape'),
      (): void => { this.openSettings(); });
    const yearInReviewItem: ProfileListItem = new ProfileListItem(
      'year_in_review', $r('app.string.year_in_review_button_title'), $r('sys.symbol.calendar'),
      (): void => { this.openYearInReview(); },
      this.needsYiRNotification, false, false, $r('app.color.blue600'));
    const joinWikipediaItem: ProfileListItem = new ProfileListItem(
      'log_in_join_wikipedia', $r('app.string.profile_page_join_title'),
      $r('sys.symbol.arrow_right_and_square'),
      (): void => { this.openLogin(); });

    if (isLoggedIn && user !== null) {
      const userName: string = user.name;
      const userPageItem: ProfileListItem = new ProfileListItem(
        'user_page', $r('app.string.watchlist_user_button_user_page'), $r('sys.symbol.person_fill'),
        (): void => { this.openSinglePageWeb(this.wikiUrl(`User:${userName}`)); },
        false, false, false, '#AF52DE');
      const talkPageItem: ProfileListItem = new ProfileListItem(
        'talk_page', $r('app.string.account_talk_page_title'), $r('sys.symbol.text_bubble_left_2'),
        (): void => { this.openUserTalk(userName); },
        false, false, false, '#34C759');
      const watchlistItem: ProfileListItem = new ProfileListItem(
        'watchlist', $r('app.string.watchlist'), $r('sys.symbol.star_badge_list'),
        (): void => { this.openWatchlist(); },
        false, false, false, '#FF8D28');
      const logoutItem: ProfileListItem = new ProfileListItem(
        'log_out', $r('app.string.main_menu_account_logout'), $r('sys.symbol.arrow_right_and_square'),
        (): void => { this.confirmLogout(); });
      const section3Items: ProfileListItem[] = showYiR ? [donateItem, yearInReviewItem] : [donateItem];
      this.items = [
        new ProfileSection('account', [userPageItem, talkPageItem, watchlistItem, logoutItem]),
        new ProfileSection('support', section3Items),
        new ProfileSection('settings', [settingsItem])
      ];
    } else if (isTemporary && user !== null) {
      const userName: string = user.name;
      const userPageItem: ProfileListItem = new ProfileListItem(
        'user_page', $r('app.string.watchlist_user_button_user_page'), $r('sys.symbol.person_fill'),
        (): void => { this.openSinglePageWeb(this.wikiUrl(`User:${userName}`)); },
        false, false, false, '#FF8D28');
      const talkPageItem: ProfileListItem = new ProfileListItem(
        'talk_page', $r('app.string.account_talk_page_title'), $r('sys.symbol.text_bubble_left_2'),
        (): void => { this.openUserTalk(userName); },
        false, false, false, '#34C759');
      this.items = [
        new ProfileSection('join', [userPageItem, talkPageItem, joinWikipediaItem],
          $r('app.string.profile_page_join_subtext')),
        new ProfileSection('support', [donateItem], $r('app.string.profile_page_donate_subtext')),
        new ProfileSection('settings', [settingsItem])
      ];
    } else {
      // Captured logged-out state S0181: join, donate, (year in review), settings.
      const loggedOutSections: ProfileSection[] = [
        new ProfileSection('join', [joinWikipediaItem], $r('app.string.profile_page_join_subtext')),
        new ProfileSection('support', [donateItem], $r('app.string.profile_page_donate_subtext'))
      ];
      if (showYiR) {
        loggedOutSections.push(new ProfileSection('yir', [yearInReviewItem],
          $r('app.string.profile_page_logged_out_year_in_review_subtext')));
      }
      loggedOutSections.push(new ProfileSection('settings', [settingsItem]));
      this.items = loggedOutSections;
    }
  }

  private async loadYearInReviewEntryPoint(): Promise<void> {
    const year: number = new Date().getFullYear();
    this.showYiREntryPoint = await YearInReviewStore.shouldShowEntryPoint(year);
    this.needsYiRNotification = this.showYiREntryPoint
      && !Prefs.getBoolean(WMFDataPrefKeys.tappedYIR, false);
    this.rebuildSections();
  }

  private wikiUrl(title: string): string {
    return `https://${this.appLangCode}.wikipedia.org/wiki/${title}`;
  }

  // didTapLogIn -> presentFullLoginFlow(). The login is a routed page: this sheet already
  // spends its node's single modal binding on Year in Review, and a cover raised from
  // inside a sheet is the nesting that leaves screens half-built. Close the sheet, then push.
  private openLogin(): void {
    this.onClose();
    router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
      console.error('profile: login push failed: ' + e.message);
    });
  }

  // yearInReviewItem action: mark the profile item tapped, drop the dot, then present.
  private openYearInReview(): void {
    YearInReviewStore.markTappedYearInReview();
    this.needsYiRNotification = false;
    this.rebuildSections();
    // a routed page: as this sheet's content cover it never redrew past the intro
    this.onClose();
    router.pushUrl({ url: 'pages/WMFYearInReviewViewPage' }).catch((e: Error) => {
      console.error('profile: year in review push failed: ' + e.message);
    });
  }

  private openWatchlist(): void {
    this.onClose();
    router.pushUrl({ url: 'pages/WMFWatchlistViewPage' });
  }

  // ProfileCoordinator.logout(): a confirm alert, then the session is cleared.
  private confirmLogout(): void {
    this.logoutConfirmVisible = true;
    AlertDialog.show({
      title: $r('app.string.main_menu_account_logout_are_you_sure'),
      message: $r('app.string.main_menu_account_logout_are_you_sure_message'),
      primaryButton: {
        value: $r('app.string.main_menu_account_logout'),
        action: (): void => {
          this.logoutConfirmVisible = false;
          SessionStore.clear();
          this.onClose();
        }
      },
      secondaryButton: {
        value: $r('app.string.action_cancel'),
        action: (): void => {
          this.logoutConfirmVisible = false;
        }
      }
    });
  }

  // WMFDonateDataController.loadConfigs()/fetchConfigs(for:) — memory first, then the
  // persisted config while it is under seven days old, else the raw config endpoint.
  private async loadDonateConfig(): Promise<WMFDonateConfig | null> {
    const held: WMFDonateConfig | null = this.donateConfig;
    if (held !== null && held.cachedDate !== null
      && (Date.now() - held.cachedDate) < DONATE_CONFIG_MAX_AGE_MS) {
      return held;
    }
    const list: WMFDonateConfigJson[] = await HttpClient.getJson<WMFDonateConfigJson[]>(DONATE_CONFIG_URL);
    // WMFDonateConfigResponse: keep the entry matching currentVersion, ignore the rest.
    for (const j of list) {
      if ((j.version ?? 0) === DONATE_CONFIG_VERSION) {
        const config: WMFDonateConfig = WMFDonateConfig.fromJson(j);
        config.cachedDate = Date.now();
        this.donateConfig = config;
        return config;
      }
    }
    return null;
  }

  // DonateCoordinator.start(): setLoadingBlock(true), fetch the donate configs for the
  // donor's country, then either the native payment sheet or navigateToOtherPaymentMethod
  // (the web donate form). The profile sheet deliberately stays up while this runs.
  // HarmonyOS exposes no Apple-Pay equivalent, so the native form is the registered
  // feat_donate substitution and the web form is the only destination; the fetched config
  // is what the spinner covers and what the seven-day cache in loadDonateConfig() reuses.
  private async openDonate(): Promise<void> {
    const countryCode: string = i18n.System.getSystemRegion();
    this.isLoadingDonateConfigs = true;
    this.rebuildSections();
    try {
      await this.loadDonateConfig();
    } catch (e) {
      // fetch failed: the source still falls through to navigateToOtherPaymentMethod
      this.donateConfig = null;
    } finally {
      this.isLoadingDonateConfigs = false;
      this.rebuildSections();
    }
    this.openSinglePageWeb(this.donateUrl(countryCode));
  }

  // webViewURL + replacingDonateParameters(language:metricsId:); country as in the
  // coordinator's LandingCheck URLs.
  private donateUrl(countryCode: string): string {
    return `https://donate.wikimedia.org/?wmf_medium=WikipediaApp&wmf_campaign=iOS&wmf_source=${this.appLangCode}${countryCode}_appmenu_iOS&uselang=${this.appLangCode}&country=${countryCode}`;
  }

  private openSettings(): void {
    this.onClose();
    router.pushUrl({ url: 'pages/SettingsTabViewControllerPage' });
  }

  private openNotificationsCenter(): void {
    this.onClose();
    router.pushUrl({ url: 'pages/NotificationsCenterViewControllerPage' });
  }

  // ProfileCoordinator -> UserTalkCoordinator: the native talk page for User talk:<name>
  private openUserTalk(userName: string): void {
    router.pushUrl({ url: 'pages/TalkPageViewControllerPage',
      params: { 'talkPageTitle': 'User talk:' + userName, 'languageCode': this.appLangCode } });
  }

  private openSinglePageWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }
}
