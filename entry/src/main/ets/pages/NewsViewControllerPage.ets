// screen_news — presentation: page.
// S3 structure from Wikipedia/Code/NewsViewController.swift
// (ColumnarCollectionViewController: nav bar titled "In the news"; sections = stories.count + 1,
// section 0 empty, each later section = NewsCollectionViewHeader (date label) + one
// NewsCollectionViewCell). Story list bound to svc_feed (S4 wires the load; starts empty).
import { BackToExploreFeedButton } from '../components/BackToExploreFeedButton';
import { router } from '@kit.ArkUI';
import { NewsCollectionViewCell } from '../components/NewsCollectionViewCell';
import { WMFFeedNewsStory } from '../model/WMFFeedNewsStory';
import { WMFFeedDayResponse } from '../model/WMFFeedDayResponse';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFContent } from '../model/WMFContent';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { FeedService } from '../common/FeedService';
import { FeedStore, ContentGroupKind } from '../common/FeedStore';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { common } from '@kit.AbilityKit';
import { NAV_TEXT_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// NewsViewController.headerDateFormatter — setLocalizedDateFormatFromTemplate("EEEEMMMMd"):
// weekday + month name + day number, resolved against the current year
// (combineStoryDateWithCurrentYear).
const WEEKDAY_NAMES: string[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday'];
const MONTH_NAMES: string[] = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

class NewsStoryDataSource implements IDataSource {
  private items: WMFFeedNewsStory[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): WMFFeedNewsStory {
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

  reload(items: WMFFeedNewsStory[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct NewsViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // stories: [WMFFeedNewsStory] — svc_feed (feed_featured "news"); S4 loads it.
  @State items: WMFFeedNewsStory[] = [];
  // CollectionViewHeader subtitle — WMFContentGroup.headerSubTitle for .news:
  // "From %1$@ Wikipedia" with the site language (WMFContentGroup+WMFFeedContentDisplaying.m).
  @State headerSubtitle: string = '';
  // load status — the source shows the list only once the feed content group resolved.
  @State loading: boolean = true;
  @State loadFailed: boolean = false;
  private itemsSource: NewsStoryDataSource = new NewsStoryDataSource();

  aboutToAppear(): void {
    this.load();
  }

  // NewsViewController is initialized with `stories` from the feed content group Explore
  // persisted (WMFFeedContentSource "news"); the group's fullContent carries the full list,
  // and a cold entry falls back to the live feed_featured fetch (svc_feed).
  private async load(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    // Every read below (the store AND LanguageStore.appLanguage) goes through the RDB store,
    // so the store has to be open before any of them — a cold deep-link into this page has
    // no Explore ahead of it to have opened it.
    try {
      await Database.init(getContext(this) as common.UIAbilityContext);
    } catch (e) {
      console.error('news: database init failed: ' + this.describeError(e));
      this.loading = false;
      this.loadFailed = true;
      return;
    }
    let stories: WMFFeedNewsStory[] = await this.storedStories();
    if (stories.length === 0) {
      stories = await this.fetchedStories();
    }
    this.loading = false;
    this.items = stories;
    this.itemsSource.reload(stories);
    await this.applyHeaderSubtitle();
  }

  // Renders the caught value diagnosable in hilog: message + stack for Errors,
  // String(e) otherwise (a throw is not guaranteed to be an Error).
  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message + (e.stack !== undefined ? ' | ' + e.stack : '');
    }
    return String(e);
  }

  private async applyHeaderSubtitle(): Promise<void> {
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.headerSubtitle = lang.localizedName === '' ?
        'From Wikipedia' : 'From ' + lang.localizedName + ' Wikipedia';
    } catch (e) {
      this.headerSubtitle = 'From Wikipedia';
    }
  }

  private async storedStories(): Promise<WMFFeedNewsStory[]> {
    try {
      const group: WMFContentGroup | null =
        await FeedStore.newestGroupOfKind(ContentGroupKind.News, true);
      if (group === null) {
        return [];
      }
      const key: string = group.key ?? '';
      const content: WMFContent | null =
        key === '' ? null : await FeedStore.fullContentForGroup(key);
      const json: string = content === null ?
        (group.contentPreviewJSON ?? '') : (content.objectJSON ?? '');
      if (json === '') {
        return [];
      }
      return JSON.parse(json) as WMFFeedNewsStory[];
    } catch (e) {
      console.error('news: stored stories unavailable: ' + this.describeError(e));
      return [];
    }
  }

  private async fetchedStories(): Promise<WMFFeedNewsStory[]> {
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      const feed: WMFFeedDayResponse =
        await FeedService.fetchTodayFeed(lang.languageCode + '.wikipedia.org');
      return feed.newsStories;
    } catch (e) {
      console.error('news: feed fetch failed: ' + this.describeError(e));
      this.loadFailed = true;
      return [];
    }
  }

  // NewsViewController.headerTitle(for:) — the story's month/day, one header per section.
  private headerTitle(story: WMFFeedNewsStory): string {
    const raw: string = story.midnightUTCMonthAndDay ?? '';
    if (raw === '') {
      return '';
    }
    const parts: string[] = raw.trim().split(' ');
    if (parts.length < 2) {
      return raw;
    }
    const month: number = MONTH_NAMES.indexOf(parts[0]);
    const day: number = Number.parseInt(parts[1], 10);
    if (month < 0 || Number.isNaN(day)) {
      return raw;
    }
    const date = new Date(new Date().getFullYear(), month, day);
    return WEEKDAY_NAMES[date.getDay()] + ', ' + MONTH_NAMES[month] + ' ' + String(day);
  }

  // CollectionViewHeader (style .detail) — headerTitle 34 bold + headerSubtitle 15
  // secondary, 5pt apart; block [0,116]-[0,224] in capture S0341.
  @Builder
  detailHeader() {
    Column() {
      Text('In the news')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
      if (this.headerSubtitle !== '') {
        Text(this.headerSubtitle)
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .width('100%')
          .margin({ top: 5 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 41 })
  }

  @Builder
  storySection(story: WMFFeedNewsStory) {
    Column() {
      // NewsCollectionViewHeader — single date label, WMFFont .boldSubheadline / primaryText
      if (this.headerTitle(story) !== '') {
        Text(this.headerTitle(story))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
          .width('100%')
          .padding({ left: 16, right: 16, top: 19, bottom: 20 })
      }
      NewsCollectionViewCell({
        story: story,
        onSelectArticle: (articleTitle: string): void => {
          this.openArticle(articleTitle);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // interItemSpacing 22 between sections (ColumnarCollectionViewLayoutMetrics)
    .padding({ bottom: 22 })
  }

  // Load / empty / error visuals for the svc_feed-bound story list. The source keeps the
  // detail header visible and only the content region changes.
  @Builder
  statusBlock() {
    Column() {
      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color($r('app.color.theme_secondary_text'))
      } else {
        Text(this.loadFailed ?
          'The news could not be loaded. Check your connection and try again.' :
          'No news stories available.')
          .fontSize(15)
          .lineHeight(21)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 40, bottom: 40 })
    .justifyContent(FlexAlign.Center)
  }

  // The source's back button returns to the Explore feed (capture BackButton.ui.json). A
  // deep-linked cold start has nothing under this page, so a bare router.back() would end the
  // ability instead of landing there.
  private goBack(): void {
    if (router.getLength() === '1') {
      router.replaceUrl({ url: 'pages/ExploreViewControllerPage' })
        .catch((e: Error) => {
          console.error('back to Explore failed: ' + e.message);
        });
      return;
    }
    router.back();
  }

  build() {
    Column() {
      // WMFNavigationBarTitleConfig(title:, alignment: .hidden) — the title lives on the
      // back button (chevron + title), the bar itself is empty (capture S0341: [16,62]-[155,106]).
      Row() {
        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
            Text('In the news')
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.goBack();
              })
          }
        }
          .id('BackButton')
          .accessibilityText('Back')
          .attributeModifier(NAV_TEXT_BUTTON)
          .onClick(() => {
            this.goBack();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      List() {
        // section 0 — CollectionViewHeader (detail style)
        ListItem() {
          this.detailHeader()
        }

        if (this.loading || this.items.length === 0) {
          ListItem() {
            this.statusBlock()
          }
        }

        LazyForEach(this.itemsSource, (story: WMFFeedNewsStory) => {
          ListItem() {
            this.storySection(story)
          }
          // list row — shared id, index-resolved by replay (Rule 12 exception)
          .id('news_itemroot')
        }, (story: WMFFeedNewsStory, index: number) => (story.storyHTML ?? '') + '_' + index)
        // footerButtonTitle: the last row of the detail list
        ListItem() {
          BackToExploreFeedButton()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .cachedCount(3)
    }
    .id('NewsViewController')
    .width('100%')
    .height('100%')
    // NewsViewController.apply(theme:) — view + collectionView = theme.colors.paperBackground
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private openArticle(articleTitle: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
