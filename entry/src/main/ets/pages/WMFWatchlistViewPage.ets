// screen_watchlist — presentation: page, reached from the profile.
// Ported from WMFComponents/.../Watchlist/WMFWatchlistView.swift: a ZStack over the paper
// background whose contentView branches on the view model — ProgressView until
// hasPerformedInitialFetch, then WMFWatchlistContentView when there are sections, else
// WMFEmptyView(.filter) when activeFilterCount > 0, else WMFEmptyView(.noItems).
// WMFWatchlistContentView is a ScrollView + LazyVStack: per local day a bold uppercased full
// date, then one WMFWatchlistViewCell per item — a bordered rounded card with the local time
// and the "N bytes" change in an 80 pt column and, on the right, the full page title with its
// project icon, the HTML-stripped edit summary (italic "Empty edit summary" when empty) and
// the username capsule menu (user page / talk page / contributions / thank). Tapping a cell
// opens that revision's diff (watchlistUserDidTapDiff).
// The navigation bar is the source's: back button, centred title, "Filter" text button, which
// presents WMFWatchlistFilterView (WMFFormView: Wikimedia Projects, Wikipedias, Latest
// Revisions, Watchlist Activity, Automated Contributions, Significance, User registration,
// Type of change). The settings are saved when the sheet closes and the list is refetched.
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { WMFWatchlistItem, WMFWatchlist } from '../model/WMFWatchlistItem';
import { WatchlistService, WatchlistFilterSettings, WatchlistProject, COMMONS_HOST, WIKIDATA_HOST }
  from '../common/WatchlistService';
import { SessionStore } from '../common/SessionStore';
import { Prefs, PrefKeys } from '../common/Prefs';
import { WMFOnboardingView, WMFOnboardingCellModel } from '../components/WMFOnboardingView';

import { decodeEntities } from '../common/WebDocument';
import { NAV_ICON_BUTTON, NAV_TEXT_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// viewModel.sections — items grouped by local day.
export class WatchlistSection {
  key: string = '';
  title: string = '';
  items: WMFWatchlistItem[] = [];
}

class WatchlistSectionDataSource implements IDataSource {
  private sections: WatchlistSection[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.sections.length;
  }

  getData(index: number): WatchlistSection {
    return this.sections[index];
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

  reload(sections: WatchlistSection[]): void {
    this.sections = sections;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

// sortWatchlistItems(): newest first, one section per local calendar day
// (Calendar.current.startOfDay), titled with the full date (wmfFullDateFormatter).
function groupByDay(items: WMFWatchlistItem[]): WatchlistSection[] {
  const locale: string = i18n.System.getSystemLocale();
  const sorted: WMFWatchlistItem[] = items.slice().sort(
    (a: WMFWatchlistItem, b: WMFWatchlistItem): number => Date.parse(b.timestamp) - Date.parse(a.timestamp));
  const out: WatchlistSection[] = [];
  for (const item of sorted) {
    const d: Date = new Date(item.timestamp);
    const key: string = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
    if (out.length === 0 || out[out.length - 1].key !== key) {
      const section = new WatchlistSection();
      section.key = key;
      section.title = d.toLocaleDateString(locale,
        { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).toLocaleUpperCase();
      out.push(section);
    }
    out[out.length - 1].items.push(item);
  }
  return out;
}

// A black template logo redrawn in one colour (its alpha kept).
function logoTint(hex: string): ColorFilter {
  const n: number = parseInt(hex.replace('#', ''), 16);
  return new ColorFilter([
    0, 0, 0, 0, ((n >> 16) & 0xFF) / 255,
    0, 0, 0, 0, ((n >> 8) & 0xFF) / 255,
    0, 0, 0, 0, (n & 0xFF) / 255,
    0, 0, 0, 1, 0
  ]);
}

// One option of a single-select filter section: its label and the settings value it stands for.
class FilterOption {
  label: Resource;
  value: number;

  constructor(label: Resource, value: number) {
    this.label = label;
    this.value = value;
  }
}

@Entry
@Component
struct WMFWatchlistViewPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  @StorageProp('wmfIsDark') wmfIsDark: boolean = false;

  @State items: WatchlistSection[] = [];
  // ViewControllerRouter.showWatchlistOnboarding: once, on the first visit
  @State showOnboarding: boolean = false;
  @State hasPerformedInitialFetch: boolean = false;
  // activeFilterCount — decides which empty view is shown
  @State activeFilterCount: number = 0;
  // conditionalVariant: a watchlist needs a permanent account
  @State isLoggedIn: boolean = false;
  @State showFilterSheet: boolean = false;
  // S6: a failed fetch must not read as "you have no watched pages".
  @State loadError: string = '';
  // the filter form's working copy (WMFWatchlistFilterViewModel.formViewModel)
  @State filterProjects: WatchlistProject[] = [];
  @State offProjects: string[] = [];
  @State latestRevisions: number = 1;
  @State activity: number = 0;
  @State automatedContributions: number = 0;
  @State significance: number = 0;
  @State userRegistration: number = 0;
  @State offTypes: number[] = [];
  private sectionsSource: WatchlistSectionDataSource = new WatchlistSectionDataSource();
  // set when "Add language..." leaves for the language list; the list is refetched on return
  private reloadOnShow: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    this.sectionsSource.reload(this.items);
    // WMFWatchlistView needs a permanent account (viewModel is only fetched when signed in)
    SessionStore.restore();
    this.isLoggedIn = SessionStore.isLoggedIn;
    if (!this.isLoggedIn) {
      return;
    }
    if (!Prefs.getBoolean(PrefKeys.userHasOnboardedToWatchlists, false)) {
      this.showOnboarding = true;
      Prefs.putBoolean(PrefKeys.userHasOnboardedToWatchlists, true);
    }
    this.reload();
  }

  @Builder
  onboardingSheet() {
    WMFOnboardingView({
      title: $r('app.string.watchlist_onboarding_title'),
      cells: [
        new WMFOnboardingCellModel($r('app.media.track_changes'), $r('app.string.watchlist_track_title'),
          $r('app.string.watchlist_track_subtitle')),
        new WMFOnboardingCellModel($r('app.media.watch_articles'), $r('app.string.watchlist_watch_title'),
          $r('app.string.watchlist_watch_subtitle')),
        new WMFOnboardingCellModel($r('app.media.set_expiration'), $r('app.string.watchlist_expiration_title'),
          $r('app.string.watchlist_expiration_subtitle')),
        new WMFOnboardingCellModel($r('app.media.view_updates'), $r('app.string.watchlist_updates_title'),
          $r('app.string.watchlist_updates_subtitle'))
      ],
      primaryButtonTitle: $r('app.string.continue_button_title'),
      secondaryButtonTitle: $r('app.string.watchlist_onboarding_button_title'),
      onPrimary: (): void => {
        this.showOnboarding = false;
      },
      onSecondary: (): void => {
        this.showOnboarding = false;
        router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage',
          params: { 'url': 'https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_FAQ#Watchlist' } });
      }
    })
  }

  onPageShow(): void {
    if (this.reloadOnShow) {
      this.reloadOnShow = false;
      this.reload();
    }
  }

  private reload(): void {
    this.load().catch((e: Error) => {
      console.error('watchlist: load failed: ' + e.message);
    });
  }

  // fetchWatchlist() -> viewModel.sections
  private async load(): Promise<void> {
    try {
      const watchlist: WMFWatchlist = await WatchlistService.fetchWatchlist();
      this.items = groupByDay(watchlist.items);
      this.activeFilterCount = watchlist.activeFilterCount;
      this.loadError = '';
      this.sectionsSource.reload(this.items);
    } catch (e) {
      console.error('watchlist: fetch failed: '
        + (e instanceof Error ? e.message : JSON.stringify(e)));
      this.items = [];
      this.sectionsSource.reload(this.items);
      this.loadError = 'Your watchlist could not be loaded. Check your connection.';
    }
    this.hasPerformedInitialFetch = true;
  }

  // timestampString — wmfShortTimeFormatter: the local time in the device's style.
  private timeOfDay(timestamp: string): string {
    return new Date(timestamp).toLocaleTimeString(i18n.System.getSystemLocale(),
      { hour: 'numeric', minute: '2-digit' });
  }

  private byteChange(item: WMFWatchlistItem): number {
    return item.byteLength - item.oldByteLength;
  }

  // bytesString — "watchlist-byte-change": {{PLURAL:$1|$1 byte|$1 bytes}}
  private bytesString(item: WMFWatchlistItem): string {
    const n: number = this.byteChange(item);
    return n.toString() + (Math.abs(n) === 1 ? ' byte' : ' bytes');
  }

  // bytesTextColorKeyPath: 0 secondaryText, > 0 accent, < 0 destructive
  private bytesColor(item: WMFWatchlistItem): Resource {
    const n: number = this.byteChange(item);
    return n === 0 ? $r('app.color.theme_secondary_text')
      : (n > 0 ? $r('app.color.theme_accent') : $r('app.color.theme_destructive'));
  }

  // comment — htmlStripped(commentHTML) (String.removingHTML)
  private comment(item: WMFWatchlistItem): string {
    return decodeEntities(item.commentHtml.replace(/<[^>]*>/g, '')).trim();
  }

  private wikiUrl(host: string, title: string): string {
    return 'https://' + host + '/wiki/' + encodeURIComponent(title.replace(/ /g, '_'));
  }

  private openWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  // watchlistUserDidTapDiff(project:title:revisionID:oldRevisionID:)
  private openDiff(item: WMFWatchlistItem): void {
    if (item.revisionID === 0) {
      return;
    }
    const params: Record<string, string> = {
      'host': item.project,
      'articleTitle': item.title,
      'fromID': item.oldRevisionID.toString(),
      'toID': item.revisionID.toString(),
      'toTime': item.timestamp,
      'toUser': item.username,
      'toComment': this.comment(item),
      'toSize': this.byteChange(item).toString(),
      'mode': 'compare'
    };
    router.pushUrl({ url: 'pages/DiffContainerViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('watchlist: diff route failed: ' + e.message);
      });
  }

  // userButtonThank: action=thank for the revision, then the source's success toast.
  private thank(item: WMFWatchlistItem): void {
    WatchlistService.thank(item.project, item.revisionID).then((ok: boolean) => {
      if (ok) {
        promptAction.showToast({ message: `Your ‘Thanks’ was sent to ${item.username}` });
      }
    }).catch((e: Error) => {
      console.error('watchlist: thank failed: ' + e.message);
    });
  }

  // menuButtonItems / menuButtonItemsWithoutThank (bots and anonymous editors)
  private userMenu(item: WMFWatchlistItem): MenuElement[] {
    const menu: MenuElement[] = [
      { value: $r('app.string.watchlist_user_button_user_page'), action: () => { this.openWeb(this.wikiUrl(item.project, 'User:' + item.username)); } },
      { value: $r('app.string.watchlist_user_button_user_talk_page'),
        // the native talk page on a Wikipedia (project.supportsNativeUserTalkPages); Commons and
        // Wikidata keep the web page
        action: () => {
          if (item.project.endsWith('.wikipedia.org')) {
            router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: {
              'talkPageTitle': 'User talk:' + item.username, 'languageCode': item.project.split('.')[0] } });
          } else {
            this.openWeb(this.wikiUrl(item.project, 'User_talk:' + item.username));
          }
        } },
      { value: $r('app.string.watchlist_user_button_user_contributions'),
        action: () => { this.openWeb(this.wikiUrl(item.project, 'Special:Contributions/' + item.username)); } }
    ];
    if (!item.isBot && !item.isAnon) {
      menu.push({ value: $r('app.string.watchlist_user_button_thank'), action: () => { this.thank(item); } });
    }
    return menu;
  }

  // WMFProjectIconView: the language code in a thin rounded box, or the project's logo.
  @Builder
  projectIcon(host: string) {
    if (host === COMMONS_HOST || host === WIKIDATA_HOST) {
      Image(host === COMMONS_HOST ? $r('app.media.project_commons') : $r('app.media.project_wikidata'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
        .colorFilter(logoTint(this.wmfIsDark ? '#C8CCD1' : '#72777D'))
        .margin({ left: 8 })
    } else {
      Text(host.split('.')[0].toUpperCase())
        .fontSize(12)
        .fontColor($r('app.color.theme_secondary_text'))
        .padding({ left: 3, right: 3, top: 4, bottom: 4 })
        .border({ width: 1, color: $r('app.color.theme_secondary_text'), radius: 4 })
        .margin({ left: 8 })
    }
  }

  // WMFWatchlistViewCell
  @Builder
  watchlistCell(item: WMFWatchlistItem) {
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Text(this.timeOfDay(item.timestamp))
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
        Text(this.bytesString(item))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.bytesColor(item))
      }
      .width(80)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Row() {
          Text(item.title)
            .layoutWeight(1)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_text'))
          this.projectIcon(item.project)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.comment(item) !== '' ? this.comment(item) : $r('app.string.empty_edit_summary'))
          .width('100%')
          .fontSize(13)
          .fontStyle(this.comment(item) !== '' ? FontStyle.Normal : FontStyle.Italic)
          .fontColor($r('app.color.theme_secondary_text'))

        // WMFSmallSwiftUIMenuButton(title: username, image: person.fill / temp)
        Row({ space: 6 }) {
          if (item.isTemp) {
            Image($r('app.media.tempaccounticon'))
              .width(13)
              .height(13)
              .fillColor($r('app.color.theme_link'))
          } else {
            SymbolGlyph($r('sys.symbol.person_fill'))
              .fontSize(13)
              .fontColor([$r('app.color.theme_link')])
          }
          Text(item.username)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_link'))
        }
        .id('watchlist_user_menu_itemroot')
        .padding(8)
        .borderRadius(100)
        .backgroundColor(this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background'))
        .bindMenu(this.userMenu(item))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .border({ width: 0.5, color: $r('app.color.theme_border'), radius: 8 })
    .alignItems(VerticalAlign.Top)
  }

  // --- WMFWatchlistFilterView (WMFFormView) -------------------------------------------------

  private openFilter(): void {
    const s: WatchlistFilterSettings = WatchlistService.loadFilterSettings();
    this.offProjects = s.offProjects;
    this.latestRevisions = s.latestRevisions;
    this.activity = s.activity;
    this.automatedContributions = s.automatedContributions;
    this.significance = s.significance;
    this.userRegistration = s.userRegistration;
    this.offTypes = s.offTypes;
    WatchlistService.allProjects().then((all: WatchlistProject[]) => {
      // Commons and Wikidata first (section 1), then the Wikipedias (section 2)
      this.filterProjects = all.filter((p: WatchlistProject) => p.languageCode === '')
        .concat(all.filter((p: WatchlistProject) => p.languageCode !== ''));
      this.showFilterSheet = true;
    }).catch((e: Error) => {
      console.error('watchlist: projects failed: ' + e.message);
    });
  }

  // viewWillDisappear: saveNewFilterSettings(), then watchlistFilterDidChange refetches.
  private saveFilter(): void {
    const s = new WatchlistFilterSettings();
    s.offProjects = this.offProjects;
    s.latestRevisions = this.latestRevisions;
    s.activity = this.activity;
    s.automatedContributions = this.automatedContributions;
    s.significance = this.significance;
    s.userRegistration = this.userRegistration;
    s.offTypes = this.offTypes;
    WatchlistService.saveFilterSettings(s);
    this.reload();
  }

  private selected(key: string): number {
    switch (key) {
      case 'latest': return this.latestRevisions;
      case 'activity': return this.activity;
      case 'bot': return this.automatedContributions;
      case 'minor': return this.significance;
      default: return this.userRegistration;
    }
  }

  private select(key: string, value: number): void {
    switch (key) {
      case 'latest': this.latestRevisions = value; break;
      case 'activity': this.activity = value; break;
      case 'bot': this.automatedContributions = value; break;
      case 'minor': this.significance = value; break;
      default: this.userRegistration = value; break;
    }
  }

  private toggleProject(host: string, isOn: boolean): void {
    const off: string[] = this.offProjects.filter((h: string) => h !== host);
    if (!isOn) {
      off.push(host);
    }
    this.offProjects = off;
  }

  private toggleType(type: number, isOn: boolean): void {
    const off: number[] = this.offTypes.filter((t: number) => t !== type);
    if (!isOn) {
      off.push(type);
    }
    this.offTypes = off;
  }

  @Builder
  formHeader(title: Resource) {
    Text(title)
      .width('100%')
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 24, bottom: 8 })
  }

  // inset on both sides; rows with a project logo start it after the logo
  @Builder
  formDivider(left: number = 16) {
    Divider()
      .strokeWidth(0.5)
      .color($r('app.color.theme_border'))
      .margin({ left: left, right: 16 })
  }

  // WMFFormSelectMultiRowView: optional project logo, title, switch
  @Builder
  projectRow(p: WatchlistProject) {
    Row({ space: 12 }) {
      if (p.languageCode === '') {
        Stack() {
          Image(p.host === COMMONS_HOST ? $r('app.media.project_commons') : $r('app.media.project_wikidata'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .colorFilter(logoTint('#FFFFFF'))
        }
        .width(32)
        .height(32)
        .borderRadius(7)
        .backgroundColor('#72777D')
      }
      Text(p.name)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
      Toggle({ type: ToggleType.Switch, isOn: this.offProjects.indexOf(p.host) < 0 })
        .selectedColor($r('app.color.theme_accent'))
        .onChange((isOn: boolean) => {
          this.toggleProject(p.host, isOn);
        })
    }
    .width('100%')
    .height(p.languageCode === '' ? 62 : 52)
    .padding({ left: 16, right: 16 })
  }

  // WMFFormSelectSingleRowView: title and a checkmark on the selected row
  @Builder
  singleSection(header: Resource, key: string, options: FilterOption[]) {
    this.formHeader(header)
    Column() {
      ForEach(options, (o: FilterOption, i: number) => {
        if (i > 0) {
          this.formDivider()
        }
        Row() {
          Text(o.label)
            .layoutWeight(1)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_link')])
            .visibility(this.selected(key) === o.value ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.select(key, o.value);
        })
      }, (o: FilterOption) => key + o.value.toString())
    }
    .formCard(this.wmfPaperBg)
  }

  @Builder
  filterSheet() {
    Column() {
      // titleConfig "Filter" (centerCompact) + WMFLargeCloseButtonConfig(.prominentCheck)
      Stack() {
        Text($r('app.string.watchlist_filter'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Blank()
          Button() {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(22)
              .fontColor([Color.White])
          }
          .id('watchlist_filter_done')
          .type(ButtonType.Circle)
          .width(44)
          .height(44)
          .backgroundColor($r('app.color.theme_link'))
          .onClick(() => {
            this.showFilterSheet = false;
          })
        }
        .width('100%')
      }
      .width('100%')
      .height(64)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          this.formHeader($r('app.string.notifications_center_inbox_wikimedia_projects_section_title'))
          Column() {
            ForEach(this.filterProjects.filter((p: WatchlistProject) => p.languageCode === ''),
              (p: WatchlistProject, i: number) => {
                if (i > 0) {
                  this.formDivider(60)
                }
                this.projectRow(p)
              }, (p: WatchlistProject) => p.host)
          }
          .formCard(this.wmfPaperBg)

          this.formHeader($r('app.string.notifications_center_inbox_wikipedias_section_title'))
          Column() {
            ForEach(this.filterProjects.filter((p: WatchlistProject) => p.languageCode !== ''),
              (p: WatchlistProject) => {
                this.projectRow(p)
                this.formDivider()
              }, (p: WatchlistProject) => p.host)
            // WMFFormSelectableAccessoryRowView: "Add language..."
            Text($r('app.string.watchlist_filters_add_language'))
              .width('100%')
              .height(52)
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.showFilterSheet = false;
                this.reloadOnShow = true;
                router.pushUrl({ url: 'pages/WMFPreferredLanguagesViewControllerPage' });
              })
          }
          .formCard(this.wmfPaperBg)

          this.singleSection($r('app.string.watchlist_filter_latest_revisions_header'), 'latest', [
            new FilterOption($r('app.string.watchlist_filter_latest_revisions_options_not_latest_revision'), 1),
            new FilterOption($r('app.string.watchlist_filter_latest_revisions_options_latest_revision'), 0)
          ])
          this.singleSection($r('app.string.watchlist_filter_activity_header'), 'activity', [
            new FilterOption($r('app.string.filter_options_all'), 0),
            new FilterOption($r('app.string.watchlist_filter_activity_options_unseen_changes'), 1),
            new FilterOption($r('app.string.watchlist_filter_activity_options_seen_changes'), 2)
          ])
          this.singleSection($r('app.string.watchlist_filter_automated_contributions_header'), 'bot', [
            new FilterOption($r('app.string.filter_options_all'), 0),
            new FilterOption($r('app.string.watchlist_filter_automated_contributions_options_bot'), 1),
            new FilterOption($r('app.string.watchlist_filter_automated_contributions_options_human'), 2)
          ])
          this.singleSection($r('app.string.watchlist_filter_significance_header'), 'minor', [
            new FilterOption($r('app.string.filter_options_all'), 0),
            new FilterOption($r('app.string.watchlist_filter_significance_options_minor_edits'), 1),
            new FilterOption($r('app.string.watchlist_filter_significance_options_non_minor_edits'), 2)
          ])
          this.singleSection($r('app.string.watchlist_filter_user_registration_header'), 'registration', [
            new FilterOption($r('app.string.filter_options_all'), 0),
            new FilterOption($r('app.string.watchlist_filter_user_registration_options_unregistered'), 1),
            new FilterOption($r('app.string.watchlist_filter_user_registration_options_registered'), 2)
          ])

          // section 8: Type of change (multi)
          this.formHeader($r('app.string.watchlist_filter_type_of_change_header'))
          Column() {
            ForEach([
              new FilterOption($r('app.string.watchlist_filter_type_of_change_options_page_edits'), 0),
              new FilterOption($r('app.string.watchlist_filter_type_of_change_options_page_creations'), 1),
              new FilterOption($r('app.string.watchlist_filter_type_of_change_options_category_changes'), 2),
              new FilterOption($r('app.string.watchlist_filter_type_of_change_options_wikidata_edits'), 3),
              new FilterOption($r('app.string.watchlist_filter_type_of_change_options_logged_actions'), 4)
            ], (o: FilterOption, i: number) => {
              if (i > 0) {
                this.formDivider()
              }
              Row() {
                Text(o.label)
                  .layoutWeight(1)
                  .fontSize(17)
                  .fontColor($r('app.color.theme_text'))
                Toggle({ type: ToggleType.Switch, isOn: this.offTypes.indexOf(o.value) < 0 })
                  .selectedColor($r('app.color.theme_accent'))
                  .onChange((isOn: boolean) => {
                    this.toggleType(o.value, isOn);
                  })
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
            }, (o: FilterOption) => 'type' + o.value.toString())
          }
          .formCard(this.wmfPaperBg)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background'))
  }

  build() {
    Column() {
      // the onboarding sheet's anchor (one bindSheet per node; the root has the filters)
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showOnboarding, this.onboardingSheet(), { height: SheetSize.LARGE, showClose: false,
          dragBar: false })
      // configureNavigationBar(titleConfig: "Watchlist", alignment: .centerCompact) + filter
      Stack() {
        Text($r('app.string.watchlist'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
          .id('BackButton')
          .accessibilityText('Back')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            router.back();
          })
          Blank()
          if (this.isLoggedIn) {
            Button($r('app.string.watchlist_filter'))
              .id('watchlist_filter')
              .attributeModifier(NAV_TEXT_BUTTON)
              .fontColor($r('app.color.theme_text'))
              .onClick(() => {
                this.openFilter();
              })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (!this.isLoggedIn) {
        // conditionalVariant(isLoggedIn == false): the login prompt replaces the list
        Column() {
          Text('Log in to see your watchlist')
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .id('watchlist_logged_out')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else if (!this.hasPerformedInitialFetch) {
        // ProgressView()
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('app.color.theme_link'))
          .margin({ top: 48 })
      } else if (this.items.length > 0) {
        List() {
          LazyForEach(this.sectionsSource, (section: WatchlistSection) => {
            ListItem() {
              Column() {
                Text(section.title)
                  .width('100%')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.theme_secondary_text'))
                  .padding({ top: 6, bottom: 6 })
                ForEach(section.items, (item: WMFWatchlistItem) => {
                  Column() {
                    this.watchlistCell(item)
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                  .onClick(() => {
                    this.openDiff(item);
                  })
                }, (item: WMFWatchlistItem) => item.project + item.revisionID.toString() + item.timestamp)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ bottom: 14 })
            }
            // one row of a repeated list — shared id, index-resolved by replay (Rule 12)
            .id('watchlist_itemroot')
          }, (section: WatchlistSection) => section.key + section.items.length.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      } else if (this.activeFilterCount > 0) {
        // WMFEmptyView(type: .filter)
        Text($r('app.string.watchlist_empty_view_filter_title'))
          .id('watchlist_empty_filter')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_secondary_text'))
          .padding({ left: 32, right: 32, top: 48, bottom: 48 })
      } else {
        // WMFEmptyView(type: .noItems) — or the failure text, so a dead network never
        // reads as an empty watchlist.
        Text(this.loadError !== '' ? this.loadError : 'You have no watched pages')
          .id('watchlist_empty_no_items')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_secondary_text'))
          .padding({ left: 32, right: 32, top: 48, bottom: 48 })
      }
    }
    .id('WMFWatchlistView')
    .width('100%')
    .height('100%')
    .backgroundColor(this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'))
    .bindSheet($$this.showFilterSheet, this.filterSheet(), {
      height: SheetSize.LARGE,
      showClose: false,
      dragBar: false,
      onDisappear: () => {
        this.saveFilter();
      }
    })
  }
}

// insetGrouped section card
@Extend(Column)
function formCard(paperBg: string) {
  .width('100%')
  .borderRadius(24)
  .clip(true)
  .backgroundColor(paperBg !== '' ? paperBg : $r('app.color.theme_paper_background'))
}
