// screen_about — presentation: page.
// S3 structure from Wikipedia/Code/AboutViewController.m: the WKWebView renders
// assets/about.html, whose divs are filled by injectAboutPageContentIntoWebView: —
// version, wikipedia, contributors_title/body, translators_title/body (link to the twn URL),
// libraries_title/body ("Complete list" -> wmflicense://licenses -> LibrariesUsedViewController),
// repositories_title/body (the AboutViewController.plist repositories: Gerrit, GitHub) with
// repositories_subtitle (MIT License link), license_title/body (Creative Commons
// Attribution-ShareAlike), places_maps_license_title/body (Apple Maps attribution link),
// feedback_body ("Send app feedback" -> the mailto feedback URL) and footer ("Made by the
// Wikimedia Foundation with the help of volunteers like you").
// Rendered natively rather than in a Web component so every link is an addressable control
// (a link inside a WebView carries no .id() and cannot be driven on device).
// URLs and the contributor list come from Wikipedia/Code/AboutViewController.plist.
// Wired edges: about -> single_page_web (external links), about -> libraries_used.
// S5/S6 style (capture S0057, 402x874pt): white page; nav bar = title-bar back button at
// [16,62] with the inline 17 semibold title CENTERED at [176,73] (iOS default,
// mapping-tables §7). The body reproduces about.html's own stylesheet: margin 1.45em (23pt)
// each side, base font-size 100% (16px Helvetica) at lineHeight 20, #wikipedia 2.0em (32)
// bold, #version 1.5em (24) bold, .title 1.5em (23pt) above its 0.5em-spaced body, .feedback
// centered and .footer-table 1.0em below it. The colours are NOT the stylesheet's — the
// controller overwrites body/.heading/.title/A with the theme's primaryText / secondaryText /
// link (wmf_setTextFontColor:), which is what the app.color tokens below carry.
// The footer's WMF_White.pdf logo lives in the about.html bundle, not Assets.xcassets, so no
// asset was carried over and none is substituted.
import { router } from '@kit.ArkUI';
import { appVersion, versionedUserAgent } from '../common/HttpClient';
import common from '@ohos.app.ability.common';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// AboutViewController.plist -> urls
const URL_TWN: string = 'https://translatewiki.net';
const URL_MIT: string = 'https://raw.githubusercontent.com/wikimedia/wikipedia-ios/main/LICENSE.txt';
const URL_SHAREALIKE: string = 'https://creativecommons.org/licenses/by-sa/4.0/';
const URL_APPLEMAPS: string = 'https://gspe21-ssl.ls.apple.com/html/attribution.html';
const URL_WMF: string = 'https://wikimediafoundation.org';
// AboutViewController.plist feedback: mailto:ios-support@wikimedia.org?subject=Feedback:$1, $1 the
// versioned user agent (feedbackURL)
const URL_FEEDBACK: string = 'mailto:ios-support@wikimedia.org?subject=Feedback:';
// AboutViewController.plist -> repositories
const URL_GERRIT: string = 'https://gerrit.wikimedia.org/r/#/q/project:apps/ios/wikipedia,n,z';
const URL_GITHUB: string = 'https://github.com/wikimedia/wikipedia-ios';

@Entry
@Component
struct AboutViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // wmf_appVersion, injected into the `version` div
  @State appVersion: string = '';
  // titleLabelTappedCount — 7 taps on the nav title open the developer settings
  @State titleLabelTappedCount: number = 0;
  // AboutViewController.plist -> contributors, joined by ", "
  private contributors: string =
    'Abbey Ripstra, Adam Baso, Alexander Claussen, Amal Ramadan, Amani Hunter, ' +
    'Amir E. Aharoni, Ammar Abdulhamid, Anirudh S, André Costa, Anthony Borba, ' +
    'Antoine Musso, Alexey Karataev, Barbara Martina Rodeker, bart-kneepkens, ' +
    'Bernd Sitzmann, Boris Dušek, brett ohland, Brian Gerstle, Brooke Vibber, ' +
    'Carolyn Li-Madeo, Chelsy Xie, Christian Bilodeau, Cole Roberts, Corey Floyd, ' +
    'cromulentlabs, Daisy Chen, Dan Garry, Daniel McGlinchey, David Xia, ' +
    'Deepak Mantena, Dmitry Brant, Douglas Rodrigues Pinto Neto, Elena Tonkovidova, ' +
    'Ethan Holshouser, Evelyn Harthbrooke, Gabicoware, Gianmarco Salerno, Hua Zhenyu, ' +
    'Hynek Hanke, Grey Olson, Ian MacFarlane, Isidore Baldado, Jan Berkel, ' +
    'Jazmin Tanner, Joe Walsh, Jon Harald Søby, Jonatan Svensson Glad, Joshua Minor, ' +
    'Julien Bodet, Junho Lee, Kaity Hammerstein, Kelly Roach, Kenan Wang, ' +
    'Kotaro Fujita, Kunal Mehta, Logan Keller, Luiggi Minaya Salcedo, MagikCow, ' +
    'Marcos Varani, Maryana Pinchuk, Marina Azevedo, Matt Cleinman, Max Semenik, ' +
    'Maxim Korobov, Michael Holloway, Michael Hulet, Michal Ciurus, Mikhail Popov, ' +
    'Moiz Syed, Monte Hurd, Morgan Davison, Mun May Tee, Natalia Harateh, negati-ve, ' +
    'Nick DiStefano, Nicole Borrelli, Niklas Laxström, Nirzar Pangarkar, ' +
    'Olga Tichonova, Oliver Keyes, Ori Livneh, Pedro Vereza, Phil Herbert, ' +
    'Prayag Verma, Rita Ho, Robin Schoenbaechler, Rummana Yasmeen, Salman Jamil, ' +
    'Sam Symons, Sandeep Kumar, Scott Petit, Sean Villalta, Sergei Lukoianov, ' +
    'Seshadri Mahalingam, Shay Nowick, Sherah Smith, Shilan Patel, Siebrand Mazeland, ' +
    'Spencer Edgecombe, Stephen Niedzielski, Steve Peak, Steven Schobert, ' +
    'Sunil Sharma, Taís Lessa, Thomas PT, Tiago Martinho, Tim Johnsen, Timo Tijhof, ' +
    'Tomasz Finc, Toni Sevener, Vibha Bamba, Victor Barrera, Victor Peschenkov, ' +
    'Viktar Staravoitau, waffleboot, Yongmin Hong, Yuri Solodkin, Yuvi Panda, ' +
    'Zoran Dori';

  aboutToAppear(): void {
    // wmf_appVersion, as the source's about.html shows it (e.g. 6144-r-2026-08-11)
    this.appVersion = appVersion();
  }

  build() {
    Column() {
      // WMFNavigationBar: push-navigation back button + the tappable, centered title label
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              .fillColor($r('app.color.theme_text'))
          }
          .id('BackButton')
          .accessibilityText('About')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.goBack();
          })
          Blank()
        }
        .width('100%')

        Text($r('app.string.about_title'))
          // the native WMFNavigationBar title (iOS inline title), not about.html body type
          .fontSize(17)
          .fontWeight(600)
          .fontColor($r('app.color.theme_text'))
          .onClick(() => {
            this.didTapTitleView();
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 4, bottom: 4 })

      Scroll() {
        Column() {
          // `wikipedia` + `version`
          Text('Wikipedia')
            .width('100%')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
          Text(this.appVersion)
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))

          // contributors_title / contributors_body
          Text($r('app.string.about_contributors'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Text(this.contributors)
            .width('100%')
            .fontSize(16)
            .lineHeight(20)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 7 })

          // translators_title / translators_body
          Text($r('app.string.about_translators'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Translated by volunteers at ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text('/translatewiki.net')
              .id('translatewiki_net')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_TWN);
              })
          }
          .width('100%')
          .margin({ top: 7 })

          // libraries_title / libraries_body (wmflicense://licenses)
          Text($r('app.string.about_libraries'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Text($r('app.string.about_libraries_complete_list'))
            .id('complete_list')
            .fontSize(16)
            .lineHeight(20)
            .fontColor($r('app.color.theme_link'))
            .width('100%')
            .onClick(() => {
              this.openLibrariesUsed();
            })

          // repositories_title / repositories_body / repositories_subtitle
          Text($r('app.string.about_repositories'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Gerrit')
              .id('gerrit')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_GERRIT);
              })
            Text(', ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text('GitHub')
              .id('github')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_GITHUB);
              })
          }
          .width('100%')
          .margin({ top: 7 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Source code available under the ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text($r('app.string.about_repositories_app_source_license_mit'))
              .id('mit_license')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_MIT);
              })
            Text('.')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
          }
          .width('100%')
          .margin({ top: 7 })

          // license_title / license_body
          Text($r('app.string.about_content_license'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Unless otherwise specified, content is available under a ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text($r('app.string.about_content_license_details_share_alike_license'))
              .id('creative_commons_attribution')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_SHAREALIKE);
              })
            Text('.')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
          }
          .width('100%')
          .margin({ top: 7 })

          // places_maps_license_title / places_maps_license_body
          Text($r('app.string.about_places_maps_license'))
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 23 })
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Places uses maps provided by Apple Maps. ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text($r('app.string.about_places_maps_license_details_link_text'))
              .id('please_see_here')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_APPLEMAPS);
              })
            Text('.')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
          }
          .width('100%')
          .margin({ top: 7 })

          // feedback_body
          Text($r('app.string.about_send_feedback'))
            .id('send_app_feedback')
            .fontSize(16)
            .lineHeight(20)
            .fontColor($r('app.color.theme_link'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 23 })
            .onClick(() => {
              this.sendFeedback();
            })

          // footer
          Flex({ wrap: FlexWrap.Wrap }) {
            Text('Made by the ')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
            Text($r('app.string.about_wikimedia_foundation'))
              .id('wikimedia_foundation')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.openWeb(URL_WMF);
              })
            Text(' with the help of volunteers like you')
              .fontSize(16)
              .lineHeight(20)
              .fontColor($r('app.color.theme_text'))
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 23, right: 23, top: 23, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('AboutViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private goBack(): void {
    router.back();
  }

  // didTapTitleViewWithGestureRecognizer: 7 taps present the developer settings
  // (WMFDeveloperSettingsViewController).
  private didTapTitleView(): void {
    this.titleLabelTappedCount = this.titleLabelTappedCount + 1;
    if (this.titleLabelTappedCount >= 7) {
      this.titleLabelTappedCount = 0;
      router.pushUrl({ url: 'pages/WMFDeveloperSettingsViewControllerPage' }).catch((e: Error) => {
        console.error('about: developer settings route failed: ' + e.message);
      });
    }
  }

  // isExternalURL(mailto) -> openURL: the mail app, not the in-app web view
  private sendFeedback(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const url: string = URL_FEEDBACK + encodeURIComponent(versionedUserAgent());
    try {
      ctx.openLink(url).catch((e: Error) => {
        console.error('about: openLink(mailto) failed: ' + e.message);
      });
    } catch (e) {
      console.error('about: openLink(mailto) threw: ' + (e as Error).message);
    }
  }

  // "Complete list" -> wmflicense://licenses -> the libraries list
  private openLibrariesUsed(): void {
    router.pushUrl({ url: 'pages/LibrariesUsedViewControllerPage' });
  }

  private openWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }
}
