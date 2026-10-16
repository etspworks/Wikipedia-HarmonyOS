// screen_table_of_contents — the article's table of contents as the source presents it on a
// phone (TableOfContentsPresentationController.swift + TableOfContentsAnimator.swift, modal
// display mode): a panel sliding in from the article's leading edge, at most 300 vp wide and
// always leaving at least 60 vp of the article visible beside it under a blur. A tap on
// that blurred strip or on its 44 vp close button, a swipe back toward the leading edge, or the
// system back closes it. NOT a routed page: the article screens mount it over themselves.
// The panel itself is comp_toc_panel (components/TableOfContentsViewController.ets).
import { display } from '@kit.ArkUI';
import { topSafeInset } from '../common/SafeArea';
import { TableOfContentsViewController, TocItem } from '../components/TableOfContentsViewController';

// TableOfContentsPresentationController.maximumTableOfContentsWidth / minimumVisibleBackgroundWidth
const MAX_PANEL_WIDTH: number = 300;
const MIN_VISIBLE_BACKGROUND: number = 60;

@Component
export struct TableOfContentsView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;
  @Prop items: TocItem[] = [];
  @Prop articleTitle: string = '';
  @Prop currentAnchor: string = '';
  // the article's own direction: a right-to-left article gets the panel on the right
  @Prop rtl: boolean = false;
  // didSelectItem — the host scrolls the article to the anchor and closes the panel
  onSelect: (anchor: string) => void = (anchor: string): void => {};
  // TableOfContentsPresentationController.didTap(_:) — the dimmed strip and the close button
  onClose: () => void = (): void => {};
  private panelWidth: number = MAX_PANEL_WIDTH;
  // the status bar's height: the view sits below it, and the strip reaches up over it
  private topInset: number = topSafeInset();

  aboutToAppear(): void {
    try {
      const screenWidth: number = px2vp(display.getDefaultDisplaySync().width);
      this.panelWidth = Math.min(MAX_PANEL_WIDTH, screenWidth - MIN_VISIBLE_BACKGROUND);
    } catch (e) {
      this.panelWidth = MAX_PANEL_WIDTH;
    }
  }

  private paper(): ResourceColor {
    return this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // backgroundView: blurs the article (Theme.blurEffectStyle: light, dark in Dark/Black); a
      // tap anywhere on it closes the panel
      Stack({ alignContent: Alignment.TopEnd }) {
        // closeButton: WMFLargeCloseButtonConfig .plainX, top trailing
        Button() {
          // tinted primaryText, without the iOS 26 glass backing
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('TableOfContentsViewController.close_button')
        .accessibilityText('Close Table of contents')
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .width(44)
        .height(44)
        .margin({ top: 8, right: 8 })
        .onClick((): void => {
          this.onClose();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK,
        { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT })
      // the navigation indicator strip blurs too, as the source's view covers the whole window
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onClick((): void => {
        this.onClose();
      })
      .transition(TransitionEffect.OPACITY)

      // statusBarBackground: the paper colour across the status bar, full width, with its shadow
      // falling on the blur (the panel, above it, hides it on its own side)
      Column()
        .width('100%')
        .height(this.topInset)
        .position({ x: 0, y: -this.topInset })
        .backgroundColor(this.paper())
        .shadow({ radius: 8, color: this.isDark ? '#66000000' : '#33000000', offsetY: 3 })
        .hitTestBehavior(HitTestMode.None)
        .transition(TransitionEffect.OPACITY)

      Column() {
        TableOfContentsViewController({
          items: this.items,
          articleTitle: this.articleTitle,
          currentAnchor: this.currentAnchor,
          onSelect: (anchor: string): void => {
            this.onSelect(anchor);
          }
        })
      }
      .id('TableOfContentsViewController')
      .width(this.panelWidth)
      .height('100%')
      // the panel starts under the status bar strip (frameOfPresentedViewInContainerView)
      // and runs down under the navigation indicator
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .backgroundColor(this.paper())
      .shadow({ radius: 10, color: '#1F000000', offsetX: 3, offsetY: 0 })
      // TableOfContentsViewController.closeGestureRecognizer: a swipe toward the side it
      // came from
      .gesture(PanGesture({ direction: this.rtl ? PanDirection.Right : PanDirection.Left, distance: 20 })
        .onActionEnd((): void => {
          this.onClose();
        }))
      .transition(TransitionEffect.move(TransitionEdge.START))
    }
    .width('100%')
    .height('100%')
    .direction(this.rtl ? Direction.Rtl : Direction.Ltr)
  }
}
