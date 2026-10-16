// screen_single_page_web — presentation: page. SinglePageWebViewController.swift: a web view
// loading the URL its presenter passes (user page, talk, help, donate, about links...).
// The page body is the shared WikiWebView (an ArkWeb Web, as the source's WKWebView).
// Native chrome is only what SinglePageWebViewController installs: the platform back,
// searchBarButtonItem (accessibilityIdentifier "web_view_search", line 156) and the
// `.action` share item (tappedAction, ~line 216).
import { router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { WikiWebView } from '../components/WikiWebView';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

@Entry
@Component
struct SinglePageWebViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // bindingContract: "web page content" <- currentUrl (WKWebView.load(url passed by the
  // presenter)); kept up to date as the reader follows links, for share.
  @State currentUrl: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.currentUrl = params['url'] ?? '';
    }
    if (this.currentUrl === '') {
      // A cold deep-link launch carries no router params; EntryAbility publishes the
      // Want's URL under this key, exactly like 'launchArticleTitle'.
      this.currentUrl = AppStorage.get<string>('launchWebUrl') ?? '';
    }
    if (this.currentUrl === '') {
      this.currentUrl = 'https://en.m.wikipedia.org/wiki/Main_Page';
    }
  }

  // The system back gesture walks the web history first, then leaves the screen.
  onBackPress(): boolean | void {
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    return false;
  }

  build() {
    Column() {
      // S5 (capture S0281): the source's nav chrome is a back button at the left and share
      // then search at the right - round HarmonyOS title-bar buttons (NavButton), glyphs
      // textPrimary, same as ArticleViewControllerPage.
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
        Row({ space: NAV_BUTTON_GAP }) {
          Button() {
            Image($r('app.media.share'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
            .id('share')
            .accessibilityText('Share')
            .attributeModifier(NAV_ICON_BUTTON)
            .onClick(() => {
              this.share();
            })
          Button() {
            Image($r('app.media.search'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
            .id('web_view_search')
            .accessibilityText('Search Wikipedia')
            .attributeModifier(NAV_ICON_BUTTON)
            .onClick(() => {
              router.pushUrl({ url: 'pages/SearchViewControllerPage' });
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      WikiWebView({ controller: this.controller, currentUrl: $currentUrl })
      .width('100%')
      .layoutWeight(1)
    }
    .id('SinglePageWebViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // No ShareKit in this SDK: copy the URL and confirm by toast
  // (self-signed-capabilities.md — the action must never silently no-op).
  private share(): void {
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.currentUrl);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: 'Link copied' });
    }).catch((e: Error) => {
      console.error('singlePageWeb: share failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not share this page' });
    });
  }
}
