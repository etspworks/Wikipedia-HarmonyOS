// screen_activity_tab — presentation: page (a root tab of WMFAppViewController's tab bar).
// Hosts overlays: WMFProfileViewSheet (sheet), WMFArticleTabsView (modal cover), WMFLoginView
// (modal cover — WMFActivityTabViewController.presentFullLoginFlow() presents the login flow
// from this view controller, which is what the logged-out CTA does).
//
// S3 structure from Wikipedia/Code/ActivityTabViewController.swift (the UIKit host: the
// navigation bar + the embedded hosting controller) and WMFComponents/.../Activity Tab/
// WMFActivityTabView.swift (the SwiftUI body it embeds):
//   The navigation bar carries the "Activity" title plus the profile, tabs and overflow
//   ("More") bar-button items; the tab bar underneath belongs to WMFAppViewController and is
//   comp_root_tab_bar, mounted here as on every root screen (Activity is index 3).
//   body: isLoading -> a ProgressView; authenticationState == .loggedIn -> loggedInList
//   (or customizedEmptyState() when every insight module is off); otherwise loggedOutList.
//   loggedOutView (the logged-out module) is a VStack of loggedOutTitle over
//   loggedOutSubtitle over a WMFSmallButton titled loggedOutPrimaryCTA with the
//   person.fill glyph, whose action is viewModel.didTapPrimaryLoggedOutCTA ->
//   presentFullLoginFlow(). loggedOutList shows that module, and WMFEmptyView(.noItems)
//   under it when viewModel.sections is empty.
//   timelineSectionsList() -> TimelineSectionView per section (WMFTimelineView.swift): a
//   TimelineHeaderView (the section's day) and, unless shouldShowEmptyState, one
//   TimelineRowView per item. TimelineRowView builds a WMFAsyncPageRowViewModel and renders
//   comp_page_row (WMFPageRow); its tapAction is timelineViewModel.onTap(item) — the article.
//   The plan's conditionalVariants for this screen are exactly the two branches built here:
//   isLoggedIn == false -> the logged-out module above the history, and history.length == 0
//   -> the empty state.
// bindingContract: the timeline rows come from svc_history_store (CDPageView history grouped
// by day = HistoryStore.fetchHistorySections()), never from a literal.
// Rule 12: profile-button / Tabs Button / activity_tab_more / log_in_join_wikipedia are the
// SOURCE slugs from the capture (results/traversal-source/pages/WMFActivityTabViewController);
// the timeline rows share 'activity_timeline_itemroot' (Rule 12's list-row exception).
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { router, SymbolGlyphModifier } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { RootTabBar, isRootTabSwitch, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { WMFPageRow } from '../components/WMFPageRow';
import { EmptyViewController } from '../components/EmptyViewController';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { WMFActivityTabCustomizeView } from '../components/WMFActivityTabCustomizeView';
import { HistoryStore, HistorySection, HistoryItem } from '../common/HistoryStore';
import { SessionStore } from '../common/SessionStore';
import { Subscription } from '../common/Reactive';
import { Database } from '../common/Database';
import { SavedStore } from '../common/SavedStore';
import { WMFArticle } from '../model/WMFArticle';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { ActivityInsightsService, MonthlyContributions } from '../common/ActivityInsightsService';
import { localizedLanguageName } from '../common/LanguageService';
import { openRootTab } from '../components/RootTabBar';
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';
import { formatString } from '../common/Plural';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE, navIconTint, ROOT_BAR_HEIGHT } from '../components/NavButton';
import { formatParts } from '../common/Plural';

@Entry
@Component
export struct WMFActivityTabViewControllerPage {
  @StorageProp('wmfIsDark') isDark: boolean = false;
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @State showProfileSheet: boolean = false;
  @State showArticleTabs: boolean = false;
  // customizeAction's sheet (WMFActivityTabCustomizeView).
  @State showCustomize: boolean = false;
  // viewModel.authenticationState
  @State isLoggedIn: boolean = false;
  // viewModel.sections — the CDPageView reading history, grouped by day (the plan's
  // `history` conditional-variant binding).
  @State history: HistorySection[] = [];
  // the flat timeline items recomputeShouldShowEmptyState() reads (`hasReadItem`).
  @State items: HistoryItem[] = [];
  // viewModel.isLoading — the source body's ProgressView branch. Rendered in the content
  // region only, so the nav chrome and the logged-out module stay put (fidelity §7).
  @State isLoading: boolean = true;
  // the timeline read failed — the source's fetch error path.
  @State loadError: string = '';
  // loggedInList insight modules (WMFActivityTabViewModel): reader name, minutes read since
  // the start of this week, distinct articles read since the 1st, and the last read date.
  @State userName: string = '';
  @State minutesThisWeek: number = 0;
  @State articlesThisMonth: number = 0;
  @State lastReadMs: number = 0;
  @State showTimeSpent: boolean = true;
  @State showReadingInsights: boolean = true;
  @State showEditingInsights: boolean = true;
  // customizeViewModel.isTimelineOfBehaviorOn
  @State showTimeline: boolean = true;
  // Articles saved this month: count, newest save, up to three thumbnails
  @State savedThisMonth: number = 0;
  @State lastSavedMs: number = 0;
  @State savedThumbs: string[] = [];
  // Top categories this month (of the articles read), and the global edit count
  @State topCategories: string[] = [];
  @State totalEdits: number = -1;
  // articlesReadGraph: articles read in each of the last four weeks, oldest first
  @State weeklyReads: number[] = [];
  // ContributionsView: edits on the app's wiki this month / last month, and the last edit
  @State contributions: MonthlyContributions | null = null;
  // "Your impact" subtitle: "On <app language> Wikipedia"
  @State wikiLanguageName: string = '';
  // the page scroller, so the articles-read card can bring the timeline into view
  private scroller: Scroller = new Scroller();
  private insightsHeight: number = 0;
  // an article's reading time lands after this tab has already reloaded on the way back
  @StorageProp('wmfPageViewSecondsSaved') @Watch('reloadTimeline') secondsSavedAt: number = 0;

  // didLogIn / didLogOut observers: the profile sheet logs out over this page without a page
  // show, so the insights would otherwise outlive the session.
  private userSub: Subscription | null = null;

  aboutToAppear(): void {
    this.updateLoginState();
    this.reloadTimeline();
    this.userSub = SessionStore.currentUser.subscribe((): void => {
      if (this.isLoggedIn !== SessionStore.isLoggedIn) {
        this.updateLoginState();
        this.reloadTimeline();
      }
    });
  }

  aboutToDisappear(): void {
    this.userSub?.dispose();
  }

  // viewWillAppear -> viewModel.fetchData(fromAppearance: true)
  onPageShow(): void {
    this.updateLoginState();
    this.reloadTimeline();
  }

  // updateLoginState (the didLogIn/didLogOut notification observers).
  private updateLoginState(): void {
    this.isLoggedIn = SessionStore.isLoggedIn;
  }

  private reloadTimeline(): void {
    this.isLoading = true;
    this.loadError = '';
    this.loadTimeline().then((): void => {
      this.isLoading = false;
    }).catch((e: Error) => {
      console.error('activity tab: history load failed: ' + e.message);
      this.loadError = e.message;
      this.isLoading = false;
    });
  }

  // The timeline reads the RDB store, which the Activity tab can reach as the cold-start
  // landing screen; Database.init is memoized, so this opens the file once.
  private async loadTimeline(): Promise<void> {
    await Database.init(getContext(this) as common.UIAbilityContext);
    const sections: HistorySection[] = await HistoryStore.fetchHistorySections();
    const flat: HistoryItem[] = [];
    for (const section of sections) {
      for (const item of section.items) {
        flat.push(item);
      }
    }
    this.history = sections;
    this.items = flat;
    if (this.isLoggedIn) {
      await this.loadInsights();
    }
  }

  private async loadInsights(): Promise<void> {
    this.userName = SessionStore.currentUser.value?.name ?? '';
    // the source's customize flags default on
    this.showTimeSpent = Prefs.getBoolean(WMFDataPrefKeys.activityTabTimeSpentReading, true);
    this.showReadingInsights = Prefs.getBoolean(WMFDataPrefKeys.activityTabReadingInsights, true);
    this.showTimeline = Prefs.getBoolean(WMFDataPrefKeys.activityTabTimelineOfBehavior, true);
    const now: Date = new Date();
    const firstDay: number = i18n.getCalendar(i18n.System.getSystemLocale()).getFirstDayOfWeek() - 1;
    const weekStart: Date = new Date(now.getFullYear(), now.getMonth(),
      now.getDate() - (now.getDay() - firstDay + 7) % 7);
    const monthStart: Date = new Date(now.getFullYear(), now.getMonth(), 1);
    this.minutesThisWeek = await HistoryStore.fetchPageViewMinutes(weekStart.getTime(), now.getTime());
    this.articlesThisMonth = (await HistoryStore.fetchPageViewCounts(monthStart.getTime(), now.getTime())).size;
    this.lastReadMs = (await HistoryStore.fetchMostRecentPageViewTime()) ?? 0;
    const weeks: number[] = [];
    for (let w = 3; w >= 0; w--) {
      const end: number = now.getTime() - w * 7 * 86400000;
      weeks.push((await HistoryStore.fetchPageViewCounts(end - 7 * 86400000, end)).size);
    }
    this.weeklyReads = weeks;
    this.showEditingInsights = Prefs.getBoolean(WMFDataPrefKeys.activityTabEditingInsights, true);
    const saved: WMFArticle[] = (await SavedStore.savedArticles())
      .filter((a: WMFArticle) => (a.savedDate ?? 0) >= monthStart.getTime());
    this.savedThisMonth = saved.length;
    this.lastSavedMs = saved.reduce((m: number, a: WMFArticle) => Math.max(m, a.savedDate ?? 0), 0);
    this.savedThumbs = saved.filter((a: WMFArticle) => (a.imageURLString ?? '') !== '')
      .slice(0, 3).map((a: WMFArticle) => a.imageURLString ?? '');
    // network modules: a failure leaves the module out rather than the whole block
    const lang: MWKLanguageLink = await LanguageStore.appLanguage();
    const host: string = lang.languageCode + '.wikipedia.org';
    this.wikiLanguageName = localizedLanguageName(lang.languageCode, lang.languageCode);
    const readTitles: string[] = Array.from(
      (await HistoryStore.fetchPageViewCounts(monthStart.getTime(), now.getTime())).keys());
    ActivityInsightsService.topCategories(host, readTitles, 3).then((c: string[]) => {
      this.topCategories = c;
    }).catch((e: Error) => {
      console.warn('activity tab: top categories unavailable: ' + e.message);
    });
    if (this.userName !== '') {
      ActivityInsightsService.monthlyContributions(host, this.userName).then((c: MonthlyContributions) => {
        this.contributions = c;
      }).catch((e: Error) => {
        console.warn('activity tab: contributions unavailable: ' + e.message);
      });
      ActivityInsightsService.globalEditCount(host, this.userName).then((n: number) => {
        this.totalEdits = n;
      }).catch((e: Error) => {
        console.warn('activity tab: edit count unavailable: ' + e.message);
      });
    }
  }

  @Builder
  profileSheetBuilder() {
    WMFProfileViewSheet({
      onClose: (): void => {
        this.showProfileSheet = false;
      }
    })
  }

  @Builder
  customizeBuilder() {
    WMFActivityTabCustomizeView({
      onClose: (): void => {
        this.showCustomize = false;
      },
      onLogIn: (): void => {
        this.showCustomize = false;
        this.presentFullLoginFlow();
      }
    })
  }

  @Builder
  articleTabsBuilder() {
    WMFArticleTabsView()
  }

  // S5 (capture S0028 — pages/WMFActivityTabViewController/base.png): white page, 28 vp bold
  // large title, and the nav items as separate round title-bar buttons (NavButton) in the
  // capture's order: More, Tabs, Profile. The logged-out module is a
  // white card inset 16 vp with a 1 vp gray200 hairline, 12 vp radius and 16 vp padding, and
  // its CTA is a theme_link capsule with the person glyph and white 17 vp label.

  // loggedOutView — the logged-out module (title, subtitle, primary CTA).
  @Builder
  loggedOutView() {
    Column() {
      Text($r('app.string.activity_tab_logged_out_title'))
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      Text($r('app.string.activity_tab_logged_out_subtitle'))
        .width('100%')
        .fontSize(17)
        .lineHeight(24)
        .fontColor($r('app.color.theme_text'))
        .margin({ top: 10 })
      Button() {
        Row() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(17)
            .fontColor([(this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'))])
            .margin({ right: 8 })
          Text($r('app.string.profile_page_join_title'))
            .fontSize(17)
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        }
        .alignItems(VerticalAlign.Center)
      }
      .id('log_in_join_wikipedia')
      .type(ButtonType.Capsule)
      .height(46)
      .backgroundColor($r('app.color.theme_link'))
      .padding({ left: 22, right: 22 })
      .margin({ top: 18 })
      .accessibilityText($r('app.string.profile_page_join_title'))
      .onClick(() => {
        this.presentFullLoginFlow();
      })
    }
    // 100% plus the side margins ran the card past the screen edge
    .width('calc(100% - 32vp)')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .margin({ left: 16, right: 16, top: 16 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.gray200') })
  }

  // WMFActivityTabInfoCardView's date: the time for today, otherwise the day.
  private cardDate(ms: number): string {
    const d: Date = new Date(ms);
    const locale: string = i18n.System.getSystemLocale();
    return d.toDateString() === new Date().toDateString()
      ? d.toLocaleTimeString(locale, { hour: 'numeric', minute: '2-digit' })
      : d.toLocaleDateString(locale, { day: 'numeric', month: 'long' });
  }

  // ContributionsView's date: "Today", "Yesterday" or the day.
  private relativeDate(ms: number): string {
    const day: number = 86400000;
    const startOfToday: number = new Date(new Date().toDateString()).getTime();
    if (ms >= startOfToday) {
      return this.resText($r('app.string.today_title'));
    }
    if (ms >= startOfToday - day) {
      return this.resText($r('app.string.yesterday_title'));
    }
    return new Date(ms).toLocaleDateString(i18n.System.getSystemLocale(), { day: 'numeric', month: 'long' });
  }

  // WMFActivityTabInfoCardView header: a small glyph and the bold title, then the date with a
  // chevron (the card opens what it counts).
  @Builder
  infoCardHeader(symbol: Resource, title: ResourceStr, date: string) {
    Row({ space: 6 }) {
      SymbolGlyph(symbol)
        .fontSize(12)
        .fontColor([$r('app.color.theme_text')])
      Text(title)
        .layoutWeight(1)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      if (date !== '') {
        Text(date)
          .fontSize(12)
          .fontColor($r('app.color.theme_secondary_text'))
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(12)
        .fontColor([$r('app.color.theme_secondary_text')])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // articlesReadGraph: one 12 vp bar per week, up to 45 vp tall; an empty week is a 4 vp stub
  // in the border colour.
  @Builder
  weeklyGraph() {
    Row({ space: 6 }) {
      ForEach(this.weeklyReads, (n: number, i: number) => {
        Column()
          .width(12)
          .height(n > 0 ? Math.max(4, 45 * n / Math.max(1, Math.max(...this.weeklyReads))) : 4)
          .borderRadius(1.5)
          // theme.accent, as the source's bars
          .backgroundColor(n > 0 ? $r('app.color.theme_accent') : $r('app.color.theme_border'))
      }, (n: number, i: number) => i + '_' + n)
    }
    .height(45)
    .alignItems(VerticalAlign.Bottom)
    .margin({ right: 8 })
  }

  // ContributionBar: this month's or last month's edits against the larger of the two.
  @Builder
  contributionRow(count: number, label: ResourceStr, max: number, accent: boolean) {
    Column({ space: 4 }) {
      Text(String(count))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_secondary_text'))
      if (count > 0) {
        Column()
          .width(`${Math.round(100 * count / Math.max(1, max))}%`)
          .height(16)
          .borderRadius(3)
          .backgroundColor(accent ? $r('app.color.theme_accent') : $r('app.color.theme_border'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // loggedInList: the reading section ('<name>'s reading', its platform tag, the time spent,
  // the articles read / saved cards, top categories) and the editing section (Your impact).
  @Builder
  loggedInInsights() {
    Column() {
      Text(this.userName !== '' ?
        formatString(getContext(this) as common.Context, $r('app.string.activity_tab_usernames_reading_title'),
          [this.userName]) : this.resText($r('app.string.activity_tab_no_username_reading_title')))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      // headerView's capsule: the source says "ON WIKIPEDIA iOS"; this is the HarmonyOS app
      Text($r('app.string.activity_tab_hours_on_wikipedia_harmonyos'))
        .fontSize(11)
        .fontFamily('monospace')
        .fontColor($r('app.color.theme_text'))
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.blue100'))
        .borderRadius(12)
        .margin({ top: 8 })
      if (this.showTimeSpent) {
        // hoursMinutesRead: bold title with the source's red-orange-yellow-blue gradient
        Text(formatString(getContext(this) as common.Context, $r('app.string.activity_tab_hours_minutes_read'),
          [String(Math.floor(this.minutesThisWeek / 60)), String(this.minutesThisWeek % 60)]))
          .id('activity_time_spent_reading')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .shaderStyle(new LinearGradientStyle({ direction: GradientDirection.Right,
            colors: [['#DD3333', 0], ['#FF9500', 0.33], ['#FFCC33', 0.66], ['#6699FF', 1]] }))
          .margin({ top: 14 })
        Text($r('app.string.activity_tab_time_spent_reading'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .margin({ top: 2 })
      }
      if (this.showReadingInsights) {
        Column() {
          this.infoCardHeader($r('sys.symbol.doc_text'), $r('app.string.activity_tab_articles_read'),
            this.lastReadMs > 0 ? this.cardDate(this.lastReadMs) : '')
          Row() {
            Text(String(this.articlesThisMonth))
              .id('activity_articles_read_count')
              .layoutWeight(1)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
            this.weeklyGraph()
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 16 })
        }
        .id('activity_articles_read')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .margin({ top: 18 })
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.gray200') })
        // onTapModule: scroll to the timeline below
        .onClick(() => {
          this.scroller.scrollTo({ xOffset: 0, yOffset: this.insightsHeight, animation: true });
        })

        // Articles saved this month
        Column() {
          this.infoCardHeader($r('sys.symbol.bookmark'), $r('app.string.activity_tab_saved'),
            this.lastSavedMs > 0 ? this.cardDate(this.lastSavedMs) : '')
          Row() {
            Text(String(this.savedThisMonth))
              .id('activity_articles_saved_count')
              .layoutWeight(1)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
            // savedArticlesImages: up to three 38 vp circles 4 vp apart, then "+N"
            Row({ space: 4 }) {
              ForEach(this.savedThumbs, (url: string) => {
                Image(url)
                  .width(38)
                  .height(38)
                  .borderRadius(19)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor($r('app.color.gray200'))
              }, (url: string) => url)
              if (this.savedThisMonth > this.savedThumbs.length && this.savedThumbs.length > 0) {
                Text(formatString(getContext(this) as common.Context, $r('app.string.activity_tab_remaining_articles'),
                  [String(this.savedThisMonth - this.savedThumbs.length)]))
                  .width(38)
                  .height(38)
                  .borderRadius(19)
                  .textAlign(TextAlign.Center)
                  .fontSize(11)
                  .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
                  .backgroundColor($r('app.color.theme_secondary_text'))
              }
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 16 })
        }
        .id('activity_articles_saved')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .margin({ top: 12 })
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.gray200') })
        // onTapSaved: the Saved tab
        .onClick(() => {
          openRootTab(this.getUIContext().getRouter(), 2);
        })

        // Top categories this month (topCategoriesModule, when there are any)
        if (this.topCategories.length > 0) {
          Column() {
            Text($r('app.string.activity_tab_top_categories'))
              .width('100%')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
            ForEach(this.topCategories, (c: string) => {
              Text(c)
                .width('100%')
                .fontSize(16)
                .fontColor($r('app.color.theme_text'))
                .margin({ top: 8 })
            }, (c: string) => c)
          }
          .id('activity_top_categories')
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.gray200') })
        }
      }

      // Your impact (editing insights): YourImpactHeaderView, ContributionsView, totalEditsView
      if (this.showEditingInsights && (this.totalEdits >= 0 || this.contributions !== null)) {
        Column({ space: 4 }) {
          Text($r('app.string.activity_tab_your_impact'))
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
          if (this.wikiLanguageName !== '') {
            Text($r('app.string.explore_on_wikipedia_format', this.wikiLanguageName))
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
          }
        }
        .width('100%')
        .margin({ top: 24 })
        if (this.contributions !== null) {
          Column({ space: 16 }) {
            this.infoCardHeader($r('sys.symbol.list_bullet'), $r('app.string.activity_tab_contributions_this_month'),
              this.contributions.lastEditMs > 0 ? this.relativeDate(this.contributions.lastEditMs) : '')
            this.contributionRow(this.contributions.thisMonth, $r('app.string.activity_tab_edits_this_month'),
              Math.max(this.contributions.thisMonth, this.contributions.lastMonth), true)
            this.contributionRow(this.contributions.lastMonth, $r('app.string.activity_tab_edits_last_month'),
              Math.max(this.contributions.thisMonth, this.contributions.lastMonth), false)
          }
          .id('activity_contributions')
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.gray200') })
          // navigateToContributions: the user's contributions page
          .onClick(() => {
            this.openContributions();
          })
        }
        if (this.totalEdits >= 0) {
          Column() {
            Text($r('app.string.activity_tab_total_edits'))
              .width('100%')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
            Text(String(this.totalEdits))
              .id('activity_total_edits_count')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
              .margin({ top: 10 })
          }
          .id('activity_total_edits')
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .margin({ top: 12 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.gray200') })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16, top: 20, bottom: 20 })
    // the source's section background: paper fading into soft blue
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [[(this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')), 0], [$r('app.color.blue100'), 1]] })
    .onAreaChange((_o: Area, n: Area) => {
      this.insightsHeight = Number(n.height);
    })
  }

  // navigateToContributions: Special:Contributions/<user> on the app's wiki
  private openContributions(): void {
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
      const params: Record<string, string> = {
        'url': 'https://' + lang.languageCode + '.wikipedia.org/wiki/Special:Contributions/' +
          encodeURIComponent(this.userName.replace(/ /g, '_'))
      };
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
    });
  }

  private resText(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res.id);
    } catch (e) {
      return '';
    }
  }

  // customizedEmptyState() -> WMFSimpleEmptyStateView: every module is off. The image over
  // "Activity modules are turned off. Switch them on to see updates in this tab."; a tap
  // anywhere on the text opens Customize.
  @Builder
  customizedEmptyState() {
    Column() {
      Image($r('app.media.empty_activity_tab'))
        .width(132)
        .height(118)
        .objectFit(ImageFit.Contain)
      Text() {
        Span(formatParts(getContext(this), $r('app.string.activity_tab_customize_empty_state'))[0])
        Span(formatParts(getContext(this), $r('app.string.activity_tab_customize_empty_state'))[1])
          .fontColor($r('app.color.theme_link'))
        Span(formatParts(getContext(this), $r('app.string.activity_tab_customize_empty_state'))[2])
      }
        .fontSize(15)
        .lineHeight(21)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
        .margin({ top: 12, bottom: 8 })
        .onClick(() => {
          this.showCustomize = true;
        })
    }
    .id('activity_customized_empty_state')
    .width('100%')
    .padding({ left: 16, right: 16, top: 120 })
    .alignItems(HorizontalAlign.Center)
  }

  // TimelineHeaderView — the section's day.
  @Builder
  timelineHeader(section: HistorySection) {
    // the day in the device language ('25 Eylül 2026 Cuma'), not toDateString()'s English
    Text(new Date(section.dateWithoutTime).toLocaleDateString(i18n.System.getSystemLocale(),
      { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }))
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 20, bottom: 6 })
  }

  // TimelineRowView — comp_page_row over the item, tapping through to the article.
  @Builder
  timelineRow(item: HistoryItem) {
    Column() {
      WMFPageRow({
        titleHtml: item.titleHtml,
        articleDescription: item.description ?? '',
        imageURLString: item.imageURLString ?? ''
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .id('activity_timeline_itemroot')
    .onClick(() => {
      this.openArticle(item);
    })
  }

  // moreBarButtonItem's overflow items: SF-symbol outlines in the label colour, one style for all
  // four (gearshape / info.circle / clock.badge.xmark / flag).
  private menuSymbol(res: Resource): SymbolGlyphModifier {
    return new SymbolGlyphModifier(res).fontColor([$r('app.color.theme_text')]);
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
      // WMFNavigationBar: the "Activity" title with the profile / tabs / overflow items.
      Row() {
        Text($r('app.string.activity_tab_title'))
          .layoutWeight(1)
          .fontSize(ROOT_TITLE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        // the three bar-button items, each its own round button, in the capture's order.
        Row({ space: NAV_BUTTON_GAP }) {
          // moreBarButtonItem's overflowMenu (UIMenu .displayInline): customizeAction,
          // learnMoreAction, clearAction, reportIssueAction.
          Button() {
            Image($r('app.media.more'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              // theme text colour, like the Tabs and profile glyphs beside it: the fixed
              // near-black vanished on the dark and black themes
              .colorFilter(navIconTint(this.isDark))
          }
          .id('activity_tab_more')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText('More')
          // Each row carries its own glyph, as the source's menu does; the last row is
          // "Problem with feature", not a question.
          .bindMenu([
            {
              value: $r('app.string.customize_action_title'),
              symbolIcon: this.menuSymbol($r('sys.symbol.gearshape')),
              action: (): void => {
                this.userDidTapCustomize();
              }
            },
            {
              value: $r('app.string.learn_more_title'),
              symbolIcon: this.menuSymbol($r('sys.symbol.info_circle')),
              action: (): void => {
                this.userDidTapLearnMore();
              }
            },
            {
              value: $r('app.string.activity_tab_menu_clear_history'),
              symbolIcon: this.menuSymbol($r('sys.symbol.clock')),
              action: (): void => {
                this.userDidTapClearReadingHistory();
              }
            },
            {
              value: $r('app.string.problem_with_feature_title'),
              symbolIcon: this.menuSymbol($r('sys.symbol.flag')),
              action: (): void => {
                this.userDidTapReportIssue();
              }
            }
          ])
          Button() {
            Image($r('app.media.article_tabs_square'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.theme_text'))
          }
          .id('Tabs Button')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText('Tabs')
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
          .accessibilityText('Profile')
          .onClick(() => {
            this.openProfile();
          })
          // On the button, not the page root: the root already carries the Customize sheet,
          // and a second bindSheet on the same node replaced this one, so Profile did nothing.
          .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(),
            { height: SheetSize.LARGE, dragBar: false, showClose: false })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .height(ROOT_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })

      Scroll(this.scroller) {
        Column() {
          // conditionalVariant: authenticationState == .loggedOut -> the logged-out module
          // above the timeline.
          if (!this.isLoggedIn) {
            this.loggedOutView()
          } else if (!this.isLoading && !this.showTimeSpent && !this.showReadingInsights &&
            !this.showEditingInsights && !this.showTimeline) {
            this.customizedEmptyState()
          } else if (!this.isLoading && (this.showTimeSpent || this.showReadingInsights || this.showEditingInsights)) {
            this.loggedInInsights()
          }

          // isTimelineOfBehaviorOn: a signed-in reader who turned the timeline off sees none
          if (!this.isLoggedIn || this.showTimeline) {
            // conditionalVariant: no history -> WMFEmptyView(.noItems); otherwise the timeline.
            // recomputeShouldShowEmptyState(): sections.count == 0, or none of their items is a
            // read item (every ported item is one, so an empty flat list stands for it).
            if (this.isLoading) {
              // body: isLoading -> ProgressView()
              Column() {
                LoadingProgress()
                  .width(36)
                  .height(36)
                  .color($r('app.color.theme_secondary_text'))
              }
              .width('100%')
              .padding({ top: 64, bottom: 64 })
              .alignItems(HorizontalAlign.Center)
            } else if (this.loadError !== '') {
              EmptyViewController({
                emptyTitle: 'Unable to load your activity',
                message: 'Something went wrong. Pull up the tab again to retry.'
              })
            } else if (this.history.length === 0 || this.items.length === 0) {
              EmptyViewController({
                emptyTitle: 'No history to show',
                message: 'Articles you read will appear here'
              })
            } else if (this.isLoggedIn) {
              // loggedOutList: signed out, the list carries the logged-out module only - the
              // timeline sections belong to a signed-in reader (WMFActivityTabView.swift:231).
              ForEach(this.history, (section: HistorySection) => {
                Column() {
                  this.timelineHeader(section)
                  ForEach(section.items, (item: HistoryItem) => {
                    this.timelineRow(item)
                  }, (item: HistoryItem) => item.id)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }, (section: HistorySection) => section.dateWithoutTime.toString())
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)

      // persistent root tab bar (UITabBarController) — Activity is tab 3
      RootTabBar({ selected: 3 })
    }
    .id('WMFActivityTabViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindContentCover($$this.showArticleTabs, this.articleTabsBuilder())
    // dragBar: the sheet is dismissed by dragging its handle past the threshold, and springs
    // back below it — both are the sheet's own behaviour, not something the page drives.
    .bindSheet($$this.showCustomize, this.customizeBuilder(),
      {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE], dragBar: true, showClose: false,
        // the insight modules follow the toggles as soon as the sheet goes away
        onDisappear: (): void => {
          this.reloadTimeline();
        }
      })
  }

  private openProfile(): void {
    this.showProfileSheet = true;
  }

  private openArticleTabs(): void {
    router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
      console.error('article tabs push failed: ' + e.message);
    });
  }

  // didTapPrimaryLoggedOutCTA -> presentFullLoginFlow()
  // A routed page, as the profile sheet's login is: this page already binds one content
  // cover, a second one on the same node never showed, so the CTA did nothing.
  private presentFullLoginFlow(): void {
    router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
      console.error('activity tab: login route failed: ' + e.message);
    });
  }

  // customizeAction -> userDidTapCustomize(): the activity-tab customize settings.
  private userDidTapCustomize(): void {
    this.showCustomize = true;
  }

  // learnMoreAction -> userDidTapLearnMore(): the activity FAQ page.
  private userDidTapLearnMore(): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage' }).catch((e: Error) => {
      console.error('activity tab: learn more route failed: ' + e.message);
    });
  }

  // clearAction -> userDidTapClearReadingHistory(): clears the CDPageView history the
  // timeline reads, then re-renders it.
  private userDidTapClearReadingHistory(): void {
    HistoryStore.clearReadHistory().then(() => {
      this.reloadTimeline();
    }).catch((e: Error) => {
      console.error('activity tab: clear history failed: ' + e.message);
    });
  }

  // reportIssueAction -> userDidTapReportIssue(): the source opens a mail composer to the app
  // support address with the Activity Tab issue template (activity_tab_email_*), not a help page.
  private lastReportTap: number = 0;

  private userDidTapReportIssue(): void {
    // a double tap must not open two composers
    if (Date.now() - this.lastReportTap < 1500) {
      return;
    }
    this.lastReportTap = Date.now();
    const ctx = getContext(this) as common.UIAbilityContext;
    const s = (r: Resource): string => {
      try {
        return ctx.resourceManager.getStringSync(r.id);
      } catch (e) {
        return '';
      }
    };
    const body: string = [s($r('app.string.activity_tab_email_first_line')), '',
      s($r('app.string.activity_tab_email_second_line')), '',
      s($r('app.string.activity_tab_email_third_line')), '',
      s($r('app.string.activity_tab_email_fourth_line')), '',
      s($r('app.string.activity_tab_email_fifth_line'))].join('\n');
    const mailto: string = 'mailto:ios-support@wikimedia.org?subject=' +
      encodeURIComponent(s($r('app.string.activity_tab_email_title'))) + '&body=' + encodeURIComponent(body);
    try {
      ctx.openLink(mailto).catch((e: Error) => {
        console.error('activity tab: no mail composer: ' + e.message);
        this.getUIContext().getPromptAction().showToast({ message: 'ios-support@wikimedia.org' });
      });
    } catch (e) {
      console.error('activity tab: mailto rejected: ' + (e as Error).message);
      this.getUIContext().getPromptAction().showToast({ message: 'ios-support@wikimedia.org' });
    }
  }

  // timelineViewModel.onTap(item) — opens the article the row stands for.
  private openArticle(item: HistoryItem): void {
    const params: Record<string, string> = { 'articleTitle': item.titleHtml, 'articleKey': item.articleKey };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('activity tab: article route failed: ' + e.message);
      });
  }
}
