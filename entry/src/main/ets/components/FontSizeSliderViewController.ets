// comp_font_slider — ported from Wikipedia/Code/FontSizeSliderViewController.swift (+ its
// .xib): the tSmall glyph, the SWStepSlider over the 7 article font-size multipliers, and
// the tLarge glyph. fontSliderValueChanged writes WMFArticleFontSizeMultiplier and posts
// WMFArticleFontSizeUpdatedNotification; indexOfCurrentFontSize seeds the slider from the
// stored multiplier and falls back to the middle step.
// Users: screen_appearance_settings, screen_reading_themes_controls.
// S5/S6 (capture S0359): the SWStepSlider is a thin border-coloured track with a tick per
// font-size step and a round white block, under a row carrying the small and large T glyphs.
import { Prefs } from '../common/Prefs';

// WMFFontSizeMultiplier raw values (NSUserDefaults+WMFApplicationDefaults.swift).
const FONT_SIZE_MULTIPLIERS: number[] = [70, 80, 90, 100, 125, 150, 175];
// WMFArticleFontSizeMultiplierKey
const ARTICLE_FONT_SIZE_MULTIPLIER_KEY: string = 'WMFArticleFontSizeMultiplier';

const IDENTITY_GLYPH: number[] = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
const LIGHT_GLYPH: number[] = [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0];

@Component
export struct FontSizeSliderViewController {
  // The slider's accessibilityIdentifier differs per host (the reading-themes popover
  // labels it "Article Reading Themes Text Size Slider").
  @Prop sliderId: string = 'Article Reading Themes Text Size Slider';
  @State stepIndex: number = 3;
  // The host may observe the change (ReadingThemesControlsResponding.updateWebViewTextSize).
  onMultiplierChanged: ((multiplier: number) => void) | null = null;

  // the T glyph PNGs are black; in the dark themes they vanished
  @StorageProp('wmfIsDark') isDark: boolean = false;

  aboutToAppear(): void {
    this.stepIndex = this.indexOfCurrentFontSize();
    // hosts showing a preview read the multiplier off AppStorage before the slider moves
    AppStorage.setOrCreate<number>(ARTICLE_FONT_SIZE_MULTIPLIER_KEY, FONT_SIZE_MULTIPLIERS[this.stepIndex]);
  }

  private indexOfCurrentFontSize(): number {
    const stored: number = Prefs.getNumber(ARTICLE_FONT_SIZE_MULTIPLIER_KEY, 0);
    const index: number = FONT_SIZE_MULTIPLIERS.indexOf(stored);
    return index >= 0 ? index : Math.floor(FONT_SIZE_MULTIPLIERS.length / 2);
  }

  private setFontSize(index: number): void {
    if (index < 0 || index >= FONT_SIZE_MULTIPLIERS.length) {
      return;
    }
    this.stepIndex = index;
    const multiplier: number = FONT_SIZE_MULTIPLIERS[index];
    Prefs.putNumber(ARTICLE_FONT_SIZE_MULTIPLIER_KEY, multiplier);
    // The article reads the multiplier off AppStorage, so it resizes live behind the popover.
    AppStorage.setOrCreate<number>(ARTICLE_FONT_SIZE_MULTIPLIER_KEY, multiplier);
    const cb = this.onMultiplierChanged;
    if (cb !== null) {
      cb(multiplier);
    }
  }

  build() {
    // S6 (capture S0359): the .xib stacks the two T glyphs ABOVE the step slider (glyph row
    // y 75-90, slider row y 94-138) — they are not inline with it.
    Column() {
      Row() {
        Image($r('app.media.t_small'))
          .width(12)
          .height(15)
          .objectFit(ImageFit.Contain)
          .colorFilter(new ColorFilter(this.isDark ? LIGHT_GLYPH : IDENTITY_GLYPH))
        Blank()
        Image($r('app.media.t_large'))
          .width(12)
          .height(15)
          .objectFit(ImageFit.Contain)
          .colorFilter(new ColorFilter(this.isDark ? LIGHT_GLYPH : IDENTITY_GLYPH))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // SWStepSlider: a tick per step (7), visible on both sides of the knob. The Slider's own
      // steps are hidden under its selected track, so the ticks sit behind it (block inset 15).
      Stack() {
        Row() {
          ForEach(FONT_SIZE_MULTIPLIERS, (m: number) => {
            Circle({ width: 6, height: 6 }).fill($r('app.color.theme_secondary_text'))
          }, (m: number) => String(m))
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.SpaceBetween)
        .hitTestBehavior(HitTestMode.Transparent)
        Slider({
          value: this.stepIndex,
          min: 0,
          max: FONT_SIZE_MULTIPLIERS.length - 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .id(this.sliderId)
          .width('100%')
          .trackThickness(2)
          .selectedColor($r('app.color.theme_border'))
          .trackColor($r('app.color.theme_border'))
          .blockColor(Color.White)
          .blockBorderColor($r('app.color.theme_border'))
          .blockBorderWidth(1)
          .blockSize({ width: 30, height: 30 })
          .onChange((value: number) => {
            this.setFontSize(Math.round(value));
          })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 15, right: 15, top: 13, bottom: 8 })
  }
}
