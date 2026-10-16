// comp_activity_tab_customize — ported from WMFComponents/.../Activity Tab/
// WMFActivityTabCustomizeView.swift: the sheet the Activity tab's overflow "Customize" action
// presents. Four insight toggles over the explanatory footnote, with Cancel in the sheet's
// own bar. Each toggle writes its WMFUserDefaults flag as it changes (the source's
// @Published bindings write through); Cancel restores the values the sheet opened with, so a
// cancelled sheet persists nothing.
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';
import { SessionStore } from '../common/SessionStore';

// One toggle row: the flag it owns and the label it carries.
class CustomizeToggle {
  key: string = '';
  label: ResourceStr = '';
  rowId: string = '';

  constructor(key: string, label: ResourceStr, rowId: string) {
    this.key = key;
    this.label = label;
    this.rowId = rowId;
  }
}

@Component
export struct WMFActivityTabCustomizeView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  onClose?: () => void;
  // WMFToastConfig buttonAction -> presentFullLoginFlow(fromCustomizeToast:)
  onLogIn?: () => void;
  // the logged-out warning toast with its "Log in" button (WMFToastPresenter)
  @State showLoginToast: boolean = false;
  private toastTimer: number = -1;
  // The four flags, re-read on open so the sheet shows what is stored.
  @State values: boolean[] = [false, false, false, false];
  // What the flags held when the sheet opened — Cancel writes these back.
  private opened: boolean[] = [false, false, false, false];
  private rows: CustomizeToggle[] = [
    new CustomizeToggle(WMFDataPrefKeys.activityTabTimeSpentReading,
      $r('app.string.activity_tab_customize_time_spent_reading'), 'Toggle_isTimeSpentReadingOn'),
    new CustomizeToggle(WMFDataPrefKeys.activityTabReadingInsights,
      $r('app.string.activity_tab_customize_reading_insights'), 'Toggle_isReadingInsightsOn'),
    new CustomizeToggle(WMFDataPrefKeys.activityTabEditingInsights,
      $r('app.string.activity_tab_customize_editing_insights'), 'Toggle_isEditingInsightsOn'),
    new CustomizeToggle(WMFDataPrefKeys.activityTabTimelineOfBehavior,
      $r('app.string.activity_tab_customize_timeline_of_behavior'), 'Toggle_isTimelineOfBehaviorOn')
  ];

  aboutToAppear(): void {
    // WMFActivityTabCustomizeViewModel.loadState: signed out, every insight reads off.
    const current: boolean[] = [];
    for (const row of this.rows) {
      current.push(SessionStore.isLoggedIn ? Prefs.getBoolean(row.key, true) : false);
    }
    this.values = current;
    this.opened = current.slice();
  }

  // The insights are per-account, so a signed-out reader cannot switch one on: the source
  // shows logoutWarning and leaves the flag alone.
  private setToggle(index: number, value: boolean): void {
    if (!SessionStore.isLoggedIn) {
      // the switch snaps back off and nothing is stored
      const reverted: boolean[] = this.values.slice();
      reverted[index] = false;
      this.values = reverted;
      if (value) {
        this.presentLoginToast();
      }
      return;
    }
    const next: boolean[] = this.values.slice();
    next[index] = value;
    this.values = next;
    Prefs.putBoolean(this.rows[index].key, value);
  }

  private presentLoginToast(): void {
    this.showLoginToast = true;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => {
      this.showLoginToast = false;
    }, 5000);
  }

  aboutToDisappear(): void {
    clearTimeout(this.toastTimer);
  }

  private cancel(): void {
    for (let i: number = 0; i < this.rows.length; i++) {
      Prefs.putBoolean(this.rows[i].key, this.opened[i]);
    }
    if (this.onClose !== undefined) {
      this.onClose();
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.customize_action_title'))
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        // Cancel sizes to its own label so a longer translation is neither clipped nor
        // truncated; the title beside it gives up the width instead.
        Button() {
          Text($r('app.string.action_cancel'))
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .maxLines(1)
        }
        .id('activity_customize_cancel')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 0, top: 6, bottom: 6 })
        .onClick(() => {
          this.cancel();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      List() {
        ForEach(this.rows, (row: CustomizeToggle, index: number) => {
          ListItem() {
            Row() {
              // The label wraps rather than truncating: the longest translations of these
              // four run well past one line on a phone.
              Text(row.label)
                .layoutWeight(1)
                .fontSize(17)
                .fontColor($r('app.color.theme_text'))
                .margin({ right: 12 })
              Toggle({ type: ToggleType.Switch, isOn: this.values[index] })
                .id(row.rowId)
                .selectedColor($r('app.color.theme_accent'))
                .onChange((value: boolean) => {
                  this.setToggle(index, value);
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
        }, (row: CustomizeToggle) => row.key)

        // The footnote rides inside the list: at the sheet's smaller detent the rows plus the
        // footnote are taller than the sheet, and a footnote outside the list is simply cut.
        ListItem() {
          Text($r('app.string.activity_tab_customize_footer'))
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 16, bottom: 40 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 1, color: $r('app.color.theme_border'), startMargin: 16, endMargin: 16 })
      .scrollBar(BarState.Off)

      if (this.showLoginToast) {
        Row({ space: 12 }) {
          Text($r('app.string.activity_tab_customize_logout_warning'))
            .layoutWeight(1)
            .fontSize(15)
            .fontColor($r('app.color.theme_text'))
          Button() {
            Text($r('app.string.main_menu_account_login'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_link'))
              .decoration({ type: TextDecorationType.Underline, color: $r('app.color.theme_link') })
          }
          .id('activity_customize_toast_login')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showLoginToast = false;
            if (this.onLogIn !== undefined) {
              this.onLogIn();
            }
          })
        }
        .id('activity_customize_login_toast')
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 24 })
        .borderRadius(12)
        .backgroundColor($r('app.color.theme_mid_background'))
        .shadow({ radius: 12, color: '#33000000' })
        .constraintSize({ maxWidth: '92%' })
      }
    }
    .id('WMFActivityTabCustomizeView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
