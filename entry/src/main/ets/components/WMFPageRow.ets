// comp_page_row — ported from
// WMFComponents/Sources/WMFComponents/Components/Shared/Page/WMFPageRow.swift: rowContent is an
// HStack of an optional leading icon, a VStack of titleHtml (titleLineLimit lines) over an
// optional articleDescription (1 line), a Spacer, and the article thumbnail loaded from
// imageURLString. The swipe actions the source attaches in `body` belong to the enclosing
// ListItem, so the consuming screen attaches .swipeAction() around this row.
// Users: screen_activity_tab, screen_watchlist.
// S5: styled on the app baseline tokens (no capture) — 18 Medium title over a 15
// secondary description, 40 vp thumbnail on the 3 vp thumb radius.

@Component
export struct WMFPageRow {
  @Prop titleHtml: string = '';
  @Prop articleDescription: string = '';
  @Prop imageURLString: string = '';
  @Prop titleLineLimit: number = 1;

  build() {
    Row() {
      Column() {
        Text(this.titleHtml)
          .width('100%')
          .maxLines(this.titleLineLimit)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        if (this.articleDescription !== '') {
          Text(this.articleDescription)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.imageURLString !== '') {
        Image(this.imageURLString)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Cover)
          .borderRadius(3)
          .backgroundColor($r('app.color.gray200'))
          .margin({ left: 12 })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
