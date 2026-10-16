// screen_home_feed_settings — presentation: page, pushed from screen_settings_tab.
//
// S3 structure from WMFComponents/.../Settings/Home/Main/WMFHomeFeedSettingsView.swift +
// WMFHomeFeedSettingsViewModel: a List of SettingsSections over theme.midBackground, rows on
// theme.chromeBackground with hidden separators. The view model builds ONE section here —
// header "For you" with the Modules row (subtitle "Turn on or off 'For You' modules") and the
// What's Driving row — each a SettingsItem with a .chevron accessory. The Community section is
// gated on WMFDeveloperSettingsDataController.enableHomePhase2, which is off in this build
// (the capture shows no Community section and the plan's controlInventory has no row for it),
// so it is not rendered.
// The two chevron rows push WMFHomeFeedForYouSettingsViewController ("Modules", three module
// toggles) and WMFHomeFeedWhatsDrivingSettingsViewController ("What's driving your feed",
// three chevron rows) — captured as states S0152 / S0151 of THIS page slug, so they are
// rendered here as in-page sections rather than routed pages.
// S4: the module toggles persist through svc_prefs (the source's
// homeDataController.setForYou*IsOn); Back pops the section, then the page (S0154 = Settings).
// The "For you" section-header cell is tappable in the capture but its captured next state
// (S0153) is identical to the base state — SwiftUI's Section header carries no action — so it
// selects the root section and changes nothing visible, matching the source.
// S5: capture base.ui.json (402x874) — nav bar y62..116 with the back chevron at x16 and the
// 17pt centered title, rows inset to [16,386] with 15pt title over a 13pt secondary subtitle
// and the 8x13 forward chevron at x361.
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Prefs } from '../common/Prefs';

@Entry
@Component
struct WMFHomeFeedSettingsViewPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  @StorageProp('wmfChromeBg') wmfChromeBg: string = '';

  // which pushed sub-controller is on screen: '' (root), 'modules', 'whatsDriving'
  @State section: string = '';
  // "My languages" pushes WMFPreferredLanguagesViewController, a hosted @Component here
  // (unregistered by design), presented the same way SettingsTabViewControllerPage does.
  // WMFHomeFeedForYouSettingsViewModel module bindings
  @State basedOnInterestsIsOn: boolean = true;
  @State becauseYouReadIsOn: boolean = true;
  @State continueReadingIsOn: boolean = true;

  aboutToAppear(): void {
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      this.basedOnInterestsIsOn = Prefs.getBoolean('home-feed-for-you-based-on-interests', true);
      this.becauseYouReadIsOn = Prefs.getBoolean('home-feed-for-you-because-you-read', true);
      this.continueReadingIsOn = Prefs.getBoolean('home-feed-for-you-continue-reading', true);
    } catch (e) {
      // svc_prefs is this screen's only data source; fall back to the source's defaults
      // (every module on) rather than rendering a blank page.
      console.error('homeFeedSettings: preferences unavailable: ' + (e as Error).message);
    }
  }

  private setModule(key: string, value: boolean): void {
    try {
      Prefs.putBoolean(key, value);
    } catch (e) {
      console.error('homeFeedSettings: module persist failed: ' + (e as Error).message);
    }
  }

  private navTitle(): Resource {
    if (this.section === 'modules') {
      return $r('app.string.home_feed_for_you_settings_title');
    }
    if (this.section === 'whatsDriving') {
      return $r('app.string.home_feed_whats_driving_settings_title');
    }
    return $r('app.string.home_feed_settings_title');
  }

  // The nav back button pops the pushed sub-controller first, then the page itself.
  private goBack(): void {
    if (this.section !== '') {
      this.section = '';
      return;
    }
    router.back();
  }

  // Raster template glyphs cannot be tinted with colorBlend; rebuild the color from alpha.
  private iconTint(color: string): ColorFilter {
    const n: number = parseInt(color.replace('#', ''), 16);
    return new ColorFilter([
      0, 0, 0, ((n >> 16) & 0xFF) / 255, 0,
      0, 0, 0, ((n >> 8) & 0xFF) / 255, 0,
      0, 0, 0, (n & 0xFF) / 255, 0,
      0, 0, 0, 1, 0
    ]);
  }

  // SettingsRow with a .chevron accessory.
  @Builder
  chevronRow(rowId: string, title: Resource, subtitle: Resource, onTap: () => void) {
    Row() {
      Column() {
        Text(title)
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.theme_text'))
        Text(subtitle)
          .width('100%')
          .fontSize(13)
          .lineHeight(18)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.chevron_right'))
        .width(8)
        .height(13)
        .objectFit(ImageFit.Contain)
        .colorFilter(this.iconTint('#9AA0A6'))
        .margin({ left: 12 })
    }
    .width('100%')
    .constraintSize({ minHeight: 70 })
    .padding({ left: 16, right: 17, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .id(rowId)
    .onClick(onTap)
  }

  // SettingsRow with a .toggle accessory.
  @Builder
  toggleRow(rowId: string, title: Resource, subtitle: Resource, isOn: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.theme_text'))
        Text(subtitle)
          .width('100%')
          .fontSize(13)
          .lineHeight(18)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .width(51)
        .height(31)
        .selectedColor($r('app.color.theme_link'))
        .margin({ left: 12 })
        .onChange(onChange)
    }
    .width('100%')
    .constraintSize({ minHeight: 90 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .id(rowId)
  }

  // A List section header row (rendered as its own cell in the capture).
  @Builder
  sectionHeaderRow(rowId: string, title: Resource) {
    Row() {
      Text(title)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor($r('app.color.theme_text'))
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .id(rowId)
    .onClick(() => {
      // SwiftUI's Section header carries no action: selecting it keeps the root section.
      this.section = '';
    })
  }

  // The explanatory header cell each pushed sub-controller starts with.
  @Builder
  headerTextRow(text: Resource) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      // WMFNavigationBar: back button + centered title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .colorFilter(this.iconTint('#3366CC'))
          }
          .id('BackButton')
          .accessibilityText('Customize the home feed')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            this.goBack();
          })
          Blank()
        }
        .width('100%')

        Text(this.navTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          if (this.section === 'modules') {
            // WMFHomeFeedForYouSettingsView
            Column() {
              this.headerTextRow($r('app.string.home_feed_for_you_settings_header'))
            }
            .width('100%')
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            Column() {
              this.toggleRow('based_on_your_interests',
                $r('app.string.home_feed_for_you_based_on_interests_title'),
                $r('app.string.home_feed_for_you_based_on_interests_subtitle'),
                this.basedOnInterestsIsOn,
                (value: boolean): void => {
                  this.basedOnInterestsIsOn = value;
                  this.setModule('home-feed-for-you-based-on-interests', value);
                })
              this.toggleRow('because_you_read',
                $r('app.string.home_feed_for_you_because_you_read_title'),
                $r('app.string.home_feed_for_you_because_you_read_subtitle'),
                this.becauseYouReadIsOn,
                (value: boolean): void => {
                  this.becauseYouReadIsOn = value;
                  this.setModule('home-feed-for-you-because-you-read', value);
                })
              this.toggleRow('continue_reading',
                $r('app.string.home_feed_for_you_continue_reading_title'),
                $r('app.string.home_feed_for_you_continue_reading_subtitle'),
                this.continueReadingIsOn,
                (value: boolean): void => {
                  this.continueReadingIsOn = value;
                  this.setModule('home-feed-for-you-continue-reading', value);
                })
            }
            .width('100%')
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            .margin({ top: 1 })
          } else if (this.section === 'whatsDriving') {
            // WMFHomeFeedWhatsDrivingSettingsView
            Column() {
              this.headerTextRow($r('app.string.home_feed_whats_driving_settings_header'))
            }
            .width('100%')
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            Column() {
              this.chevronRow('your_interests',
                $r('app.string.home_feed_whats_driving_your_interests_title'),
                $r('app.string.home_feed_whats_driving_your_interests_subtitle'),
                (): void => {
                  router.pushUrl({ url: 'pages/ExploreFeedSettingsViewControllerPage' });
                })
              this.chevronRow('reading_history',
                $r('app.string.home_feed_whats_driving_reading_history_title'),
                $r('app.string.home_feed_whats_driving_reading_history_subtitle'),
                (): void => {
                  router.pushUrl({ url: 'pages/SavedViewControllerPage' });
                })
              this.chevronRow('languages',
                $r('app.string.home_feed_whats_driving_languages_title'),
                $r('app.string.home_feed_whats_driving_languages_subtitle'),
                (): void => {
                  router.pushUrl({ url: 'pages/WMFPreferredLanguagesViewControllerPage' })
                    .catch((e: Error) => {
                      console.error('homeFeedSettings: languages route failed: ' + e.message);
                    });
                })
            }
            .width('100%')
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
            .margin({ top: 1 })
          } else {
            // The "For you" section of WMFHomeFeedSettingsViewModel.
            Column() {
              this.sectionHeaderRow('for_you',
                $r('app.string.home_feed_settings_for_you_section_title'))
              this.chevronRow('modules_turn_on_or',
                $r('app.string.home_feed_settings_modules_title'),
                $r('app.string.home_feed_settings_for_you_modules_subtitle'),
                (): void => {
                  this.section = 'modules';
                })
              this.chevronRow('what_s_driving_your',
                $r('app.string.home_feed_settings_whats_driving_title'),
                $r('app.string.home_feed_settings_whats_driving_subtitle'),
                (): void => {
                  this.section = 'whatsDriving';
                })
            }
            .width('100%')
            .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('WMFHomeFeedSettingsView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
