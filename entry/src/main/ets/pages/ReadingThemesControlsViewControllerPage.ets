// screen_reading_themes_controls — presentation: popup, hosted by
// ArticleViewControllerPage (.bindPopup). NOT a routed page.
// Structure from Wikipedia/Code/ReadingThemesControlsViewController.swift (+ its nib's
// stackView): the text-size slider block (FontSizeSliderViewController's step slider
// between the T glyphs), a separator, the brightness row (minBrightness glyph, brightness
// slider, maxBrightness glyph), a separator, the four theme buttons (Light / Sepia / Dark /
// Black, each labelled "Aa" and carrying its own accessibility identifier), and the last
// separator + syntax-highlighting row, which the article presenter hides
// (showsSyntaxHighlighting == false) and the editor shows.
// userDidSelect(theme:) posts WMFUserDidSelectThemeNotification — here it writes the theme
// straight to svc_theme (ThemeManager), which the host article observes; the dark and black
// buttons carry the stored image-dimming flag, as the source does.
// S5/S6 (capture S0359): popover card on paperBackground; separatorViews carry
// theme.colors.border; the brightness glyphs sit ABOVE a full-width link-filled slider (the
// nib stacks them: glyph row y 148-169, slider y 178-212); each theme button is a 56pt
// circle filled with ITS theme's paperBackground and titled in that theme's primaryText,
// with the source's unselected 0.5pt theme.colors.border and — applyBorder(to:) — a 2pt
// link ring on the button whose theme is the applied one (capture: Light).
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Prefs, PrefKeys, SYNTAX_HIGHLIGHTING_KEY } from '../common/Prefs';
import { ThemeManager, WMFTheme } from '../common/ThemeManager';
import { FontSizeSliderViewController } from '../components/FontSizeSliderViewController';

@Component
export struct ReadingThemesControlsView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // showsSyntaxHighlighting (ReadingThemesControlsPresenting) — false for the article.
  @Prop showsSyntaxHighlighting: boolean = false;
  // isTextSizeSliderHidden
  @Prop isTextSizeSliderHidden: boolean = false;
  @State screenBrightness: number = 0.5;
  @State isSyntaxHighlightingEnabled: boolean = false;
  // applyBorder(to:) marks the applied theme's button; ThemeManager is the applied theme.
  @State appliedThemeName: string = WMFTheme.standard.name;

  aboutToAppear(): void {
    this.isSyntaxHighlightingEnabled =
      Prefs.getBoolean(PrefKeys.isSyntaxHighlightingEnabled, false);
    this.appliedThemeName = ThemeManager.theme.value.name;
    // viewDidLoad: brightnessSlider.value = Float(UIScreen.main.brightness)
    const ctx = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(ctx).then((win: window.Window) => {
      const brightness: number = win.getWindowProperties().brightness;
      if (brightness >= 0) {
        this.screenBrightness = brightness;
      }
    }).catch((e: Error) => {
      console.error('readingThemes: brightness read failed: ' + e.message);
    });
  }

  // brightnessSliderValueChanged — UIScreen.main.brightness = sender.value
  private setBrightness(value: number): void {
    this.screenBrightness = value;
    const ctx = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(ctx).then((win: window.Window) => {
      win.setWindowBrightness(value).catch((e: Error) => {
        console.error('readingThemes: setWindowBrightness failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('readingThemes: getLastWindow failed: ' + e.message);
    });
  }

  // userDidSelect(theme:) — dark and black carry wmf_isImageDimmingEnabled.
  private selectTheme(theme: WMFTheme, appliesDimming: boolean): void {
    const dimming: boolean = Prefs.getBoolean(PrefKeys.isImageDimmingEnabled, false);
    const selected: WMFTheme = appliesDimming ? theme.withDimmingEnabled(dimming) : theme;
    ThemeManager.setTheme(selected);
    this.appliedThemeName = selected.name;
    // WMFUserDidSelectThemeNotification — the hosts read the applied theme off AppStorage
    // (@StorageProp('WMFAppThemeName')), so publishing it there is what restyles them.
    AppStorage.setOrCreate<string>('WMFAppThemeName', selected.name);
  }

  // applyBorder(to:) — 2pt link ring on the applied theme's button, the source's 0.5pt
  // border on the rest. 'dark-dimmed'/'black-dimmed' are the same button as their base.
  private isApplied(base: string): boolean {
    return this.appliedThemeName.split('-')[0] === base;
  }

  private ringWidth(base: string): number {
    return this.isApplied(base) ? 2 : 0.5;
  }

  private ringColor(base: string): Resource {
    return this.isApplied(base)
      ? $r('app.color.theme_link')
      : $r('app.color.theme_border');
  }

  // syntaxHighlightingSwitched
  private setSyntaxHighlighting(enabled: boolean): void {
    this.isSyntaxHighlightingEnabled = enabled;
    Prefs.putBoolean(PrefKeys.isSyntaxHighlightingEnabled, enabled);
    // toggleSyntaxHighlighting: the open editor recolours
    AppStorage.setOrCreate<boolean>(SYNTAX_HIGHLIGHTING_KEY, enabled);
  }

  build() {
    Column() {
      // textSizeSliderViews
      if (!this.isTextSizeSliderHidden) {
        FontSizeSliderViewController({
          sliderId: 'Article Reading Themes Text Size Slider'
        })
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.theme_border'))
      }

      // brightnessSlider row — minBrightness/maxBrightness glyphs above the slider.
      Column() {
        Row() {
          Image($r('app.media.minbrightness'))
            .width(15)
            .height(15)
            .objectFit(ImageFit.Contain)
          Blank()
          Image($r('app.media.maxbrightness'))
            .width(21)
            .height(21)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Slider({
          value: this.screenBrightness,
          min: 0,
          max: 1,
          step: 0.01,
          style: SliderStyle.OutSet
        })
          .id('Article Reading Themes Brightness Slider')
          .width('100%')
          .trackThickness(6)
          .selectedColor($r('app.color.theme_link'))
          .trackColor($r('app.color.gray200'))
          // iOS slider thumbs are white in every theme; the paper colour vanished in dark.
          .blockColor(Color.White)
          .blockBorderColor($r('app.color.theme_border'))
          .blockBorderWidth(1)
          .blockSize({ width: 30, height: 30 })
          .margin({ top: 9 })
          .onChange((value: number) => {
            this.setBrightness(value);
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 15, top: 13, bottom: 5 })

      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.theme_border'))

      // lightThemeButton / sepiaThemeButton / darkThemeButton / blackThemeButton
      Row() {
        Button('Aa')
          .id('Article Reading Themes Light Button')
          .type(ButtonType.Circle)
          .width(56)
          .height(56)
          .fontSize(20)
          .backgroundColor($r('app.color.wmf_white'))
          .fontColor($r('app.color.gray700'))
          .border({ width: this.ringWidth('light'), color: this.ringColor('light') })
          .accessibilitySelected(this.isApplied('light'))
          .onClick(() => {
            this.selectTheme(WMFTheme.light, false);
          })
        Button('Aa')
          .id('Article Reading Themes Sepia Button')
          .type(ButtonType.Circle)
          .width(56)
          .height(56)
          .fontSize(20)
          .backgroundColor($r('app.color.beige100'))
          .fontColor($r('app.color.gray700'))
          .border({ width: this.ringWidth('sepia'), color: this.ringColor('sepia') })
          .accessibilitySelected(this.isApplied('sepia'))
          .onClick(() => {
            this.selectTheme(WMFTheme.sepia, false);
          })
        Button('Aa')
          .id('Article Reading Themes Dark Button')
          .type(ButtonType.Circle)
          .width(56)
          .height(56)
          .fontSize(20)
          .backgroundColor($r('app.color.gray675'))
          .fontColor($r('app.color.wmf_white'))
          .border({ width: this.ringWidth('dark'), color: this.ringColor('dark') })
          .accessibilitySelected(this.isApplied('dark'))
          .onClick(() => {
            this.selectTheme(WMFTheme.dark, true);
          })
        Button('Aa')
          .id('Article Reading Themes Black Button')
          .type(ButtonType.Circle)
          .width(56)
          .height(56)
          .fontSize(20)
          .backgroundColor($r('app.color.wmf_black'))
          .fontColor($r('app.color.wmf_white'))
          .border({ width: this.ringWidth('black'), color: this.ringColor('black') })
          .accessibilitySelected(this.isApplied('black'))
          .onClick(() => {
            this.selectTheme(WMFTheme.black, true);
          })
      }
      .width('100%')
      .padding({ left: 17, right: 17, top: 14, bottom: 20 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // lastSeparator + syntaxHighlightingContainerView
      if (this.showsSyntaxHighlighting) {
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.theme_border'))
        Row() {
          Text($r('app.string.reading_themes_controls_syntax_highlighting'))
            .layoutWeight(1)
            .fontSize(16)
            .fontColor($r('app.color.theme_text'))
          Toggle({ type: ToggleType.Switch, isOn: this.isSyntaxHighlightingEnabled })
            .id('syntax_highlighting_switch')
            .onChange((isOn: boolean) => {
              this.setSyntaxHighlighting(isOn);
            })
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }
    }
    // view.accessibilityIdentifier = AccessibilityIdentifiers.Article.readingThemesView
    .id('ReadingThemesControlsViewController')
    .width('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius({ topLeft: 10, topRight: 10 })
  }
}
