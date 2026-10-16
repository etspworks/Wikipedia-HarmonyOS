// comp_article_rt_cell — ported from Wikipedia/Code/ArticleRightAlignedImageCollectionViewCell.swift
// (titleLabel + descriptionLabel left, right-aligned imageView, separators; save button from
// ArticleCollectionViewCell). S5: styled per captured states S0001/S0008.
//
// A row can also carry the source's peek/pop: ArticleCollectionViewController's
// contextMenuConfigurationForItem builds an ArticlePeekPreviewViewController plus the
// Open / Save for later / Share actions. Set `enablePreview` and give the row its article
// key and site host; the summary behind the preview is fetched when the menu opens.
import { Router, SymbolGlyphModifier } from '@kit.ArkUI';
import { TabsStore } from '../common/TabsStore';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { SavedStore } from '../common/SavedStore';
import { openRootTab } from './RootTabBar';

// Tint black template PNG (save.png) to the app link blue #3366CC.
// A press held this long is a hold, not a tap: releasing it before the menu appears does not
// open the article (TC-SEARCH-109). A plain tap lasts ~100 ms; the menu needs ~800 ms.
// a lift this close to where the long press began counts as not having moved
const STILL_VP: number = 10;
const HOLD_MS: number = 300;
const MENU_OPEN_ID: string = 'Article Preview Open';
const MENU_SAVE_ID: string = 'Article Preview Save';
const MENU_SHARE_ID: string = 'Article Preview Share';
const MENU_NEW_TAB_ID: string = 'Article Preview New Tab';
const MENU_BACKGROUND_TAB_ID: string = 'Article Preview Background Tab';
const MENU_MAP_ID: string = 'Article Preview Map';
// read by PlacesViewControllerPage: the article to centre the map on
export const PLACES_FOCUS_KEY: string = 'wmfPlacesFocus';
const PLACES_TAB: number = 1;

// NSUserActivity.wmf_URLForActivity(of: .places, withArticleURL:) -> PlacesViewController.showArticleURL:
// the Places tab, centred on the article with its callout open (the peek's map action and the
// article footer's "View on a map").
export function showArticleOnMap(router: Router, title: string, description: string, thumbnail: string,
  lat: number, lon: number): void {
  AppStorage.setOrCreate<string>(PLACES_FOCUS_KEY, JSON.stringify({
    title: title, description: description, thumbnail: thumbnail, lat: lat, lon: lon
  }));
  openRootTab(router, PLACES_TAB);
}

const BLUE_TINT: number[] = [
  0, 0, 0, 0, 0.2,
  0, 0, 0, 0, 0.4,
  0, 0, 0, 0, 0.8,
  0, 0, 0, 1, 0
];

@Component
export struct ArticleRightAlignedImageCollectionViewCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop title: string = '';
  // setTitleHTML(_:boldedString:): search results set the typed term; the title is then drawn
  // regular with that term bold, as the source's search list does. '' keeps the plain title.
  @Prop boldedString: string = '';
  @Prop description: string = '';
  @Prop imageURL: string = '';
  @Prop showSaveButton: boolean = false;
  // Row-root slug: each hosting screen passes its OWN list-row slug (Rule 12). Defaults to
  // screen_explore's, so that screen's usage is unchanged.
  @Prop rowId: string = 'Explore Article Cell';
  onTap?: () => void;
  onSave?: () => void;
  // peek/pop (ArticleCollectionViewController.contextMenuConfigurationForItem)
  @Prop enablePreview: boolean = false;
  // WMFArticle.key — 'https://<host>/wiki/<Title_with_underscores>'
  @Prop articleKey: string = '';
  @Prop host: string = '';
  @Prop articleTitle: string = '';
  // the snippet under the preview's title; filled from the article summary when the menu opens
  @State private previewExtract: string = '';
  @State private isSavedArticle: boolean = false;
  // article.location: [lat, lon] from the summary; the map action shows only when set
  @State private coords: number[] = [];
  onShare?: () => void;
  onSaveToggled?: (isSaved: boolean) => void;
  private pressStart: number = 0;
  private pressX: number = 0;
  // one summary request per row, started as the finger lands
  private summaryRequested: boolean = false;
  // the summary answered (or failed): the card stops showing its spinner
  @State summaryDone: boolean = false;
  private pressY: number = 0;
  private menuShown: boolean = false;
  // where each menu item sits, in vp from the screen origin (the menu window is full screen)
  private itemAreas: Map<string, Area> = new Map<string, Area>();

  // The peek preview and its saved-state label are only worth a round trip when the reader
  // actually holds the row, so both are read in the menu's onAppear.
  private loadPreview(): void {
    if (this.host !== '' && this.articleTitle !== '' && this.previewExtract === '' && !this.summaryRequested) {
      this.summaryRequested = true;
      ArticleService.fetchSummary(this.host, this.articleTitle)
        .then((summary: ArticleSummary): void => {
          this.previewExtract = summary.extract ?? '';
          if (summary.coordinates !== null) {
            this.coords = [summary.coordinates.lat, summary.coordinates.lon];
          }
          this.summaryDone = true;
        })
        .catch((e: Error): void => {
          this.summaryRequested = false;
          this.summaryDone = true;
          console.error('articleCell: preview summary failed: ' + e.message);
        });
    }
    if (this.articleKey !== '') {
      SavedStore.isSaved(this.articleKey)
        .then((saved: boolean): void => {
          this.isSavedArticle = saved;
        })
        .catch((e: Error): void => {
          console.error('articleCell: saved state failed: ' + e.message);
        });
    }
  }

  private toggleSave(): void {
    if (this.articleKey === '') {
      return;
    }
    SavedStore.toggleSave(this.articleKey, null, this.title)
      .then((saved: boolean): void => {
        this.isSavedArticle = saved;
        if (this.onSaveToggled !== undefined) {
          this.onSaveToggled(saved);
        }
      })
      .catch((e: Error): void => {
        console.error('articleCell: save toggle failed: ' + e.message);
      });
  }

  // Open in new tab: a fresh current tab, then the article (which appends itself to the current
  // tab). Open in background tab: a tab holding the article that does not become current.
  private openInTab(foreground: boolean): void {
    const projectID: string = 'wikipedia.' + (this.host !== '' ? this.host.split('.')[0] : 'en');
    const title: string = this.articleTitle !== '' ? this.articleTitle : this.title;
    (foreground ? TabsStore.createArticleTab(null, projectID, true) :
      TabsStore.createArticleTab(title, projectID, false))
      .then((): void => {
        if (foreground && this.onTap !== undefined) {
          this.onTap();
        }
      })
      .catch((e: Error): void => {
        console.error('articleCell: open in tab failed: ' + e.message);
      });
  }

  // The Places tab, centred on this article with its callout open.
  private viewOnMap(): void {
    showArticleOnMap(this.getUIContext().getRouter(), this.articleTitle !== '' ? this.articleTitle : this.title,
      this.description, this.imageURL, this.coords[0], this.coords[1]);
  }

  // ArticleActivityItemProvider — the system share panel over the article's URL.
  private share(): void {
    if (this.onShare !== undefined) {
      this.onShare();
      return;
    }
    const record: systemShare.SharedRecord = {
      utd: 'general.hyperlink',
      content: this.articleKey,
      title: this.title,
      description: this.description
    };
    try {
      const controller: systemShare.ShareController =
        new systemShare.ShareController(new systemShare.SharedData(record));
      controller.show(getContext(this) as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      }).catch((e: Error): void => {
        console.error('articleCell: share panel failed: ' + e.message);
      });
    } catch (e) {
      console.error('articleCell: share panel unavailable: ' + (e as Error).message);
    }
  }

  // The finger that raised the menu lifts on the row, not in the menu window, so the menu
  // never sees it. Lifting over an item runs that item (slide-to-select); lifting where the
  // press began leaves the preview and menu up, as iOS does (TC-SEARCH-110 / 112); lifting
  // after sliding anywhere else, the card included, dismisses them (TC-SEARCH-107 / 111).
  private onRowTouch(e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      this.pressStart = Date.now();
      // head start on the long-press threshold, so the card opens with its extract
      if (this.enablePreview) {
        this.loadPreview();
      }
      if (e.changedTouches.length > 0) {
        this.pressX = e.changedTouches[0].displayX;
        this.pressY = e.changedTouches[0].displayY;
      }
      return;
    }
    if (e.type !== TouchType.Up || !this.menuShown || e.changedTouches.length === 0) {
      return;
    }
    const x: number = e.changedTouches[0].displayX;
    const y: number = e.changedTouches[0].displayY;
    const onItem: boolean = this.isOver(MENU_OPEN_ID, x, y) || this.isOver(MENU_SAVE_ID, x, y) ||
      this.isOver(MENU_NEW_TAB_ID, x, y) || this.isOver(MENU_BACKGROUND_TAB_ID, x, y) ||
      this.isOver(MENU_SHARE_ID, x, y) || this.isOver(MENU_MAP_ID, x, y);
    if (!onItem && Math.abs(x - this.pressX) <= STILL_VP && Math.abs(y - this.pressY) <= STILL_VP) {
      return;
    }
    ContextMenu.close();
    if (this.isOver(MENU_OPEN_ID, x, y)) {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    } else if (this.isOver(MENU_SAVE_ID, x, y)) {
      this.toggleSave();
    } else if (this.isOver(MENU_SHARE_ID, x, y)) {
      this.share();
    } else if (this.isOver(MENU_NEW_TAB_ID, x, y)) {
      this.openInTab(true);
    } else if (this.isOver(MENU_BACKGROUND_TAB_ID, x, y)) {
      this.openInTab(false);
    } else if (this.isOver(MENU_MAP_ID, x, y)) {
      this.viewOnMap();
    }
  }

  private isOver(id: string, x: number, y: number): boolean {
    const a: Area | undefined = this.itemAreas.get(id);
    if (a === undefined) {
      return false;
    }
    const left: number = Number(a.globalPosition.x);
    const top: number = Number(a.globalPosition.y);
    return x >= left && x <= left + Number(a.width) && y >= top && y <= top + Number(a.height);
  }

  // ArticlePeekPreviewViewController — image over title, description and the lead extract.
  @Builder
  previewCard() {
    Column() {
      if (this.imageURL !== '') {
        Image(this.imageURL)
          .width('100%')
          .height(160)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('app.color.gray200'))
      }
      Column() {
        Text(this.title)
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.description !== '') {
          Text(this.description)
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 4 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        // The snippet's five lines are reserved before it loads: a card that grew afterwards
        // moved the menu under the finger, and the slide-to-select hit test with it.
        if (!this.summaryDone) {
          // the source's peek shows a spinner until the summary arrives
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color($r('app.color.theme_secondary_text'))
          }
          .width('100%')
          .height(105)
          .margin({ top: 10 })
          .justifyContent(FlexAlign.Center)
        } else {
          Text(this.previewExtract)
            .width('100%')
            .height(105)
            .fontSize(15)
            .lineHeight(21)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 10 })
            .align(Alignment.TopStart)
            // the snippet ends on a whole line with an ellipsis rather than being sliced
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width(320)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  @Builder
  previewMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.article_tabs_open'), endIcon: $r('app.media.chevron_right') })
        .id(MENU_OPEN_ID)
        .onAreaChange((o: Area, n: Area): void => {
          this.itemAreas.set(MENU_OPEN_ID, n);
        })
        .onClick((): void => {
          if (this.onTap !== undefined) {
            this.onTap();
          }
        })
      // the source's contextMenu: Open, Open in new tab, Open in background tab, Save, Share
      MenuItem({ content: $r('app.string.article_tabs_open_new_tab'), symbolStartIcon: this.menuSymbol($r('sys.symbol.square_and_square')) })
        .id(MENU_NEW_TAB_ID)
        .onAreaChange((o: Area, n: Area): void => {
          this.itemAreas.set(MENU_NEW_TAB_ID, n);
        })
        .onClick((): void => {
          this.openInTab(true);
        })
      MenuItem({ content: $r('app.string.article_tabs_open_background_tab'), symbolStartIcon: this.menuSymbol($r('sys.symbol.square_and_square')) })
        .id(MENU_BACKGROUND_TAB_ID)
        .onAreaChange((o: Area, n: Area): void => {
          this.itemAreas.set(MENU_BACKGROUND_TAB_ID, n);
        })
        .onClick((): void => {
          this.openInTab(false);
        })
      MenuItem({
        content: this.isSavedArticle ? $r('app.string.button_saved_remove')
          : $r('app.string.button_save_for_later'),
        // a saved article shows the filled bookmark (bookmark.fill), an unsaved one the outline
        symbolStartIcon: this.menuSymbol(this.isSavedArticle ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
      })
        .id(MENU_SAVE_ID)
        .onAreaChange((o: Area, n: Area): void => {
          this.itemAreas.set(MENU_SAVE_ID, n);
        })
        .onClick((): void => {
          this.toggleSave();
        })
      // viewOnMapArticlePreviewActionSelected: only for an article with a location
      if (this.coords.length === 2) {
        MenuItem({ content: $r('app.string.page_location'), symbolStartIcon: this.menuSymbol($r('sys.symbol.map')) })
          .id(MENU_MAP_ID)
          .onAreaChange((o: Area, n: Area): void => {
            this.itemAreas.set(MENU_MAP_ID, n);
          })
          .onClick((): void => {
            this.viewOnMap();
          })
      }
      MenuItem({ content: $r('app.string.article_share'), symbolStartIcon: this.menuSymbol($r('sys.symbol.share')) })
        .id(MENU_SHARE_ID)
        .onAreaChange((o: Area, n: Area): void => {
          this.itemAreas.set(MENU_SHARE_ID, n);
        })
        .onClick((): void => {
          this.share();
        })
    }
  }

  // the context menu's SF-symbol glyphs: system symbols scale to the row instead of cropping
  // a fixed-size bitmap
  private menuSymbol(res: Resource): SymbolGlyphModifier {
    return new SymbolGlyphModifier(res).fontColor([$r('app.color.theme_text')]);
  }

  build() {
    // The long-press preview is attached on a wrapper: bindContextMenu takes no visibility
    // flag in this API version, so the rows that do not want it are built without it.
    if (this.enablePreview) {
      Column() {
        this.rowBody()
      }
      .width('100%')
      .onTouch((e: TouchEvent): void => {
        this.onRowTouch(e);
      })
      .bindContextMenu(this.previewMenu(), ResponseType.LongPress, {
        preview: this.previewCard(),
        onAppear: (): void => {
          this.menuShown = true;
          this.loadPreview();
        },
        onDisappear: (): void => {
          this.menuShown = false;
        }
      })
    } else {
      this.rowBody()
    }
  }

  // The title split around every case-insensitive occurrence of boldedString:
  // [before, match, between, match, ..., after]; one run when there is nothing to bold.
  private titleRuns(): string[] {
    const term: string = this.boldedString.trim().toLowerCase();
    if (term === '') {
      return [this.title];
    }
    const lower: string = this.title.toLowerCase();
    const runs: string[] = [];
    let at: number = 0;
    let hit: number = lower.indexOf(term);
    while (hit >= 0) {
      runs.push(this.title.substring(at, hit));
      runs.push(this.title.substring(hit, hit + term.length));
      at = hit + term.length;
      hit = lower.indexOf(term, at);
    }
    runs.push(this.title.substring(at));
    return runs;
  }

  @Builder
  rowBody() {
    Column() {
      Row() {
        Column() {
          // Full width, so a right-to-left title lines up on the right like its description
          // instead of hugging the left edge.
          Text() {
            ForEach(this.titleRuns(), (run: string, i: number) => {
              // odd runs are the matched term
              Span(run)
                .fontWeight(i % 2 === 1 ? FontWeight.Bold : (this.boldedString !== '' ? FontWeight.Regular : FontWeight.Medium))
            }, (run: string, i: number) => i + '_' + run)
          }
            .width('100%')
            .fontSize(18)
            .fontColor($r('app.color.theme_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.description !== '') {
            Text(this.description)
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ top: 3 })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.imageURL !== '') {
          Image(this.imageURL)
            .width(60)
            .height(60)
            .objectFit(ImageFit.Cover)
            .borderRadius(3)
            .backgroundColor($r('app.color.gray200'))
            .margin({ left: 12 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.showSaveButton) {
        Button() {
          Row() {
            Image($r('app.media.save'))
              .height(18)
              .objectFit(ImageFit.Contain)
              .colorFilter(new ColorFilter(BLUE_TINT))
            Text('Save for later')
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .margin({ left: 8 })
          }
          .alignItems(VerticalAlign.Center)
        }
        .id('save_for_later')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .margin({ top: 10 })
        .onClick(() => {
          if (this.onSave !== undefined) {
            this.onSave();
          }
        })
      }
      // capture shows no separator line between rows — whitespace only
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .id(this.rowId)
    .onClick(() => {
      if (this.enablePreview && Date.now() - this.pressStart >= HOLD_MS) {
        return;
      }
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
