// screen_talk_page_archives — presentation: page, pushed from the talk page's overflow menu.
// Ported from Wikipedia/Code/TalkPageArchivesViewController.swift + TalkPageArchivesView.swift
// + DisclosureButton.swift: "Archives" in the navigation bar over a list of the talk page's
// archive subpages (semibold callout title, chevron, divider), loaded 30 first then 10 more
// whenever the last row appears. No archives shows "No archived pages found."; a failed first
// load shows the generic error text. A row opens that archive as a talk page.
import { router } from '@kit.ArkUI';
import { TalkPageService, TalkPageArchive, TalkPageArchivesPage } from '../common/TalkPageService';

@Entry
@Component
struct TalkPageArchivesViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @State items: TalkPageArchive[] = [];
  @State didFetchFirstPage: boolean = false;
  @State firstPageFailed: boolean = false;
  private talkPageTitle: string = '';
  private languageCode: string = 'en';
  private nextOffset: number = -1;
  private loadingNext: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.talkPageTitle = params['talkPageTitle'] ?? '';
      this.languageCode = params['languageCode'] ?? 'en';
    }
    TalkPageService.fetchArchives(this.host(), this.talkPageTitle, -1).then((page: TalkPageArchivesPage) => {
      this.didFetchFirstPage = true;
      this.append(page);
    }).catch((e: Error) => {
      console.error('archives: first page failed: ' + e.message);
      this.didFetchFirstPage = true;
      this.firstPageFailed = true;
    });
  }

  private host(): string {
    return this.languageCode + '.wikipedia.org';
  }

  // processResponse: drop the talk page itself and archives already listed
  private append(page: TalkPageArchivesPage): void {
    this.nextOffset = page.nextOffset;
    const fresh: TalkPageArchive[] = page.items.filter((a: TalkPageArchive) =>
      a.title !== this.talkPageTitle && this.items.findIndex((b: TalkPageArchive) => b.pageID === a.pageID) < 0);
    this.items = this.items.concat(fresh);
  }

  // the last row appearing fetches the next page
  private fetchNextPage(): void {
    if (this.nextOffset < 0 || this.loadingNext) {
      return;
    }
    this.loadingNext = true;
    TalkPageService.fetchArchives(this.host(), this.talkPageTitle, this.nextOffset).then((page: TalkPageArchivesPage) => {
      this.loadingNext = false;
      this.append(page);
    }).catch((e: Error) => {
      this.loadingNext = false;
      console.error('archives: next page failed: ' + e.message);
    });
  }

  // TalkPageArchivesItem.description: displayTitle without its markup
  private static plain(html: string): string {
    return html.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, '\'').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
  }

  private openArchive(item: TalkPageArchive): void {
    const params: Record<string, string> = { 'talkPageTitle': item.title, 'languageCode': this.languageCode };
    router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params }).catch((e: Error) => {
      console.error('archives: talk page route failed: ' + e.message);
    });
  }

  @Builder
  infoText(text: Resource) {
    Text(text)
      .width('100%')
      .textAlign(TextAlign.Center)
      .fontSize(16)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 30, bottom: 30 })
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('BackButton')
          .type(ButtonType.Normal)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .width(44)
          .height(44)
          .borderRadius(22)
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.back();
          })
        Text($r('app.string.talk_pages_archives_view_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        // balances the back button so the title stays centred
        Blank()
          .width(44)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (!this.didFetchFirstPage) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color($r('app.color.theme_secondary_text'))
          .margin({ top: 30 })
      } else if (this.firstPageFailed) {
        this.infoText($r('app.string.fetcher_error_generic'))
      } else if (this.items.length === 0) {
        this.infoText($r('app.string.talk_pages_archives_empty_title'))
      } else {
        List() {
          ForEach(this.items, (item: TalkPageArchive, i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Text(TalkPageArchivesViewControllerPage.plain(item.displayTitle))
                    .layoutWeight(1)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.theme_text'))
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(13)
                    .fontColor([$r('app.color.theme_secondary_text')])
                    .margin({ left: 12 })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                Divider()
                  .strokeWidth(1)
                  .color($r('app.color.theme_mid_background'))
              }
              .id('talk_archive_itemroot')
              .onClick(() => {
                this.openArchive(item);
              })
              .onAppear(() => {
                if (i === this.items.length - 1) {
                  this.fetchNextPage();
                }
              })
            }
          }, (item: TalkPageArchive) => item.pageID.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .id('TalkPageArchivesViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
