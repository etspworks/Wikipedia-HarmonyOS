// Ported from Wikipedia/Code/EditPreviewViewController.swift (article flow, editorPreviewSave):
// "Preview" with Next, the "Retrieving preview of your changes..." toast, and a web view of the
// edited wikitext as mobile-html (wikitextToMobileHTMLPreviewRequest, output-mode editPreview).
// A tapped link is not followed: an internal one shows EditPreviewInternalLinkViewController (the
// article peek over an OK button, InternalLinkPreviewing.showInternalLink), a red link the "No
// internal link found" alert, and anything else the "External link" alert. Next goes on to the
// save step, which the editor shows when it comes back (editPreviewViewControllerDidTapNext).
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';

// set when Next is tapped; the editor opens its save step when it shows again
export const EDIT_PREVIEW_NEXT_KEY: string = 'wmfEditPreviewNext';

const LINK_CATCHER: string = "document.addEventListener('click', function (e) {" +
  "var a = e.target.closest ? e.target.closest('a[href]') : null;" +
  "if (!a || (a.getAttribute('href') || '').charAt(0) === '#') { return; }" +
  "e.preventDefault(); e.stopPropagation(); wmfPreview.linkTapped(a.href); }, true);";

class LinkBridge {
  private onTap: (url: string) => void;

  constructor(onTap: (url: string) => void) {
    this.onTap = onTap;
  }

  linkTapped(url: string): void {
    this.onTap(url);
  }
}

@Entry
@Component
struct EditPreviewViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;

  @State loadError: string = '';
  @State isLoading: boolean = true;
  // the internal link card (EditPreviewInternalLinkViewController)
  @State linkTitle: string = '';
  @State linkSummary: ArticleSummary | null = null;
  private controller: webview.WebviewController = new webview.WebviewController();
  private host: string = 'en.wikipedia.org';
  private articleTitle: string = '';
  private wikitext: string = '';
  private mode: string = '';
  private html: string = '';
  private webReady: boolean = false;
  private linkBridge: LinkBridge = new LinkBridge((url: string) => this.linkTapped(url));

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    if (params !== undefined) {
      this.host = params['host'] ?? this.host;
      this.articleTitle = params['articleTitle'] ?? '';
      this.wikitext = params['wikitext'] ?? '';
      this.mode = params['mode'] ?? '';
    }
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.wikitext_preview_changes') });
    ArticleService.fetchPreviewMobileHtml(this.host, this.articleTitle, this.wikitext).then((html: string) => {
      this.html = html;
      this.loadHtml();
    }).catch((e: Error) => {
      console.error('editPreview: preview failed: ' + e.message);
      this.isLoading = false;
      this.loadError = e.message;
    });
  }

  // the page's ./Title links resolve against /wiki/, as on the article's own site
  private loadHtml(): void {
    if (!this.webReady || this.html === '') {
      return;
    }
    this.controller.loadData(this.html, 'text/html', 'UTF-8', 'https://' + this.host + '/wiki/', '');
  }

  private string(id: number): string {
    return getContext(this).resourceManager.getStringSync(id).replace(/\\\$/g, '$');
  }

  private alert(title: Resource, message: string): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      confirm: {
        value: $r('app.string.button_ok'),
        action: (): void => {
          console.info('editPreview: alert dismissed');
        }
      }
    });
  }

  // previewWebViewContainer(_:didTapLink:) / ArticleWebMessagingController .link
  private linkTapped(url: string): void {
    const internal: RegExpMatchArray | null = url.match(new RegExp('^https://' + this.host.replace(/\./g, '\\.') +
      '/wiki/([^?#]+)(\\?[^#]*)?'));
    if (internal === null) {
      this.alert($r('app.string.wikitext_preview_link_external_preview_title'),
        this.string($r('app.string.wikitext_preview_link_external_preview_description').id).replace('$1', url));
      return;
    }
    if ((internal[2] ?? '').indexOf('redlink=1') >= 0) {
      this.alert($r('app.string.wikitext_preview_link_not_found_preview_title'),
        this.string($r('app.string.wikitext_preview_link_not_found_preview_description').id));
      return;
    }
    const title: string = decodeURIComponent(internal[1]).replace(/_/g, ' ');
    this.linkTitle = title;
    this.linkSummary = null;
    ArticleService.fetchSummary(this.host, title).then((s: ArticleSummary) => {
      if (this.linkTitle === title) {
        this.linkSummary = s;
      }
    }).catch((e: Error) => {
      console.error('editPreview: link summary failed: ' + e.message);
    });
  }

  @Builder
  navigationBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.theme_link')])
      }
      .id('preview_back')
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })
      Text($r('app.string.navbar_title_mode_edit_wikitext_preview'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      Button() {
        Text($r('app.string.button_next'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_link'))
      }
      .id('preview_next')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        // the image-recommendation flow goes on to Save changes; the editor shows its own
        if (this.mode === 'imageRecommendation') {
          router.pushUrl({ url: 'pages/EditSaveViewControllerPage', params: { 'host': this.host,
            'articleTitle': this.articleTitle, 'wikitext': this.wikitext } });
          return;
        }
        AppStorage.setOrCreate<boolean>(EDIT_PREVIEW_NEXT_KEY, true);
        router.back();
      })
    }
    .width('100%')
    .height(44)
    .padding({ left: 8, right: 12 })
  }

  // EditPreviewInternalLinkViewController: the article peek (lead image, title, description,
  // extract) over a rounded OK button; a tap outside dismisses it too
  @Builder
  linkCard() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.linkTitle = '';
        })
      Column({ space: 12 }) {
        Column() {
          if (this.linkSummary !== null && this.linkSummary.thumbnail !== null) {
            Image(this.linkSummary.original?.source ?? this.linkSummary.thumbnail.source)
              .width('100%')
              .height(160)
              .objectFit(ImageFit.Cover)
          }
          Column({ space: 4 }) {
            Text((this.linkSummary?.displayTitle ?? this.linkTitle).replace(/<[^>]*>/g, ''))
              .width('100%')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_text'))
            if ((this.linkSummary?.articleDescription ?? '') !== '') {
              Text(this.linkSummary?.articleDescription ?? '')
                .width('100%')
                .fontSize(15)
                .fontColor($r('app.color.theme_secondary_text'))
            }
            if (this.linkSummary === null) {
              LoadingProgress()
                .width(32)
                .height(32)
                .margin({ top: 10 })
            } else {
              Text(this.linkSummary.extract ?? '')
                .width('100%')
                .fontSize(15)
                .lineHeight(21)
                .fontColor($r('app.color.theme_text'))
                .margin({ top: 6 })
                .maxLines(5)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .padding(16)
        }
        .width('100%')
        .borderRadius(12)
        .clip(true)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        Button($r('app.string.button_ok'))
          .id('preview_link_ok')
          .type(ButtonType.Normal)
          .width('100%')
          .height(50)
          .borderRadius(8)
          .fontSize(20)
          .fontColor($r('app.color.theme_link'))
          .backgroundColor($r('app.color.theme_mid_background'))
          .onClick(() => {
            this.linkTitle = '';
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .id('preview_link_card')
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        this.navigationBar()
        Stack() {
          Web({ src: '', controller: this.controller })
            .id('preview_web_view')
            .width('100%')
            .height('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .darkMode(this.isDark ? WebDarkMode.On : WebDarkMode.Off)
            .forceDarkAccess(this.isDark)
            .onControllerAttached(() => {
              this.webReady = true;
              this.loadHtml();
            })
            // ArticleWebMessagingController: PCS handles taps itself, so links are caught before
            // it and reported here; anchors (references, sections) stay inside the page
            .javaScriptProxy({
              object: this.linkBridge,
              name: 'wmfPreview',
              methodList: ['linkTapped'],
              controller: this.controller
            })
            .onPageEnd(() => {
              this.isLoading = false;
              this.controller.runJavaScript(LINK_CATCHER);
            })
            .visibility(this.loadError === '' ? Visibility.Visible : Visibility.Hidden)
          if (this.isLoading && this.loadError === '') {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.theme_secondary_text'))
          }
          if (this.loadError !== '') {
            Text(this.loadError)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .padding(16)
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      if (this.linkTitle !== '') {
        this.linkCard()
      }
    }
    .id('EditPreviewViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
