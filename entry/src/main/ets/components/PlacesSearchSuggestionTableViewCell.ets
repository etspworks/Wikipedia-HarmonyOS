// comp_places_suggestion_cell — ported from
// Wikipedia/Code/PlacesSearchSuggestionTableViewCell.swift (+ its .xib): a leading
// iconImageView tinted theme.colors.secondaryText, a titleLabel on primaryText and a
// detailLabel on secondaryText, over the paperBackground row.
// Used by screen_places for the PlaceSearchSuggestionController table.
// S5: styled on the app baseline tokens — 17pt title, 13pt secondary detail, 44pt row.

@Component
export struct PlacesSearchSuggestionTableViewCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop title: string = '';
  @Prop detail: string = '';
  // "location" for a coordinate search, "text" for a string/article completion, "arrow" for
  // "Your current location"
  @Prop iconKind: string = 'text';

  build() {
    Row() {
      Image(this.iconKind === 'location' ? $r('app.media.places_suggestion_location')
        : this.iconKind === 'arrow' ? $r('app.media.places_location_arrow')
        : $r('app.media.places_suggestion_text'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)

      Column() {
        Text(this.title)
          .width('100%')
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.detail !== '') {
          Text(this.detail)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 16 })
    }
    .width('100%')
    .constraintSize({ minHeight: 44 })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
