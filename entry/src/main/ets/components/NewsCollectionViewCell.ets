// comp_news_cell — ported from Wikipedia/Code/NewsCollectionViewCell.swift
// (SideScrollingCollectionViewCell: descriptionLabel = story HTML + horizontally
// scrolling article-preview cards). S5: styled per capture conventions.
import { WMFFeedNewsStory } from '../model/WMFFeedNewsStory';
import { WMFFeedArticlePreview } from '../model/WMFFeedArticlePreview';

@Component
export struct NewsCollectionViewCell {
  @Prop story: WMFFeedNewsStory = new WMFFeedNewsStory();
  onSelectArticle?: (articleTitle: string) => void;

  private plainStory(): string {
    const html: string = this.story.storyHTML ?? '';
    return html.replace(new RegExp('<[^>]*>', 'g'), '');
  }

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

  build() {
    Column() {
      // story HTML rendered as plain text (bold spans dropped; body role)
      Text(this.plainStory())
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
        .lineHeight(24)
      List({ space: 10 }) {
        ForEach(this.story.articlePreviews, (p: WMFFeedArticlePreview) => {
          ListItem() {
            this.previewCard(p)
          }
        }, (p: WMFFeedArticlePreview, index: number) => p.displayTitle + '_' + index)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .height(160)
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
  }
}
