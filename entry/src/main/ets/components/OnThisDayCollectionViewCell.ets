// comp_onthisday_cell — ported from Wikipedia/Code/OnThisDayCollectionViewCell.swift
// (SideScrollingCollectionViewCell + TimelineView: year title, event text, horizontally
// scrolling article previews). S5: styled — blue timeline dot/line, blue year label.
import { WMFFeedOnThisDayEvent } from '../model/WMFFeedOnThisDayEvent';
import { WMFFeedArticlePreview } from '../model/WMFFeedArticlePreview';

@Component
export struct OnThisDayCollectionViewCell {
  @Prop event: WMFFeedOnThisDayEvent = new WMFFeedOnThisDayEvent();
  onSelectArticle?: (articleTitle: string) => void;
  onTap?: () => void;

  @Builder
  previewCard(p: WMFFeedArticlePreview) {
    Column() {
      if (p.thumbnailURL !== null) {
        Image(p.thumbnailURL ?? '')
          .width('100%')
          .height(80)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('app.color.gray200'))
      }
      Text(p.displayTitle)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6, left: 8, right: 8 })
      if (p.wikidataDescription !== null) {
        Text(p.wikidataDescription ?? '')
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2, left: 8, right: 8 })
      }
    }
    .width(150)
    .alignItems(HorizontalAlign.Start)
    .border({ width: 0.5, color: $r('app.color.gray200') })
    .borderRadius(8)
    .clip(true)
    .id('Explore Article Cell')
    .onClick(() => {
      if (this.onSelectArticle !== undefined) {
        this.onSelectArticle(p.displayTitle);
      }
    })
  }

  // TimelineView's dot, drawn over the content column's own left border.
  @Builder
  timelineDot() {
    Circle()
      .width(9)
      .height(9)
      .fill($r('app.color.theme_link'))
  }

  private yearsAgo(): string {
    const year: number = this.event.year ?? 0;
    const delta: number = new Date().getFullYear() - year;
    return delta > 0 ? delta.toString() : '0';
  }

  build() {
    // The timeline line is the CONTENT column's left border, not a sibling Divider. As a
    // sibling it needed a height to stretch to, and every expression of that - layoutWeight
    // on the Divider, height('100%') on its Column - resolves against the parent's max
    // constraint, i.e. the whole viewport, so each event cell grew to a screen tall and the
    // card showed a huge empty gap under every year. A border is drawn on the box the
    // content already sizes, so the line ends exactly where the entry ends.
    Row() {
      Column() {
        if (this.event.year !== null) {
          // OnThisDayViewControllerCell pairs the year with how long ago it was; the port
          // showed the bare year, so the timeline said nothing about distance in time.
          Row({ space: 8 }) {
            Text(String(this.event.year ?? 0))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_link'))
            Text($r('app.string.explore_on_this_day_years_ago', this.yearsAgo()))
              .id('on_this_day_years_ago')
              .fontSize(13)
              .fontColor($r('app.color.theme_secondary_text'))
          }
          .alignItems(VerticalAlign.Center)
        }
        if (this.event.text !== null) {
          Text(this.event.text ?? '')
            .fontSize(15)
            .fontColor($r('app.color.theme_text'))
            .lineHeight(22)
            .margin({ top: 4 })
        }
        List({ space: 10 }) {
          ForEach(this.event.articlePreviews, (p: WMFFeedArticlePreview) => {
            ListItem() {
              this.previewCard(p)
            }
          }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .height(150)
        .width('100%')
        .margin({ top: 10 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, bottom: 4 })
      .border({ width: { left: 1 }, color: $r('app.color.blue300') })
      .overlay(this.timelineDot(), { align: Alignment.TopStart, offset: { x: -4, y: 4 } })
      .onClick(() => {
        if (this.onTap !== undefined) {
          this.onTap();
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }
}
