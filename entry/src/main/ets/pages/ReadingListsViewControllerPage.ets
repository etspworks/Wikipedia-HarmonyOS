// screen_reading_lists — presentation: page.
// S3 structure from Wikipedia/Code/ReadingListsViewController.swift:
//   - collectionView of ReadingListsCollectionViewCell rows (cellForItemAt ->
//     configure(cell:forItemAt:), one row per ReadingList of the fetchedResultsController,
//     default list first), row tap -> ReadingListDetailViewController.
//   - showEmptyView() (isEmptyDidChange): WMFEmptyViewController with title
//     "Organize saved articles with reading lists", subtitle "Create lists for places to
//     travel to, favorite topics and much more" and the button CommonStrings.createNewListTitle
//     ("Create a new list") -> presentCreateReadingListViewController(). The collectionView is
//     HIDDEN while empty, so the two never render together.
//   - createReadingList(with:) presents CreateReadingListViewController over full screen —
//     hosted here as a modal cover (screen_create_reading_list, hostedBy this screen).
// The nav bar carries the push-navigation Back button (capture S0323: Button "Back",
// resource-id BackButton).
// The root tab bar is NOT rendered here: this screen's controlInventory declares only
// create_a_new_list + Back, and the source tab bar belongs to the root screens.
// Data binding (lists <- svc_saved_store) is S4's pass.
import { router } from '@kit.ArkUI';
import { CreateReadingListView } from './CreateReadingListViewControllerPage';
import { ReadingListsCollectionViewCell } from '../components/ReadingListsCollectionViewCell';
import { EmptyViewController } from '../components/EmptyViewController';
import { ReadingListWithId, SavedStore } from '../common/SavedStore';
import { Database } from '../common/Database';
import { common } from '@kit.AbilityKit';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

class ReadingListDataSource implements IDataSource {
  private items: ReadingListWithId[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ReadingListWithId {
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

  reload(items: ReadingListWithId[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct ReadingListsViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State showCreateReadingList: boolean = false;
  // spec stateVar `items` — the fetchedResultsController's ReadingList objects (S4 fills).
  @State items: ReadingListWithId[] = [];
  // handleReadingListNameError(_:) — the duplicate-name error the create sheet shows
  @State createNameError: string = '';
  private itemsSource: ReadingListDataSource = new ReadingListDataSource();

  aboutToAppear(): void {
    this.reloadLists();
  }

  // viewWillAppear(_:) re-runs the fetchedResultsController fetch.
  onPageShow(): void {
    this.reloadLists();
  }

  // ReadingListsViewController.lists — the fetchedResultsController objects, spec'd on this
  // page as `items`. isEmptyDidChange branches on this collection being empty.
  private lists(): ReadingListWithId[] {
    return this.items;
  }

  @Builder
  createReadingListBuilder() {
    // createReadingList(with:) presents it; the delegate callback creates the list and
    // dismisses (the insert into svc_saved_store is S4's pass).
    CreateReadingListView({
      nameError: this.createNameError,
      onClose: (): void => {
        this.showCreateReadingList = false;
      },
      onCreate: (name: string, description: string): void => {
        this.didCreateReadingList(name, description);
      }
    })
  }

  @Builder
  listRow(item: ReadingListWithId) {
    ReadingListsCollectionViewCell({
      name: item.list.canonicalName ?? '',
      listDescription: item.list.readingListDescription ?? '',
      articleCount: item.list.countOfEntries,
      isDefault: item.list.isDefault,
      isCompact: false
    })
  }

  build() {
    Column() {
      // WMFNavigationBar — push navigation Back button: an icon-only round title-bar
      // button with the chevron glyph, no title beside it.
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.theme_text'))
        }
        .id('BackButton')
        .accessibilityText($r('app.string.back_button_accessibility_label'))
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          this.goBack();
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      // isEmptyDidChange: the empty view REPLACES the collection view (never beside it).
      if (this.lists().length === 0) {
        Column() {
          EmptyViewController({
            emptyImage: $r('app.media.reading_lists_empty_state'),
            // capture: the artwork is 132x118, not the 185 default
            imageSize: 132,
            emptyTitle: this.text($r('app.string.empty_no_reading_lists_title')),
            message: this.text($r('app.string.empty_no_reading_lists_message')),
            buttonTitle: this.text($r('app.string.reading_list_create_new_list_title')),
            buttonId: 'create_a_new_list',
            // capture S0323: title is 17 Bold and the button is a full-width
            // 322x46 capsule (radius 23), not the shared component's defaults
            titleFontSize: 17,
            buttonCapsule: true,
            onButtonTap: (): void => {
              this.openCreateReadingList();
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List() {
          LazyForEach(this.itemsSource, (item: ReadingListWithId) => {
            ListItem() {
              this.listRow(item)
            }
            .id('reading_list_itemroot')
            .onClick(() => {
              this.openReadingListDetail(item.listRowId);
            })
          }, (item: ReadingListWithId, index: number) => String(item.listRowId) + '_' + index)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .scrollBar(BarState.Off)
      }
    }
    .id('ReadingListsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }

  private goBack(): void {
    router.back();
  }

  // didSelectItemAt -> ReadingListDetailViewController(for: readingList)
  private openReadingListDetail(listRowId: number): void {
    const params: Record<string, string> = { 'listRowId': String(listRowId) };
    router.pushUrl({ url: 'pages/ReadingListDetailViewControllerPage', params: params });
  }

  // presentCreateReadingListViewController()
  private openCreateReadingList(): void {
    router.pushUrl({ url: 'pages/CreateReadingListViewControllerPage' });
  }

  // EmptyViewController and the create sheet take plain strings, so the screen resolves its own;
  // as literals they stayed English whatever the device language.
  private text(res: Resource): string {
    try {
      return (getContext(this) as common.Context).resourceManager.getStringSync(res);
    } catch (e) {
      console.error('reading lists: string unavailable: ' + (e as Error).message);
      return '';
    }
  }

  // createReadingListViewController(_:didCreateReadingListWith:description:articles:) —
  // S4 writes the list through svc_saved_store; the cover dismisses either way.
  private didCreateReadingList(name: string, description: string): void {
    this.createReadingList(name, description).catch((e: Error) => {
      // handleReadingListNameError: listExistsWithTheSameName keeps the sheet open.
      this.createNameError = e.message === 'listExistsWithTheSameName'
        ? this.text($r('app.string.reading_list_exists_with_same_name')) : e.message;
    });
  }

  // The store has to be open before any read or write below — this page is reached by a push
  // from Saved and by a deep link, and neither guarantees anyone opened it first.
  // Database.init is memoized, so each entry path calling it still opens the file once.
  private db(): Promise<void> {
    return Database.init(getContext(this) as common.UIAbilityContext);
  }

  private async createReadingList(name: string, description: string): Promise<void> {
    this.createNameError = '';
    await this.db();
    await SavedStore.createReadingList(name, description !== '' ? description : null);
    this.showCreateReadingList = false;
    await this.loadLists();
  }

  private reloadLists(): void {
    this.loadLists().catch((e: Error) => {
      console.error('reading lists: load failed: ' + e.message);
    });
  }

  private async loadLists(): Promise<void> {
    await this.db();
    const rows: ReadingListWithId[] = await SavedStore.readingLists();
    this.items = rows;
    this.itemsSource.reload(rows);
  }
}
