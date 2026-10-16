// screen_disambiguation_pages — presentation: page. UNCAPTURED; structure from source.
// Wikipedia/Code/DisambiguationPagesViewController.swift (ArticleFetchedResultsViewController):
// nav bar titled "Similar pages", article rows (title + description + thumbnail),
// row tap -> article. Rows bound to page_summary batch via svc_article (S4 fills).
// Plan declares no row component for this screen — rows are inline.
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ArticleSummary } from '../model/ArticleSummary';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { ArticleService } from '../common/ArticleService';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs } from '../common/Prefs';

class SummaryDataSource implements IDataSource {
  private items: ArticleSummary[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): ArticleSummary {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: ArticleSummary[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct DisambiguationPagesViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfChromeBg') wmfChromeBg: string = '';

  @State items: ArticleSummary[] = [];
  @State isLoading: boolean = false;
  private itemsSource: SummaryDataSource = new SummaryDataSource();
  // init(with URLs:siteURL:) — the presenting article hands over the disambiguation
  // titles; the article footer's "Similar pages" hands over its own title instead.
  private titles: string[] = [];
  private articleTitle: string = '';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      const titles: string = params['titles'] ?? '';
      if (titles !== '') {
        this.titles = titles.split('|');
      }
      this.articleTitle = params['articleTitle'] ?? '';
    }
    this.load().catch((e: Error) => {
      console.error('disambiguation: load failed: ' + e.message);
    });
  }

  // updateOrCreateArticleSummariesForArticles(withKeys:) — one page_summary per title.
  private async load(): Promise<void> {
    this.isLoading = true;
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      const host: string = lang.languageCode + '.wikipedia.org';
      if (this.titles.length === 0) {
        if (this.articleTitle === '') {
          return;
        }
        this.setItems(await ArticleService.fetchRelatedArticles(host, this.articleTitle, 10));
        return;
      }
      const out: ArticleSummary[] = [];
      for (const title of this.titles) {
        try {
          out.push(await ArticleService.fetchSummary(host, title));
        } catch (e) {
          console.error('disambiguation: summary failed for ' + title);
        }
      }
      this.setItems(out);
    } finally {
      this.isLoading = false;
    }
  }

  private setItems(items: ArticleSummary[]): void {
    this.items = items;
    this.itemsSource.reload(items);
  }

  build() {
    Column() {
      // S5 (uncaptured — styled from the source theme + the app style baseline):
      // iOS inline nav title centered, right-aligned 60pt thumbnail rows on paper.
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
          .id('BackButton')
          .accessibilityText('Back')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            router.back();
          })
        Text('Similar pages')
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .padding({ right: 44 })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4, right: 4 })
      .backgroundColor((this.wmfChromeBg !== '' ? this.wmfChromeBg : $r('app.color.theme_chrome_background')))
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      List() {
        LazyForEach(this.itemsSource, (a: ArticleSummary) => {
          ListItem() {
            Row({ space: 12 }) {
              Column({ space: 2 }) {
                Text(a.displayTitle !== null ? a.displayTitle : (a.title !== null ? a.title : ''))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.theme_text'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (a.articleDescription !== null && a.articleDescription !== '') {
                  Text(a.articleDescription)
                    .fontSize(15)
                    .fontColor($r('app.color.theme_secondary_text'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (a.thumbnail !== null) {
                Image(a.thumbnail.source)
                  .width(60)
                  .height(60)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(3)
                  .backgroundColor($r('app.color.gray200'))
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          // list row — shared id, index-resolved by replay (Rule 12 exception)
          .id('disambiguation_itemroot')
          .onClick(() => {
            this.openArticle(a.title !== null ? a.title : '');
          })
        }, (a: ArticleSummary) => a.title !== null ? a.title : '')
      }
      .layoutWeight(1)
      .cachedCount(5)
      .scrollBar(BarState.Off)
      .divider({
        strokeWidth: 1,
        color: $r('app.color.gray200'),
        startMargin: 16,
        endMargin: 0
      })
    }
    .id('DisambiguationPagesViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private openArticle(articleTitle: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
