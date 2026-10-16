// Ported from WMFComponents/.../Shared/Onboarding (WMFOnboardingView, WMFOnboardingCell,
// WMFOnboardingViewModel): the bold title 1 heading 44 vp below the top, the rows (an icon in a
// link-tinted circle, a bold callout title and a subheadline subtitle) 24 vp apart, and, pinned
// below the scrolling content, the primary large button and the quiet secondary button.
export class WMFOnboardingCellModel {
  icon: Resource;
  title: Resource;
  subtitle: Resource;
  // an SF Symbol in the source: drawn as a symbol glyph in the link colour
  isSymbol: boolean;

  constructor(icon: Resource, title: Resource, subtitle: Resource, isSymbol: boolean = false) {
    this.icon = icon;
    this.title = title;
    this.subtitle = subtitle;
    this.isSymbol = isSymbol;
  }
}

@Component
export struct WMFOnboardingView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  title: Resource = $r('app.string.watchlist_onboarding_title');
  cells: WMFOnboardingCellModel[] = [];
  primaryButtonTitle: Resource = $r('app.string.continue_button_title');
  secondaryButtonTitle: Resource | null = null;
  onPrimary: () => void = () => {};
  onSecondary: () => void = () => {};

  build() {
    Column() {
      Scroll() {
        Column() {
          Text(this.title)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
            .margin({ top: 60, bottom: 44 })
          ForEach(this.cells, (cell: WMFOnboardingCellModel) => {
            Row({ space: 8 }) {
              if (cell.isSymbol) {
                Stack() {
                  SymbolGlyph(cell.icon)
                    .fontSize(20)
                    .fontColor([$r('app.color.theme_link')])
                }
                .width(34)
                .height(34)
                .borderRadius(17)
                .backgroundColor('#403366CC')
              } else {
                Image(cell.icon)
                  .width(34)
                  .height(34)
                  .padding(5)
                  .objectFit(ImageFit.Contain)
                  .borderRadius(17)
                  .backgroundColor('#403366CC')
              }
              Column({ space: 1 }) {
                Text(cell.title)
                  .width('100%')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.theme_text'))
                Text(cell.subtitle)
                  .width('100%')
                  .fontSize(15)
                  .fontColor($r('app.color.theme_secondary_text'))
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .margin({ bottom: 24 })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      Column({ space: 20 }) {
        Button(this.primaryButtonTitle)
          .id('onboarding_primary')
          .type(ButtonType.Normal)
          .width('100%')
          .height(46)
          .borderRadius(8)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.theme_link'))
          .margin({ top: 16 })
          .onClick(() => {
            this.onPrimary();
          })
        if (this.secondaryButtonTitle !== null) {
          Button(this.secondaryButtonTitle)
            .id('onboarding_secondary')
            .type(ButtonType.Normal)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_link'))
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.onSecondary();
            })
        }
      }
      .width('100%')
      .padding({ top: 12, left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
