// Ported from Wikipedia/Code/EditSaveViewController.swift as the image-recommendation flow uses
// it (ExploreViewController.editPreviewViewControllerDidTapNext): "Save changes" with back and
// Publish; "Add an edit summary" over the summary field and the canned summaries Added image /
// Added image and caption; the minor-edit and watch switches with their Learn more links; the
// licence text. Publish (WikiTextSectionUploader) saves section 0 with the app-suggestededit and
// app-image-add-top tags, sends the accepted feedback with the new revision and returns to Add
// image, which loads the next recommendation and says the edit was published.
import { router, LengthMetrics } from '@kit.ArkUI';
import { EditService } from '../common/EditService';
import { GrowthTasksService, ImageRecSession, IMAGE_REC_PUBLISHED_KEY } from '../common/GrowthTasksService';
import { InsertMediaSession } from '../common/InsertMedia';

const TERMS_URL: string = 'https://foundation.wikimedia.org/wiki/Terms_of_Use';
const CC_BY_SA_URL: string = 'https://creativecommons.org/licenses/by-sa/4.0/';
const GFDL_URL: string = 'https://www.gnu.org/licenses/fdl.html';

@Entry
@Component
struct EditSaveViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @State summary: string = '';
  @State isMinor: boolean = false;
  @State isWatched: boolean = false;
  @State isPublishing: boolean = false;
  private host: string = 'en.wikipedia.org';
  private articleTitle: string = '';
  private wikitext: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.host = params?.['host'] ?? this.host;
    this.articleTitle = params?.['articleTitle'] ?? '';
    this.wikitext = params?.['wikitext'] ?? '';
  }

  private open(url: string): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
  }

  // wikitext-upload-save-terms-and-licenses-ccsa4: $1..$2 terms, $3..$4 CC BY-SA, $5..$6 GFDL
  private licenseParts(): string[] {
    try {
      return getContext(this).resourceManager
        .getStringSync($r('app.string.wikitext_upload_save_terms_and_licenses_ccsa4').id).split(/\\?\$\d/);
    } catch (e) {
      return [];
    }
  }

  private publish(): void {
    if (this.isPublishing) {
      return;
    }
    this.isPublishing = true;
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.wikitext_upload_save') });
    const rec = ImageRecSession.recommendation;
    EditService.publishSection(this.host, this.articleTitle, 0, this.wikitext, this.summary,
      'app-suggestededit,app-image-add-top', this.isMinor, this.isWatched).then((revId: number) => {
      if (rec !== null) {
        const caption: string = InsertMediaSession.settings.caption.trim();
        GrowthTasksService.sendFeedback(this.host, rec, true, [], caption === '' ? null : caption, revId)
          .catch((e: Error) => {
            console.error('editSave: feedback failed: ' + e.message);
          });
      }
      AppStorage.setOrCreate<boolean>(IMAGE_REC_PUBLISHED_KEY, true);
      router.back({ url: 'pages/WMFImageRecommendationsViewControllerPage' });
    }).catch((e: Error) => {
      this.isPublishing = false;
      this.getUIContext().getPromptAction().showToast({ message: e.message });
    });
  }

  @Builder
  chip(title: Resource, id: string) {
    Text(title)
      .id(id)
      .fontSize(15)
      .fontColor($r('app.color.theme_link'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .border({ width: 1, color: $r('app.color.theme_link'), radius: 16 })
      .onClick(() => {
        this.summary = getContext(this).resourceManager.getStringSync(title.id);
      })
  }

  @Builder
  toggleRow(title: Resource, learnMore: Resource, url: string, id: string, isOn: boolean,
    onChange: (on: boolean) => void) {
    Column({ space: 4 }) {
      Row() {
        Text(title)
          .layoutWeight(1)
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
        Toggle({ type: ToggleType.Switch, isOn: isOn })
          .id(id)
          .onChange((on: boolean) => {
            onChange(on);
          })
      }
      .width('100%')
      Text(learnMore)
        .fontSize(15)
        .fontColor($r('app.color.theme_link'))
        .onClick(() => {
          this.open(url);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 16 })
  }

  build() {
    Column() {
      Stack() {
        Text($r('app.string.wikitext_preview_save_changes_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_link')])
          }
          .id('edit_save_back')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
          Blank()
          Button() {
            Text($r('app.string.button_publish'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isPublishing ? $r('app.color.theme_secondary_text') : $r('app.color.theme_link'))
          }
          .id('edit_save_publish')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .enabled(!this.isPublishing)
          .onClick(() => {
            this.publish();
          })
        }
        .width('100%')
        .padding({ left: 8, right: 12 })
      }
      .width('100%')
      .height(54)

      Scroll() {
        Column() {
          Text($r('app.string.edit_summary_add_summary_text'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
          TextInput({ text: $$this.summary, placeholder: $r('app.string.edit_summary_placeholder_text') })
            .id('edit_save_summary')
            .width('100%')
            .fontSize(17)
            .margin({ top: 8 })
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            this.chip($r('app.string.edit_summary_choice_added_image'), 'edit_save_chip_image')
            this.chip($r('app.string.edit_summary_choice_added_image_and_caption'), 'edit_save_chip_image_caption')
          }
          .width('100%')
          .margin({ top: 12 })
          this.toggleRow($r('app.string.edit_minor_text'), $r('app.string.edit_minor_learn_more_text'),
            'https://www.mediawiki.org/wiki/Special:MyLanguage/Help:Minor_edit', 'edit_save_minor', this.isMinor,
            (on: boolean) => {
              this.isMinor = on;
            })
          this.toggleRow($r('app.string.edit_watch_this_page_text'), $r('app.string.edit_watch_list_learn_more_text'),
            'https://www.mediawiki.org/wiki/Help:Watching_pages', 'edit_save_watch', this.isWatched,
            (on: boolean) => {
              this.isWatched = on;
            })
          if (this.licenseParts().length >= 7) {
            Text() {
              Span(this.licenseParts()[0])
              Span(this.licenseParts()[1]).fontColor($r('app.color.theme_link')).onClick(() => {
                this.open(TERMS_URL);
              })
              Span(this.licenseParts()[2])
              Span(this.licenseParts()[3]).fontColor($r('app.color.theme_link')).onClick(() => {
                this.open(CC_BY_SA_URL);
              })
              Span(this.licenseParts()[4])
              Span(this.licenseParts()[5]).fontColor($r('app.color.theme_link')).onClick(() => {
                this.open(GFDL_URL);
              })
              Span(this.licenseParts()[6])
            }
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 24 })
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .id('EditSaveViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
