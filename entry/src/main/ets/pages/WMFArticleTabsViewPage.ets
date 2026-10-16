// screen_article_tabs — presentation: modal. NOW A ROUTED PAGE (see ArticleTabsPage at the
// foot of this file). As a .bindContentCover child of a root screen it was built twice: the
// host rebuilds its cover content on its own state writes, and the instance that ran
// aboutToAppear (and therefore set isReady) was not the instance left on screen, so the
// overview sat on its loading spinner forever with the tab data already read.
//
// Source: WMFComponents/.../Article Tabs/WMFArticleTabsView.swift (grid + tab card),
// WMFArticleTabsHostingController.swift (nav bar: close / add / overflow menu),
// WMFArticleTabsViewModel.swift (loadTabs, closeTab, didTapTab, didTapCloseAllTabs).
// Data: svc_tabs_store (TabsStore / CDArticleTab / CDArticleTabItem) + article summaries.

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { formatString, pluralString } from '../common/Plural';
import { ArticleTab, TabArticle, TabsStore } from '../common/TabsStore';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';

// WMFArticleTabsView.ArticleTab (view model) + its Info — one grid cell.
export class TabCard {
  identifier: string = '';                         // CDArticleTab.identifier
  title: string = '';                              // data.articles.last.title
  timestamp: number = 0;                           // dateCreated (grid sort key)
  isCurrent: boolean = false;                      // currentTabID == tab.id (border)
  isMain: boolean = false;                         // data.articles.last.isMain
  articleURL: string = '';
  projectID: string = '';
  hasInfo: boolean = false;                        // info == nil -> loadingTabContent()
  subtitle: string = '';                           // info.subtitle
  description: string = '';                        // info.description
  imageURL: string = '';                           // info.image
}

// LazyVGrid backing store.
class TabCardDataSource implements IDataSource {
  private cards: TabCard[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.cards.length;
  }

  getData(index: number): TabCard {
    return this.cards[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  reload(cards: TabCard[]): void {
    this.cards = cards;
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  // One card's Info arrived. LazyForEach keys by tab identifier, which does not change when
  // a summary lands, so onDataReloaded alone left the already-built cell on screen with its
  // title and nothing else. onDataChange is the notification that rebuilds that one cell.
  update(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataChange(index);
    }
  }
}

@Component
export struct WMFArticleTabsView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // didTapDone — the host owns the cover flag.
  onClose: () => void = (): void => {};
  // spec stateVar: items <- svc_tabs_store (fetchAllArticleTabs)
  @State items: TabCard[] = [];
  // isReady (loadingView until the first load resolves)
  @State isReady: boolean = false;
  // the overflow menu is up — the button is drawn in its active state while it is.
  @State isMenuOpen: boolean = false;
  private source: TabCardDataSource = new TabCardDataSource();
  private disposed: boolean = false;

  // navBarTitleFormat: {{PLURAL:$1|$1 tab|$1 tabs}}. The count was built from English
  // literals, so a Turkish device read "2 tabs" where the catalogue says "2 sekme".
  private navTitle(): string {
    return pluralString(getContext(this) as common.Context,
      $r('app.string.tabs_navbar_title_format'), this.items.length);
  }

  build() {
    Column() {
      // WMFArticleTabsHostingController.configureNavigationBar
      Row() {
        // WMFLargeCloseButtonConfig(imageType: .prominentCheck, action: tappedDone)
        Button() {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor([(this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'))])
        }
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFArticleTabsView.close_button')
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.theme_link'))
        .onClick((): void => {
          this.isMenuOpen = false;
          this.onClose();                       // didTapDone -> host dismisses the cover
        })

        Blank()
        Text(this.navTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        Blank()

        // overflowButton — shown with the dynamic-tabs-V2 nav bar (capture S0190)
        Button() {
          // SF `ellipsis`. sys.symbol.more_fill draws as a four-square grid on this device,
          // not the capture's horizontal three dots, so the button carries the bundled
          // more.png (the same glyph the Activity nav bar uses) tinted to the text colour.
          // Selected state: the source's overflow button is drawn active while its menu is
          // up; on the round title-bar button that is the glyph turning link blue.
          Image($r('app.media.more'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
            .colorFilter(this.glyphTint(this.isMenuOpen ? (this.isDark ? '#6699FF' : '#3366CC')
              : (this.isDark ? '#F8F9FA' : '#202122')))
        }
        .id('article_tabs_more')
        .attributeModifier(NAV_ICON_BUTTON)
        .margin({ right: 20 })
        // The menu is drawn in the page rather than with bindMenu: bindMenu's overlay
        // swallows the tap that dismisses it, so tapping done or + while the menu was up
        // only closed the menu and the button underneath never fired.
        .onClick((): void => {
          this.isMenuOpen = !this.isMenuOpen;
        })

        // addTabButton
        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('article_tabs_add')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick((): void => {
          this.isMenuOpen = false;
          this.addTab();
        })
      }
      .width('100%')
      .height(54)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      // galleryBody: loadingView / emptyStateContainer / tabsGrid, with the overflow menu
      // drawn over it. The menu's dismiss area stops at the nav bar, so a tap on done or +
      // reaches the button.
      Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
      if (!this.isReady) {
        LoadingProgress()
          .width(48)
          .height(48)
      } else if (this.items.length === 0) {
        this.emptyState()
      } else {
        Grid() {
          LazyForEach(this.source,
            (card: TabCard) => {
              GridItem() {
                this.tabCard(card)
              }
            },
            // The key carries the card's load state: LazyForEach reuses a cell whose key is
            // unchanged, so keying on the tab identifier alone left the first-rendered
            // title-only cell on screen after its summary arrived.
            (card: TabCard) => card.identifier + (card.hasInfo ? '-info' : '-loading'))
        }
        .columnsTemplate('1fr 1fr')            // calculateColumns: phone portrait = 2
        .columnsGap(8)
        .rowsGap(8)
        .padding({ left: 8, right: 8 })
        .layoutWeight(1)
        .width('100%')
      }
      }
      .width('100%')
      .height('100%')

      if (this.isMenuOpen) {
        // tap anywhere in the body to dismiss, as the source's menu does
        Column()
          .width('100%')
          .height('100%')
          .onClick((): void => {
            this.isMenuOpen = false;
          })
        Column() {
          Row() {
            Text($r('app.string.close_all_tabs'))
              .fontSize(17)
              .fontColor($r('app.color.theme_destructive'))   // UIAlertAction .destructive
          }
          .id('article_tabs_close_all')
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .onClick((): void => {
            this.isMenuOpen = false;
            this.confirmCloseAllTabs();
          })
        }
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(14)
        .shadow({ radius: 16, color: '#26000000', offsetY: 4 })
        .margin({ top: 8, right: 20 })
      }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .id('WMFArticleTabsView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }

  // more.png is a solid gray raster template; .fillColor is SVG-only and .colorBlend does
  // not tint a raster, so rebuild the glyph colour from the alpha channel.
  private glyphTint(hex: string): ColorFilter {
    const n: number = parseInt(hex.replace('#', ''), 16);
    return new ColorFilter([
      0, 0, 0, ((n >> 16) & 0xFF) / 255, 0,
      0, 0, 0, ((n >> 8) & 0xFF) / 255, 0,
      0, 0, 0, (n & 0xFF) / 255, 0,
      0, 0, 0, 1, 0
    ]);
  }

  // emptyStateContainer — WMFEmptyView(.noItems) with the "empty-tabs" image.
  @Builder
  emptyState() {
    Column() {
      Image($r('app.media.empty_tabs'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
      Text($r('app.string.tabs_empty_view_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
      Text($r('app.string.tabs_empty_view_subtitle'))
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 32, right: 32 })
    .justifyContent(FlexAlign.Center)
  }

  // WMFArticleTabsViewContent
  @Builder
  tabCard(card: TabCard) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if (card.isMain) {
          this.mainPageTabContent(card)
        } else {
          // loadingTabContent() still shows the tab's TITLE while its summary is in
          // flight — the card is identifiable from the moment it exists. Rendering an
          // empty Text instead left a tab whose summary never arrived (offline, or a
          // failed fetch) as a permanently blank white card.
          this.standardTabContent(card)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // WMFSmallCloseButton — shouldShowCloseButton (dynamic-tabs V2: always shown)
      Button() {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(20)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
          .fontColor([$r('app.color.theme_link'), $r('app.color.theme_new_border')])
      }
      .id('xmark.circle.fill')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(44)
      .height(44)
      .onClick((): void => {
        this.closeTab(card);
      })
    }
    .id('article_tab_itemroot')
    .width('100%')
    .aspectRatio(3 / 4)                       // AspectRatioModifier(shouldLockAspectRatio)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(12)
    .clip(true)
    .border({
      width: 1,
      color: card.isCurrent ? $r('app.color.theme_secondary_text') : Color.Transparent
    })
    .shadow({ radius: 16, color: '#0D000000' })
    .onClick((): void => {
      this.openTab(card);
    })
  }

  // mainPageTabContent()
  @Builder
  mainPageTabContent(card: TabCard) {
    Column() {
      Image($r('app.media.globe_yir'))
        .width('100%')
        .height(95)
        .objectFit(ImageFit.Contain)
      Text($r('app.string.main_page'))
        .fontSize(16)
        .fontFamily('serif')                  // WMFFont.georgiaCallout
        .fontColor($r('app.color.theme_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 10, right: 10, top: 10, bottom: 2 })
      Text($r('app.string.tabs_main_page_subtitle'))
        .fontSize(12)
        .fontColor($r('app.color.theme_secondary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 10, right: 10 })
      Divider()
        .width(24)
        .color($r('app.color.theme_secondary_text'))
        .margin({ left: 10, top: 4, bottom: 6 })
      Text($r('app.string.tabs_main_page_description'))
        .fontSize(12)
        .fontColor($r('app.color.theme_text'))
        .lineHeight(17)
        .margin({ left: 10, right: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // standardTabContent()
  @Builder
  standardTabContent(card: TabCard) {
    Column() {
      if (card.imageURL !== '') {
        Image(card.imageURL)
          .width('100%')
          .height(95)
          .objectFit(ImageFit.Cover)
          .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        Text(card.title)
          .fontSize(16)
          .fontFamily('serif')                // WMFFont.georgiaCallout
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 10, right: 10, top: 10, bottom: 2 })
        this.tabText(card)
      } else {
        Text(card.title)
          .fontSize(16)
          .fontFamily('serif')
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 10, right: 40, top: 10, bottom: 2 })
        this.tabText(card)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // tabText(tab:)
  @Builder
  tabText(card: TabCard) {
    Column() {
      if (card.subtitle !== '') {
        Text(card.subtitle)
          .fontSize(12)
          .fontColor($r('app.color.theme_secondary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Divider()
        .width(24)
        .color($r('app.color.theme_secondary_text'))
        .margin({ top: 8, bottom: 8 })
      if (card.description !== '') {
        // The card is a fixed 3:4 tile that clips: cap the extract so it ends on a whole
        // line with an ellipsis instead of being sliced mid-glyph at the card's edge.
        Text(card.description)
          .fontSize(12)
          .fontColor($r('app.color.theme_text'))
          .lineHeight(17)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 10, right: 10 })
  }

  aboutToAppear(): void {
    // WMFArticleTabsViewModel.init -> Task { await loadTabs() }
    this.loadTabs();
    // dataController.updateSurveyDataTabsOverviewSeenCount() (overview impression)
    TabsStore.updateSurveyDataTabsOverviewSeenCount();
  }

  aboutToDisappear(): void {
    // prefetch tasks are cancelled on deinit — stop applying late summary results.
    this.disposed = true;
  }

  private async currentProjectID(): Promise<string> {
    const lang: MWKLanguageLink = await LanguageStore.appLanguage();
    return 'wikipedia~' + lang.languageCode;
  }

  private async currentHost(): Promise<string> {
    const lang: MWKLanguageLink = await LanguageStore.appLanguage();
    return lang.languageCode + '.wikipedia.org';
  }

  // WMFArticleTabsViewModel.loadTabs()
  private async loadTabs(): Promise<void> {
    try {
      const tabs: ArticleTab[] = await TabsStore.fetchAllArticleTabs();
      const currentTabID: string | null = await TabsStore.currentTabIdentifier();
      const cards: TabCard[] = [];
      for (const tab of tabs) {
        const card = new TabCard();
        card.identifier = tab.identifier;
        card.timestamp = tab.timestamp;
        card.isCurrent = tab.identifier === currentTabID;
        const last: TabArticle | null =
          tab.articles.length > 0 ? tab.articles[tab.articles.length - 1] : null;
        if (last !== null) {
          card.title = last.title.replace(/_/g, ' ');   // title.underscoresToSpaces
          card.articleURL = last.articleURL;
          card.projectID = last.projectID;
          card.isMain = card.title === 'Main Page';
        }
        cards.push(card);
      }
      this.publish(cards);
      // The grid (or the empty state) is ready as soon as the tabs are read. The source
      // fills each card's Info afterwards — loadingTabContent() is a per-CARD placeholder,
      // not a screen-wide gate. Awaiting the summary prefetch here meant one hung network
      // call left the whole overview on its spinner with nothing else to look at, which is
      // exactly what a device with no open tabs showed: a permanent loading indicator.
      this.isReady = true;
      await this.loadSummaries(cards);
    } catch (e) {
      console.error('articleTabs: loadTabs failed: ' + this.describeError(e));
    } finally {
      this.isReady = true;
    }
  }

  // ensureInfo(for:) / prefetchAllSummariesTrickled — fills each card's Info.
  private async loadSummaries(cards: TabCard[]): Promise<void> {
    const host: string = await this.currentHost();
    for (let i: number = 0; i < cards.length; i++) {
      if (this.disposed) {
        return;
      }
      const card: TabCard = cards[i];
      if (card.isMain || card.title === '') {
        card.hasInfo = true;
        continue;
      }
      try {
        const summary: ArticleSummary = await ArticleService.fetchSummary(host, card.title);
        card.subtitle = summary.articleDescription ?? '';
        card.description = summary.extract ?? '';
        card.imageURL = summary.thumbnail !== null ? summary.thumbnail.source : '';
      } catch (e) {
        console.error('articleTabs: summary failed for ' + card.title + ': ' +
          this.describeError(e));
      }
      card.hasInfo = true;
      this.source.update(i);
    }
  }

  private publish(cards: TabCard[]): void {
    this.items = cards;
    this.source.reload(cards);
  }

  // didTapTab(tab.data) — set the tapped tab current, open its last article, dismiss.
  // replaceUrl, not pushUrl + onClose(): onClose is router.back(), which popped the article
  // that had just been pushed and dropped the reader back on the overview.
  private openTab(card: TabCard): void {
    TabsStore.setTabAsCurrent(card.identifier).then((): void => {
      // isRestoringState = true keeps the tab's reading position
      const params: Record<string, string> = { 'articleTitle': card.title, 'articleKey': card.articleURL,
        'restoreScroll': 'true' };
      router.replaceUrl({ url: 'pages/ArticleViewControllerPage', params: params })
        .catch((e: Error): void => {
          console.error('articleTabs: open tab route failed: ' + e.message);
        });
    }).catch((e: Object): void => {
      console.error('articleTabs: setTabAsCurrent failed: ' + this.describeError(e));
    });
  }

  // closeTab(tab:) — deleteArticleTab, then reload.
  private closeTab(card: TabCard): void {
    TabsStore.deleteArticleTab(card.identifier).then((): void => {
      this.loadTabs();
    }).catch((e: Object): void => {
      console.error('articleTabs: closeTab failed: ' + this.describeError(e));
    });
  }

  // tappedAddTab() — new tab on Main Page, set current, and show it in the grid. The
  // overview stays up: the new tab is added to it, and the reader leaves through the done
  // button or by tapping a card, so repeated taps add one tab each.
  private addTab(): void {
    TabsStore.didTapOpenNewTab();
    this.currentProjectID().then((projectID: string): void => {
      TabsStore.createArticleTab('Main Page', projectID, true).then((): void => {
        this.loadTabs();
      }).catch((e: Object): void => {
        console.error('articleTabs: createArticleTab failed: ' + this.describeError(e));
      });
    });
  }

  // overflowMenu -> presentCloseAllTabsConfirmationDialog()
  private confirmCloseAllTabs(): void {
    // The catalogue's $1 is not ArkUI's placeholder syntax: passed to $r() the dialog read
    // "$1 sekmenin tumu kapatilsin mi?". These are resolved before they reach the dialog.
    const context = getContext(this) as common.Context;
    const count: string[] = [this.items.length.toString()];
    AlertDialog.show({
      title: formatString(context, $r('app.string.close_all_tabs_confirmation_title_with_value'), count),
      message: formatString(context, $r('app.string.close_all_tabs_confirmation_subtitle_with_value'), count),
      // stacked, not side by side: "Tum sekmeleri kapat" is wider than half the dialog and
      // came out as "Tum ...".
      buttonDirection: DialogButtonDirection.VERTICAL,
      buttons: [
        {
          value: $r('app.string.close_all_tabs'),
          fontColor: $r('app.color.theme_destructive'),   // UIAlertAction .destructive
          action: (): void => {
            this.closeAllTabs();
          }
        },
        {
          value: $r('app.string.cancel'),
          action: (): void => {
          }
        }
      ]
    });
  }

  // didTapCloseAllTabs()
  private closeAllTabs(): void {
    TabsStore.deleteAllTabs().then((): void => {
      this.loadTabs();
    }).catch((e: Object): void => {
      console.error('articleTabs: deleteAllTabs failed: ' + this.describeError(e));
    });
  }

  private describeError(e: Object): string {
    return e instanceof Error ? e.message : String(e);
  }
}

// The routed host. Every screen with a Tabs button pushes this instead of binding a cover,
// so the overview owns its own component tree and its loaded state survives whatever the
// screen underneath is doing.
@Entry
@Component
struct ArticleTabsPage {
  // A second tap on done arrives before the pop has run, and two back()s popped the article
  // underneath as well.
  private dismissed: boolean = false;

  build() {
    Column() {
      WMFArticleTabsView({
        onClose: (): void => {
          if (this.dismissed) {
            return;
          }
          this.dismissed = true;
          router.back();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
