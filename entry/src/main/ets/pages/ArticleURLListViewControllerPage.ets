// screen_article_u_r_l_list — presentation: page.
// S3 structure from Wikipedia/Code/ArticleURLListViewController.swift
// (ArticleCollectionViewController: nav bar with title, collection of
// ArticleRightAlignedImageCollectionViewCell rows; row tap -> article).
// Rows bound to svc_article summaries (S4 fills; starts empty).
import { BackToExploreFeedButton } from '../components/BackToExploreFeedButton';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ArticleRightAlignedImageCollectionViewCell } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { ArticleSummary, ArticleSummaryImage, ArticleSummaryURLs } from '../model/ArticleSummary';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFFeedArticlePreview } from '../model/WMFFeedArticlePreview';
import { FeedStore, ContentGroupKind } from '../common/FeedStore';
import { Database } from '../common/Database';
import { Prefs } from '../common/Prefs';
import { stripTags } from '../common/WebDocument';
import { WMFContent } from '../model/WMFContent';

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
struct ArticleURLListViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfChromeBg') wmfChromeBg: string = '';

  @State listTitle: string = '';
  @State items: ArticleSummary[] = [];
  @State isLoading: boolean = false;
  private itemsSource: SummaryDataSource = new SummaryDataSource();
  // ArticleURLListViewController(articleURLs:contentGroup:) — the presenter hands over the
  // content group whose previews are the list; Explore routes here for the top-read footer.
  private contentGroupKey: string = '';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.listTitle = params['listTitle'] ?? '';
      this.contentGroupKey = params['contentGroupKey'] ?? '';
    }
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        console.error('article-url-list: load failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('article-url-list: db init failed: ' + e.message);
    });
  }

  private async load(): Promise<void> {
    this.isLoading = true;
    try {
      const group: WMFContentGroup | null = this.contentGroupKey !== ''
        ? await FeedStore.groupForKey(this.contentGroupKey)
        : await FeedStore.newestGroupOfKind(ContentGroupKind.TopRead, true);
      if (group === null) {
        return;
      }
      if (this.listTitle === '') {
        this.listTitle = 'Top read';
      }
      // The whole list, not the card's five-row preview: the feed stores it as the group's
      // full content (topRead.articlePreviews).
      const full: WMFContent | null = group.key !== null ? await FeedStore.fullContentForGroup(group.key) : null;
      const json: string | null = full?.objectJSON ?? group.contentPreviewJSON;
      if (json === null || json === '') {
        return;
      }
      // The previews already carry title, description and thumbnail. Re-fetching every row's
      // page_summary one by one replaced the plain titles with its HTML displaytitle
      // ("<span lang=...") and kept the screen busy for the length of ~50 requests.
      // a Because you read card stored the article it is based on first: the list is only
      // the related articles
      const previews: WMFFeedArticlePreview[] = (JSON.parse(json) as WMFFeedArticlePreview[])
        .filter((p: WMFFeedArticlePreview): boolean =>
          group.contentGroupKindInteger !== ContentGroupKind.RelatedPages || p.articleURL !== group.articleURLString);
      this.setItems(previews.map((p: WMFFeedArticlePreview) => this.summaryFromPreview(p)));
    } finally {
      this.isLoading = false;
    }
  }

  private setItems(items: ArticleSummary[]): void {
    this.items = items;
    this.itemsSource.reload(items);
  }

  private summaryFromPreview(p: WMFFeedArticlePreview): ArticleSummary {
    const out = new ArticleSummary();
    out.title = p.displayTitle;
    out.displayTitle = stripTags(p.displayTitleHTML !== '' ? p.displayTitleHTML : p.displayTitle);
    const urls: ArticleSummaryURLs = new ArticleSummaryURLs();
    urls.page = p.articleURL;
    out.contentURLs.desktop = urls;
    out.articleDescription = p.wikidataDescription;
    out.extract = p.snippet;
    if (p.thumbnailURL !== null) {
      const thumb = new ArticleSummaryImage();
      thumb.source = p.thumbnailURL;
      out.thumbnail = thumb;
    }
    return out;
  }

  build() {
    Column() {
      // nav bar (WMFNavigationBarTitleConfig; back from push navigation)
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
        // iOS inline nav title: centered in the bar (mapping-tables §7)
        Text(this.listTitle)
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
            ArticleRightAlignedImageCollectionViewCell({
              title: a.displayTitle !== null ? a.displayTitle : (a.title !== null ? a.title : ''),
              description: a.articleDescription !== null ? a.articleDescription : '',
              imageURL: a.thumbnail !== null ? a.thumbnail.source : '',
              onTap: (): void => {
                this.openArticle(a);
              }
            })
          }
          // list row — shared id, index-resolved by replay (Rule 12 exception)
          .id('article_url_list_itemroot')
        }, (a: ArticleSummary) => a.title !== null ? a.title : '')
        // footerButtonTitle: the last row of the detail list
        ListItem() {
          BackToExploreFeedButton()
        }
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
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    }
    .id('ArticleURLListViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // 'articleKey' opens the card's own wiki, as Explore's cards do.
  private openArticle(a: ArticleSummary): void {
    const params: Record<string, string> = { 'articleTitle': a.title ?? '', 'articleKey': a.articleURL ?? '' };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
