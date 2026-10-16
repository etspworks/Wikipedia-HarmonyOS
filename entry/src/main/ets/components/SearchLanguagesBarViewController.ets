// comp_search_bar — ported from Wikipedia/Code/SearchLanguagesBarViewController.swift.
// Source structure: a horizontal UIScrollView holding one SearchLanguageButton per
// preferred language (a square language-code badge + the language name, the selected one
// underlined/tinted), followed by the trailing "More" (otherLanguagesButton) button that
// opens the preferred-languages picker. Selecting a language sets
// wmf_currentSearchContentLanguageCode and re-runs the search (delegate
// searchLanguagesBarViewController(_:didChangeSelectedSearchContentLanguageCode:)).
// S5: styled from capture S0034 — gray bar, blue square language-code badge, the
// selected language in link blue with a blue underline, trailing blue "More".
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { Prefs, PrefKeys } from '../common/Prefs';
import { capitalizeFirst } from '../common/LanguageService';

@Component
export struct SearchLanguagesBarViewController {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // languageBarLanguages() — languageLinkController.preferredLanguages
  @Prop @Watch('updateMoreLanguagesTip') languages: MWKLanguageLink[] = [];
  // MoreLanguagesTip: a popover on More while 2+ languages are on the bar, until closed
  @State showMoreLanguagesTip: boolean = false;
  private moreLanguagesTipShown: boolean = false;
  // selectedSearchContentLanguageCode
  @Prop selectedLanguageCode: string = '';
  onSelectLanguage?: (languageCode: string) => void;
  onTapMore?: () => void;

  aboutToAppear(): void {
    this.updateMoreLanguagesTip();
  }

  // MoreLanguagesTip.rules: numberOfAppLanguages >= 2 and the bar is visible (it is, while
  // this component exists).
  private updateMoreLanguagesTip(): void {
    this.showMoreLanguagesTip = this.languages.length >= 2 &&
      !Prefs.getBoolean(PrefKeys.didCloseMoreLanguagesTip, false);
  }

  // the popover's X, or a tap outside it (presentationControllerDidDismiss)
  private closeMoreLanguagesTip(): void {
    this.showMoreLanguagesTip = false;
    Prefs.putBoolean(PrefKeys.didCloseMoreLanguagesTip, true);
  }

  // TipUIPopoverViewController: bold title, secondary message, trailing close X
  @Builder
  moreLanguagesTip() {
    Row() {
      Column() {
        Text($r('app.string.more_languages_tooltip_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Text($r('app.string.more_languages_tooltip_description'))
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .id('more_languages_tip_close')
        .fontSize(24)
        .fontColor([$r('app.color.theme_secondary_text')])
        .margin({ left: 12 })
        .onClick(() => {
          this.closeMoreLanguagesTip();
        })
    }
    .id('more_languages_tip')
    .padding({ left: 16, right: 12, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Top)
  }

  private select(languageCode: string): void {
    const cb: ((languageCode: string) => void) | undefined = this.onSelectLanguage;
    if (cb !== undefined) {
      cb(languageCode);
    }
  }

  build() {
    Row() {
      // scrollView + stackView of SearchLanguageButton
      Scroll() {
        Row() {
          ForEach(this.languages, (lang: MWKLanguageLink) => {
            Row() {
              // languageCodeLabel — uppercased, max 4 characters
              Text(lang.languageCode.toUpperCase().substring(0, 4))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.wmf_white'))
                .textAlign(TextAlign.Center)
                .backgroundColor(lang.languageCode === this.selectedLanguageCode
                  ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
                .borderRadius(4)
                .height(22)
                .padding({ left: 6, right: 6 })
              // SearchLanguageButton title: language.name, the autonym (Français, not French)
              Text(lang.name !== '' ? capitalizeFirst(lang.name) : lang.localizedName)
                .fontSize(17)
                .fontColor(lang.languageCode === this.selectedLanguageCode
                  ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
                .maxLines(1)
                .margin({ left: 8 })
            }
            // one row of a repeated list — shared id, index-resolved by replay (Rule 12)
            .id('search_language_itemroot')
            .height(44)
            .alignItems(VerticalAlign.Center)
            .padding({ left: 16, right: 16 })
            // the selected language carries a 3 vp link-blue underline in the capture
            .border({
              width: { bottom: 3 },
              color: lang.languageCode === this.selectedLanguageCode
                ? $r('app.color.theme_link') : Color.Transparent
            })
            .onClick(() => {
              this.select(lang.languageCode);
            })
          }, (lang: MWKLanguageLink) => lang.languageCode)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.BottomStart)
      .layoutWeight(1)

      // otherLanguagesButton ("More")
      Button($r('app.string.main_menu_title'))
        .id('More')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .height(44)
        .padding({ left: 12, right: 16 })
        .bindPopup(this.showMoreLanguagesTip, {
          builder: this.moreLanguagesTip(),
          placement: Placement.Bottom,
          popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
          radius: 16,
          width: 340,
          shadow: { radius: 16, color: '#1F000000', offsetY: 2 },
          onStateChange: (e) => {
            // only a popover that was on screen can be closed by the user
            if (e.isVisible) {
              this.moreLanguagesTipShown = true;
            } else if (this.moreLanguagesTipShown && this.showMoreLanguagesTip) {
              this.closeMoreLanguagesTip();
            }
          }
        })
        .onClick(() => {
          const cb: (() => void) | undefined = this.onTapMore;
          if (cb !== undefined) {
            cb();
          }
        })
    }
    .id('search_languages_bar')
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Bottom)
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })
  }
}
