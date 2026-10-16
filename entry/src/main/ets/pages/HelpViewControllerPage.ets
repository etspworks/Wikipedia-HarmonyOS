// screen_help — presentation: page. S3: real structure from HelpViewController.swift
// (a SinglePageWebViewController subclass) + the captured state graph (S0064 and its 38
// depth-1 link taps).
//
// HelpViewController.viewDidLoad(): super, then `navigationItem.rightBarButtonItem = nil`
// (so, unlike the superclass, NO search and NO share item in the nav bar — only the
// platform back) and setupToolbar(), which installs a bottom UIToolbar holding
// exportUserDataToolbarItem ("Export User Data") and sendEmailToolbarItem ("Report a bug").
//
// The FAQ body is the shared WikiWebView (an ArkWeb Web, as the source's WKWebView); links
// navigate in place inside it. It used to be fetched and redrawn natively for the migration's
// test drivers, which left it unstyled.
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { pasteboard, zlib } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { Prefs } from '../common/Prefs';
import { SessionStore } from '../common/SessionStore';
import { versionedUserAgent } from '../common/HttpClient';
import { webview } from '@kit.ArkWeb';
import { WikiWebView } from '../components/WikiWebView';
import { NAV_ICON_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// HelpViewController.faqURLString / emailAddress / emailSubject — module-level consts,
// since an ArkUI struct is not a place for static members.
const FAQ_URL: string = 'https://m.mediawiki.org/wiki/Wikimedia_Apps/iOS_FAQ';
const EMAIL_ADDRESS: string = 'ios-support@wikimedia.org';
const EMAIL_SUBJECT: string = 'Bug:';

@Entry
@Component
struct HelpViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // bindingContract: "FAQ page content" <- currentUrl (WKWebView.load(FAQ url)); kept up to
  // date as the reader follows links, for share.
  @State currentUrl: string = FAQ_URL;
  @State isExportingUserData: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    let url: string = '';
    if (params !== undefined && params !== null) {
      url = params['url'] ?? '';
    }
    if (url === '') {
      // A cold deep-link launch carries no router params; EntryAbility publishes the
      // Want's URL under this key.
      url = AppStorage.get<string>('launchWebUrl') ?? '';
    }
    // The FAQ URL is the default: a cold deep-link launch of this screen must land on it.
    this.currentUrl = url !== '' ? url : FAQ_URL;
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
      // Nav bar: back, plus the superclass's share + search buttons. viewDidLoad assigns
      // the SINGULAR `navigationItem.rightBarButtonItem = nil`, which does not clear the
      // ARRAY the superclass set (SinglePageWebViewController.swift:216-217,
      // setRightBarButtonItems([searchBarButtonItem, safariItem])) — the capture
      // (base.ui.json, S0064) shows both items in the running app's NavigationBar.
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

      // setupToolbar(): the bottom UIToolbar, exportUserDataToolbarItem leading and
      // sendEmailToolbarItem trailing, separated by a flexible space.
      // S5 (capture base.png / base.ui.json, S0064): the toolbar is a 48-tall band pinned
      // above the safe area on the light `color.pageBackground` chrome, its two items
      // rendered as paper-white capsules (measured [25,792]-[189,838] and
      // [245,792]-[378,838] on a 402pt-wide screen: 24 outer inset, 44 tall, radius 22,
      // 15 inner horizontal padding) with the label in `color.textPrimary` at
      // `type.body` size — the bar tint is dark here, not the document's link accent.
      Row() {
        // setupToolbarItems(isExportingUserData:): a spinner while the export runs
        if (this.isExportingUserData) {
          LoadingProgress()
            .id('export_user_data_spinner')
            .width(32)
            .height(32)
            .margin({ left: 15, right: 15 })
            .color($r('app.color.theme_secondary_text'))
        } else {
        Text($r('app.string.export_user_data_title'))
          .id('export_user_data')
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .height(44)
          .padding({ left: 15, right: 15 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .onClick(() => {
            this.exportUserData();
          })
        }
        Blank()
        Text('Report a bug')
          .id('report_a_bug')
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .height(44)
          .padding({ left: 15, right: 15 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .onClick(() => {
            this.sendEmail();
          })
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 24, right: 24 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    }
    .id('HelpViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // The `.action` item (tappedAction, SinglePageWebViewController ~line 216). No ShareKit
  // in this SDK: copy the current URL and confirm by toast, the app's established
  // substitution (self-signed-capabilities.md — the action must never silently no-op).
  private share(): void {
    this.copyToPasteboard(this.currentUrl, 'Link copied', 'Could not share this page');
  }

  // exportUserData(): "Share app library?" with Share / Cancel
  private exportUserData(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.export_user_data_confirmation_title'),
      message: $r('app.string.export_user_data_confirmation_message'),
      buttons: [
        { value: $r('app.string.action_share'), action: (): void => {
          this.kickoffExportUserDataProcess();
        } },
        { value: $r('app.string.cancel'), action: (): void => {} }
      ]
    });
  }

  // kickoffExportUserDataProcess -> zipUpAndShare: the export item turns into a spinner, the app
  // container (files, the reading list / history database, preferences) is zipped as
  // app-container.zip and handed to the share panel. Any failure shows the generic error.
  private async kickoffExportUserDataProcess(): Promise<void> {
    if (this.isExportingUserData) {
      return;
    }
    this.isExportingUserData = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      const zipPath: string = ctx.cacheDir + '/app-container.zip';
      if (fileIo.accessSync(zipPath)) {
        fileIo.unlinkSync(zipPath);
      }
      // the preferences go in as JSON without the login session (removeUnnecessaryFiles...
      // drops the container's Library, cookies included)
      const prefsDir: string = ctx.cacheDir + '/preferences';
      if (!fileIo.accessSync(prefsDir)) {
        fileIo.mkdirSync(prefsDir);
      }
      const prefsFile: fileIo.File = fileIo.openSync(prefsDir + '/preferences.json',
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(prefsFile.fd, Prefs.exportJSON(SessionStore.privateKeys));
      } finally {
        fileIo.closeSync(prefsFile);
      }
      const dirs: string[] = [ctx.filesDir, ctx.databaseDir, prefsDir]
        .filter((d: string) => fileIo.accessSync(d));
      await zlib.compressFiles(dirs, zipPath, {
        level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(
        new systemShare.SharedData({ utd: 'general.zip', uri: fileUri.getUriFromPath(zipPath) }));
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (e) {
      console.error('help: export user data failed: ' + (e as Error).message);
      // handleGenericUserExportError
      this.getUIContext().showAlertDialog({
        message: $r('app.string.export_user_data_generic_error'),
        confirm: { value: $r('app.string.button_ok'), action: (): void => {} }
      });
    } finally {
      this.isExportingUserData = false;
    }
  }

  // sendEmail(): mailto:ios-support@wikimedia.org?subject=Bug:&body=<version>. openLink
  // hands the URI to the system (UIAbilityContext.openLink, API 12); a device with no
  // handler rejects it, which is the source's own noEmailClient path — fall back to the
  // clipboard + a toast there rather than failing silently.
  private sendEmail(): void {
    const body: string = '\n\n\n\nVersion: ' + versionedUserAgent();
    const mailto: string = 'mailto:' + EMAIL_ADDRESS +
      '?subject=' + encodeURIComponent(EMAIL_SUBJECT) +
      '&body=' + encodeURIComponent(body);
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      ctx.openLink(mailto).catch((e: Error) => {
        console.error('help: openLink(mailto) failed: ' + e.message);
        this.emailFallback();
      });
    } catch (e) {
      // openLink rejects a scheme it cannot resolve synchronously as a BusinessError.
      console.error('help: openLink(mailto) threw: ' + (e as Error).message);
      this.emailFallback();
    }
  }

  private emailFallback(): void {
    this.copyToPasteboard(EMAIL_ADDRESS,
      'Email address copied: ' + EMAIL_ADDRESS,
      'No email client is installed');
  }

  private copyToPasteboard(text: string, okMessage: string, failMessage: string): void {
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      promptAction.showToast({ message: okMessage });
    }).catch((e: Error) => {
      console.error('help: pasteboard failed: ' + e.message);
      promptAction.showToast({ message: failMessage });
    });
  }
}
