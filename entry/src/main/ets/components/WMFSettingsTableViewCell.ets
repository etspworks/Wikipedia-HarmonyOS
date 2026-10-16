// comp_settings_cell — ported from Wikipedia/Code/WMFSettingsTableViewCell.{h,m,xib}:
// one settings row = iconContainer (a tinted square badge holding the row glyph),
// titleLabel over an optional subtitleLabel, then the trailing accessory chosen by
// WMFSettingsMenuItemDisclosureType (WMFSettingsMenuItem.h):
//   None                              -> nothing
//   ViewController                    -> the chevron
//   ViewControllerWithDisclosureText  -> disclosureText + the chevron
//   ExternalLink                      -> the external-link glyph
//   Switch                            -> disclosureSwitch
//   TitleButton                       -> the title itself acts as the control
// The SwiftUI settings screen (WMFSettingsViewModel.SettingsItem/AccessoryType) maps onto the
// same row shape: .none / .chevron(label:) / .icon(_:) / .toggle(_:).
// Users: screen_settings_tab, screen_appearance_settings, screen_explore_feed_settings,
// screen_feed_card_settings.
// S5: styled from captured S0042 + WMFSettingsView.swift's own row spec — a 32x32 badge
// (RoundedRectangle cornerRadius 6, filled with the item's color, 16pt white glyph),
// .body title, .subheadline secondary subtitle, secondary accessory, 52pt row.

export enum SettingsDisclosureType {
  none = 0,
  viewController = 1,
  viewControllerWithText = 2,
  externalLink = 3,
  toggle = 4,
  titleButton = 5
}

// template tint: alpha kept, RGB white
const WHITE_GLYPH: number[] = [0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0];

@Component
export struct WMFSettingsTableViewCell {
  @Prop title: string = '';
  // subtitleLabel — hidden when empty
  @Prop subtitle: string = '';
  // disclosureText (the ViewControllerWithDisclosureText / .chevron(label:) value)
  @Prop disclosureText: string = '';
  @Prop disclosureType: number = SettingsDisclosureType.viewController;
  // disclosureSwitch state, for the Switch type
  @Prop isSwitchOn: boolean = false;
  // Rule 12: the row's own source slug, supplied by the owning screen.
  @Prop rowId: string = '';

  // The row glyph, set once when the row is built (WMFSettingsMenuItem.iconName), so these
  // are plain members rather than synchronized props. `icon` carries a system symbol (the
  // source's WMFSFSymbolIcon rows), `iconImage` a bundled asset (its WMFIcon rows).
  icon?: Resource;
  iconImage?: Resource;
  // SettingsItem.color — the badge fill (WMFSettingsView fills the RoundedRectangle with it).
  // Set once with the glyph, so a plain member like the two above, not a @Prop (a union
  // ResourceColor is not a valid @Prop type in ArkTS V1).
  iconColor: ResourceColor = $r('app.color.gray300');
  onTap?: () => void;
  onToggle?: (value: boolean) => void;

  // The row's visual content; the two build() branches differ ONLY in whether the row
  // itself is tappable (a switch row's control is the switch, so its container must not
  // carry an id or an onClick — ArkTS has no onClick(undefined) to opt out with).
  @Builder
  rowBody() {
      // iconContainer > iconImageView — the tinted 32x32 badge holding a 16pt white glyph.
      // Rows configured with no glyph (the source's plain switch rows, e.g. "Explore tab"
      // and every row on screen_feed_card_settings) carry no badge at all; rendering an
      // empty one left their titles indented against an invisible 52 vp gutter.
      if (this.icon !== undefined || this.iconImage !== undefined) {
        Stack() {
        // The glyphs are template images drawn white on the tinted tile, as the source's are.
        // Most bundled glyph PNGs are black and the symbols took the chrome colour (dark grey
        // in the dark themes), so several badges read as an empty tile; they were also small.
        if (this.icon !== undefined) {
          SymbolGlyph(this.icon)
            .fontSize(20)
            .fontColor([Color.White])
        } else if (this.iconImage !== undefined) {
          Image(this.iconImage)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .fillColor(Color.White)
            .colorFilter(new ColorFilter(WHITE_GLYPH))
        }
      }
        .width(32)
        .height(32)
        .borderRadius(6)
        .backgroundColor(this.iconColor)
        .margin({ right: 20 })
      }

      // titleLabel over subtitleLabel
      Column() {
        Text(this.title)
          .width('100%')
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // the trailing accessory
      if (this.disclosureType === SettingsDisclosureType.toggle) {
        Toggle({ type: ToggleType.Switch, isOn: this.isSwitchOn })
          .id(this.rowId)
          .selectedColor($r('app.color.theme_accent'))
          .onChange((value: boolean) => {
            if (this.onToggle !== undefined) {
              this.onToggle(value);
            }
          })
      } else if (this.disclosureType === SettingsDisclosureType.externalLink) {
        SymbolGlyph($r('sys.symbol.arrow_right_up_and_square'))
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
      } else if (this.disclosureType === SettingsDisclosureType.viewControllerWithText) {
        Text(this.disclosureText)
          .fontSize(17)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ right: 6 })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
      } else if (this.disclosureType === SettingsDisclosureType.viewController) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
      }
  }

  build() {
    if (this.disclosureType === SettingsDisclosureType.toggle) {
      Row() {
        this.rowBody()
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ left: 16, right: 17, top: 6, bottom: 6 })
      .alignItems(VerticalAlign.Center)
    } else {
      Row() {
        this.rowBody()
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ left: 16, right: 17, top: 6, bottom: 6 })
      .alignItems(VerticalAlign.Center)
      // The whole row is the tap target (tableView didSelectRowAt).
      .id(this.rowId)
      .onClick(() => {
        if (this.onTap !== undefined) {
          this.onTap();
        }
      })
    }
  }
}
