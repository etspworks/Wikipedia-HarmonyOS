// screen_reference_page — presentation: sheet, hosted by ArticleViewControllerPage
// (.bindSheet). NOT a routed page; never registered in main_pages.json.
// Ported from Wikipedia/Code/WMFReferencePageViewController.swift: a horizontal
// UIPageViewController (.scroll) over one WMFReferencePanelViewController per entry of
// lastClickedReferencesGroup, opened at lastClickedReferencesIndex, over a dimmed
// WMFReferencePageBackgroundView. It subclasses ReferenceViewController, so it carries the
// same nav chrome (title "Reference %@", close button); paging changes currentReference and
// re-highlights that reference in the article web view.
// S5: no capture — styled from the source roles + the app baseline tokens.
import { ArticleService } from '../common/ArticleService';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { extractReferences } from './ReferenceViewControllerPage';

@Component
export struct WMFReferencePageView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // the presenting ArticleViewController's article
  @Prop articleTitle: string = '';
  @Prop host: string = 'en.wikipedia.org';
  // lastClickedReferencesGroup — the reference html of every citation in the tapped group
  // spec stateVar: items <- refHtml
  @State items: string[] = [];
  // lastClickedReferencesIndex
  @State referenceIndex: number = 0;
  // referenceLinkText of the visible panel
  @State referenceLinkText: string = '';
  // S6: the visual states of the reference-group fetch S4 already wired.
  @State isLoading: boolean = true;
  @State loadError: string = '';
  onClose?: () => void;
  // didFinishAnimating -> currentReference = ref (re-highlights the link in the article)
  onReferenceChanged?: (index: number) => void;
  private swiper: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.load().catch((e: Error) => {
      console.error('referencePage: load failed: ' + e.message);
      this.loadError = 'These references could not be loaded.';
      this.isLoading = false;
    });
  }

  private async load(): Promise<void> {
    if (this.articleTitle === '') {
      this.isLoading = false;
      return;
    }
    const articleKey: string =
      'https://' + this.host + '/wiki/' + this.articleTitle.replace(/ /g, '_');
    let html: string | null = null;
    try {
      html = await ArticleCacheStore.cachedHtml(articleKey);
    } catch (e) {
      html = null;
    }
    if (html === null || html === '') {
      html = await ArticleService.fetchMobileHtml(this.host, this.articleTitle);
    }
    this.items = extractReferences(html);
    this.setCurrentReference(this.referenceIndex);
    this.isLoading = false;
  }

  // currentReference = ref — the visible panel's marker.
  private setCurrentReference(index: number): void {
    if (this.items.length === 0) {
      return;
    }
    const bounded: number = Math.min(Math.max(index, 0), this.items.length - 1);
    this.referenceIndex = bounded;
    this.referenceLinkText = '[' + (bounded + 1).toString() + ']';
  }

  build() {
    Column() {
      // ReferenceViewController's custom navigation bar
      Row() {
        // leading spacer matching the close button, so the title stays optically centred
        Row()
          .width(44)
          .height(44)
        Text('Reference ' + this.referenceLinkText)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          // Id scoping: this screen is an overlay, so its nodes share the host page's
          // component tree. The source slug is the part after the dot: close_button.
          .id('WMFReferencePageViewController.close_button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            const cb: (() => void) | undefined = this.onClose;
            if (cb !== undefined) {
              cb();
            }
          })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      if (this.isLoading) {
        // S6 loading visual — the reference group is still being read.
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('reference_page_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        // S6 empty/error visual
        Column() {
          Text(this.loadError !== '' ? this.loadError : 'No references are available.')
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .id('reference_page_empty')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
      // pageViewController: one WMFReferencePanelViewController per reference
      Swiper(this.swiper) {
        ForEach(this.items, (html: string, index: number) => {
          Scroll() {
            Text(html)
              .width('100%')
              .fontSize(17)
              .lineHeight(24)
              .fontColor($r('app.color.theme_text'))
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          }
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
        }, (html: string, index: number) => index.toString())
      }
      .index(this.referenceIndex)
      .loop(false)
      .layoutWeight(1)
      .width('100%')
      .onChange((index: number) => {
        this.setCurrentReference(index);
        const cb: ((index: number) => void) | undefined = this.onReferenceChanged;
        if (cb !== undefined) {
          cb(index);
        }
      })
      }

      // paging control (the pager's own next affordance)
      Button('Next reference')
        .id('reference_next')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .width('100%')
        .height(52)
        .onClick(() => {
          this.swiper.showNext();
        })
    }
    .id('WMFReferencePageViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
