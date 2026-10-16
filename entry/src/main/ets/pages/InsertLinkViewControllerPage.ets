// Ported from Wikipedia/Code/InsertLinkViewController.swift: "Insert link" with a plain-X close
// over the search bar (Search Wikipedia, focused, pre-filled with the selected text) and
// SearchResultsViewController without the language bar. Tapping a result hands its title back
// (insertLinkViewController(_:didInsertLinkFor:withLabel:)). Edit link also opens it to pick a
// new link target (EditLinkViewController.searchArticles), with mode 'target'.
import { router } from '@kit.ArkUI';
import { SearchService, WMFSearchResults } from '../common/SearchService';
import { MWKSearchResult } from '../model/MWKSearchResult';

// the result the editor (or Edit link) picks up when it shows again
export const LINK_WIZARD_RESULT_KEY: string = 'wmfLinkWizardResult';
export const LINK_TARGET_RESULT_KEY: string = 'wmfLinkTargetResult';

@Entry
@Component
struct InsertLinkViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @State term: string = '';
  @State results: MWKSearchResult[] = [];
  @State isSearching: boolean = false;
  private host: string = 'en.wikipedia.org';
  private mode: string = 'insert';
  private searchTimer: number = -1;
  private generation: number = 0;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    if (params !== undefined) {
      this.host = params['host'] ?? this.host;
      this.mode = params['mode'] ?? 'insert';
      this.term = params['searchTerm'] ?? '';
    }
    if (this.term !== '') {
      this.search(this.term);
    }
  }

  private search(term: string): void {
    const generation: number = ++this.generation;
    if (term.trim() === '') {
      this.results = [];
      this.isSearching = false;
      return;
    }
    this.isSearching = true;
    SearchService.prefixSearch(this.host, term, SearchService.maxResultLimit).then((r: WMFSearchResults) => {
      if (generation === this.generation) {
        this.results = r.results;
        this.isSearching = false;
      }
    }).catch((e: Error) => {
      console.error('insertLink: search failed: ' + e.message);
      this.isSearching = false;
    });
  }

  private termChanged(value: string): void {
    this.term = value;
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1;
      this.search(value);
    }, 300);
  }

  // articleTappedAction -> didInsertLinkFor page
  private pick(result: MWKSearchResult): void {
    const title: string = result.title ?? result.displayTitle ?? '';
    if (this.mode === 'target') {
      AppStorage.setOrCreate<string>(LINK_TARGET_RESULT_KEY, title);
    } else {
      const result: Record<string, string> = { 'action': 'insert', 'page': title };
      AppStorage.setOrCreate<string>(LINK_WIZARD_RESULT_KEY, JSON.stringify(result));
    }
    router.back();
  }

  build() {
    Column() {
      Stack() {
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_text')])
          }
          .id('insert_link_close')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')
        .padding({ left: 8 })
        Text($r('app.string.insert_link_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(54)

      Search({ value: this.term, placeholder: $r('app.string.search_field_placeholder_text') })
        .id('insert_link_search')
        .width('100%')
        .height(40)
        .margin({ left: 16, right: 16, bottom: 8 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.termChanged(value);
        })

      if (this.isSearching && this.results.length === 0) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 24 })
      }
      List() {
        ForEach(this.results, (result: MWKSearchResult) => {
          ListItem() {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text(result.displayTitle ?? result.title ?? '')
                  .fontSize(17)
                  .fontColor($r('app.color.theme_text'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if ((result.wikidataDescription ?? '') !== '') {
                  Text(result.wikidataDescription ?? '')
                    .fontSize(14)
                    .fontColor($r('app.color.theme_secondary_text'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if ((result.thumbnailURL ?? '') !== '') {
                Image(result.thumbnailURL ?? '')
                  .width(40)
                  .height(40)
                  .borderRadius(4)
                  .objectFit(ImageFit.Cover)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          }
          .id('insert_link_result')
          .onClick(() => {
            this.pick(result);
          })
        }, (result: MWKSearchResult) => String(result.articleID) + (result.title ?? ''))
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 1, color: $r('app.color.theme_border'), startMargin: 16 })
      .scrollBar(BarState.Off)
    }
    .id('InsertLinkViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
