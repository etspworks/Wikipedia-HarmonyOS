// screen_appearance_settings — presentation: page, pushed from screen_settings_tab.
// Structure from Wikipedia/Code/AppearanceSettingsViewController.swift
// sectionsForAppearanceSettings(), section by section and row by row:
//   READING THEMES  — 5 AppearanceSettingsCheckmarkItem rows (Default + "Matches system
//                     theme" subtitle, Light, Sepia, Dark, Black); willDisplay marks the row
//                     whose theme is a prefix of UserDefaults.themeName with .checkmark.
//   THEME OPTIONS   — ImageDimmingExampleViewController custom view, a 15pt spacer row, the
//                     Dim images switch row; footer = the image-dimming explanation.
//   TABLE SETTINGS  — the Expand tables switch row; footer = the expand-tables explanation.
//   ADJUST ARTICLE TEXT SIZING — TextSizeChangeExampleViewController custom view, a 15pt
//                     spacer row, FontSizeSliderViewController.
// The App Icon section is omitted: it is gated on WMFUserDefaultsKey.qualifiesForIcon2025 +
// AppIconUtility (alternate iOS app icons), which HarmonyOS has no equivalent for; the plan
// declares no service for it and the capture never shows it.
// Rule 12: every row id is the SOURCE slug the capture recorded (results/traversal-source/
// pages/AppearanceSettingsViewController) — tap_0 the font-slider row, tap_1/tap_7 the two
// spacer rows, tap_2 the text-size example, tap_8 the image-dimming example.
// S5 style (capture base.ui.json/base.png, 402x874pt): an iOS inset-grouped table —
// theme.colors.baseBackground #EAECF0 page, white cards inset 16 with radius 10, 13pt
// uppercase secondary section headers / 13pt secondary footers, 17pt row titles over the
// 13pt "Matches system theme" subtitle, the checkmark tinted theme.colors.link, and the
// image-dimming example on the source's own dark #2E3136 card. Tokens from
// state.json generation.styleBaseline (screen_explore / S0001).
import { upperText } from '../common/LocaleText';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Prefs, PrefKeys } from '../common/Prefs';
import { ThemeManager, WMFTheme, ThemeColors } from '../common/ThemeManager';
import { FontSizeSliderViewController } from '../components/FontSizeSliderViewController';
import { WMFSettingsTableViewCell, SettingsDisclosureType } from '../components/WMFSettingsTableViewCell';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

@Entry
@Component
struct AppearanceSettingsViewControllerPage {
  // UserDefaults.themeName — the RAW stored name, which is 'standard' while the Default row
  // is selected, so the checkmark test (willDisplay's hasPrefix) can tell it from 'light'.
  @State selectedThemeName: string = WMFTheme.defaultThemeName;
  // WMFArticleFontSizeMultiplier (percent), published by the slider below
  @StorageProp('WMFArticleFontSizeMultiplier') fontPercent: number = 100;
  // UserDefaults.wmf_isImageDimmingEnabled
  @State isImageDimmingEnabled: boolean = false;
  // UserDefaults.wmf_isAutomaticTableOpeningEnabled
  @State isAutomaticTableOpeningEnabled: boolean = false;

  aboutToAppear(): void {
    // Prefs.getSync throws when the store was never opened, which is what a deep link
    // straight to this page does (no tab host ran Prefs.init first).
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      this.selectedThemeName = Prefs.getString(PrefKeys.appThemeName, WMFTheme.defaultThemeName);
      this.isImageDimmingEnabled = Prefs.getBoolean(PrefKeys.isImageDimmingEnabled, false);
      this.isAutomaticTableOpeningEnabled =
        Prefs.getBoolean(PrefKeys.isAutomaticTableOpeningEnabled, false);
    } catch (e) {
      // feat_theming has nothing to load over the network, so its only failure state is an
      // unreadable preference store: fall back to the source's own defaults (standard theme,
      // both switches off) and render the screen rather than a blank/crashed page.
      console.error('appearance: preferences unavailable: ' + (e as Error).message);
    }
  }

  // Themeable.apply(theme:) — the source re-colors this very screen the instant a row is
  // tapped (captured: base #EAECF0, black/dark #101418, sepia #E1DAD1), so the tokens come
  // from the selected theme, not from the static light-palette color resources.
  private colors(): ThemeColors {
    const isDefault: boolean = WMFTheme.isDefaultThemeName(this.selectedThemeName);
    const theme: WMFTheme = isDefault
      ? ThemeManager.resolveDefault()
      : (WMFTheme.withName(this.selectedThemeName) ?? WMFTheme.standard);
    return theme.colors;
  }

  // WMFSettingsTableViewCell takes plain strings; these two rows were English literals.
  private ctxText(res: Resource): string {
    return getContext(this).resourceManager.getStringSync(res);
  }

  // userDidSelect(theme:) — the notification the source posts is handled here by writing the
  // theme straight to svc_theme; every themed page reads it off AppStorage.
  private selectTheme(name: string): void {
    const isDefault: boolean = WMFTheme.isDefaultThemeName(name);
    const base: WMFTheme = isDefault
      ? ThemeManager.resolveDefault()
      : (WMFTheme.withName(name) ?? WMFTheme.standard);
    const applied: WMFTheme = base.isDark
      ? base.withDimmingEnabled(this.isImageDimmingEnabled)
      : base;
    try {
      ThemeManager.setTheme(applied, isDefault);
      // setTheme persists the RESOLVED name ('light'); the Default row must stay 'standard'
      // so ThemeManager.restore and the checkmark below still read it as the default.
      if (isDefault) {
        Prefs.putString(PrefKeys.appThemeName, WMFTheme.defaultThemeName);
      }
    } catch (e) {
      // The selection still applies to this screen; only the persist was lost.
      console.error('appearance: theme persist failed: ' + (e as Error).message);
    }
    this.selectedThemeName = isDefault ? WMFTheme.defaultThemeName : applied.name;
  }

  // willDisplay: currentAppTheme.hasPrefix(checkmarkItem.theme)
  private isSelected(themeName: string): boolean {
    return this.selectedThemeName.startsWith(themeName);
  }

  // Both glyphs on this page are single-color raster templates (chevron_left.png is solid
  // BLACK, checkmark.png solid WHITE) and the page re-colors itself per selected theme, so
  // an untinted glyph collides with its own background: black chevron on the black/dark
  // theme's nav button, white checkmark on the white card. Image.fillColor is SVG-only
  // and colorBlend does not tint a raster image, so tint through a 4x5 color matrix that
  // discards the source RGB and rebuilds it from the alpha channel — the glyph then always
  // takes the live theme color, whatever color the PNG itself was authored in.
  private iconTint(hex: string): ColorFilter {
    const n: number = parseInt(hex.replace('#', ''), 16);
    const r: number = ((n >> 16) & 0xFF) / 255;
    const g: number = ((n >> 8) & 0xFF) / 255;
    const b: number = (n & 0xFF) / 255;
    return new ColorFilter([
      0, 0, 0, r, 0,
      0, 0, 0, g, 0,
      0, 0, 0, b, 0,
      0, 0, 0, 1, 0
    ]);
  }

  // handleImageDimmingSwitchValueChange -> applyImageDimmingChange, which persists the flag and
  // then re-posts userDidSelect(theme: currentThemeName, isImageDimmingEnabled:) — so the live
  // theme is re-resolved with the new dimming, not just the flag stored.
  private setImageDimming(enabled: boolean): void {
    this.isImageDimmingEnabled = enabled;
    try {
      Prefs.putBoolean(PrefKeys.isImageDimmingEnabled, enabled);
    } catch (e) {
      console.error('appearance: dimming persist failed: ' + (e as Error).message);
    }
    this.selectTheme(this.selectedThemeName);
  }

  // handleAutomaticTableOpenSwitchValueChange -> applyAutomaticTableOpenChange
  private setAutomaticTableOpening(enabled: boolean): void {
    this.isAutomaticTableOpeningEnabled = enabled;
    try {
      Prefs.putBoolean(PrefKeys.isAutomaticTableOpeningEnabled, enabled);
    } catch (e) {
      console.error('appearance: expand-tables persist failed: ' + (e as Error).message);
    }
  }

  // WMFTableHeaderFooterLabelView, .header
  @Builder
  sectionHeader(text: Resource) {
    Text(upperText(getContext(this) as common.Context, text))
      .width('100%')
      .fontSize(13)
      .fontColor(this.colors().secondaryText)
      .padding({ top: 28, bottom: 6 })
  }

  // WMFTableHeaderFooterLabelView, .footer
  @Builder
  sectionFooter(text: Resource) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor(this.colors().secondaryText)
      .padding({ top: 6, bottom: 6 })
  }

  // AppearanceSettingsCheckmarkItem rendered by WMFSettingsTableViewCell with
  // disclosureType .none plus the cell's own .checkmark accessory.
  @Builder
  themeRow(rowId: string, themeName: string, title: Resource, hasSubtitle: boolean) {
    Row() {
      Column() {
        Text(title)
          .width('100%')
          .fontSize(17)
          .fontColor(this.colors().primaryText)
        if (hasSubtitle) {
          Text($r('app.string.theme_default_explanation'))
            .width('100%')
            .fontSize(13)
            .fontColor(this.colors().secondaryText)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isSelected(themeName)) {
        Image($r('app.media.checkmark'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
          // checkmark.png is a white template glyph; iOS tints it theme.colors.link.
          .colorFilter(this.iconTint(this.colors().link))
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Center)
    .id(rowId)
    .onClick(() => {
      this.selectTheme(themeName);
    })
  }

  // AppearanceSettingsSpacerViewItem — a 15pt empty row.
  @Builder
  spacerRow(rowId: string) {
    Row()
      .width('100%')
      .height(15)
      .id(rowId)
  }

  build() {
    Column() {
      // WMFNavigationBar: the push-navigation back button + the centered title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
              // Captured source: dark glyph on light themes, near-white glyph on black/dark —
              // i.e. the nav chevron carries theme.colors.primaryText.
              .colorFilter(this.iconTint(this.colors().primaryText))
          }
          .id('BackButton')
          .accessibilityText('App theme')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        Text($r('app.string.settings_appearance'))
          .fontSize(17)
          .fontWeight(600)
          .fontColor(this.colors().primaryText)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 4, bottom: 4 })

      Scroll() {
        Column() {
          // MARK: Reading themes
          this.sectionHeader($r('app.string.appearance_settings_reading_themes'))
          Column() {
            this.themeRow('matches_system_theme', WMFTheme.defaultThemeName,
              $r('app.string.theme_default_display_name'), true)
            this.themeRow('light', 'light', $r('app.string.theme_light_display_name'), false)
            this.themeRow('sepia', 'sepia', $r('app.string.theme_sepia_display_name'), false)
            this.themeRow('dark', 'dark', $r('app.string.theme_dark_display_name'), false)
            this.themeRow('black', 'black', $r('app.string.theme_black_display_name'), false)
          }
          .width('100%')
          .backgroundColor(this.colors().paperBackground)
          .borderRadius(10)
          .clip(true)

          // MARK: Theme options
          this.sectionHeader($r('app.string.appearance_settings_theme_options'))
          // ImageDimmingExampleViewController — the ftux-puzzle-globe image, dimmed to
          // Theme.dimmedImageOpacity while image dimming is on.
          Row() {
            Image($r('app.media.ftux_puzzle_globe'))
              .width('100%')
              .height(151)
              .objectFit(ImageFit.Contain)
              .opacity(this.isImageDimmingEnabled ? WMFTheme.dimmedImageOpacity : 1)
          }
          .width('100%')
          .height(151)
          .backgroundColor($r('app.color.gray650'))
          .borderRadius(10)
          .clip(true)
          .id('tap_8')
          this.spacerRow('tap_7')
          Column() {
            WMFSettingsTableViewCell({
              title: this.ctxText($r('app.string.dim_images')),
              disclosureType: SettingsDisclosureType.toggle,
              isSwitchOn: this.isImageDimmingEnabled,
              rowId: 'dim_images',
              iconImage: $r('app.media.settings_image_dimming'),
              iconColor: $r('app.color.gray400'),
              onToggle: (value: boolean): void => {
                this.setImageDimming(value);
              }
              })
          }
          .width('100%')
          .backgroundColor(this.colors().paperBackground)
          .borderRadius(10)
          .clip(true)
          this.sectionFooter($r('app.string.appearance_settings_image_dimming_footer'))

          // MARK: Table settings
          this.sectionHeader($r('app.string.appearance_settings_set_automatic_table_opening'))
          Column() {
            WMFSettingsTableViewCell({
              title: this.ctxText($r('app.string.appearance_settings_expand_tables')),
              disclosureType: SettingsDisclosureType.toggle,
              isSwitchOn: this.isAutomaticTableOpeningEnabled,
              rowId: 'expand_tables',
              iconImage: $r('app.media.settings_tables_expand'),
              iconColor: $r('app.color.blue300'),
              onToggle: (value: boolean): void => {
                this.setAutomaticTableOpening(value);
              }
              })
          }
          .width('100%')
          .backgroundColor(this.colors().paperBackground)
          .borderRadius(10)
          .clip(true)
          this.sectionFooter($r('app.string.appearance_settings_expand_tables_footer'))

          // MARK: Adjust article text sizing
          this.sectionHeader($r('app.string.appearance_settings_adjust_text_sizing'))
          // TextSizeChangeExampleViewController — the example paragraph the slider resizes.
          Row() {
            // resizes with the slider, as the source's example does
            Text($r('app.string.appearance_settings_text_sizing_example_text'))
              .width('100%')
              .fontSize(17 * this.fontPercent / 100)
              .lineHeight(24 * this.fontPercent / 100)
              .fontColor(this.colors().primaryText)
          }
          .width('100%')
          .constraintSize({ minHeight: 200 })
          .alignItems(VerticalAlign.Top)
          .padding(16)
          .backgroundColor(this.colors().paperBackground)
          .borderRadius(10)
          .clip(true)
          .id('tap_2')
          this.spacerRow('tap_1')
          Row() {
            FontSizeSliderViewController()
          }
          .width('100%')
          .backgroundColor(this.colors().paperBackground)
          .borderRadius(10)
          .clip(true)
          .id('tap_0')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('AppearanceSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().baseBackground)
  }
}
