// screen_saved — presentation: page (Saved tab).
// S3 structure from Wikipedia/Code/SavedViewController.swift: configureNavigationBar()
// (customLeadingLarge title "Saved", profileButtonConfig -> profile-button,
// tabsButtonConfig(leadingBarButtonItem: moreBarButtonItem) -> saved_more + Tabs Button,
// WMFNavigationBarSearchConfig with showsScopeBar and scopeButtonTitles
// ["All articles", "Reading lists"]), the XIB's progressContainerView
// (savedProgressViewController) over containerView, and the two `currentView` children:
// .savedArticles -> SavedAllArticlesCoordinator's list of SavedArticlesCollectionViewCell rows,
// .readingLists -> ReadingListsViewController (its own page here) with its own
// empty-no-reading-lists empty view.
// Wired edges: saved -> reading_lists / reading_list_detail / article.
// Overlays: profileCoordinator (sheet) and tabsCoordinator (cover) are started by this
// controller itself, so they are hosted here exactly as on Explore.
// State/data binding (savedArticles <- svc_saved_store) is S4's pass.
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { router } from '@kit.ArkUI';
import { SavedArticlesCollectionViewCell } from '../components/SavedArticlesCollectionViewCell';
import { EmptyViewController } from '../components/EmptyViewController';
import { RootTabBar, isRootTabSwitch, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { WMFArticle } from '../model/WMFArticle';
import { Prefs } from '../common/Prefs';
import { ARTICLE_ERROR_API_FAILED, SavedStore, ReadingListWithId, ReadingListTag } from '../common/SavedStore';
import { ReadingListsCollectionViewCell } from '../components/ReadingListsCollectionViewCell';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { ReadingListSyncService, LIST_LIMIT_ERROR } from '../common/ReadingListSyncService';
import { SessionStore } from '../common/SessionStore';
import { Database } from '../common/Database';
import { searchFold } from '../common/LocaleText';
import { common } from '@kit.AbilityKit';
import { NAV_ICON_BUTTON, NAV_TEXT_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE, navIconTint, ROOT_BAR_HEIGHT } from '../components/NavButton';

class SavedArticleDataSource implements IDataSource {
  private items: WMFArticle[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): WMFArticle {
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

  reload(items: WMFArticle[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// LoginToSyncSavedArticlesToReadingListPanel. A system alert cut the long log-in label to one
// line ("Kayıtlı maddelerinizi senkronize ..."); here every label wraps.
@CustomDialog
struct LoginToSyncDialog {
  controller?: CustomDialogController;
  onLogin: () => void = () => {
  };

  build() {
    Column() {
      Text($r('app.string.reading_list_login_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
      Text($r('app.string.reading_list_login_subtitle'))
        .fontSize(15)
        .lineHeight(21)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
      Button() {
        Text($r('app.string.reading_list_login_button_title'))
          .fontSize(16)
          .fontColor($r('app.color.theme_link'))
          .textAlign(TextAlign.Center)
      }
      .id('login_to_sync_button')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .margin({ top: 16 })
      .onClick(() => {
        this.controller?.close();
        this.onLogin();
      })
      Button($r('app.string.action_cancel'))
        .id('login_to_sync_cancel')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(16)
        .fontColor($r('app.color.theme_link'))
        .width('100%')
        .height(44)
        .onClick(() => {
          this.controller?.close();
        })
    }
    .padding({ left: 24, right: 24, top: 24, bottom: 12 })
  }
}

@Entry
@Component
export struct SavedViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;

  // SavedViewController.currentView (View.savedArticles / .readingLists)
  @State scope: string = 'savedArticles';
  // svc_saved_store.allSaved() — filled in S4; the list starts empty, never seeded.
  @State savedArticles: WMFArticle[] = [];
  // navigationItem.searchController's search bar text
  @State searchText: string = '';
  // savedProgressViewController — the sync progress container of the XIB
  @State pullRefreshing: boolean = false;
  @State isSyncing: boolean = false;
  @State showProfileSheet: boolean = false;
  @State showTabsCover: boolean = false;
  // allArticlesSortType (SortActionType.byRecentlyAdded / .byTitle)
  @State sortByRecentlyAdded: boolean = true;
  // ReadingListsViewController.sortActionType — .byTitle until the reader picks another
  @State listsSortByRecentlyAdded: boolean = false;
  // viewModel.isEditing / editController batch-editing state
  @State isEditing: boolean = false;
  private itemsSource: SavedArticleDataSource = new SavedArticleDataSource();
  // the unfiltered MWKSavedPageList fetch; savedArticles is its search/sort projection
  private allSaved: WMFArticle[] = [];
  // Reading lists scope: the user's lists (the default list is 'All articles', not a row
  // here) and their search projection.
  @State readingLists: ReadingListWithId[] = [];
  // the reading-list tags under each saved article, by article key
  @State listTags: Map<string, ReadingListTag[]> = new Map<string, ReadingListTag[]>();
  private downloading: boolean = false;
  private allReadingLists: ReadingListWithId[] = [];
  // batch editing: the article keys ticked for the toolbar action
  @State selectedKeys: string[] = [];

  private sortPromptOpen: boolean = false;

  // a list renamed, created or deleted on a pushed page reloads this tab's lists
  private onStoreChange: () => void = (): void => {
    this.reloadReadingLists();
  };

  aboutToAppear(): void {
    this.reloadSavedArticles();
    this.reloadReadingLists();
    this.syncReadingLists();
    SavedStore.addObserver(this.onStoreChange);
  }

  aboutToDisappear(): void {
    SavedStore.removeObserver(this.onStoreChange);
  }

  // viewWillAppear(_:) re-reads the saved page list every time the tab comes forward.
  onPageShow(): void {
    this.reloadSavedArticles();
    this.reloadReadingLists();
  }

  private reloadReadingLists(): void {
    this.loadReadingLists().catch((e: Error) => {
      console.error('saved: reading lists load failed: ' + e.message);
    });
  }

  private async loadReadingLists(): Promise<void> {
    await this.db();
    // Settings > Show Saved reading list puts the default list among them
    const showDefault: boolean = Prefs.getBoolean('WMFShowDefaultReadingList', false);
    this.allReadingLists = (await SavedStore.readingLists())
      .filter((l: ReadingListWithId): boolean => showDefault || !l.list.isDefault);
    this.applyListFilter();
  }

  private applyListFilter(): void {
    const term: string = searchFold(this.searchText.trim());
    const lists: ReadingListWithId[] = term === '' ? this.allReadingLists.slice() : this.allReadingLists.filter(
      (l: ReadingListWithId): boolean => searchFold(l.list.canonicalName ?? '').indexOf(term) >= 0 ||
        searchFold(l.list.readingListDescription ?? '').indexOf(term) >= 0);
    // baseSortDescriptors (the default list first), then the chosen sort action: canonicalName
    // ascending, or createdDate descending for Recently added
    lists.sort((a: ReadingListWithId, b: ReadingListWithId): number => {
      if (a.list.isDefault !== b.list.isDefault) {
        return a.list.isDefault ? -1 : 1;
      }
      if (this.listsSortByRecentlyAdded) {
        return (b.list.createdDate ?? 0) - (a.list.createdDate ?? 0);
      }
      return (a.list.canonicalName ?? '').localeCompare(b.list.canonicalName ?? '');
    });
    this.readingLists = lists;
  }


  private searchPlaceholder(): ResourceStr {
    // allArticlesSearchBarPlaceholder / "Search reading lists" per currentView
    return this.scope === 'readingLists' ? $r('app.string.saved_reading_lists_search_placeholder')
      : $r('app.string.saved_search_default_text');
  }

  // EmptyViewController takes plain strings, so the screen resolves its own. As literals the
  // Saved tab stayed English whatever the device language.
  private text(res: Resource): string {
    try {
      return (getContext(this) as common.Context).resourceManager.getStringSync(res);
    } catch (e) {
      console.error('saved: string unavailable: ' + (e as Error).message);
      return '';
    }
  }

  @Builder
  deleteListAction(item: ReadingListWithId) {
    Button($r('app.string.article_delete'))
      .id('delete_reading_list')
      .type(ButtonType.Normal)
      .height('100%')
      .fontSize(15)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.theme_destructive'))
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        SavedStore.deleteReadingList(item.listRowId).then(() => this.reloadReadingLists())
          .catch((e: Error) => console.error('saved: delete list failed: ' + e.message));
      })
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
  tabsCoverBuilder() {
    WMFArticleTabsView({
      onClose: (): void => {
        this.showTabsCover = false;
      }
    })
  }

  @Builder
  savedArticleRow(item: WMFArticle) {
    SavedArticlesCollectionViewCell({
      title: item.displayTitle ?? '',
      articleDescription: item.wikidataDescription ?? '',
      imageURL: item.thumbnailURLString ?? item.imageURLString ?? '',
      isDownloaded: item.isDownloaded,
      // determineAlertType step 3: not downloaded -> the article error, else queued
      alertText: this.articleAlertText(item),
      onAlertTap: (): void => {
        this.presentArticleErrorRecovery(item);
      },
      // the reading lists the article is in; a tap opens that list
      tags: (this.listTags.get(item.key ?? '') ?? []).map((t: ReadingListTag): string => t.name),
      showsSeparator: true,
      onTagTap: (index: number): void => {
        const tag: ReadingListTag | undefined = (this.listTags.get(item.key ?? '') ?? [])[index];
        if (tag !== undefined) {
          const params: Record<string, string> = { 'listRowId': String(tag.listRowId) };
          router.pushUrl({ url: 'pages/ReadingListDetailViewControllerPage', params: params });
        }
      }
    })
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
      // navigation bar (capture base.ui.json): customLeadingLarge title "Saved" at x16 on the
      // SAME optical row (y66-102) as the more / tabs / profile buttons.
      Row() {
        // customLeadingLarge title — CommonStrings.savedTabTitle
        // The title takes the room the buttons leave and shrinks to fit: at its natural width a
        // longer translation ("Kaydedilenler") pushed the buttons and the whole tab off the screen.
        Text($r('app.string.saved_title'))
          .layoutWeight(1)
          .maxLines(1)
          .maxFontSize(ROOT_TITLE_FONT_SIZE)
          .minFontSize(22)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        if (this.isEditing) {
          Button($r('app.string.description_published_button_title'))
            .id('saved_edit_done')
            .attributeModifier(NAV_TEXT_BUTTON)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.isEditing = false;
              this.selectedKeys = [];
            })
        }
        Row({ space: NAV_BUTTON_GAP }) {
          Button() {
            Image($r('app.media.more'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              .colorFilter(navIconTint(this.isDark))
          }
          .id('saved_more')
          .attributeModifier(NAV_ICON_BUTTON)
          // overflowMenu: sortAction + editAction (UIMenu .displayInline)
          .bindMenu([
            {
              value: $r('app.string.action_sort'),
              action: (): void => {
                this.didTapSort();
              }
            },
            {
              value: $r('app.string.edit_menu_item'),
              action: (): void => {
                this.didTapEdit();
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
          .onClick(() => {
            this.userDidTapTabs();
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
            this.userDidTapProfile();
          })
        }
        .visibility(this.isEditing ? Visibility.None : Visibility.Visible)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .height(ROOT_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      // the tabs cover is bound on the nav bar Row, not the root (the root carries bindSheet)
      .bindContentCover($$this.showTabsCover, this.tabsCoverBuilder())

      // navigationItem.searchController's search bar — floating white 44pt pill (x16-386,
      // y117-161) with the leading magnifier at x28.
      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(20)
          .fontColor([$r('app.color.theme_secondary_text')])
        TextInput({ placeholder: this.searchPlaceholder(), text: this.searchText })
          .id('saved_search_bar')
          // commit each keystroke; an uncommitted (preview) word never reached onChange
          .enablePreviewText(false)
          .layoutWeight(1)
          .height(44)
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .placeholderColor($r('app.color.theme_secondary_text'))
          .placeholderFont({ size: 17 })
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 8, right: 0 })
          .onChange((value: string) => {
            // the text was stored but nothing re-filtered, so the search did nothing
            this.searchText = value;
            this.applyFilterAndSort();
            this.applyListFilter();
          })
      }
      .width('calc(100% - 32vp)')
      .height(44)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(22)
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
      .margin({ left: 16, right: 16, top: 15 })

      // scope bar — scopeButtonTitles ["All articles", "Reading lists"], a 32pt white
      // segmented pill (x16-386, y178-210) whose selected half sits on a theme_base_background capsule (light grey, dark in dark mode).
      Row() {
        Text($r('app.string.saved_all_articles_title'))
          .id('scopeBar')
          .layoutWeight(1)
          .height(28)
          .fontSize(15)
          .fontWeight(this.scope === 'savedArticles' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .backgroundColor(this.scope === 'savedArticles' ? $r('app.color.theme_base_background') : '#00000000')
          .borderRadius(14)
          .onClick(() => {
            this.selectAllArticles();
          })
        Text($r('app.string.saved_reading_lists_title'))
          .id('reading_lists')
          .layoutWeight(1)
          .height(28)
          .fontSize(15)
          .fontWeight(this.scope === 'readingLists' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .backgroundColor(this.scope === 'readingLists' ? $r('app.color.theme_base_background') : '#00000000')
          .borderRadius(14)
          .onClick(() => {
            this.selectReadingLists();
          })
      }
      .width('calc(100% - 32vp)')
      .height(32)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 2, right: 2 })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(16)
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
      .margin({ left: 16, right: 16, top: 17, bottom: 10 })

      // progressContainerView -> savedProgressViewController (reading-list sync progress)
      if (this.isSyncing) {
        Progress({ value: 0, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color($r('app.color.theme_link'))
          .backgroundColor($r('app.color.gray200'))
      }

      // containerView: the child of the current view
      if (this.scope === 'readingLists') {
        // evaluateEmptyState(): .readingLists with no collection shows
        // ReadingListsViewController.showEmptyView() (empty-no-reading-lists-title/-message
        // over "reading-lists-empty-state"), as captured in reading_lists.ui.json;
        // otherwise the ReadingListsViewController child (its own page here).
        // The lists are this tab's own content (ReadingListsViewController as the child); the
        // tab used to push a separate page that also listed the hidden default list.
        if (this.readingLists.length > 0) {
          List() {
            ForEach(this.readingLists, (item: ReadingListWithId) => {
              ListItem() {
                ReadingListsCollectionViewCell({
                  name: item.list.nameWithDefaultTitle(this.text($r('app.string.saved_title'))),
                  listDescription: item.list.readingListDescription ?? '',
                  articleCount: item.list.countOfEntries,
                  isDefault: false,
                  isCompact: false,
                  syncError: item.list.errorCode === LIST_LIMIT_ERROR ?
                    this.text($r('app.string.reading_lists_list_not_synced_limit_exceeded')) : ''
                })
              }
              .id('reading_list_itemroot')
              // swipe to delete (ReadingListsViewController's delete swipe action)
              .swipeAction({ end: this.deleteListAction(item) })
              .onClick(() => {
                const params: Record<string, string> = { 'listRowId': String(item.listRowId) };
                router.pushUrl({ url: 'pages/ReadingListDetailViewControllerPage', params: params });
              })
            // count and name in the key: keyed by id alone, a row kept its old article count
            // after a move or remove, because ForEach reused it without redrawing
            }, (item: ReadingListWithId) => item.listRowId + '_' + item.list.countOfEntries + '_' + (item.list.canonicalName ?? ''))
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else if (this.searchText.trim() !== '' && this.allReadingLists.length > 0) {
          Column() {
            Text($r('app.string.empty_no_search_results_message'))
              .fontSize(17)
              .fontColor($r('app.color.theme_secondary_text'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            EmptyViewController({
              emptyImage: $r('app.media.reading_lists_empty_state'),
              imageSize: 132,
              emptyTitle: this.text($r('app.string.empty_no_reading_lists_title')),
              titleFontSize: 17,
              message: this.text($r('app.string.empty_no_reading_lists_message')),
              buttonTitle: this.text($r('app.string.reading_list_create_new_list_title')),
              buttonId: 'create_a_new_list',
              buttonCapsule: true,
              onButtonTap: (): void => {
                this.openCreateReadingList();
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
        }
      } else if (this.savedArticles.length === 0) {
        Column() {
          EmptyViewController({
            emptyImage: $r('app.media.saved_blank'),
            emptyTitle: this.text($r('app.string.empty_no_saved_pages_title')),
            message: this.text($r('app.string.empty_no_saved_pages_message'))
          })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        // pull to refresh: the source syncs the reading lists, or - logged out - offers the
        // "sync your saved articles?" login panel
        Refresh({ refreshing: $$this.pullRefreshing }) {
          List() {
            LazyForEach(this.itemsSource, (item: WMFArticle) => {
              ListItem() {
                Row() {
                  // batch editing: the selection circle ahead of each row
                  if (this.isEditing) {
                    SymbolGlyph(this.selectedKeys.includes(item.key ?? '')
                      ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
                      .fontSize(24)
                      .fontColor([this.selectedKeys.includes(item.key ?? '')
                        ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text')])
                      .margin({ left: 16 })
                  }
                  Column() {
                    this.savedArticleRow(item)
                  }
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .id('saved_article_itemroot')
              .onClick(() => {
                if (this.isEditing) {
                  this.toggleSelected(item.key ?? '');
                  return;
                }
                this.openArticle(item.displayTitle ?? '', item.key ?? '');
              })
            // the download state is part of the key: a row only redraws (its dot clearing once
            // the offline copy lands) when its key changes
            }, (item: WMFArticle, index: number) => (item.key ?? '') + '_' + index + (item.isDownloaded ? '_d' : '') +
              (item.errorCodeNumber === ARTICLE_ERROR_API_FAILED ? '_e' : ''))
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .scrollBar(BarState.Off)
        }
        .onRefreshing(() => {
          this.pullRefreshing = false;
          if (SessionStore.isLoggedIn) {
            this.syncReadingLists();
          } else {
            this.showLoginToSyncPanel();
          }
        })
        .width('100%')
        .layoutWeight(1)
      }

      // batch-edit toolbar (the source's editing toolbar): unsave the ticked articles
      if (this.isEditing) {
        Row() {
          // the source's editing toolbar: Add to list | Unsave
          Button($r('app.string.action_add_to_reading_list_short'))
            .id('saved_edit_add_to_list')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .enabled(this.selectedKeys.length > 0)
            .fontColor(this.selectedKeys.length > 0 ? $r('app.color.theme_link')
              : $r('app.color.theme_secondary_text'))
            .onClick(() => {
              this.addSelectedToList();
            })
          // the source's editing toolbar title: "Unsave"
          Button($r('app.string.action_unsave'))
            .id('saved_edit_unsave')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .enabled(this.selectedKeys.length > 0)
            .fontColor(this.selectedKeys.length > 0 ? $r('app.color.theme_destructive')
              : $r('app.color.theme_secondary_text'))
            .onClick(() => {
              this.unsaveSelected();
            })
        }
        .width('100%')
        .height(52)
        .padding({ left: 8, right: 8 })
        .justifyContent(FlexAlign.SpaceBetween)
        .border({ width: { top: 1 }, color: $r('app.color.theme_border') })

      }

      // persistent root tab bar (UITabBarController) — Saved is tab 2
      RootTabBar({ selected: 2 })
    }
    .id('SavedViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(),
      { height: SheetSize.LARGE, dragBar: false, showClose: false })
  }



  // the batch "Add to list": AddArticlesToReadingListViewController as a routed page (as a
  // content cover its lists never drew); editing ends, the lists reload on the way back
  private addSelectedToList(): void {
    const params: Record<string, string> = { 'articleKeys': JSON.stringify(this.selectedKeys) };
    this.selectedKeys = [];
    this.isEditing = false;
    router.pushUrl({ url: 'pages/AddArticlesToReadingListViewControllerPage', params: params });
  }

  // currentView = .savedArticles
  private selectAllArticles(): void {
    if (this.scope === 'savedArticles') {
      return;
    }
    this.scope = 'savedArticles';
    this.clearSearch();
  }

  // Each scope searches its own content (the placeholder changes with it); a term typed for
  // articles carried over into the reading lists.
  private clearSearch(): void {
    this.searchText = '';
    this.applyFilterAndSort();
    this.applyListFilter();
  }

  // currentView = .readingLists — the child collection is ReadingListsViewController.
  private selectReadingLists(): void {
    if (this.scope === 'readingLists') {
      return;
    }
    this.scope = 'readingLists';
    this.isEditing = false;
    this.clearSearch();
    this.reloadReadingLists();
  }

  // presentCreateReadingListViewController() — a routed page (see CreateReadingListPage);
  // a double tap pushes it once.
  private lastCreateTap: number = 0;

  private openCreateReadingList(): void {
    if (Date.now() - this.lastCreateTap < 1000) {
      return;
    }
    this.lastCreateTap = Date.now();
    router.pushUrl({ url: 'pages/CreateReadingListViewControllerPage' });
  }

  // didTapSort() -> presentAllArticlesSortAlert / savedWillShowSortAlert; the chosen
  // SortActionType reorders the fetch (byRecentlyAdded is the store's own order).
  // presentAllArticlesSortAlert: an action sheet (Recently added / Title / Cancel); the chosen
  // order applies. It toggled silently before. One sheet per tap burst.
  private didTapSort(): void {
    if (this.sortPromptOpen) {
      return;
    }
    this.sortPromptOpen = true;
    // savedWillShowSortAlert: the sort applies to the segment on screen
    const pick = (byRecent: boolean): void => {
      this.sortPromptOpen = false;
      if (this.scope === 'savedArticles') {
        this.sortByRecentlyAdded = byRecent;
        this.applyFilterAndSort();
      } else {
        this.listsSortByRecentlyAdded = byRecent;
        this.applyListFilter();
      }
    };
    // after the overflow menu has closed; shown from its item action it never appeared
    setTimeout(() => this.showSortSheet(pick), 300);
  }

  private showSortSheet(pick: (byRecent: boolean) => void): void {
    this.getUIContext().showActionSheet({
      title: $r('app.string.action_sort'),
      message: '',
      // only its buttons close it: the rest of a double tap on Sırala landed outside and
      // dismissed it as soon as it appeared
      autoCancel: false,
      confirm: {
        value: $r('app.string.action_cancel'),
        action: () => {
          this.sortPromptOpen = false;
        }
      },
      cancel: () => {
        this.sortPromptOpen = false;
      },
      sheets: [
        { title: $r('app.string.sort_by_recently_added_action'), action: () => pick(true) },
        { title: $r('app.string.sort_by_title_action'), action: () => pick(false) }
      ]
    });
  }

  // MWKSavedPageList fetch (savedDate != nil, savedDate DESC).
  private reloadSavedArticles(): void {
    this.loadSavedArticles().catch((e: Error) => {
      console.error('saved: load failed: ' + e.message);
    });
  }

  // Every store read below goes through the RDB store, so it must be open first — the Saved
  // tab can be the cold-start landing screen, with no Explore ahead of it to have opened it.
  // Database.init is memoized, so calling it from each entry path still opens the file once.
  private db(): Promise<void> {
    return Database.init(getContext(this) as common.UIAbilityContext);
  }

  private async loadSavedArticles(): Promise<void> {
    await this.db();
    const rows: WMFArticle[] = await SavedStore.savedArticles();
    for (const article of rows) {
      // feat_offline_cache — statusView marks an article whose offline copy the
      // SavedArticlesFetcher has not downloaded yet.
      article.isDownloaded = await ArticleCacheStore.isCached(article.key ?? '');
    }
    this.listTags = await SavedStore.listTagsByArticle();
    this.allSaved = rows;
    this.applyFilterAndSort();
    this.downloadMissing(rows);
  }

  private articleAlertText(a: WMFArticle): string {
    if (a.isDownloaded) {
      return '';
    }
    return this.text(a.errorCodeNumber === ARTICLE_ERROR_API_FAILED
      ? $r('app.string.reading_lists_article_api_failure')
      : $r('app.string.reading_lists_article_queued_to_be_downloaded'));
  }

  // presentArticleErrorRecovery: for apiFailed, an action sheet titled with the error, Retry
  // (retryDownload: clear the error, download again) and Cancel.
  private presentArticleErrorRecovery(a: WMFArticle): void {
    if (a.errorCodeNumber !== ARTICLE_ERROR_API_FAILED || a.key === null) {
      return;
    }
    const key: string = a.key;
    this.getUIContext().showActionSheet({
      title: this.text($r('app.string.reading_lists_article_api_failure')),
      message: '',
      autoCancel: true,
      confirm: { value: this.text($r('app.string.action_cancel')), action: () => {} },
      sheets: [{
        title: this.text($r('app.string.action_retry')),
        action: () => {
          SavedStore.setArticleError(key, null).then(() => {
            a.errorCodeNumber = null;
            this.allSaved = this.allSaved.slice();
            this.applyFilterAndSort();
            this.downloadMissing(this.allSaved);
          }).catch((e: Error) => console.error('saved: retry failed: ' + e.message));
        }
      }]
    });
  }

  // SavedArticlesFetcher: fetch the offline copies still missing (articles synced from another
  // device), one at a time, clearing each row's dot as its copy lands.
  private async downloadMissing(rows: WMFArticle[]): Promise<void> {
    if (this.downloading) {
      return;
    }
    this.downloading = true;
    for (const article of rows) {
      if (article.isDownloaded || article.key === null) {
        continue;
      }
      // a failed article waits for the reader's Retry (retryFailedArticleDownloads runs on
      // pull to refresh in the source)
      if (article.errorCodeNumber === ARTICLE_ERROR_API_FAILED) {
        continue;
      }
      try {
        await SavedStore.downloadOffline(article.key);
        article.isDownloaded = true;
      } catch (e) {
        article.errorCodeNumber = ARTICLE_ERROR_API_FAILED;
        console.warn('saved: offline copy failed: ' + (e as Error).message);
      }
      this.allSaved = this.allSaved.slice();
      this.applyFilterAndSort();
    }
    this.downloading = false;
  }

  // searchBar textDidChange + allArticlesSortType applied to the fetch.
  private applyFilterAndSort(): void {
    const term: string = searchFold(this.searchText.trim());
    let rows: WMFArticle[] = this.allSaved.slice();
    if (term !== '') {
      rows = rows.filter((a: WMFArticle): boolean =>
        searchFold(a.displayTitle ?? '').indexOf(term) >= 0);
    }
    if (!this.sortByRecentlyAdded) {
      // SortActionType.byTitle
      rows.sort((a: WMFArticle, b: WMFArticle): number =>
        (a.displayTitle ?? '') < (b.displayTitle ?? '') ? -1 : 1);
    }
    this.savedArticles = rows;
    this.itemsSource.reload(rows);
  }

  // wmf_showLoginToSyncSavedArticlesToReadingListPanel: title, why, a log-in button and
  // Cancel. Only its buttons close it (the dimmed page behind stays inert).
  private loginToSyncDialog: CustomDialogController = new CustomDialogController({
    builder: LoginToSyncDialog({
      onLogin: (): void => {
        router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
          console.error('saved: login route failed: ' + e.message);
        });
      }
    }),
    autoCancel: false,
    cornerRadius: 32,
    width: '90%'
  });

  private showLoginToSyncPanel(): void {
    this.loginToSyncDialog.open();
  }

  // feat_saved_sync — ReadingListsController's sync runs behind
  // savedProgressViewController; it only runs while an account is signed in.
  private syncReadingLists(): void {
    if (!SessionStore.isLoggedIn) {
      return;
    }
    this.isSyncing = true;
    this.db()
      .then(() => ReadingListSyncService.syncToDatabase())
      .then(() => {
        this.isSyncing = false;
        this.reloadSavedArticles();
      })
      .catch((e: Error) => {
        this.isSyncing = false;
        console.error('saved: reading list sync failed: ' + e.message);
      });
  }

  // editAction -> toggleEditing / changeEditingState(to: .open)
  private didTapEdit(): void {
    this.scope = 'savedArticles';
    this.selectedKeys = [];
    this.isEditing = true;
  }

  private toggleSelected(key: string): void {
    this.selectedKeys = this.selectedKeys.includes(key)
      ? this.selectedKeys.filter((k: string): boolean => k !== key) : this.selectedKeys.concat([key]);
  }

  // the batch toolbar's Unsave
  private unsaveSelected(): void {
    const keys: string[] = this.selectedKeys.slice(0);
    this.selectedKeys = [];
    this.isEditing = false;
    Promise.all(keys.map((k: string): Promise<void> => SavedStore.userUnsave(k))).then(() => {
      this.reloadSavedArticles();
    }).catch((e: Error) => {
      console.error('saved: unsave failed: ' + e.message);
    });
  }

  private userDidTapProfile(): void {
    this.showProfileSheet = true;
  }

  private userDidTapTabs(): void {
    router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
      console.error('article tabs push failed: ' + e.message);
    });
  }

  private openArticle(articleTitle: string, articleKey: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle, 'articleKey': articleKey };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
