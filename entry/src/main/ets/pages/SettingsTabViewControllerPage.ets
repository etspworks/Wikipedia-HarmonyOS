// screen_settings_tab — presentation: page.
// Ported from Wikipedia/Code/SettingsTabViewController.swift, whose rows come from
// WMFComponents/.../Settings/WMFSettingsViewModel.swift buildSections() =
// [getAccountSection(), getMainSection(), getTermsSection(), getHelpSection()], each row a
// SettingsItem rendered by comp_settings_cell. Row actions go through
// SettingsCoordinator.handleSettingsAction(_:).
//
// The three conditional rows are real source branches, not styling:
//   getAccountSection() — username -> "Account"/.account, else isTempAccount ->
//     "Account"/.tempAccount (TempAccountsSettingsViewController), else "Log in"/.logIn.
//   getMainSection()    — WMFDeveloperSettingsDataController.shared.enableHomeTab gates the
//     Home-feed rows (.homeFeed -> WMFHomeFeedSettingsView); with the flag off the single
//     "Explore feed, On" row (.exploreFeed) is shown instead. enableHomePhase2 splits the
//     on-branch into one "Home feed" row vs "For you" + "Community feed".
//   getMainSection()    — the Year in Review row appears only when
//     dataController.shouldShowYiRSettingsItem().
//   getTermsSection()   — the donation-history row only when dataController.hasLocalDonations().
// None of those flags was set in the capture, which is why the capture (and the plan's
// controlInventory) shows the Log in / Explore feed rows and neither hosted child.
//
// Wired edges: settings -> single_page_web / about / appearance_settings /
// explore_feed_settings / help / home_feed_settings / temp_accounts_settings /
// push_notifications_settings / year_in_review_settings (routed pages);
// settings -> preferred_languages / login / article_tabs (modal covers hosted here) and
// -> profile (sheet hosted here), matching the source's present(_:animated:) calls.
// S5: styled from captured S0042 — white header (large 'Settings' title + the round
// Tabs/Profile title-bar buttons) over the grouped-gray body, each source section in its own
// white inset card, row badges tinted with each SettingsItem.color.
import { TalkPageService } from '../common/TalkPageService';
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { topSafeInset } from '../common/SafeArea';
import { router, promptAction } from '@kit.ArkUI';
import { WMFLoginView } from './WMFLoginViewControllerPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { RootTabBar, isExploreTabEnabled, isRootTabSwitch, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { WMFSettingsTableViewCell, SettingsDisclosureType } from '../components/WMFSettingsTableViewCell';
import { common } from '@kit.AbilityKit';
import { SessionStore } from '../common/SessionStore';
import { WMFCurrentUser, WMFCurrentUserAuthState } from '../model/WMFCurrentUser';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { ThemeManager, WMFTheme } from '../common/ThemeManager';
import { YearInReviewStore } from '../common/YearInReviewStore';
import { ReadingListSyncService } from '../common/ReadingListSyncService';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { RecentSearchStore } from '../common/RecentSearchStore';
import { Database } from '../common/Database';
import { Prefs, PrefKeys, WMFDataPrefKeys } from '../common/Prefs';
import { fileIo } from '@kit.CoreFileKit';
import { i18n } from '@kit.LocalizationKit';
import { formatString } from '../common/Plural';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';
import { DonateHistory } from '../common/DonateHistory';
import { advertiseActivity, resignActivity } from '../common/Continuation';

// wmf_settingsViewActivity
const SETTINGS_ACTIVITY_URI: string = 'wikipedia://settings';

// CommonStrings.privacyPolicyURLString / termsOfUseURLString /
// legalAndSafetyContactUsURLString, and the App Store link behind tappedRateApp().
const PRIVACY_POLICY_URL: string = 'https://foundation.wikimedia.org/wiki/Policy:Privacy_policy';
const TERMS_OF_USE_URL: string = 'https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use';
// CommonStrings.legalAndSafetyContactUsURLString (WMFLocalizations/.../CommonStrings.swift:242).
const LEGAL_AND_SAFETY_URL: string = 'https://foundation.wikimedia.org/wiki/Legal:Wikimedia_Foundation_Legal_and_Safety_Contact_Information';
// tappedRateApp(): the store's page for this app, where it is rated - AppGallery on HarmonyOS
// (the source's apps.apple.com link is the iOS app).
const APPGALLERY_DETAIL_URI: string = 'store://appgallery.huawei.com/app/detail?id=';
const APPGALLERY_WEB_URL: string = 'https://appgallery.huawei.com/app/detail?id=';
// ReadingListsController's sync flag (WMFIsSyncEnabled in the source's user defaults).
const SYNC_ENABLED_KEY: string = 'WMFIsSyncEnabled';


// Bytes under the given directories (files the app cannot stat are skipped).
async function tempCacheBytes(dirs: string[]): Promise<number> {
  let total: number = 0;
  for (const dir of dirs) {
    try {
      if (!fileIo.accessSync(dir)) {
        continue;
      }
      for (const rel of fileIo.listFileSync(dir, { recursion: true })) {
        try {
          total += fileIo.statSync(dir + (rel.startsWith('/') ? '' : '/') + rel).size;
        } catch (e) {
          // unreadable entry: not counted
        }
      }
    } catch (e) {
      console.warn('settings: cache size unavailable for ' + dir);
    }
  }
  return total;
}

// ByteCountFormatter(.file): decimal megabytes, one fraction digit, locale separators.
export function formatBytes(bytes: number): string {
  const locale: string = i18n.System.getSystemLocale();
  return new Intl.NumberFormat(locale, { maximumFractionDigits: 1 }).format(bytes / 1000000) + ' MB';
}

@Entry
@Component
export struct SettingsTabViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // one cover flag + a discriminator: repeated bindContentCover calls on one node override
  // each other (see ExploreViewControllerPage).
  @State showCover: boolean = false;
  @State activeCover: string = '';
  @State showProfileSheet: boolean = false;
  // authenticationManager: the permanent username, the temp username, and whether the
  // current account is temporary (getAccountSection()).
  @State username: string = '';
  @State tempUsername: string = '';
  @State isTempAccount: boolean = false;
  // updateDynamicValues(primaryLanguage:exploreFeedStatus:readingPreferenceTheme:)
  @State mainLanguage: string = '';
  @State exploreFeedStatus: boolean = false;
  @State readingPreferenceTheme: string = '';
  // WMFDeveloperSettingsDataController.shared.enableHomeTab / .enableHomePhase2 — both
  // default off, as in the captured build.
  @State enableHomeTab: boolean = false;
  @State enableHomePhase2: boolean = false;
  // dataController.shouldShowYiRSettingsItem() / .hasLocalDonations()
  @State showYearInReviewItem: boolean = false;
  @State hasLocalDonations: boolean = false;
  // showClearCacheActionSheet()
  @State showClearCacheConfirm: boolean = false;
  // WMFAccountSettingsViewModel: auto-sign talk page discussions
  @State autoSignDiscussions: boolean = false;
  // VanishAccountWarningViewHostingViewController, presented from Account > Vanish account
  @State showVanishWarning: boolean = false;
  // WMFSearchSettingsViewModel: showLanguagesTitle / openOnSearchTabTitle
  @State showSearchLanguageBar: boolean = true;
  @State openAppOnSearchTab: boolean = false;
  // ReadingListsController.isSyncEnabled — "Sync saved articles and lists"
  @State syncEnabled: boolean = false;

  aboutToDisappear(): void {
    resignActivity(getContext(this) as common.UIAbilityContext, SETTINGS_ACTIVITY_URI);
  }

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    // NSUserActivity.wmf_makeActive(wmf_settingsViewActivity())
    advertiseActivity(ctx, SETTINGS_ACTIVITY_URI);
    SessionStore.restore();
    ThemeManager.restore();
    ArticleCacheStore.init(ctx);
    this.readDynamicValues();
    Database.init(ctx).then(() => {
      LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
        // fetchDynamicValues().primaryLanguage
        this.mainLanguage = lang.languageCode.toUpperCase();
      }).catch((e: Error) => {
        console.error('settings: app language failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('settings: db init failed: ' + e.message);
    });
  }

  onPageShow(): void {
    // updateDynamicValues on return from a pushed settings page
    this.readDynamicValues();
  }

  // getAccountSection() + fetchDynamicValues() + the two section flags.
  private readDynamicValues(): void {
    const user: WMFCurrentUser | null = SessionStore.currentUser.value;
    const name: string = user !== null ? user.name : '';
    const isTemp: boolean = user !== null && user.authState === WMFCurrentUserAuthState.temporary;
    this.isTempAccount = isTemp;
    this.username = isTemp ? '' : name;
    this.tempUsername = isTemp ? name : '';
    // UserDefaults.standard.defaultTabType == .explore
    this.openAppOnSearchTab = Prefs.getBoolean(WMFDataPrefKeys.openAppOnSearchTab, false);
    this.exploreFeedStatus = !this.openAppOnSearchTab;
    // UserDefaults.standard.themeDisplayName
    // the stored name: 'standard' for Default, and the dimmed variants ('black-dimmed') read as
    // their base theme - the raw name used to show up in the row
    const stored: string = Prefs.getString(PrefKeys.appThemeName, WMFTheme.defaultThemeName);
    this.readingPreferenceTheme =
      this.themeName(WMFTheme.isDefaultThemeName(stored) ? 'default' : stored.split('-')[0]);
    // dataController.shouldShowYiRSettingsItem() / .hasLocalDonations()
    this.showYearInReviewItem = YearInReviewStore.isYearInReviewEnabled();
    this.hasLocalDonations = Prefs.getBoolean(WMFDataPrefKeys.hasLocallySavedDonations, false);
    // WMFSettingsDataController.autoSignTalkPageDiscussions: on unless turned off
    this.autoSignDiscussions = TalkPageService.autoSignTalkPageDiscussions();
    this.showSearchLanguageBar = Prefs.getBoolean(WMFDataPrefKeys.showSearchLanguageBar, true);
    this.syncEnabled = Prefs.getBoolean(SYNC_ENABLED_KEY, false);
  }

  @Builder
  coverBuilder() {
    if (this.activeCover === 'login') {
      WMFLoginView({
        onClose: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'tabs') {
      WMFArticleTabsView({
        onClose: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'account') {
      this.accountSettingsCover()
    } else if (this.activeCover === 'search') {
      this.searchSettingsCover()
    } else if (this.activeCover === 'articleSyncing') {
      // showArticleSyncing() — the saved-articles sync preference.
      Column() {
        Row() {
          Text($r('app.string.settings_storage_and_syncing_enable_sync_title'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled })
            .id('sync_saved_articles')
            .onChange((isOn: boolean) => {
              this.setSyncEnabled(isOn);
            })
        }
        .width('100%')
        .height(48)
      }
      .width('100%')
      .padding(16)
    }
  }

  // WMFAccountSettingsView: the "Account" navigation bar over the grouped sections
  // "Your Account" (the username, Vanish account) and "Talk page preferences" (Auto-sign discussions, with
  // its footer). The cover was two bare rows with no way back, drawn over the Settings list.
  @Builder
  accountSettingsCover() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('account_settings_back')
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .width(44)
        .height(44)
        .onClick(() => {
          this.showCover = false;
        })
        Text($r('app.string.settings_account'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Blank()
          .width(44)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      Scroll() {
        Column() {
          this.settingsSectionHeader($r('app.string.account_group_title'))
          Column() {
            WMFSettingsTableViewCell({
              title: this.username,
              disclosureType: SettingsDisclosureType.none,
              rowId: 'account_username',
              iconColor: $r('app.color.orange600'),
              icon: $r('sys.symbol.person_fill')
            })
            Divider()
              .color($r('app.color.gray200'))
              .margin({ left: 60 })
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.account_request_vanishing')),
              disclosureType: SettingsDisclosureType.viewController,
              rowId: 'vanish_account',
              iconColor: $r('app.color.red600'),
              icon: $r('sys.symbol.person_badge_xmark_fill'),
              onTap: (): void => {
                this.showVanishWarning = true;
              }
            })
          }
          .margin({ left: 16, right: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(12)
          .clip(true)

          this.settingsSectionHeader($r('app.string.account_talk_preferences_title'))
          Column() {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.account_talk_preferences_auto_sign_discussions')),
              disclosureType: SettingsDisclosureType.toggle,
              isSwitchOn: this.autoSignDiscussions,
              rowId: 'auto_sign_discussions',
              onToggle: (isOn: boolean): void => {
                this.autoSignDiscussions = isOn;
                Prefs.putBoolean(WMFDataPrefKeys.autoSignTalkPageDiscussions, isOn);
              }
            })
          }
          .margin({ left: 16, right: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(12)
          .clip(true)
          Text($r('app.string.account_talk_preferences_auto_sign_discussions_setting_explanation'))
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 32, right: 32, top: 8 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
    }
    .id('account_settings')
    .width('100%')
    .height('100%')
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    .bindSheet($$this.showVanishWarning, this.vanishWarningSheet(), { height: SheetSize.LARGE, showClose: false })
  }

  // VanishAccountWarningView: "Warning", the body with its bold runs, a red Continue and Cancel.
  @Builder
  vanishWarningSheet() {
    Column() {
      Scroll() {
        Column() {
          Text($r('app.string.vanish_account_warning_title'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 64 })
          Text() {
            ForEach(this.text($r('app.string.vanish_account_warning_body')).split('**'), (part: string, i: number) => {
              Span(part)
                .fontWeight(i % 2 === 1 ? FontWeight.Bold : FontWeight.Normal)
            }, (part: string, i: number) => i.toString())
          }
            .width('100%')
            .fontSize(17)
            .lineHeight(24)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 50 })
        }
        .width('100%')
        .padding({ left: 32, right: 32, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      Button($r('app.string.vanish_account_continue_button_title'))
        .id('vanish_continue')
        .type(ButtonType.Normal)
        .width(335)
        .height(46)
        .borderRadius(8)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .backgroundColor($r('app.color.theme_destructive'))
        .margin({ bottom: 4 })
        .onClick(() => {
          // userDidDismissVanishAccountWarningView(presentVanishView: true): the global
          // vanish request form on Meta in the in-app web page
          this.showVanishWarning = false;
          this.showCover = false;
          setTimeout(() => {
            this.openSinglePageWeb('https://meta.wikimedia.org/wiki/Special:GlobalVanishRequest');
          }, 300);
        })
      Button($r('app.string.action_cancel'))
        .id('vanish_cancel')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_link'))
        .height(44)
        .margin({ bottom: 18 })
        .onClick(() => {
          this.showVanishWarning = false;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // a grouped List section header (footnote, secondary text)
  @Builder
  settingsSectionHeader(title: Resource) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 32, right: 32, top: 24, bottom: 8 })
  }

  // WMFSearchSettingsViewController: a navigation bar with its own back affordance and the
  // "Search" title over one grouped section of two switches, footer below. The cover used to
  // be two bare English rows with no way back, which read as a page that never loaded.
  @Builder
  searchSettingsCover() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('search_settings_back')
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .width(44)
        .height(44)
        .onClick(() => {
          this.showCover = false;
        })
        Text($r('app.string.search_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Blank()
          .width(44)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      Column() {
        // The whole row is the control, as a UITableView switch row is.
        Row() {
          Text($r('app.string.settings_language_bar'))
            .layoutWeight(1)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          Toggle({ type: ToggleType.Switch, isOn: this.showSearchLanguageBar })
            .id('show_languages_on_search')
            .onChange((isOn: boolean) => {
              this.setShowSearchLanguageBar(isOn);
            })
        }
        .id('show_languages_on_search_row')
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .padding({ left: 16, right: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.setShowSearchLanguageBar(!this.showSearchLanguageBar);
        })
        Divider()
          .color($r('app.color.gray200'))
          .margin({ left: 16 })
        Row() {
          Text($r('app.string.settings_search_open_app_on_search'))
            .layoutWeight(1)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          Toggle({ type: ToggleType.Switch, isOn: this.openAppOnSearchTab })
            .id('open_app_on_search_tab')
            .onChange((isOn: boolean) => {
              this.setOpenAppOnSearchTab(isOn);
            })
        }
        .id('open_app_on_search_tab_row')
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .padding({ left: 16, right: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.setOpenAppOnSearchTab(!this.openAppOnSearchTab);
        })
      }
      .margin({ left: 16, right: 16, top: 16 })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(12)

      Text($r('app.string.settings_search_footer_text'))
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .padding({ left: 32, right: 32, top: 8 })
    }
    .id('search_settings')
    .width('100%')
    .height('100%')
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }

  private setShowSearchLanguageBar(isOn: boolean): void {
    this.showSearchLanguageBar = isOn;
    Prefs.putBoolean(WMFDataPrefKeys.showSearchLanguageBar, isOn);
  }

  private setOpenAppOnSearchTab(isOn: boolean): void {
    this.openAppOnSearchTab = isOn;
    Prefs.putBoolean(WMFDataPrefKeys.openAppOnSearchTab, isOn);
    this.exploreFeedStatus = !isOn;
  }

  @Builder
  profileSheetBuilder() {
    WMFProfileViewSheet({
      onClose: (): void => {
        this.showProfileSheet = false;
      }
    })
  }

  // WMFSettingsTableViewCell takes plain strings, so the screen resolves its own labels;
  // as literals they stayed English whatever the device language.
  private text(res: Resource): string {
    try {
      return (getContext(this) as common.Context).resourceManager.getStringSync(res);
    } catch (e) {
      console.error('settings: string unavailable: ' + (e as Error).message);
      return '';
    }
  }

  // theme_{light,sepia,dark,black,default}_display_name
  private themeName(name: string): string {
    try {
      return (getContext(this) as common.Context).resourceManager
        .getStringByNameSync('theme_' + name + '_display_name');
    } catch (e) {
      return name;
    }
  }

  // localizedStrings.onTitle / .offTitle
  private onOff(value: boolean): string {
    return this.text(value ? $r('app.string.settings_on') : $r('app.string.settings_off'));
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
      // navigationItem: the pushed-navigation back affordance, the "Settings" title and the
      // Tabs / Profile bar buttons.
      Row() {
        // A root tab has nothing to go back to, so the back affordance is only rendered
        // while this screen is pushed from somewhere.
        if (isExploreTabEnabled()) {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(NAV_BUTTON_SYMBOL_SIZE)
              .fontColor([$r('app.color.theme_text')])
          }
            .id('BackButton')
            .attributeModifier(NAV_ICON_BUTTON)
            .onClick(() => {
              router.back();
            })
        }
        Blank()
        // The two bar buttons, each its own round title-bar button (S0042).
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
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .bindContentCover($$this.showCover, this.coverBuilder())

      // navigationItem.largeTitleDisplayMode — the title sits on the white header band.
      Text($r('app.string.settings_title'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontSize(ROOT_TITLE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .padding({ left: 16, right: 16, top: 8, bottom: 14 })
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))

      Scroll() {
        Column() {
          // ---- getAccountSection() ----
          Column() {
          if (this.username !== '') {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.settings_account')),
              disclosureText: this.username,
              disclosureType: SettingsDisclosureType.viewControllerWithText,
              rowId: 'account',
              iconColor: $r('app.color.orange600'),
              icon: $r('sys.symbol.person_fill'),
              onTap: (): void => {
                this.openAccount();
              }
            })
          } else if (this.isTempAccount) {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.settings_account')),
              disclosureText: this.tempUsername,
              disclosureType: SettingsDisclosureType.viewControllerWithText,
              rowId: 'account',
              iconColor: $r('app.color.orange600'),
              iconImage: $r('app.media.temp'),
              onTap: (): void => {
                this.openTemporaryAccount();
              }
            })
          } else {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.main_menu_account_login')),
              disclosureType: SettingsDisclosureType.viewController,
              rowId: 'log_in',
              iconColor: $r('app.color.gray300'),
              icon: $r('sys.symbol.person_fill'),
              onTap: (): void => {
                this.openLogin();
              }
            })
          }

          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .margin({ top: 16 })

          // ---- getMainSection() ----
          Column() {
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_my_languages')),
            disclosureText: this.mainLanguage,
            disclosureType: SettingsDisclosureType.viewControllerWithText,
            rowId: 'my_languages_en',
            iconColor: $r('app.color.blue300'),
            iconImage: $r('app.media.settings_language'),
            onTap: (): void => {
              this.openPreferredLanguages();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.search_title')),
            disclosureType: SettingsDisclosureType.viewController,
            rowId: 'search',
            iconColor: $r('app.color.green600'),
            icon: $r('sys.symbol.magnifyingglass'),
            onTap: (): void => {
              this.openSearchSettings();
            }
          })

          if (this.enableHomeTab) {
            if (this.enableHomePhase2) {
              // Phase 2: one Home-feed row covers both segments.
              WMFSettingsTableViewCell({
                title: this.text($r('app.string.settings_home_feed_title')),
                disclosureType: SettingsDisclosureType.viewController,
                rowId: 'home_feed',
                iconColor: $r('app.color.blue300'),
                icon: $r('sys.symbol.house'),
                onTap: (): void => {
                  this.openHomeFeedSettings();
                }
              })
            } else {
              // Phase 1: the For You row plus the relabeled Community feed row.
              WMFSettingsTableViewCell({
                title: this.text($r('app.string.home_feed_settings_for_you_section_title')),
                disclosureType: SettingsDisclosureType.viewController,
                rowId: 'for_you',
                iconColor: $r('app.color.blue300'),
                icon: $r('sys.symbol.house'),
                onTap: (): void => {
                  this.openHomeFeedSettings();
                }
              })
              WMFSettingsTableViewCell({
                title: 'Community feed',
                disclosureText: this.onOff(this.exploreFeedStatus),
                disclosureType: SettingsDisclosureType.viewControllerWithText,
                rowId: 'community_feed',
                iconColor: $r('app.color.blue300'),
                iconImage: $r('app.media.settings_explore'),
                onTap: (): void => {
                  this.openExploreFeedSettings();
                }
              })
            }
          } else {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.welcome_exploration_explore_feed_title')),
              disclosureText: this.onOff(this.exploreFeedStatus),
              disclosureType: SettingsDisclosureType.viewControllerWithText,
              rowId: 'explore_feed_on',
              iconColor: $r('app.color.blue300'),
              iconImage: $r('app.media.settings_explore'),
              onTap: (): void => {
                this.openExploreFeedSettings();
              }
            })
          }

          // The row stays when the reader switches Year in Review off (that switch lives behind
          // it); the source hides it only where the feature is not offered. Its value mirrors
          // the switch: Açık / Kapalı.
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.year_in_review_button_title')),
            disclosureText: this.onOff(this.showYearInReviewItem),
            disclosureType: SettingsDisclosureType.viewControllerWithText,
            rowId: 'year_in_review',
            iconColor: $r('app.color.blue700'),
            iconImage: $r('app.media.settings_calendar'),
            onTap: (): void => {
              this.openYearInReviewSettings();
            }
          })

          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_notifications')),
            disclosureType: SettingsDisclosureType.viewController,
            rowId: 'push_notifications',
            iconColor: $r('app.color.red600'),
            iconImage: $r('app.media.settings_notifications'),
            onTap: (): void => {
              this.openPushNotificationsSettings();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_appearance')),
            disclosureText: this.readingPreferenceTheme,
            disclosureType: SettingsDisclosureType.viewControllerWithText,
            rowId: 'app_theme_default',
            iconColor: $r('app.color.wmf_black'),
            // the source's "T T" appearance glyph (drawn white by the cell)
            iconImage: $r('app.media.settings_appearance'),
            onTap: (): void => {
              this.openAppearanceSettings();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_storage_and_syncing_title')),
            disclosureType: SettingsDisclosureType.viewController,
            rowId: 'article_storage_and_syncing',
            iconColor: $r('app.color.blue600'),
            icon: $r('sys.symbol.bookmark_fill'),
            onTap: (): void => {
              this.openArticleSyncing();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_clear_cache')),
            disclosureType: SettingsDisclosureType.none,
            rowId: 'clear_cached_data',
            iconColor: $r('app.color.yellow600'),
            iconImage: $r('app.media.settings_clear_cache'),
            onTap: (): void => {
              this.clearCachedData();
            }
          })

          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .margin({ top: 24 })

          // ---- getTermsSection() ----
          Text($r('app.string.main_menu_heading_legal'))
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 24, bottom: 8 })
          Column() {
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.main_menu_privacy_policy')),
            disclosureType: SettingsDisclosureType.externalLink,
            rowId: 'privacy_policy',
            iconColor: $r('app.color.purple600'),
            iconImage: $r('app.media.settings_privacy'),
            onTap: (): void => {
              this.openSinglePageWeb(PRIVACY_POLICY_URL);
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.terms_of_use_title')),
            disclosureType: SettingsDisclosureType.externalLink,
            rowId: 'terms_of_use',
            iconColor: $r('app.color.gray300'),
            iconImage: $r('app.media.settings_terms'),
            onTap: (): void => {
              this.openSinglePageWeb(TERMS_OF_USE_URL);
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_legal_sefaty_title')),
            disclosureType: SettingsDisclosureType.externalLink,
            rowId: 'legal_safety_contacts',
            iconColor: $r('app.color.blue300'),
            icon: $r('sys.symbol.info_circle_fill'),
            onTap: (): void => {
              this.openSinglePageWeb(LEGAL_AND_SAFETY_URL);
            }
          })
          if (this.hasLocalDonations) {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.donate_history_delete')),
              disclosureType: SettingsDisclosureType.none,
              rowId: 'delete_local_donation_history',
              iconColor: $r('app.color.gray300'),
              icon: $r('sys.symbol.heart_fill'),
              onTap: (): void => {
                this.clearDonationHistory();
              }
            })
          }

          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)

          // ---- getHelpSection() ----
          Column() {
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.main_menu_rate_app')),
            disclosureType: SettingsDisclosureType.externalLink,
            rowId: 'rate_the_app',
            iconColor: $r('app.color.orange600'),
            iconImage: $r('app.media.settings_rate'),
            onTap: (): void => {
              this.openRateApp();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.settings_help_and_feedback')),
            disclosureType: SettingsDisclosureType.viewController,
            rowId: 'help_and_feedback',
            iconColor: $r('app.color.red600'),
            iconImage: $r('app.media.settings_help_and_feedback'),
            onTap: (): void => {
              this.openHelp();
            }
          })
          WMFSettingsTableViewCell({
            title: this.text($r('app.string.about_title')),
            disclosureType: SettingsDisclosureType.viewController,
            rowId: 'about',
            iconColor: $r('app.color.wmf_black'),
            iconImage: $r('app.media.settings_about'),
            onTap: (): void => {
              this.openAbout();
            }
          })
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .margin({ top: 24, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))

      // When the reader has turned the Explore tab off, this screen IS root tab 0 and has
      // to carry the bar, exactly like the other root pages do.
      if (!isExploreTabEnabled()) {
        RootTabBar({ selected: 0 })
      }
    }
    .id('SettingsTabViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    // WMFProfileHostingController is a near-full-height sheet; the profile page draws its
    // own X close, so the framework's close button and grabber stay off.
    .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(),
      { height: SheetSize.LARGE, dragBar: false, showClose: false })
  }

  private openPreferredLanguages(): void {
    router.pushUrl({ url: 'pages/WMFPreferredLanguagesViewControllerPage' })
      .catch((e: Error) => {
        console.error('settings: languages route failed: ' + e.message);
      });
  }

  // showLogin(): settingsNav.present(loginNavVC) — the login form over the settings stack.
  private openLogin(): void {
    this.activeCover = 'login';
    this.showCover = true;
  }

  private openArticleTabs(): void {
    router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
      console.error('article tabs push failed: ' + e.message);
    });
  }

  private openProfile(): void {
    this.showProfileSheet = true;
  }

  private openAbout(): void {
    router.pushUrl({ url: 'pages/AboutViewControllerPage' });
  }

  private openAppearanceSettings(): void {
    router.pushUrl({ url: 'pages/AppearanceSettingsViewControllerPage' });
  }

  private openExploreFeedSettings(): void {
    router.pushUrl({ url: 'pages/ExploreFeedSettingsViewControllerPage' });
  }

  // handleSettingsAction(.homeFeed) -> showHomeFeedSettings()
  private openHomeFeedSettings(): void {
    router.pushUrl({ url: 'pages/WMFHomeFeedSettingsViewPage' });
  }

  // handleSettingsAction(.tempAccount) -> showTemporaryAccount()
  private openTemporaryAccount(): void {
    router.pushUrl({ url: 'pages/TempAccountsSettingsViewControllerPage' });
  }

  private openPushNotificationsSettings(): void {
    router.pushUrl({ url: 'pages/WMFPushNotificationsSettingsViewPage' });
  }

  private openYearInReviewSettings(): void {
    router.pushUrl({ url: 'pages/WMFYearInReviewSettingsViewPage' });
  }

  private openRateApp(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const bundle: string = ctx.abilityInfo.bundleName;
    ctx.startAbility({ action: 'ohos.want.action.appdetail', uri: APPGALLERY_DETAIL_URI + bundle })
      .catch((e: Error) => {
        // no AppGallery on the device: its web page for the app
        console.warn('settings: AppGallery unavailable, opening the web page: ' + e.message);
        this.openSinglePageWeb(APPGALLERY_WEB_URL + bundle);
      });
  }

  private openHelp(): void {
    router.pushUrl({ url: 'pages/HelpViewControllerPage' });
  }

  // showClearCacheActionSheet() -> clearCache(). The message states the space it frees
  // (ByteCountFormatter in the device locale: "10,2 MB"); it was an English literal with none.
  private clearCachedData(): void {
    this.showClearCacheConfirm = true;
    tempCacheBytes(this.tempCacheDirs()).then((bytes: number) => {
      AlertDialog.show({
        title: $r('app.string.settings_clear_cache_are_you_sure_title'),
        message: formatString(getContext(this) as common.Context,
          $r('app.string.settings_clear_cache_are_you_sure_message'), [formatBytes(bytes)]),
        primaryButton: {
          value: $r('app.string.settings_clear_cache_cancel'),
          action: (): void => {
            this.showClearCacheConfirm = false;
          }
        },
        secondaryButton: {
          value: $r('app.string.settings_clear_cache_ok'),
          action: (): void => {
            this.showClearCacheConfirm = false;
            // showClearCacheInProgressBanner()
            promptAction.showToast({ message: $r('app.string.clearing_cache_in_progress') });
            this.clearCache().then(() => {
              // showClearCacheComplete()
              promptAction.showToast({ message: $r('app.string.clearing_cache_complete') });
            }).catch((e: Error) => {
              console.error('settings: clear cache failed: ' + e.message);
              // showClearCacheErrorBanner()
              promptAction.showToast({ message: $r('app.string.clearing_cache_error') });
            });
          }
        }
      });
    });
  }

  // clearTemporaryCache: the module cache (image_file_cache, map_tiles, gallery images) and the
  // app's preload cache. Saved pages' offline copies live in filesDir and stay - this used to
  // delete them, although the dialog promises it will not.
  private tempCacheDirs(): string[] {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return [ctx.cacheDir, ctx.getApplicationContext().cacheDir + '/preload_caches'];
  }

  private async clearCache(): Promise<void> {
    for (const dir of this.tempCacheDirs()) {
      if (!fileIo.accessSync(dir)) {
        continue;
      }
      for (const name of fileIo.listFileSync(dir)) {
        try {
          const path: string = dir + '/' + name;
          if (fileIo.statSync(path).isDirectory()) {
            fileIo.rmdirSync(path);
          } else {
            fileIo.unlinkSync(path);
          }
        } catch (e) {
          console.warn('settings: cache entry kept: ' + name + ' ' + JSON.stringify(e));
        }
      }
    }
    RecentSearchStore.removeAllEntries();
  }

  // clearDonationHistory(): "Confirm deletion" with Delete / Cancel; Delete removes the local
  // donations, refreshes the sections (the row goes) and confirms "Local history deleted".
  private clearDonationHistory(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.confirm_donation_history_deletion_title'),
      message: $r('app.string.confirm_donation_history_deletion_subtitle'),
      buttons: [
        { value: $r('app.string.article_delete'), fontColor: Color.Red, action: (): void => {
          DonateHistory.deleteAll();
          this.hasLocalDonations = false;
          this.getUIContext().showAlertDialog({
            title: $r('app.string.confirmed_donation_history_deletion'),
            message: '',
            confirm: { value: $r('app.string.button_ok'), action: (): void => {} }
          });
        } },
        { value: $r('app.string.cancel'), action: (): void => {} }
      ]
    });
  }

  // showAccount() — WMFAccountSettingsViewController's talk-page preferences.
  private openAccount(): void {
    this.activeCover = 'account';
    this.showCover = true;
  }

  // showSearch() — WMFSearchSettingsViewController's two search preferences.
  private openSearchSettings(): void {
    this.activeCover = 'search';
    this.showCover = true;
  }

  // showArticleSyncing() — the saved-articles sync preference.
  private openArticleSyncing(): void {
    // a routed page: the cover showed a lone switch with no title and no way back
    router.pushUrl({ url: 'pages/StorageAndSyncingSettingsViewControllerPage' });
  }

  // ReadingListsController.setSyncEnabled: the server-side setup/teardown plus the flag.
  private setSyncEnabled(isOn: boolean): void {
    this.syncEnabled = isOn;
    Prefs.putBoolean(SYNC_ENABLED_KEY, isOn);
    const call: Promise<void> = isOn ? ReadingListSyncService.setup() : ReadingListSyncService.teardown();
    call.catch((e: Error) => {
      console.error('settings: reading-list sync toggle failed: ' + e.message);
    });
  }

  private openSinglePageWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }
}
