// screen_hint — presentation: popup, hosted by screen_article
// (.bindPopup in ArticleViewControllerPage). NOT a routed page.
// S3 structure from Wikipedia/Code/HintViewController.swift: three exclusive views —
// defaultView (image + label), confirmationView (image + label + accessory button),
// warningView (label + subtitle). Hint text passed by the presenter (bindingContract).
@Component
export struct HintView {
  @Prop kind: string = 'default';   // 'default' | 'confirmation' | 'warning'
  @Prop hintText: string = '';
  @Prop subtitle: string = '';
  @Prop actionTitle: string = '';
  onAction?: () => void;

  build() {
    Column() {
      // S5 (no device capture — styled from HintViewController.apply(theme:):
      // hintBackground = blue100, labels = mediumSubheadline in theme.colors.link,
      // warning = theme warning surface with primaryText subtitle (caption1)).
      if (this.kind === 'confirmation') {
        Row() {
          Text(this.hintText)
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_link'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.actionTitle !== '') {
            Button(this.actionTitle)
              .id('hint_action')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_link'))
              .height(36)
              .padding({ left: 12, right: 4 })
              .onClick(() => {
                if (this.onAction !== undefined) {
                  this.onAction();
                }
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 12, top: 10, bottom: 10 })
      } else if (this.kind === 'warning') {
        Column({ space: 2 }) {
          Text(this.hintText)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_warning'))
          if (this.subtitle !== '') {
            Text(this.subtitle)
              .fontSize(13)
              .fontColor($r('app.color.theme_text'))
              .lineHeight(18)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Row() {
          Text(this.hintText)
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_link'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      }
    }
    .id('HintViewController')
    .width('100%')
    .backgroundColor(this.kind === 'warning'
      ? $r('app.color.orange100alpha')
      : $r('app.color.blue100'))
    .borderRadius(8)
    .clip(true)
  }
}
