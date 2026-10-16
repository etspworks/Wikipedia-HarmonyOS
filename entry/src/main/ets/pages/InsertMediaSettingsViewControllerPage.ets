// Ported from Wikipedia/Code/InsertMediaSettingsViewController.swift (+ InsertMediaSettingsImageView,
// InsertMediaSettingsTextTableViewCell, InsertMediaSettingsButtonView): "Media settings" with back
// and Insert. The chosen image (100 x 100) beside its title (opens the file page) and description,
// then Caption and Alternative text, each a growing text field with its explanation and a Learn
// more link, and Advanced settings. Insert builds the wikitext (prepareWikitext) and returns to the
// editor with it.
import { router } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { InsertMediaSession, INSERT_MEDIA_RESULT_KEY, mediaWikitext, insertImageWikitextAfterTemplates }
  from '../common/InsertMedia';
import { ImageRecSession } from '../common/GrowthTasksService';

@Entry
@Component
struct InsertMediaSettingsViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @State caption: string = InsertMediaSession.settings.caption;
  @State alternativeText: string = InsertMediaSession.settings.alternativeText;
  // fromImageRecommendations: "Add image details" with Next (grey until there is a caption),
  // which goes on to Preview with the image in the lead section
  private fromImageRecommendations: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.fromImageRecommendations = params?.['mode'] === 'imageRecommendation';
  }

  private insert(): void {
    InsertMediaSession.settings.caption = this.caption;
    InsertMediaSession.settings.alternativeText = this.alternativeText;
    const image: string = mediaWikitext(InsertMediaSession.fileTitle, InsertMediaSession.settings);
    if (!this.fromImageRecommendations) {
      AppStorage.setOrCreate<string>(INSERT_MEDIA_RESULT_KEY, image);
      router.back({ url: 'pages/SectionEditorViewControllerPage' });
      return;
    }
    // ExploreViewController.insertMediaSettingsViewControllerDidTapProgress: the image after the
    // lead section's templates, then Preview (section 0)
    let wikitext: string = '';
    try {
      wikitext = insertImageWikitextAfterTemplates(image, ImageRecSession.recommendation?.wikitext ?? '');
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: (e as Error).message });
      return;
    }
    router.pushUrl({ url: 'pages/EditPreviewViewControllerPage', params: { 'host': InsertMediaSession.host,
      'articleTitle': InsertMediaSession.articleTitle, 'wikitext': wikitext, 'mode': 'imageRecommendation' } });
  }

  private open(url: string): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
  }

  // the Suggested edits help page, in the device language
  private learnMoreURL(anchor: string): string {
    const lang: string = i18n.System.getSystemLanguage().split('-')[0];
    return `https://www.mediawiki.org/wiki/Special:MyLanguage/Wikimedia_Apps/iOS_Suggested_edits?uselang=${lang}#${anchor}`;
  }

  @Builder
  textCell(title: Resource, placeholder: Resource, footer: Resource, id: string, value: string,
    onChange: (value: string) => void, learnMoreAnchor: string) {
    Column({ space: 12 }) {
      Text(title)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
      TextArea({ text: value, placeholder: placeholder })
        .id(id)
        .width('100%')
        .fontSize(16)
        .padding(0)
        .borderRadius(0)
        .backgroundColor(Color.Transparent)
        .onChange((v: string) => {
          onChange(v);
        })
      Text(footer)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
      Text($r('app.string.learn_more_title'))
        .id(id + '_learn_more')
        .fontSize(15)
        .fontColor($r('app.color.theme_link'))
        .onClick(() => {
          this.open(this.learnMoreURL(learnMoreAnchor));
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 32, top: 20 })
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_link')])
        }
        .id('media_settings_back')
        .type(ButtonType.Normal)
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })
        Text(this.fromImageRecommendations ? $r('app.string.insert_media_add_image_details_title') :
          $r('app.string.insert_media_media_settings_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Button() {
          Text(this.fromImageRecommendations ? $r('app.string.next_action_title') : $r('app.string.insert_action_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.fromImageRecommendations && this.caption.trim() === '' ?
              $r('app.color.theme_secondary_text') : $r('app.color.theme_link'))
        }
        .id('media_settings_insert')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.insert();
        })
      }
      .width('100%')
      .height(54)
      .padding({ left: 8, right: 12 })

      Scroll() {
        Column() {
          // InsertMediaSettingsImageView
          Row({ space: 12 }) {
            Image(InsertMediaSession.imageURL)
              .width(100)
              .height(100)
              .objectFit(ImageFit.Cover)
              .clip(true)
            Column({ space: 12 }) {
              Text() {
                Span(InsertMediaSession.displayTitle + '  ')
                ImageSpan($r('app.media.mini_external'))
                  .width(14)
                  .height(14)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              }
              .id('media_settings_file_title')
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                if (InsertMediaSession.filePageURL !== '') {
                  this.open(InsertMediaSession.filePageURL);
                }
              })
              if (InsertMediaSession.imageDescription !== '') {
                Text(InsertMediaSession.imageDescription)
                  .fontSize(13)
                  .fontColor($r('app.color.theme_secondary_text'))
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.theme_border'))

          this.textCell($r('app.string.insert_media_caption_title'),
            $r('app.string.insert_media_caption_caption_placeholder'),
            $r('app.string.insert_media_caption_description'), 'media_settings_caption', this.caption,
            (v: string) => {
              this.caption = v;
            }, 'Image_captions')
          this.textCell($r('app.string.insert_media_alternative_text_title'),
            $r('app.string.insert_media_alternative_text_placeholder'),
            $r('app.string.insert_media_alternative_text_description'), 'media_settings_alt', this.alternativeText,
            (v: string) => {
              this.alternativeText = v;
            }, 'Tips_for_creating_alt-text')

          // InsertMediaSettingsButtonView
          Text($r('app.string.advanced_settings_title'))
            .id('media_settings_advanced')
            .width('100%')
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 12, top: 24, bottom: 24 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/InsertMediaAdvancedSettingsViewControllerPage',
                params: { 'screen': 'advanced' } });
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .id('InsertMediaSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
