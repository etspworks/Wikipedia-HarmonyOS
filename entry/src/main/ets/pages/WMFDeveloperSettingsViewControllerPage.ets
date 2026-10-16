// Ported from WMFComponents WMFDeveloperSettingsView / WMFDeveloperSettingsViewModel /
// WMFDeveloperSettingsViewController, presented by About's 7-tap title. "Developer Settings"
// with an X close over an inset grouped list: Enable Developer Mode; Games (Show Games
// Version 2, Clear games persistence); Visual Editor (Enable Visual Editing journey, Clear
// default edit mode); then the form section of switches. Every switch writes its
// WMFDeveloperSettingsDataController user-defaults key as it flips.
import { router, promptAction } from '@kit.ArkUI';
import { Prefs } from '../common/Prefs';
import { GameStore } from '../common/GameStore';

class DevToggle {
  title: string;
  key: string;

  constructor(title: string, key: string) {
    this.title = title;
    this.key = key;
  }
}

// WMFUserDefaultsKey raw values
export class DeveloperSettingsKeys {
  static readonly enableDeveloperMode: string = 'dev-enable-developer-mode';
  static readonly showGamesV2: string = 'dev-settings-show-games-v2';
  static readonly enableVisualEditingJourney: string = 'dev-settings-enable-visual-editing-journey';
  static readonly enableHomeTab: string = 'dev-settings-enable-home-tab';
  static readonly enableHomePhase2: string = 'dev-settings-enable-home-phase-2';
  static readonly alwaysShowNewOnboarding: string = 'dev-settings-always-show-new-onboarding';
  static readonly doNotPostImageRecommendationsEdit: string = 'dev-settings-do-not-post-image-rec-edit';
  static readonly sendAnalyticsToWMFLabs: string = 'dev-settings-send-analytics-to-wmflabs';
  static readonly bypassDonation: string = 'bypass-donation';
  static readonly forceEmailAuth: string = 'force-email-auth';
  static readonly forceMaxArticleTabsTo5: string = 'dev-settings-article-tab-max-5';
  static readonly enableMoreDynamicTabsV2GroupC: string = 'more-dynamic-tabs-group-c-v2';
  static readonly showYiR2025: string = 'dev-settings-yir-show-v3';
  static readonly forceHCaptchaChallenge: string = 'dev-settings-force-hcaptcha-challenge';
  static readonly allowGestureZoomArticleWebview: string = 'dev-settings-allow-gesture-zoom-article-webview';
  // WMFSettingsDataController.clearDefaultEditMode
  static readonly defaultEditMode: string = 'default-edit-mode';
  // port-only QA aid, not in the source: the Suggested Edits card and its feed setting without
  // the 50-edit requirement
  static readonly ignoreSuggestedEditsEditCount: string = 'dev-settings-suggested-edits-ignore-edit-count';
}

// formViewModel's one multi-select section, in the source's order
const FORM_ITEMS: DevToggle[] = [
  new DevToggle('Enable Home Tab', DeveloperSettingsKeys.enableHomeTab),
  new DevToggle('Enable Home Phase 2', DeveloperSettingsKeys.enableHomePhase2),
  new DevToggle('Always Show New Onboarding', DeveloperSettingsKeys.alwaysShowNewOnboarding),
  new DevToggle('Do not post image recommendations edit.', DeveloperSettingsKeys.doNotPostImageRecommendationsEdit),
  new DevToggle('Send analytics to wmflabs.', DeveloperSettingsKeys.sendAnalyticsToWMFLabs),
  new DevToggle('Bypass Donation', DeveloperSettingsKeys.bypassDonation),
  new DevToggle('Force email auth', DeveloperSettingsKeys.forceEmailAuth),
  new DevToggle('Force Max Article Tabs to 5', DeveloperSettingsKeys.forceMaxArticleTabsTo5),
  new DevToggle('Enable tabs V2 with group C', DeveloperSettingsKeys.enableMoreDynamicTabsV2GroupC),
  new DevToggle('Show Year in Review 2025', DeveloperSettingsKeys.showYiR2025),
  new DevToggle('Force hCaptcha Challenge', DeveloperSettingsKeys.forceHCaptchaChallenge),
  new DevToggle('Allow pinch to zoom when reading articles', DeveloperSettingsKeys.allowGestureZoomArticleWebview),
  new DevToggle('Suggested Edits without the 50-edit minimum', DeveloperSettingsKeys.ignoreSuggestedEditsEditCount)
];

@Entry
@Component
struct WMFDeveloperSettingsViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';

  @Builder
  toggleRow(title: string, key: string, last: boolean) {
    Column() {
      Row() {
        Text(title)
          .layoutWeight(1)
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
        Toggle({ type: ToggleType.Switch, isOn: Prefs.getBoolean(key, false) })
          .id('dev_' + key)
          .onChange((isOn: boolean) => {
            Prefs.putBoolean(key, isOn);
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      if (!last) {
        Divider()
          .margin({ left: 16 })
          .color($r('app.color.theme_border'))
      }
    }
  }

  @Builder
  buttonRow(title: string, id: string, action: () => void) {
    Text(title)
      .id(id)
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .padding({ left: 16, right: 16 })
      .fontSize(17)
      .fontColor($r('app.color.theme_link'))
      .onClick(action)
  }

  @Builder
  header(title: string) {
    Text(title.toUpperCase())
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, top: 24, bottom: 6 })
  }

  build() {
    Column() {
      // WMFNavigationBarTitleConfig (.centerCompact) + WMFLargeCloseButtonConfig(.plainX, .leading)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('CloseButton')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            router.back();
          })
        Text('Developer Settings')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Blank()
          .width(44)
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 8, bottom: 8 })

      Scroll() {
        Column() {
          Column() {
            this.toggleRow('Enable Developer Mode', DeveloperSettingsKeys.enableDeveloperMode, true)
          }
          .width('100%')
          .borderRadius(10)
          .margin({ top: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))

          this.header('Games')
          Column() {
            this.toggleRow('Show Games Version 2', DeveloperSettingsKeys.showGamesV2, false)
            this.buttonRow('Clear games persistence', 'dev_clear_games', () => {
              GameStore.clearGamesPersistence()
                .catch((e: Error) => console.error('developer settings: games reset failed: ' + e.message));
            })
          }
          .width('100%')
          .borderRadius(10)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))

          this.header('Visual Editor')
          Column() {
            this.toggleRow('Enable Visual Editing journey', DeveloperSettingsKeys.enableVisualEditingJourney, false)
            this.buttonRow('Clear default edit mode', 'dev_clear_edit_mode', () => {
              Prefs.remove(DeveloperSettingsKeys.defaultEditMode);
              promptAction.showToast({ message: 'Edit Mode preference cleared.' });
            })
          }
          .width('100%')
          .borderRadius(10)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))

          Column() {
            ForEach(FORM_ITEMS, (item: DevToggle, i: number) => {
              this.toggleRow(item.title, item.key, i === FORM_ITEMS.length - 1)
            }, (item: DevToggle) => item.key)
          }
          .width('100%')
          .borderRadius(10)
          .margin({ top: 32, bottom: 32 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('WMFDeveloperSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }
}
