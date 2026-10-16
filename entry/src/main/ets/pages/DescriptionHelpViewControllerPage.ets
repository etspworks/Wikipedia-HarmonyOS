// Ported from Wikipedia/Code/DescriptionHelpViewController.swift (+ .xib), the "Learn more" of
// the Wikidata description editor (WikidataDescriptionController.learnMoreViewControllerWithTheme):
// "Article description help" with the plain-X close at the trailing edge, over midBackground:
// About, Tips for creating descriptions with the two examples (the example on the
// descriptionBackground, its explanation below), More information, and the About Wikidata and
// Wikidata guide rows between dividers, which open those pages.
import { router } from '@kit.ArkUI';
import { topSafeInset } from '../common/SafeArea';

@Entry
@Component
struct DescriptionHelpViewControllerPage {
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  @StorageProp('WMFAppThemeName') themeName: string = '';

  // Theme.descriptionBackground
  private exampleBackground(): string {
    if (this.themeName.startsWith('dark') || this.themeName.startsWith('black')) {
      return '#6699FF';
    }
    return this.themeName.startsWith('sepia') ? '#FF9500' : '#FFCC33';
  }

  private open(url: string): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
  }

  @Builder
  heading(text: Resource) {
    Text(text)
      .width('100%')
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.theme_secondary_text'))
      .margin({ top: 24 })
  }

  @Builder
  body(text: Resource) {
    Text(text)
      .width('100%')
      .fontSize(16)
      .lineHeight(22)
      .fontColor($r('app.color.theme_text'))
      .margin({ top: 8 })
  }

  @Builder
  example(title: Resource, description: Resource) {
    Column({ space: 4 }) {
      Text(title)
        .width('100%')
        .fontSize(17)
        .fontStyle(FontStyle.Italic)
        .fontColor($r('app.color.theme_text'))
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
        .backgroundColor(this.exampleBackground())
      Text(description)
        .width('100%')
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
    }
    .margin({ top: 12 })
  }

  @Builder
  linkRow(icon: Resource, text: Resource, id: string, url: string) {
    Column() {
      Divider()
        .strokeWidth(1)
        .color($r('app.color.theme_border'))
      Row({ space: 10 }) {
        Image(icon)
          .width(27)
          .height(20)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.theme_text'))
        Text(text)
          .layoutWeight(1)
          .fontSize(16)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
    }
    .id(id)
    .onClick(() => {
      this.open(url);
    })
  }

  build() {
    Column() {
      Stack() {
        Text($r('app.string.description_help_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Blank()
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_text')])
          }
          .id('description_help_close')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
        }
        .width('100%')
        .padding({ right: 8 })
      }
      .width('100%')
      .height(54)

      Scroll() {
        Column() {
          this.heading($r('app.string.description_help_about_title'))
          this.body($r('app.string.description_help_about_description'))
          this.heading($r('app.string.description_help_tips_title'))
          this.body($r('app.string.description_help_tips_description'))
          this.body($r('app.string.description_help_tips_for_example'))
          this.example($r('app.string.description_help_tips_example_title_one'),
            $r('app.string.description_help_tips_example_description_one'))
          this.example($r('app.string.description_help_tips_example_title_two'),
            $r('app.string.description_help_tips_example_description_two'))
          this.heading($r('app.string.description_help_more_info_title'))
          this.body($r('app.string.description_help_more_info_description'))
          Column() {
            this.linkRow($r('app.media.description_barcode'), $r('app.string.description_help_about_wikidata'),
              'description_help_about_wikidata', 'https://m.wikidata.org/wiki/Wikidata:Introduction')
            this.linkRow($r('app.media.description_info'), $r('app.string.description_help_wikidata_guide'),
              'description_help_wikidata_guide',
              'https://m.wikidata.org/wiki/Help:Description#Guidelines_for_descriptions_in_English')
            Divider()
              .strokeWidth(1)
              .color($r('app.color.theme_border'))
          }
          .margin({ top: 24 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('DescriptionHelpViewController')
    .width('100%')
    .height('100%')
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
