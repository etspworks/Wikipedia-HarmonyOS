// screen_article_popover — presentation: popup, hosted by screen_places
// (.bindPopup in PlacesViewControllerPage). NOT a routed page.
// S3 structure from Wikipedia/Code/ArticlePopoverViewController.swift:
// articleSummaryView (titleLabel + subtitleLabel + descriptionLabel, tap = read)
// over buttonStackView (saveButton | shareButton | readButton).
import { router } from '@kit.ArkUI';

@Component
export struct ArticlePopoverView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPopoverBg') wmfPopoverBg: string = '';

  @Prop articleTitle: string = '';
  @Prop subtitle: string = '';
  @Prop wikidataDescription: string = '';
  @Prop isSaved: boolean = false;
  // wmf_localizedString(forDistance:) from the reader's position; empty hides the line.
  @Prop distanceText: string = '';
  onRead?: () => void;
  onSave?: () => void;
  onShare?: () => void;

  build() {
    Column() {
      // S5 (no device capture — styled from the source's own theme:
      // titleLabel = georgiaTitle3 primaryText, subtitle/description = secondaryText,
      // popover surface = theme_popover_background, actions tinted theme_link).
      // articleSummaryView — tapping it performs the read action (source tap GR)
      Column({ space: 2 }) {
        Text(this.articleTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.wikidataDescription !== '') {
          Text(this.wikidataDescription)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.distanceText !== '') {
          Text(this.distanceText)
            .id('popover_distance')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
        }
      }
      .id('popover_summary')
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.read();
      })

      Divider()
        .strokeWidth(1)
        .color($r('app.color.gray200'))

      // buttonStackView
      Row() {
        Button() {
          Row({ space: 6 }) {
            Image(this.isSaved ? $r('app.media.save_filled') : $r('app.media.save'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
            Text(this.isSaved ? $r('app.string.action_saved') : $r('app.string.action_save'))
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
          }
          .alignItems(VerticalAlign.Center)
        }
          .id('popover_save')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            if (this.onSave !== undefined) {
              this.onSave();
            }
          })
        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.places_share'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
            Text($r('app.string.action_share'))
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
          }
          .alignItems(VerticalAlign.Center)
        }
          .id('popover_share')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            if (this.onShare !== undefined) {
              this.onShare();
            }
          })
        Button() {
          Row({ space: 6 }) {
            // The source's read button trails its chevron: "Read >".
            Text($r('app.string.action_read'))
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
            Image($r('app.media.places_more'))
              .width(12)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
          .alignItems(VerticalAlign.Center)
        }
          .id('popover_read')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(48)
          .layoutWeight(1)
          .onClick(() => {
            this.read();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .id('ArticlePopoverViewController')
    .width('100%')
    .backgroundColor((this.wmfPopoverBg !== '' ? this.wmfPopoverBg : $r('app.color.theme_popover_background')))
    .borderRadius(10)
    .clip(true)
  }

  private read(): void {
    if (this.onRead !== undefined) {
      this.onRead();
      return;
    }
    this.openArticle(this.articleTitle);
  }

  private openArticle(articleTitle: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
