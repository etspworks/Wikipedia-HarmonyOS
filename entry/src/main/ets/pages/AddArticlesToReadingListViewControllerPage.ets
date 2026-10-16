// screen_add_articles_to_reading_list — presentation: modal, hosted by
// ArticleViewControllerPage (.bindContentCover). NOT a routed page.
// Structure from Wikipedia/Code/AddArticlesToReadingListViewController.swift:
// a centerCompact nav title ("Add {{PLURAL:$1|$1 article|$1 articles}} to reading list"),
// the child ReadingListsViewController's list of pickable reading-list rows
// (ReadingListsCollectionViewCell, compact display type), and the bottom-pinned
// "Create a new list" button (createNewListButtonPressed -> createReadingList(with:)).
// The source presents CreateReadingListViewController INSIDE this modal (captured
// S0326 -> S0327 keeps the same page slug). The branch itself is owned by the HOST's
// `coverBuilder()` (activeCover === 'createReadingList'), not by a local @State here —
// see `onCreateNewList` below for why.
// The source's leading close X is a nav-bar affordance the capture does not carry and the
// plan's controlInventory does not list (its only implicit control is the sheet dismiss
// gesture), so no close button is rendered here.
// S5 (capture S0326): sheet on theme_mid_background; centerCompact nav title 17 semibold;
// the bottom button is the source's capsule UIButton.Configuration.filled() — height 46,
// baseBackgroundColor theme.colors.link (#3366CC, sampled from the capture), foreground
// paperBackground, .semiboldHeadline title, sizeClassPadding 8 inside a paperBackground
// container pinned to the safe-area bottom.
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { pluralString, formatString } from '../common/Plural';
import { Database } from '../common/Database';
import { SavedStore, ReadingListWithId, MAX_ENTRIES_PER_LIST } from '../common/SavedStore';
import { ReadingListsCollectionViewCell } from '../components/ReadingListsCollectionViewCell';

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

// The list an article was just added to ([rowId, name]), for the article's confirmation toast.
export const READING_LIST_ADDED_KEY: string = 'wmfReadingListAdded';

@Component
export struct AddArticlesToReadingListView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // init(with:articles:) — the articles the host screen is adding (the article the host
  // is showing), and the list of lists they are added to.
  @Prop articleKey: string = '';
  @Prop articleTitle: string = '';
  // several articles at once (the Saved tab's batch "Add to list"); empty = just articleKey
  @Prop articleKeys: string[] = [];
  // moveArticlesToReadingList: the list the articles leave once added elsewhere (0 = add only)
  @Prop moveFromListId: number = 0;
  @State items: ReadingListWithId[] = [];
  // The source pushes CreateReadingListViewController inside this same modal. A LOCAL
  // @State branch here never redraws: this struct is instantiated through the host's
  // `coverBuilder()` (an @Builder invoked as content for `.bindContentCover`), and ArkUI's
  // update pass for that overlay layer only re-runs off the HOST's own tracked state — a
  // plain internal @State write on THIS struct is accepted (the field genuinely flips) but
  // never triggers the redraw. Proven on device: `console.error` around the assignment
  // showed `showCreateList` going false -> true while the on-screen tree stayed byte-
  // identical. So the switch is routed back through the host, exactly like opening this
  // overlay itself already is (host `activeCover`/`showCover`, proven to redraw correctly).
  onCreateNewList: () => void = (): void => {};
  // needsAutoDismissUponAdd — the source dismisses itself once the articles are added
  // (readingListsViewController(_:didAddArticles:to:)). The host owns the cover flag.
  onDismiss: () => void = (): void => {};
  private itemsSource: ReadingListDataSource = new ReadingListDataSource();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        console.error('addArticles: load failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('addArticles: db init failed: ' + e.message);
    });
  }

  private async load(): Promise<void> {
    // the user's own lists; the default list is 'saved', which the article's bookmark is
    const lists: ReadingListWithId[] = (await SavedStore.readingLists())
      .filter((l: ReadingListWithId): boolean => !l.list.isDefault && l.listRowId !== this.moveFromListId);
    this.items = lists;
    this.itemsSource.reload(lists);
  }

  // ReadingListsViewController.addArticles(to:) — picking a list adds the articles to it.
  private addToList(row: ReadingListWithId): void {
    const keys: string[] = this.articleKeys.length > 0 ? this.articleKeys
      : (this.articleKey !== '' ? [this.articleKey] : []);
    if (keys.length === 0) {
      return;
    }
    // throwLimitErrorIfNecessary: a list already at the entry limit takes no more articles. The
    // source refuses the add and says why; accepting it left an entry the server would reject.
    if (row.list.countOfEntries + keys.length > MAX_ENTRIES_PER_LIST) {
      const context: common.Context = getContext(this) as common.Context;
      this.getUIContext().showAlertDialog({
        message: formatString(context, $r('app.string.reading_list_entry_limit_reached'),
          [String(keys.length), MAX_ENTRIES_PER_LIST.toString(), row.list.canonicalName ?? '']),
        autoCancel: false,
        confirm: { value: $r('app.string.button_ok'), action: () => {} }
      });
      return;
    }
    const adds: Promise<void>[] = keys.map((k: string) => SavedStore.addArticleToList(row.listRowId, k, null,
      k === this.articleKey ? this.articleTitle : decodeURIComponent(k.split('/wiki/')[1] ?? '').replace(/_/g, ' ')));
    Promise.all(adds)
      .then(async () => {
        // a move takes the articles out of the list they came from
        if (this.moveFromListId !== 0) {
          for (const k of keys) {
            await SavedStore.removeArticleFromList(this.moveFromListId, k);
          }
        }
        this.load().catch((e: Error) => {
          console.error('addArticles: reload failed: ' + e.message);
        });
        // WMFReadingListToastManager: the article that was added says where it went
        if (this.moveFromListId === 0 && this.articleKeys.length === 0) {
          AppStorage.setOrCreate<string>(READING_LIST_ADDED_KEY,
            JSON.stringify([String(row.listRowId), row.list.canonicalName ?? '']));
        }
        // needsAutoDismissUponAdd
        this.onDismiss();
      })
      .catch((e: Error) => {
        console.error('addArticles: addArticleToList failed: ' + e.message);
      });
  }

  // createNewReadingListButtonPressed
  private openCreateList(): void {
    this.onCreateNewList();
  }

  // WMFNavigationBarTitleConfig: "Add {{PLURAL:$1|$1 article|$1 articles}} to reading list"
  // ($1 = articles.count — this overlay always carries the host's single article).
  private navTitle(): string {
    // "Move 1 article to reading list" for a move; the count is the articles being handed over
    const count: number = this.articleKeys.length > 0 ? this.articleKeys.length : 1;
    return pluralString(getContext(this) as common.Context, this.moveFromListId !== 0
      ? $r('app.string.move_articles_to_reading_list') : $r('app.string.add_articles_to_reading_list'), count);
  }

  // The one "Create a new list" control. The source moves it between the empty view and
  // the bottom container (createNewListButtonContainerView) rather than drawing two.
  @Builder
  createListButton() {
    Button($r('app.string.reading_list_create_new_list_title'))
      .id('create_a_new_list')
      .type(ButtonType.Capsule)
      .width('100%')
      .height(46)
      .backgroundColor($r('app.color.theme_link'))
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .onClick(() => {
        this.openCreateList();
      })
  }

  // S6 (capture S0326): WMFEmptyView.noReadingLists — the sheet renders the empty view
  // centred, with no nav title and no bottom button container: 132x117 illustration,
  // 20pt gap, semibold 17 title, 13pt gap, 15pt secondary message, 18pt gap, the capsule
  // button inset 40 each side.
  @Builder
  emptyState() {
    Column() {
      Image($r('app.media.reading_lists_empty_state'))
        .width(132)
        .height(117)
        .objectFit(ImageFit.Contain)
      Text($r('app.string.empty_no_reading_lists_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
      Text($r('app.string.empty_no_reading_lists_message'))
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
        .lineHeight(19)
        .margin({ top: 13 })
      Row() {
        this.createListButton()
      }
      .width('100%')
      .padding({ left: 40, right: 40 })
      .margin({ top: 18 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.items.length === 0) {
        this.emptyState()
      } else {
        Row() {
          Text(this.navTitle())
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        List({ space: 0 }) {
          LazyForEach(this.itemsSource, (row: ReadingListWithId) => {
            ListItem() {
              Column() {
                ReadingListsCollectionViewCell({
                  name: row.list.canonicalName ?? '',
                  listDescription: row.list.readingListDescription ?? '',
                  articleCount: row.list.countOfEntries,
                  isDefault: row.list.isDefault,
                  isCompact: true,
                  imageURLs: []
                })
              }
              .width('100%')
              .id('readinglistrow_itemroot')
              .onClick(() => {
                this.addToList(row);
              })
            }
          }, (row: ReadingListWithId) => row.listRowId.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.theme_border'),
          startMargin: 16,
          endMargin: 16
        })
        .scrollBar(BarState.Off)

        // createNewListButtonContainerView — pinned to the safe-area bottom while the
        // list has rows. (Empty state: the same button sits inside WMFEmptyView — see
        // readingListsViewControllerDidChangeEmptyState, which hides this container.)
        Row() {
          this.createListButton()
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      }
    }
    .id('AddArticlesToReadingListViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}

// Routed host. As .bindContentCover content the view's lists (loaded into its own state)
// never drew - the sheet showed the empty state with lists present - and it had no way out
// but a system back. Params: articleKey, articleTitle.
@Entry
@Component
struct AddArticlesToReadingListPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  private articleKey: string = '';
  private articleTitle: string = '';
  // several articles (the Saved tab's batch "Add to list"), as a JSON array param
  private articleKeys: string[] = [];
  private moveFromListId: number = 0;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string> | undefined;
    if (p !== undefined && p !== null) {
      this.moveFromListId = parseInt(p['moveFromListId'] ?? '0') || 0;
      this.articleKey = p['articleKey'] ?? '';
      this.articleTitle = p['articleTitle'] ?? '';
      try {
        this.articleKeys = JSON.parse(p['articleKeys'] ?? '[]') as string[];
      } catch (e) {
        this.articleKeys = [];
      }
    }
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('close_button')
        .type(ButtonType.Circle)
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      AddArticlesToReadingListView({
        articleKey: this.articleKey,
        articleTitle: this.articleTitle,
        articleKeys: this.articleKeys,
        moveFromListId: this.moveFromListId,
        onCreateNewList: (): void => {
          // replace, so the new list's page returns straight to the article
          const params: Record<string, string> = {
            'articleKey': this.articleKey, 'articleTitle': this.articleTitle,
            'articleKeys': JSON.stringify(this.articleKeys), 'moveFromListId': String(this.moveFromListId) };
          router.replaceUrl({ url: 'pages/CreateReadingListViewControllerPage', params: params });
        },
        onDismiss: (): void => {
          router.back();
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
