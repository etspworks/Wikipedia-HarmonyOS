// comp_saved_article_cell — ported from Wikipedia/Code/SavedArticlesCollectionViewCell.swift
// (setup() + configure(article:index:shouldShowSeparators:) + sizeThatFits).
// One saved-article row: a leading label column (titleLabel over descriptionLabel, with the
// statusView dot trailing the title while the article is NOT downloaded, and the alertButton
// under them when an alert type is set) beside a trailing 100pt imageView (cornerRadius 3,
// hidden when the article has no imageURL), plus the horizontal tag collection of the reading
// lists the article belongs to (hidden when there are none OR an alert is showing) and the
// bottomSeparator.
// Users: screen_saved.
// S5 style (capture SavedViewController/base.png, 402x874pt): cell 124-125pt tall, content
// TOP-aligned at y+12 — title 16 Bold #202122 at x16 (WMFFont .boldCallout), description 15 Regular #72777D 4pt
// under it, 100x100 image (source cornerRadius 3) ending at x386, full-width hairline
// separator at the cell bottom.

@Component
export struct SavedArticlesCollectionViewCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // article.displayTitleHTML
  @Prop title: string = '';
  // article.capitalizedWikidataDescriptionOrSnippet
  @Prop articleDescription: string = '';
  // article.imageURL(forWidth:) — '' means isImageViewHidden = true
  @Prop imageURL: string = '';
  // isStatusViewHidden = article.isDownloaded (the dot marks a NOT-yet-downloaded article)
  @Prop isDownloaded: boolean = false;
  // alertType -> alertButton title ('' == isAlertButtonHidden)
  @Prop alertText: string = '';
  // tags.readingLists -> TagCollectionViewCell per reading list the article is in
  @Prop tags: string[] = [];
  // shouldShowSeparators -> bottomSeparator
  @Prop showsSeparator: boolean = false;
  // didSelect(_ tag:) — tapping a tag opens that reading list
  onTagTap?: (index: number) => void;
  // WMFAsyncPageRowSavedViewModel.didTapAlert
  onAlertTap?: () => void;

  build() {
    Column() {
      Row() {
        Column() {
          // titleLabel + statusView (the sync dot sits beside the title, not under it)
          Row() {
            Text(this.title)
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (!this.isDownloaded) {
              // statusView — cornerRadius 0.5 * statusViewDimension
              Circle()
                .width(6)
                .height(6)
                .fill($r('app.color.theme_link'))
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // descriptionLabel — hidden when the article has no description/snippet
          if (this.articleDescription !== '') {
            Text(this.articleDescription)
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }

          // WMFAsyncPageRowSavedAlertView: exclamationmark.triangle + the alert text, both in
          // the warning colour, semibold caption; a tap reaches didTapAlert
          if (this.alertText !== '') {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor([$r('app.color.theme_warning')])
              Text(this.alertText)
                .layoutWeight(1)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.theme_warning'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .id('saved_article_alert')
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 6 })
            .onClick(() => {
              if (this.onAlertTap !== undefined) {
                this.onAlertTap();
              }
            })
          }

          // collectionView of TagCollectionViewCell — isTagsViewHidden when there are no
          // reading lists OR an alert is on screen.
          if (this.tags.length > 0 && this.alertText === '') {
            Row() {
              ForEach(this.tags, (tag: string, index: number) => {
                Text(tag)
                  .fontSize(12)
                  .fontColor($r('app.color.theme_tag_text'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .backgroundColor($r('app.color.theme_tag_background'))
                  .borderRadius(3)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .margin({ right: 6 })
                  .onClick(() => {
                    const cb: ((i: number) => void) | undefined = this.onTagTap;
                    if (cb !== undefined) {
                      cb(index);
                    }
                  })
              }, (tag: string, index: number) => tag + '_' + index)
            }
            .width('100%')
            .margin({ top: 8 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        // imageView — imageViewDimension 100, cornerRadius 3
        if (this.imageURL !== '') {
          Image(this.imageURL)
            .width(100)
            .height(100)
            .objectFit(ImageFit.Cover)
            .borderRadius(3)
            .backgroundColor($r('app.color.gray200'))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // bottomSeparator
      if (this.showsSeparator) {
        Divider()
          .width('100%')
          .strokeWidth(0.5)
          .color($r('app.color.gray300'))
      }
    }
    .width('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
