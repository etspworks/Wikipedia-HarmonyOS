// comp_reading_lists_cell — ported from Wikipedia/Code/ReadingListsCollectionViewCell.swift
// (configure(with:description:isDefault:...) + sizeThatFits). One row per reading list:
// a leading label column over a trailing 2x2 image grid (exactly 4 lead images) or a single
// lead image (>= 1 image), per `isImageGridHidden = imageURLs.count != 4`.
// displayType splits the column: .readingListsTab shows the uppercased article-count label
// above the title and the "cannot be deleted" tag on the default list; the compact
// .addArticlesToReadingList type (isCompact) shows the title alone — and title over
// description only for the default list.
// Users: screen_reading_lists, screen_add_articles_to_reading_list.
// S5: styled from the source's own typography (the captured add-to-list state S0326 is
// empty, so no row pixels exist): articleCountLabel .caption1 secondaryText uppercased,
// title .boldCallout (compact: .boldSubheadline), description .footnote secondaryText,
// defaultListTag .italicCaption1 secondaryText, imageViewDimension 40 when compact.

import { common } from '@kit.AbilityKit';
import { pluralString } from '../common/Plural';
import { upperText } from '../common/LocaleText';
@Component
export struct ReadingListsCollectionViewCell {
  // ReadingList.name / .readingListDescription
  @Prop name: string = '';
  @Prop listDescription: string = '';
  // articleCount: Int64 — countOfEntries of the list
  @Prop articleCount: number = 0;
  @Prop isDefault: boolean = false;
  // displayType == .addArticlesToReadingList (configureForCompactList)
  @Prop isCompact: boolean = false;
  // lastFourArticlesWithLeadImages -> imageURL(forWidth:)
  @Prop imageURLs: string[] = [];
  // alertLabel (configureAlert): why the list is not synced, e.g. the server's list limit
  @Prop syncError: string = '';

  // CommonStrings.articleCountFormat, uppercased ({{PLURAL:$1|$1 article|$1 articles}}).
  // (the catalogue carries the same text as places-filter-top-articles-count; English literals
  // before, so Turkish read '0 ARTICLES')
  private articleCountText(): string {
    const ctx: common.Context = getContext(this) as common.Context;
    return upperText(ctx, pluralString(ctx, $r('app.string.places_filter_top_articles_count'), this.articleCount));
  }

  @Builder
  imageGrid() {
    Column() {
      Row() {
        Image(this.imageURLs[0]).layoutWeight(1).height('100%').objectFit(ImageFit.Cover)
        Image(this.imageURLs[1]).layoutWeight(1).height('100%').objectFit(ImageFit.Cover)
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        Image(this.imageURLs[2]).layoutWeight(1).height('100%').objectFit(ImageFit.Cover)
        Image(this.imageURLs[3]).layoutWeight(1).height('100%').objectFit(ImageFit.Cover)
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  build() {
    Row() {
      Column() {
        // articleCountLabel — hidden for the addArticlesToReadingList display type.
        if (!this.isCompact) {
          Text(this.articleCountText())
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.name)
          .width('100%')
          .fontSize(this.isCompact ? 15 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
          .margin({ top: this.isCompact ? 0 : 3 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.listDescription !== '' && (!this.isCompact || this.isDefault)) {
          Text(this.listDescription)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 3 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.syncError !== '') {
          Text(this.syncError)
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_warning'))
            .margin({ top: 4 })
        }
        // defaultListTag — readingListsTab display type only.
        if (!this.isCompact && this.isDefault) {
          Text($r('app.string.saved_default_reading_list_tag'))
            .width('100%')
            .fontSize(12)
            .fontStyle(FontStyle.Italic)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.imageURLs.length === 4) {
        Column() {
          this.imageGrid()
        }
        .width(this.isCompact ? 40 : 100)
        .height(this.isCompact ? 40 : 100)
        .margin({ left: 12 })
        .borderRadius(3)
        .clip(true)
        .backgroundColor($r('app.color.gray200'))
      } else if (this.imageURLs.length >= 1) {
        Image(this.imageURLs[0])
          .width(this.isCompact ? 40 : 100)
          .height(this.isCompact ? 40 : 100)
          .objectFit(ImageFit.Cover)
          .margin({ left: 12 })
          .borderRadius(3)
          .backgroundColor($r('app.color.gray200'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 16,
      right: 16,
      top: this.isCompact ? 10 : 12,
      bottom: this.isCompact ? 10 : 12
    })
  }
}
