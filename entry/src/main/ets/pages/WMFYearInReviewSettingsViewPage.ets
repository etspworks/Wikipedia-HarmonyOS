// screen_year_in_review_settings — presentation: page, pushed from screen_settings_tab.
// No outgoing nav edges.
//
// S3 structure from WMFComponents/.../Settings/Year In Review/
// WMFYearInReviewSettingsView.swift + its WMFYearInReviewSettingsViewModel.swift:
//   body = a ZStack over theme.midBackground holding a List of viewModel.sections; the
//   navigation title is localizedStrings.title ("Year in Review"), displayMode .inline (the
//   capture's NavigationBar carries the push-navigation back button + that title).
//   buildSections() emits exactly ONE section — header = localizedStrings.description (the
//   "Turning off Year in Review will clear all stored personalized insights…" prose),
//   footer = nil — whose single item is yearInReviewToggleItem(): image =
//   WMFSFSymbolIcon.for(symbol: .calendar) on WMFColor.blue700, title =
//   localizedStrings.toggleTitle, no subtitle, accessory .toggle(toggleBinding).
//   row(for:) renders the .toggle case as a plain SettingsRow (HStack: the badged icon, a
//   VStack of title over the optional subtitle, a Spacer, then the switch); the .none/.icon/
//   .chevron cases render an empty Text on this screen, so the toggle row is the only row.
//   isEnabled <- dataController.yirIsActive(); setEnabled(_:) writes it back through
//   setYirActive(_:) and reverts on failure.
// Rule 12: calendar / turning_off_year_in / BackButton are the SOURCE slugs carried by the
// capture (results/traversal-source/pages/WMFYearInReviewSettingsView). Following
// comp_settings_cell's convention the row's slug sits on the switch (the row's real control)
// and <slug>_row on the row container.
import { common } from '@kit.AbilityKit';
import { upperText } from '../common/LocaleText';
import { router } from '@kit.ArkUI';
import { YearInReviewStore } from '../common/YearInReviewStore';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

@Entry
@Component
struct WMFYearInReviewSettingsViewPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // viewModel.isEnabled <- WMFSettingsDataController.yirIsActive().
  @State isEnabled: boolean = true;

  aboutToAppear(): void {
    this.loadAndBuild();
  }

  private loadAndBuild(): void {
    try {
      this.isEnabled = YearInReviewStore.isYearInReviewEnabled();
    } catch (e) {
      console.error('year in review settings: preferences unavailable: ' + (e as Error).message);
    }
  }

  // setEnabled(_:) -> dataController.setYirActive(_:), which writes the setting and returns
  // yirIsActive(); the view model reverts when the read-back disagrees.
  private setEnabled(newValue: boolean): void {
    const old: boolean = this.isEnabled;
    this.isEnabled = newValue;
    YearInReviewStore.setYearInReviewEnabled(newValue);
    if (YearInReviewStore.isYearInReviewEnabled() !== newValue) {
      this.isEnabled = old;
    }
  }

  // S5 (capture S0155 — pages/WMFYearInReviewSettingsView/base.png): SwiftUI inset-grouped
  // List on theme.midBackground (#F8F9FA). 13/18 secondary section-header prose indented to
  // the card content edge (32 vp); one white card inset 16 vp on the capture's 22 vp
  // continuous radius, carrying the 32 vp blue700 badge (WMFColor.blue700 #2A4B8D) with a
  // white calendar glyph, the 17 vp title, and the switch.
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

        Text($r('app.string.year_in_review_button_title'))
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
          // Section header — localizedStrings.description.
          // a SwiftUI List section header, which the source renders in capitals
          Text(upperText(getContext(this) as common.Context, $r('app.string.settings_year_in_review_header')))
            .width('100%')
            .id('turning_off_year_in')
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 32, bottom: 14 })

          // yearInReviewToggleItem() — SettingsRow: badged calendar glyph, title, switch.
          Row() {
            Stack() {
              SymbolGlyph($r('sys.symbol.calendar'))
                .fontSize(20)
                .fontColor([Color.White])
            }
            .width(32)
            .height(32)
            .backgroundColor($r('app.color.blue700'))
            .borderRadius(8)
            .margin({ right: 20 })
            Text($r('app.string.year_in_review_button_title'))
              .layoutWeight(1)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
              .id('calendar')
              .selectedColor($r('app.color.theme_accent'))
              .onChange((value: boolean) => {
                this.setEnabled(value);
              })
          }
          .width('100%')
          .id('calendar_row')
          .height(58)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .clip(true)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('WMFYearInReviewSettingsView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
