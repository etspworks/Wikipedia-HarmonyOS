// Ported from Wikipedia/Code/EditLinkViewController.swift (+ .xib): "Edit link" with the plain-X
// close and the prominent checkmark (finishEditing). "Display text" over the editable text
// (link.label ?? link.page), "Link target" over the target article as a compact list cell
// (title, description, thumbnail, up to five lines of extract) that opens Insert link to pick
// another target (searchArticles), and the destructive "Remove link" button.
import { router } from '@kit.ArkUI';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { LINK_WIZARD_RESULT_KEY, LINK_TARGET_RESULT_KEY } from './InsertLinkViewControllerPage';

@Entry
@Component
struct EditLinkViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';

  @State displayText: string = '';
  @State target: string = '';
  @State summary: ArticleSummary | null = null;
  @State isLoading: boolean = true;
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    if (params !== undefined) {
      this.host = params['host'] ?? this.host;
      this.target = params['page'] ?? '';
      const label: string = params['label'] ?? '';
      this.displayText = label !== '' ? label : this.target;
    }
    this.fetchArticle();
  }

  // back from Insert link with another target
  onPageShow(): void {
    const picked: string = AppStorage.get<string>(LINK_TARGET_RESULT_KEY) ?? '';
    if (picked !== '') {
      AppStorage.setOrCreate<string>(LINK_TARGET_RESULT_KEY, '');
      this.target = picked;
      this.fetchArticle();
    }
  }

  private fetchArticle(): void {
    this.isLoading = true;
    this.summary = null;
    ArticleService.fetchSummary(this.host, this.target).then((s: ArticleSummary) => {
      this.summary = s;
      this.isLoading = false;
    }).catch((e: Error) => {
      console.error('editLink: summary failed: ' + e.message);
      this.isLoading = false;
    });
  }

  private finish(result: Record<string, string>): void {
    AppStorage.setOrCreate<string>(LINK_WIZARD_RESULT_KEY, JSON.stringify(result));
    router.back();
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('edit_link_close')
        .type(ButtonType.Normal)
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })
        Text($r('app.string.edit_link_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        // finishEditingButton: WMFLargeCloseButtonConfig(.prominentCheck)
        Button() {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([Color.White])
        }
        .id('edit_link_done')
        .type(ButtonType.Circle)
        .width(36)
        .height(36)
        .backgroundColor($r('app.color.theme_link'))
        .onClick(() => {
          const result: Record<string, string> = { 'action': 'edit', 'page': this.target, 'label': this.displayText };
          this.finish(result);
        })
      }
      .width('100%')
      .height(54)
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column() {
          Text($r('app.string.edit_link_display_text_title'))
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 16, bottom: 6 })
          TextArea({ text: this.displayText })
            .id('edit_link_display_text')
            .width('100%')
            .fontSize(15)
            .borderRadius(0)
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .onChange((value: string) => {
              this.displayText = value;
            })
          Text($r('app.string.edit_link_link_target_title'))
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 24, bottom: 6 })
          // linkTargetContainerView: the article cell, tap to search for another target
          Row({ space: 12 }) {
            if (this.isLoading) {
              LoadingProgress()
                .width(28)
                .height(28)
            } else {
              Column({ space: 4 }) {
                Text((this.summary?.displayTitle ?? this.target).replace(/<[^>]*>/g, ''))
                  .fontSize(17)
                  .fontColor($r('app.color.theme_text'))
                if ((this.summary?.articleDescription ?? '') !== '') {
                  Text(this.summary?.articleDescription ?? '')
                    .fontSize(14)
                    .fontColor($r('app.color.theme_secondary_text'))
                }
                if ((this.summary?.extract ?? '') !== '') {
                  Text(this.summary?.extract ?? '')
                    .fontSize(14)
                    .fontColor($r('app.color.theme_text'))
                    .maxLines(5)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (this.summary !== null && this.summary.thumbnail !== null) {
                Image(this.summary.thumbnail.source)
                  .width(60)
                  .height(60)
                  .borderRadius(4)
                  .objectFit(ImageFit.Cover)
              }
            }
          }
          .id('edit_link_target')
          .width('100%')
          .padding(16)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .onClick(() => {
            router.pushUrl({ url: 'pages/InsertLinkViewControllerPage',
              params: { 'host': this.host, 'mode': 'target', 'searchTerm': this.target } });
          })
          Button($r('app.string.edit_link_remove_link_title'))
            .id('edit_link_remove')
            .type(ButtonType.Normal)
            .width('100%')
            .height(48)
            .fontColor($r('app.color.theme_destructive'))
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .margin({ top: 32 })
            .onClick(() => {
              const result: Record<string, string> = { 'action': 'remove' };
              this.finish(result);
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .id('EditLinkViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }
}
