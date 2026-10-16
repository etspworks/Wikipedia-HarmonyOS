// comp_scrollable_panel — ported from Wikipedia/Code/ScrollableEducationPanelViewController.swift
// (close button, imageView, headingLabel, subheadingTextView, primary/secondary buttons,
// footerTextView, scroll container). S5: styled — centered panel, filled blue primary,
// plain blue secondary, footnote footer.

@Component
export struct ScrollableEducationPanelViewController {
  @Prop imageURL: string = '';
  @Prop heading: string = '';
  @Prop subheading: string = '';
  @Prop primaryButtonTitle: string = '';
  @Prop secondaryButtonTitle: string = '';
  @Prop footerText: string = '';
  @Prop showCloseButton: boolean = true;
  onPrimary?: () => void;
  onSecondary?: () => void;
  onClose?: () => void;

  build() {
    Column() {
      if (this.showCloseButton) {
        Row() {
          Blank()
          Button('Close')
            .id('education_panel_close')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.theme_link'))
            .fontSize(17)
            .onClick(() => {
              if (this.onClose !== undefined) {
                this.onClose();
              }
            })
        }
        .width('100%')
      }
      Scroll() {
        Column() {
          if (this.imageURL !== '') {
            Image(this.imageURL)
              .width('100%')
              .height(160)
              .objectFit(ImageFit.Contain)
              .margin({ top: 8 })
          }
          Text(this.heading)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
            .margin({ top: 16 })
          if (this.subheading !== '') {
            Text(this.subheading)
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .textAlign(TextAlign.Center)
              .lineHeight(22)
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)

      if (this.primaryButtonTitle !== '') {
        Button(this.primaryButtonTitle)
          .id('education_panel_primary')
          .width('100%')
          .height(46)
          .backgroundColor($r('app.color.theme_link'))
          .fontColor($r('app.color.wmf_white'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .borderRadius(8)
          .margin({ top: 16 })
          .onClick(() => {
            if (this.onPrimary !== undefined) {
              this.onPrimary();
            }
          })
      }
      if (this.secondaryButtonTitle !== '') {
        Button(this.secondaryButtonTitle)
          .id('education_panel_secondary')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.theme_link'))
          .fontSize(15)
          .margin({ top: 8 })
          .onClick(() => {
            if (this.onSecondary !== undefined) {
              this.onSecondary();
            }
          })
      }
      if (this.footerText !== '') {
        Text(this.footerText)
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(16)
  }
}
