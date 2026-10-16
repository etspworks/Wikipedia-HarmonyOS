// screen_notifications_center — presentation: page.
// Ported from Wikipedia/Code/NotificationsCenterViewController.swift +
// NotificationsCenterView.swift: a collection view of NotificationsCenterCell rows over the
// empty view (updateEmptyDisplayState hides the collection and shows the empty header +
// subheader), with a bottom toolbar. setToolbarItems in the non-editing state is
// [typeFilterButton, statusBarButton, projectFilterButton] and in editing (the nav bar's
// editButtonItem) [markButton, markAllAsReadButton]. The filter buttons are the source's
// glyphs: line.horizontal.3.decrease.circle(.fill) for the type filter, tray.2 / tray.fill
// for the project filter (NotificationsCenterViewModel.toolbarImageFor*Filter).
// In editing a tap selects the cell; Mark acts on the selection.
// Wired edge: notifications_center -> notifications_center_detail (row tap).
// S5: styled on the app baseline. S0196 settled on the "Editing notifications" education
// modal rather than the inbox, so the inbox styling comes from the source's own roles —
// a plain white list page, centre-compact nav title, and a toolbar of .label-tinted items.
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { RemoteNotification, RemoteNotificationLink } from '../model/RemoteNotification';
import { destinationForURL, LinkDestination } from '../common/WikiLinks';
import { intentForDestination } from '../entryability/RouteTable';
import { NotificationsService, NotificationsPage } from '../common/NotificationsService';
import { SessionStore } from '../common/SessionStore';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { WMFOnboardingView, WMFOnboardingCellModel } from '../components/WMFOnboardingView';

import { NotificationsCenterCell } from '../components/NotificationsCenterCell';
import { EmptyViewController } from '../components/EmptyViewController';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE, NAV_BUTTON_SIZE } from '../components/NavButton';
import { upperText } from '../common/LocaleText';
import { pluralString } from '../common/Plural';
import { NotificationsFilterState, NotificationFilterType, NOTIFICATION_FILTER_TYPES, passesTypeFilter } from '../common/NotificationsFilterState';

// NotificationsCenterInboxViewModel: one selectable project of the Projects sheet.
class InboxProject {
  wiki: string = '';                               // Echo wiki id: enwiki, commonswiki, ...
  title: string = '';
  icon: Resource | null = null;
}

// IDataSource over the inbox (ambient IDataSource/DataChangeListener).
class NotificationsDataSource implements IDataSource {
  private items: RemoteNotification[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): RemoteNotification {
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

  reload(items: RemoteNotification[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// an inset grouped List section: the rounded paper card
@Extend(Column)
function filtersGroup(paperBg: string) {
  .width('auto')
  .margin({ left: 16, right: 16 })
  .backgroundColor(paperBg !== '' ? paperBg : $r('app.color.theme_paper_background'))
  .borderRadius(12)
}

@Entry
@Component
struct NotificationsCenterViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // spec stateVar: items (svc_notifications) — the rows the filter lets through
  @State items: RemoteNotification[] = [];
  // presentOnboardingEducationModalIfNecessary: until it has been dismissed once
  @State showOnboarding: boolean = false;
  // the unfiltered fetch, kept so a filter change does not re-hit the API
  @State allItems: RemoteNotification[] = [];
  // authenticationManager.authStateIsPermanent — the logged-out inbox shows the empty state
  // and hides the collection view.
  @State isLoggedIn: boolean = false;
  // viewModel.emptyStateHeaderText / emptyStateSubheaderText
  @State emptyHeaderText: string = '';
  @State emptySubheaderText: string = '';
  // statusBarButton text (filterState.stateDescription)
  @State statusText: string = '';
  // userDidTapTypeFilterButton presents NotificationsCenterFilterView as a sheet; the plan
  // declares no separate screen for it, so the flag lives here and S4 builds its content.
  @State showFilters: boolean = false;
  // RemoteNotificationsFilterState.readStatus — 'all' | 'read' | 'unread'
  @State readStatus: string = 'all';
  // RemoteNotificationsFilterState.offTypes — the NotificationFilterType ids turned off
  @State offTypes: string[] = [];
  // RemoteNotificationsFilterState.offProjects — the Echo wiki ids filtered out
  @State offProjects: string[] = [];
  // userDidTapProjectFilterButton presents NotificationsCenterInboxViewController
  @State showProjects: boolean = false;
  // allInboxProjects: commons + wikidata, then the app-language Wikipedias
  @State inboxProjects: InboxProject[] = [];
  // editButtonItem
  @State isEditing: boolean = false;
  // notificationsView.refreshControl
  @State isRefreshing: boolean = false;
  // selectedCellViewModels, by notification key
  @State selectedKeys: string[] = [];
  private notifications: NotificationsDataSource = new NotificationsDataSource();
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    SessionStore.restore();
    // authenticationManager.authStateIsPermanent
    this.isLoggedIn = SessionStore.isLoggedIn;
    // populateFilterStateFromPersistence
    const filters: NotificationsFilterState = NotificationsFilterState.load();
    this.readStatus = filters.readStatus;
    this.offTypes = filters.offTypes;
    this.offProjects = filters.offProjects;
    this.emptyHeaderText = this.str($r('app.string.notifications_center_empty_no_messages').id);
    if (this.isLoggedIn && !Prefs.getBoolean(PrefKeys.userHasOnboardedToNotificationsCenter, false)) {
      this.showOnboarding = true;
    }
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        console.error('notifications: load failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('notifications: db init failed: ' + e.message);
    });
  }

  // NotificationsCenterViewModel.refreshNotifications: the API page, persisted into the
  // local store, with the cached rows as the offline fallback.
  private str(id: number): string {
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    return rm.getStringSync(id);
  }

  private async load(): Promise<void> {
    // emptyStateSubheaderText == checkingForNotifications while isLoading.
    const checking: string = this.str($r('app.string.notifications_center_empty_checking_for_notifications').id);
    this.emptySubheaderText = checking;
    this.statusText = checking;
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.host = lang.languageCode + '.wikipedia.org';
      await this.loadInboxProjects();
      if (this.isLoggedIn) {
        try {
          const page: NotificationsPage = await NotificationsService.fetchNotifications(this.host, null);
          await NotificationsService.saveNotifications(page.notifications);
        } catch (e) {
          console.error('notifications: fetch failed: ' + (e as Error).message);
        }
      }
      const cached: RemoteNotification[] = await NotificationsService.cachedNotifications();
      this.applyFilter(cached);
    } finally {
      this.emptySubheaderText = '';
    }
  }

  // NotificationsCenterInboxViewModel: the Wikimedia projects section (commons, wikidata)
  // over the Wikipedias section (app languages, alphabetical).
  private async loadInboxProjects(): Promise<void> {
    const commons = new InboxProject();
    commons.wiki = 'commonswiki';
    commons.title = this.str($r('app.string.project_name_wikimedia_commons').id);
    commons.icon = $r('app.media.wikimedia_project_commons');
    const wikidata = new InboxProject();
    wikidata.wiki = 'wikidatawiki';
    wikidata.title = this.str($r('app.string.project_name_wikidata').id);
    wikidata.icon = $r('app.media.wikimedia_project_wikidata');
    const wikipedias: InboxProject[] = [];
    for (const l of await LanguageStore.preferredLanguages()) {
      const p = new InboxProject();
      p.wiki = l.languageCode.replace(/-/g, '_') + 'wiki';
      p.title = (l.localizedName !== '' ? l.localizedName : l.name) + ' Wikipedia';
      wikipedias.push(p);
    }
    wikipedias.sort((a: InboxProject, b: InboxProject): number => a.title.localeCompare(b.title));
    this.inboxProjects = [commons, wikidata].concat(wikipedias);
  }

  private toggleProject(wiki: string): void {
    const i: number = this.offProjects.indexOf(wiki);
    this.offProjects = i >= 0
      ? this.offProjects.filter((w: string): boolean => w !== wiki)
      : this.offProjects.concat([wiki]);
    NotificationsFilterState.save(this.readStatus, this.offTypes, this.offProjects);
    this.applyFilter(this.allItems);
  }

  // NotificationsCenterModelController: the read-status and project filters over the rows.
  private applyFilter(all: RemoteNotification[]): void {
    const shown: RemoteNotification[] = [];
    for (const item of all) {
      if (item.wiki !== null && this.offProjects.indexOf(item.wiki) >= 0) {
        continue;
      }
      if (!passesTypeFilter(this.offTypes, item.categoryString ?? '', item.typeString ?? '')) {
        continue;
      }
      if (this.readStatus === 'read' && !item.isRead) {
        continue;
      }
      if (this.readStatus === 'unread' && item.isRead) {
        continue;
      }
      shown.push(item);
    }
    this.allItems = all;
    this.notifications.reload(shown);
    this.items = shown;
    // rawStatusBarText: filterState.stateDescription
    // stateDescription: "Filtered by" once the read status or a type is filtered
    this.statusText = this.readStatus === 'all' && this.offTypes.length === 0
      ? this.str($r('app.string.notifications_center_status_all_notifications').id)
      : this.str($r('app.string.notifications_center_status_filtered_by').id);
  }

  // setFilterReadStatus: the sheet stays open, as the source's does
  private setReadStatus(status: string): void {
    this.readStatus = status;
    this.saveFilters();
  }

  // appendFilterType / removeFilterType
  private toggleType(id: string): void {
    this.offTypes = this.offTypes.indexOf(id) >= 0
      ? this.offTypes.filter((t: string): boolean => t !== id)
      : this.offTypes.concat([id]);
    this.saveFilters();
  }

  // the All types toggle: on clears offTypes, off turns every type off
  private setAllTypes(on: boolean): void {
    this.offTypes = on ? [] : NOTIFICATION_FILTER_TYPES.map((t: NotificationFilterType): string => t.id);
    this.saveFilters();
  }

  private saveFilters(): void {
    NotificationsFilterState.save(this.readStatus, this.offTypes, this.offProjects);
    this.applyFilter(this.allItems);
  }

  // NotificationsCenterFilterView — presented by userDidTapTypeFilterButton: "Filters" with
  // Done over an inset grouped list: Read Status (checkmarks), Types of notifications (the
  // All types toggle and its footer), then one toggle per type with its glyph.
  @Builder
  filtersBuilder() {
    Column() {
      Row() {
        Blank()
          .width(80)
        Text($r('app.string.notifications_center_filters_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Button($r('app.string.notifications_center_done'))
          .id('notifications_filters_done')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_link'))
          .width(80)
          .padding(0)
          .onClick(() => {
            this.showFilters = false;
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      Scroll() {
        Column() {
          this.filtersSectionHeader($r('app.string.notifications_center_filters_read_status_section_title'))
          Column() {
            this.readStatusRow('all', $r('app.string.notifications_center_filters_read_status_item_title_all'))
            Divider().color($r('app.color.gray200')).margin({ left: 16 })
            this.readStatusRow('unread', $r('app.string.notifications_center_filters_read_status_item_title_unread'))
            Divider().color($r('app.color.gray200')).margin({ left: 16 })
            this.readStatusRow('read', $r('app.string.notifications_center_filters_read_status_item_title_read'))
          }
          .filtersGroup(this.wmfPaperBg)
          this.filtersSectionHeader($r('app.string.notifications_center_filters_types_section_title'))
          Column() {
            Row() {
              Text($r('app.string.notifications_center_filters_types_item_title_all'))
                .layoutWeight(1)
                .fontSize(17)
                .fontColor($r('app.color.theme_text'))
              Toggle({ type: ToggleType.Switch, isOn: this.offTypes.length === 0 })
                .id('notifications_filter_all_types')
                .selectedColor($r('app.color.theme_accent'))
                // onChange also fires when isOn follows offTypes; act only on a real flip
                .onChange((isOn: boolean) => {
                  if (isOn !== (this.offTypes.length === 0)) {
                    this.setAllTypes(isOn);
                  }
                })
            }
            .width('100%')
            .constraintSize({ minHeight: 48 })
            .padding({ left: 16, right: 12 })
          }
          .filtersGroup(this.wmfPaperBg)
          Text($r('app.string.notifications_center_filters_types_footer'))
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 32, right: 32, top: 8 })
          Column() {
            ForEach(NOTIFICATION_FILTER_TYPES, (t: NotificationFilterType, i: number) => {
              if (i > 0) {
                Divider().color($r('app.color.gray200')).margin({ left: 60 })
              }
              this.typeRow(t)
            }, (t: NotificationFilterType) => t.id + (this.offTypes.indexOf(t.id) >= 0 ? '_off' : '_on'))
          }
          .filtersGroup(this.wmfPaperBg)
          .margin({ left: 16, right: 16, top: 24, bottom: 32 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.theme_mid_background'))
  }

  @Builder
  filtersSectionHeader(title: Resource) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 32, right: 32, top: 24, bottom: 8 })
  }

  @Builder
  readStatusRow(status: string, title: Resource) {
    Row() {
      Text(title)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
      if (this.readStatus === status) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor([$r('app.color.theme_link')])
      }
    }
    .id('notifications_filter_' + status)
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.setReadStatus(status);
    })
  }

  // NotificationsCenterFilterItemView .toggle: the type glyph on its tinted square, the title
  // (and the subtitle for the login types), the switch.
  @Builder
  typeRow(t: NotificationFilterType) {
    Row({ space: 12 }) {
      Stack() {
        Image(t.icon)
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
          .fillColor(Color.White)
      }
      .width(32)
      .height(32)
      .borderRadius(6)
      .backgroundColor(t.color)
      Column({ space: 2 }) {
        Text(t.title)
          .fontSize(16)
          .fontColor($r('app.color.theme_text'))
        if (t.subtitle !== null) {
          Text(t.subtitle)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.offTypes.indexOf(t.id) < 0 })
        .id('notifications_filter_type_' + t.id)
        .selectedColor($r('app.color.theme_accent'))
        .onChange((isOn: boolean) => {
          if (isOn === (this.offTypes.indexOf(t.id) >= 0)) {
            this.toggleType(t.id);
          }
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .padding({ left: 16, right: 12, top: 6, bottom: 6 })
  }

  @Builder
  projectRow(p: InboxProject) {
    Row({ space: 12 }) {
      if (p.icon !== null) {
        Image(p.icon)
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      }
      Text(p.title)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
      if (this.offProjects.indexOf(p.wiki) < 0) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(20)
          .fontColor([$r('app.color.theme_link')])
      }
    }
    .id('notifications_project_' + p.wiki)
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.toggleProject(p.wiki);
    })
  }

  // NotificationsCenterInboxView — presented by userDidTapProjectFilterButton.
  @Builder
  projectsBuilder() {
    Column() {
      Text($r('app.string.notifications_center_inbox_title'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
        .margin({ bottom: 12 })
      Text(upperText(getContext(this), $r('app.string.notifications_center_inbox_wikimedia_projects_section_title')))
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
      ForEach(this.inboxProjects.filter((p: InboxProject): boolean => p.icon !== null), (p: InboxProject) => {
        this.projectRow(p)
      }, (p: InboxProject) => p.wiki + this.offProjects.join())
      Text($r('app.string.notifications_center_inbox_wikimedia_projects_section_footer'))
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ bottom: 16 })
      Text(upperText(getContext(this), $r('app.string.notifications_center_inbox_wikipedias_section_title')))
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
      ForEach(this.inboxProjects.filter((p: InboxProject): boolean => p.icon === null), (p: InboxProject) => {
        this.projectRow(p)
      }, (p: InboxProject) => p.wiki + this.offProjects.join())
    }
    .width('100%')
    .padding(16)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // the onboarding's dark-theme icons (the -alt assets)
  private onboardingIcon(light: Resource, dark: Resource): Resource {
    const theme: string = AppStorage.get<string>('WMFAppThemeName') ?? '';
    return theme.startsWith('dark') || theme.startsWith('black') ? dark : light;
  }

  @Builder
  onboardingSheet() {
    WMFOnboardingView({
      title: $r('app.string.notifications_center_onboarding_modal_title'),
      cells: [
        new WMFOnboardingCellModel(this.onboardingIcon($r('app.media.notifications_center_onboarding_bell'),
          $r('app.media.notifications_center_onboarding_bell_alt')),
          $r('app.string.notifications_center_onboarding_modal_notifications_alerts_title'),
          $r('app.string.notifications_center_onboarding_modal_notifications_alerts_message')),
        new WMFOnboardingCellModel(this.onboardingIcon($r('app.media.notifications_center_onboarding_filter'),
          $r('app.media.notifications_center_onboarding_filter_alt')),
          $r('app.string.notifications_center_onboarding_modal_filters_title'),
          $r('app.string.notifications_center_onboarding_modal_filters_message')),
        new WMFOnboardingCellModel(this.onboardingIcon($r('app.media.notifications_center_onboarding_inbox'),
          $r('app.media.notifications_center_onboarding_inbox_alt')),
          $r('app.string.notifications_center_onboarding_modal_project_inboxes_title'),
          $r('app.string.notifications_center_onboarding_modal_project_inboxes_message')),
        new WMFOnboardingCellModel(this.onboardingIcon($r('app.media.notifications_center_onboarding_push'),
          $r('app.media.notifications_center_onboarding_push_alt')),
          $r('app.string.notifications_center_onboarding_modal_push_notifications_title'),
          $r('app.string.notifications_center_onboarding_modal_push_notifications_message'))
      ],
      primaryButtonTitle: $r('app.string.notifications_center_onboarding_modal_continue_action'),
      secondaryButtonTitle: $r('app.string.notifications_center_onboarding_modal_learn_more_action'),
      onPrimary: (): void => {
        this.showOnboarding = false;
      },
      // userDidTapLearnMore: the FAQ in the browser
      onSecondary: (): void => {
        this.showOnboarding = false;
        (getContext(this) as common.UIAbilityContext)
          .openLink('https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_FAQ#Notifications')
          .catch((e: Error) => {
            console.error('notifications: learn more failed: ' + e.message);
          });
      }
    })
  }

  build() {
    Column() {
      // the onboarding sheet's anchor (one bindSheet per node). Dismissing it in any way counts as
      // onboarded (the source then offers push opt-in, which sets the flag).
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showOnboarding, this.onboardingSheet(), { height: SheetSize.LARGE, showClose: false,
          dragBar: false, onDisappear: () => {
            Prefs.putBoolean(PrefKeys.userHasOnboardedToNotificationsCenter, true);
          } })
      // platform push-navigation back affordance
      Row() {
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
        Text('Notifications')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .padding({ left: 8, right: 8 })
        // editButtonItem: Edit / Done, disabled while the inbox is empty
        Button(this.isEditing ? $r('app.string.notifications_center_done') : $r('app.string.edit_menu_item'))
          .id('notifications_edit')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(17)
          .fontWeight(this.isEditing ? FontWeight.Medium : FontWeight.Normal)
          .fontColor($r('app.color.theme_link'))
          .padding({ left: 0, right: 0 })
          .constraintSize({ minWidth: NAV_BUTTON_SIZE })
          .height(NAV_BUTTON_SIZE)
          .enabled(this.isLoggedIn && this.items.length > 0)
          .opacity(this.isLoggedIn && this.items.length > 0 ? 1 : 0.4)
          .onClick(() => {
            this.isEditing = !this.isEditing;
            this.selectedKeys = [];
            // the row keys carry the editing state: reload so every row rebuilds
            this.notifications.reload(this.items);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // updateEmptyDisplayState: the empty view and the collection view are exclusive.
      if (!this.isLoggedIn || this.items.length === 0) {
        EmptyViewController({
          emptyImage: $r('app.media.notifications_center_empty'),
          emptyTitle: this.emptyHeaderText,
          message: this.emptySubheaderText
        })
      } else {
        // refreshControl -> userDidPullToRefresh -> refreshNotifications(force: true)
        Refresh({ refreshing: $$this.isRefreshing }) {
        List() {
          LazyForEach(this.notifications, (item: RemoteNotification) => {
            ListItem() {
              NotificationsCenterCell({
                item: item,
                isEditing: this.isEditing,
                isSelected: this.selectedKeys.indexOf(item.key ?? '') >= 0,
                onTap: (): void => {
                  if (this.isEditing) {
                    this.toggleSelection(item);
                  } else {
                    this.openNotificationDetail(item);
                  }
                }
              })
            }
            // the cell's swipe panel: More and Mark as read / unread
            .swipeAction({ end: { builder: () => { this.swipeButtons(item); } } })
          // editing and selection are in the key: LazyForEach rebuilds a row only on a key change
          }, (item: RemoteNotification) => (item.key !== null ? item.key : '') + (item.isRead ? '_r' : '_u') +
            (this.isEditing ? '_e' : '') + (this.selectedKeys.indexOf(item.key ?? '') >= 0 ? '_s' : ''))
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        }
        .width('100%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.load().catch((e: Error) => {
            console.error('notifications: refresh failed: ' + e.message);
          }).finally(() => {
            this.isRefreshing = false;
          });
        })
      }

      // navigationController.toolbar — iOS toolbar glyphs/titles are .label, not the accent.
      Row() {
        if (this.isEditing) {
          // markButton: enabled once a cell is selected (updateMarkButtonsEnabledStates)
          Button($r('app.string.notifications_center_mark'))
            .id('notifications_mark')
            .accessibilityText($r('app.string.notifications_center_toolbar_mark_accessibility_label'))
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 0, right: 0 })
            .enabled(this.selectedKeys.length > 0)
            .opacity(this.selectedKeys.length > 0 ? 1 : 0.4)
            .onClick(() => {
              this.showMarkOptions();
            })
          Blank()
          // markAllAsReadButton: only with no selection and something unread
          Button($r('app.string.notifications_center_mark_all_as_read'))
            .id('mark_as_read')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 0, right: 0 })
            .enabled(this.selectedKeys.length === 0 && this.items.some((i: RemoteNotification): boolean => !i.isRead))
            .opacity(this.selectedKeys.length === 0 && this.items.some((i: RemoteNotification): boolean => !i.isRead) ? 1 : 0.4)
            .onClick(() => {
              this.markAsRead();
              this.isEditing = false;
            })
        } else {
          // typeFilterButton -> userDidTapTypeFilterButton (the filters sheet)
          Button() {
            Image(this.readStatus !== 'all' || this.offTypes.length > 0
              ? $r('app.media.line_3_horizontal_decrease_circle_fill')
              : $r('app.media.line_3_horizontal_decrease_circle'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.theme_text'))
          }
          .id('notifications_filter')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .accessibilityText(this.readStatus !== 'all' || this.offTypes.length > 0
            ? $r('app.string.notifications_center_applied_filters_accessibility_label')
            : $r('app.string.notifications_center_filters_accessibility_label'))
          .onClick(() => {
            this.openFilters();
          })
          Blank()
          // statusBarButton
          Text(this.statusText)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          // projectFilterButton -> userDidTapProjectFilterButton (the Projects sheet)
          Button() {
            SymbolGlyph(this.offProjects.length > 0 ? $r('sys.symbol.inbox_fill') : $r('sys.symbol.inbox'))
              .fontSize(24)
              .fontColor([$r('app.color.theme_text')])
          }
          .id('notifications_project_filter')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .accessibilityText(this.offProjects.length > 0
            ? $r('app.string.notifications_center_applied_project_filters_accessibility_label')
            : $r('app.string.notifications_center_project_filters_accessibility_label'))
          .onClick(() => {
            this.showProjects = true;
          })
          // one bindSheet per node: the filters sheet is bound on the page root
          .bindSheet($$this.showProjects, this.projectsBuilder(), { showClose: false })
        }
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })
      .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    }
    .id('NotificationsCenterViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindSheet($$this.showFilters, this.filtersBuilder(), { showClose: false, height: SheetSize.LARGE })
  }

  // userDidTapTypeFilterButton — presents the filters sheet.
  private openFilters(): void {
    this.showFilters = true;
  }

  // didTapMarkButton -> markAsReadOrUnread (echomarkread over the shown notifications).
  private markAsRead(): void {
    const ids: string[] = [];
    for (const item of this.items) {
      const id: string | null = item.id;
      if (!item.isRead && id !== null && id !== '') {
        ids.push(id);
      }
    }
    if (ids.length === 0) {
      return;
    }
    NotificationsService.markReadOrUnread(this.host, ids, true).then(() => {
      NotificationsService.refreshUnreadCount();
      this.load().catch((e: Error) => {
        console.error('notifications: reload failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('notifications: mark read failed: ' + e.message);
    });
  }

  private toggleSelection(item: RemoteNotification): void {
    const key: string = item.key ?? '';
    this.selectedKeys = this.selectedKeys.indexOf(key) >= 0
      ? this.selectedKeys.filter((k: string): boolean => k !== key)
      : this.selectedKeys.concat([key]);
    this.notifications.reload(this.items);
  }

  // markButtonOptionsMenuForNumberOfSelectedMessages: "N messages" with Mark as Read when
  // something selected is unread, Mark as Unread when something selected is read; either
  // marks every selected notification and leaves editing.
  private showMarkOptions(): void {
    const selected: RemoteNotification[] = this.items.filter((i: RemoteNotification): boolean =>
      this.selectedKeys.indexOf(i.key ?? '') >= 0);
    if (selected.length === 0) {
      return;
    }
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    const sheets: SheetInfo[] = [];
    if (selected.some((i: RemoteNotification): boolean => !i.isRead)) {
      sheets.push({ title: rm.getStringSync($r('app.string.notifications_center_mark_as_read')),
        action: () => this.markSelected(selected, true) });
    }
    if (selected.some((i: RemoteNotification): boolean => i.isRead)) {
      sheets.push({ title: rm.getStringSync($r('app.string.notifications_center_mark_as_unread')),
        action: () => this.markSelected(selected, false) });
    }
    this.getUIContext().showActionSheet({
      title: pluralString(getContext(this), $r('app.string.notifications_center_num_selected_messages_format'),
        selected.length),
      message: '',
      autoCancel: true,
      sheets: sheets,
      confirm: { value: rm.getStringSync($r('app.string.cancel')), action: () => {} }
    });
  }

  private markSelected(selected: RemoteNotification[], read: boolean): void {
    const ids: string[] = [];
    for (const i of selected) {
      if (i.id !== null && i.id !== '') {
        ids.push(i.id);
      }
    }
    this.isEditing = false;
    this.selectedKeys = [];
    this.notifications.reload(this.items);
    NotificationsService.markReadOrUnread(this.host, ids, read).then(() => {
      NotificationsService.refreshUnreadCount();
      this.load().catch((e: Error) => {
        console.error('notifications: reload failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('notifications: mark selected failed: ' + e.message);
    });
  }

  // NotificationsCenterCell swipe panel: More (gray, the action sheet) and Mark as read /
  // Mark as unread (blue).
  @Builder
  swipeButtons(item: RemoteNotification) {
    Row() {
      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.more'))
          .fontSize(22)
          .fontColor([Color.White])
        Text($r('app.string.notifications_center_swipe_more'))
          .fontSize(13)
          .fontColor(Color.White)
      }
      .id('notification_swipe_more')
      .width(88)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.gray500'))
      .onClick(() => {
        this.showMoreActions(item);
      })
      Column({ space: 4 }) {
        SymbolGlyph(item.isRead ? $r('sys.symbol.envelope') : $r('sys.symbol.envelope_open'))
          .fontSize(22)
          .fontColor([Color.White])
        Text(item.isRead ? $r('app.string.notifications_center_swipe_mark_as_unread')
          : $r('app.string.notifications_center_swipe_mark_as_read'))
          .fontSize(13)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
      }
      .id('notification_swipe_mark')
      .width(88)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.theme_link'))
      .onClick(() => {
        this.markItem(item, !item.isRead);
      })
    }
    .height('100%')
  }

  // userDidTapMoreActionForCell: an action sheet titled with the header, the body as its
  // message: Mark as read / unread, the notification's own links, Notification settings.
  // ponytail: the links are the notification's primary + secondary links (what the detail
  // screen lists), not the source's per-type view-model actions; add those per type if a
  // type's sheet is found to differ.
  private showMoreActions(item: RemoteNotification): void {
    const ctx: common.Context = getContext(this) as common.Context;
    const rm: resourceManager.ResourceManager = ctx.resourceManager;
    const sheets: SheetInfo[] = [{
      title: rm.getStringSync(item.isRead ? $r('app.string.notifications_center_swipe_mark_as_unread')
        : $r('app.string.notifications_center_swipe_mark_as_read')),
      action: () => this.markItem(item, !item.isRead)
    }];
    const seen: string[] = [];
    const links: RemoteNotificationLink[] = [];
    const primary: RemoteNotificationLink | null = item.messageLinks?.primary ?? item.messageLinks?.legacyPrimary ?? null;
    if (primary !== null) {
      links.push(primary);
    }
    for (const link of item.messageLinks?.secondary ?? []) {
      links.push(link);
    }
    for (const link of links) {
      const url: string = link.url ?? '';
      const label: string = (link.label ?? '').replace(/<[^>]+>/g, '').trim();
      if (url === '' || label === '' || seen.indexOf(url) >= 0) {
        continue;
      }
      seen.push(url);
      sheets.push({ title: label, action: () => this.openNotificationLink(item, url) });
    }
    sheets.push({
      title: rm.getStringSync($r('app.string.notifications_center_notifications_settings')),
      action: () => {
        router.pushUrl({ url: 'pages/WMFPushNotificationsSettingsViewPage' });
        if (!item.isRead) {
          this.markItem(item, true);
        }
      }
    });
    this.getUIContext().showActionSheet({
      title: (item.messageHeader ?? '').replace(/<[^>]+>/g, '').trim(),
      message: (item.messageBody ?? '').replace(/<[^>]+>/g, '').trim(),
      autoCancel: true,
      sheets: sheets,
      confirm: { value: rm.getStringSync($r('app.string.cancel')), action: () => {} }
    });
  }

  // LinkCoordinator first (a native article, talk page ...), the web page otherwise; then
  // the notification counts as read.
  private openNotificationLink(item: RemoteNotification, url: string): void {
    const d: LinkDestination | null = destinationForURL(url);
    if (d !== null) {
      const intent = intentForDestination(d);
      router.pushUrl({ url: intent.route, params: intent.params });
    } else {
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
    }
    if (!item.isRead) {
      this.markItem(item, true);
    }
  }

  private markItem(item: RemoteNotification, read: boolean): void {
    const id: string | null = item.id;
    if (id === null || id === '') {
      return;
    }
    NotificationsService.markReadOrUnread(this.host, [id], read).then(() => {
      NotificationsService.refreshUnreadCount();
      this.load().catch((e: Error) => {
        console.error('notifications: reload failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('notifications: mark read failed: ' + e.message);
    });
  }

  private openNotificationDetail(item: RemoteNotification): void {
    const params: Record<string, string> = {
      'notificationKey': item.key !== null ? item.key : ''
    };
    router.pushUrl({ url: 'pages/NotificationsCenterDetailViewControllerPage', params: params });
  }
}
