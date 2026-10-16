// The web view behind SinglePageWebViewController and its HelpViewController subclass: an ArkWeb
// Web loading a wiki URL, as the source's WKWebView. Both screens used to fetch the HTML and
// redraw it natively so the migration's on-device drivers could read the text, which dropped all
// of the site's CSS, images and scripts and drew the mobile site's menus as bare bullet lists.
//
// The host owns the controller (so its onBackPress can walk the web history) and gets the page
// the reader is on back through `currentUrl`, for share.
import { router } from '@kit.ArkUI';
import { destinationForURL, LinkDestination, LinkKind } from '../common/WikiLinks';
import { intentForDestination } from '../entryability/RouteTable';
import { webview } from '@kit.ArkWeb';
import { HttpClient } from '../common/HttpClient';
import { DonateHistory } from '../common/DonateHistory';

// The app's login lives in HttpClient's cookie jar; the web view has its own cookie store.
// Copy the session in before loading so a wiki page opens logged in, as the source's web view
// shares the app's cookie storage. Wikimedia's CentralAuth cookies work across a project's
// hosts, so they are set for the page's registrable domain (.wikipedia.org, .mediawiki.org...):
// a Domain that does not match the page's host is rejected. SessionStore.clear() drops them on
// logout.
function syncLoginCookies(url: string): void {
  const jar: string = HttpClient.cookieJar.serialize();
  const host: RegExpMatchArray | null = url.match(new RegExp('^https?://([^/:?#]+)'));
  if (jar === '' || host === null) {
    return;
  }
  const labels: string[] = host[1].split('.');
  const domain: string = '.' + labels.slice(Math.max(0, labels.length - 2)).join('.');
  for (const pair of jar.split('\n')) {
    try {
      webview.WebCookieManager.configCookieSync(url, pair + '; Domain=' + domain + '; Path=/; Secure');
    } catch (e) {
      console.error('wikiWebView: cookie sync failed: ' + (e as Error).message);
    }
  }
}

@Component
export struct WikiWebView {
  controller: webview.WebviewController = new webview.WebviewController();
  // in: the URL to open; out: the page the reader is on after following links
  @Link currentUrl: string;
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  // the app's effective colour mode (EntryAbility keeps it current)
  @StorageProp('wmfIsDark') isDark: boolean = false;
  @State private isLoading: boolean = true;
  @State private loadError: string = '';
  // src is read once; later pages come from navigation inside the web view, not from state
  private startUrl: string = '';

  aboutToAppear(): void {
    this.startUrl = this.currentUrl;
    syncLoginCookies(this.startUrl);
  }

  build() {
    Stack() {
      Web({ src: this.startUrl, controller: this.controller })
        .id('web_view')
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        // a media URL opened here (the title pronunciation) plays on open, as in the source's
        // WKWebView; ArkWeb otherwise waits for a tap on the player
        .mediaPlayGestureAccess(false)
        // follow the app's theme, not the device's (Auto tracks the device). The mobile site
        // only goes dark for a reader who set its own colour preference, so force-darken the
        // page when the app is dark.
        .darkMode(this.isDark ? WebDarkMode.On : WebDarkMode.Off)
        .forceDarkAccess(this.isDark)
        // SinglePageWebViewController.handleNavigation: a link the reader taps (.linkActivated)
        // to a page the app shows natively (LinkCoordinator) opens there, not in the web view.
        .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
          const request: WebResourceRequest = event.data;
          if (!request.isMainFrame() || !request.isRequestGesture() || request.isRedirect()) {
            return false;
          }
          const d: LinkDestination | null = destinationForURL(request.getRequestUrl());
          if (d === null || d.kind === LinkKind.Web) {
            return false;
          }
          const intent = intentForDestination(d);
          router.pushUrl({ url: intent.route, params: intent.params }).catch((e: Error) => {
            console.error('wikiWebView: native route failed: ' + e.message);
          });
          return true;
        })
        .onPageBegin((event) => {
          this.isLoading = true;
          this.loadError = '';
          if (event) {
            DonateHistory.recordIfThankYouPage(event.url);
          }
        })
        .onPageEnd((event) => {
          this.isLoading = false;
          if (event) {
            this.currentUrl = event.url;
          }
        })
        .onErrorReceive((event) => {
          // only a failed page counts; a failed image or script inside it does not
          if (event && event.request.isMainFrame()) {
            console.error('wikiWebView: load failed: ' + event.error.getErrorInfo());
            this.isLoading = false;
            this.loadError = 'This page could not be loaded.';
          }
        })
        .visibility(this.loadError === '' ? Visibility.Visible : Visibility.Hidden)

      if (this.isLoading && this.loadError === '') {
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('app.color.theme_secondary_text'))
      }

      if (this.loadError !== '') {
        Column({ space: 12 }) {
          Text(this.loadError)
            .fontSize(17)
            .lineHeight(24)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
          Button('Retry')
            .id('web_view_retry')
            .type(ButtonType.Normal)
            .fontSize(17)
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .backgroundColor($r('app.color.theme_link'))
            .borderRadius(8)
            .height(44)
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              this.loadError = '';
              this.controller.refresh();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
