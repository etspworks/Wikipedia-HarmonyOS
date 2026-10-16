// screen_push_notifications_settings — presentation: page, pushed from screen_settings_tab.
// No outgoing nav edges.
//
// S3 structure from WMFComponents/.../Settings/Push Notifications/
// WMFPushNotificationsSettingsView.swift + its WMFPushNotificationsSettingsViewModel.swift:
//   body = a ZStack over theme.midBackground holding a List of viewModel.sections; the
//   navigation title is localizedStrings.title, displayMode .inline (the capture's
//   NavigationBar carries the push-navigation back button + that title).
//   buildSections() emits exactly ONE section — header = localizedStrings.headerText (the
//   "Be alerted to activity related to your account…" prose), footer = nil — whose single
//   item is pushNotificationsToggleItem(): title = localizedStrings.pushNotificationsTitle
//   with accessory .toggle(pushNotificationsBinding) and no image/subtitle/action, rendered
//   by row(for:) as a plain SettingsRow (the .chevron case wraps the row in a Button; the
//   toggle case does not).
//   The .denied branch swaps that item for systemSettingsItem() (a .chevron row opening the
//   OS notification settings), with a footer saying why.
//   isPushEnabled is loaded from, and setPushEnabled(_:) persists to, the
//   WMFUserDefaultsKey.isSubscribedToEchoNotifications store entry.
// Rule 12: be_alerted_to_activity / push_notifications / BackButton are the SOURCE slugs
// carried by the capture (results/traversal-source/pages/WMFPushNotificationsSettingsView).
import { router } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// set once the app has asked the OS for notification permission (a later refusal is a denial)
const PUSH_PERMISSION_ASKED_KEY: string = 'wmfPushPermissionAsked';

@Entry
@Component
struct WMFPushNotificationsSettingsViewPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // viewModel.isPushEnabled — WMFUserDefaultsKey.isSubscribedToEchoNotifications.
  @State isPushEnabled: boolean = false;
  // permissionStatus == .denied: the OS refused notifications for the app.
  @State isDenied: boolean = false;

  aboutToAppear(): void {
    this.loadAndBuild();
  }

  onPageShow(): void {
    // back from the system notification settings
    this.loadAndBuild();
  }

  // loadAndBuild(): the OS authorization status gates the persisted flag. Once the app has
  // asked and the answer is no, the row becomes the source's systemSettingsItem().
  private loadAndBuild(): void {
    let authorized: boolean = false;
    try {
      authorized = notificationManager.isNotificationEnabledSync();
    } catch (e) {
      console.error('push notifications settings: notification status unavailable: ' +
        (e as Error).message);
    }
    this.isDenied = !authorized && Prefs.getBoolean(PUSH_PERMISSION_ASKED_KEY, false);
    this.isPushEnabled = authorized && Prefs.getBoolean(WMFDataPrefKeys.isSubscribedToEchoNotifications, false);
  }

  // setPushEnabled(_:). ponytail: permission only - Wikimedia's Echo push accepts APNs/FCM
  // devices and HarmonyOS has no route to it yet, so nothing is subscribed on the server. The
  // port used to subscribe an install ID it never created, which always failed with the
  // "error occurred while checking" footer. Add the subscription when a HarmonyOS provider exists.
  private async setPushEnabled(newValue: boolean): Promise<void> {
    if (newValue) {
      Prefs.putBoolean(PUSH_PERMISSION_ASKED_KEY, true);
      try {
        await notificationManager.requestEnableNotification(getContext(this) as common.UIAbilityContext);
      } catch (e) {
        console.warn('push notifications settings: permission refused: ' + (e as Error).message);
        this.loadAndBuild();
        return;
      }
    }
    Prefs.putBoolean(WMFDataPrefKeys.isSubscribedToEchoNotifications, newValue);
    this.loadAndBuild();
  }

  // onOpenSystemSettings: the app's page in the device's notification settings.
  private openSystemSettings(): void {
    notificationManager.openNotificationSettings(getContext(this) as common.UIAbilityContext)
      .catch((e: Error) => {
        console.error('push notifications settings: system settings unavailable: ' + e.message);
      });
  }

  // S5 (capture S0107 — pages/WMFPushNotificationsSettingsView/base.png): SwiftUI
  // inset-grouped List on theme.midBackground (#F8F9FA). Section header prose is 13/18
  // secondary indented to the card's content edge (32 vp); the one white card is inset
  // 16 vp on the capture's 22 vp continuous corner radius, carrying a 58 vp row.
  build() {
    Column() {
      // WMFNavigationBar: the push-navigation back button + the inline title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
          .id('BackButton')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText('Back')
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        Text($r('app.string.settings_notifications'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })

      Scroll() {
        Column() {
          // Section header — localizedStrings.headerText.
          Text($r('app.string.settings_notifications_header'))
            .width('100%')
            .id('be_alerted_to_activity')
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 32, bottom: 14 })

          // pushNotificationsToggleItem() — SettingsRow with accessory .toggle; when denied,
          // systemSettingsItem() — the same title with a chevron, opening the OS settings.
          Row() {
            Text($r('app.string.settings_notifications'))
              .layoutWeight(1)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.isDenied) {
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(18)
                .fontColor([$r('app.color.theme_secondary_text')])
            } else {
              // the row's control is the switch itself (comp_settings_cell's convention:
              // the slug on the switch, <slug>_row on the row container).
              Toggle({ type: ToggleType.Switch, isOn: this.isPushEnabled })
                .id('push_notifications')
                .selectedColor($r('app.color.theme_accent'))
                .onChange((value: boolean) => {
                  this.setPushEnabled(value).catch((e: Error) => {
                    console.error('push notifications settings: toggle failed: ' + e.message);
                  });
                })
            }
          }
          .width('100%')
          .id('push_notifications_row')
          .height(58)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .clip(true)
          .onClick(() => {
            if (this.isDenied) {
              this.openSystemSettings();
            }
          })

          if (this.isDenied) {
            Text($r('app.string.settings_notifications_system_off'))
              .id('notifications_system_off')
              .width('100%')
              .fontSize(13)
              .lineHeight(18)
              .fontColor($r('app.color.theme_secondary_text'))
              .padding({ left: 16, right: 16, top: 12 })
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
    .id('WMFPushNotificationsSettingsView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
