// screen_on_this_day — presentation: page.
// S3 structure from Wikipedia/Code/OnThisDayViewController.swift
// (ColumnarCollectionViewController: nav bar titled "On this day"; sections = events.count + 1,
// section 1 carries OnThisDayViewControllerHeader — eventsLabel / onLabel / fromLabel — every
// later section a blank header + one OnThisDayCollectionViewCell).
// Event timeline bound to svc_feed (feed_onthisday); S4 wires the load, starts empty.
import { BackToExploreFeedButton } from '../components/BackToExploreFeedButton';
import { router } from '@kit.ArkUI';
import { OnThisDayCollectionViewCell } from '../components/OnThisDayCollectionViewCell';
import { WMFFeedOnThisDayEvent } from '../model/WMFFeedOnThisDayEvent';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFContent } from '../model/WMFContent';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { FeedService } from '../common/FeedService';
import { FeedStore, ContentGroupKind } from '../common/FeedStore';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { common } from '@kit.AbilityKit';
import { i18n, intl } from '@kit.LocalizationKit';
import { formatString, pluralString } from '../common/Plural';
import { NAV_TEXT_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

class OnThisDayEventDataSource implements IDataSource {
  private items: WMFFeedOnThisDayEvent[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): WMFFeedOnThisDayEvent {
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

  reload(items: WMFFeedOnThisDayEvent[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// OnThisDayViewControllerHeader.swift / .xib — three labels configured by
// configureFor(eventCount:firstEvent:lastEvent:midnightUTCDate:).
@Component
struct OnThisDayViewControllerHeader {
  @Prop eventsText: string = '';
  @Prop onText: string = '';
  @Prop fromText: string = '';

  build() {
    // .xib order (capture S0344): onLabel boldTitle1 / primaryText [16,201]-[152,234], then
    // eventsLabel [16,249] and fromLabel [16,270] — both secondaryText, consecutive lines.
    Column() {
      Text(this.onText)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
      Text(this.eventsText)
        .fontSize(17)
        .lineHeight(21)
        .fontColor($r('app.color.theme_secondary_text'))
        .width('100%')
        .margin({ top: 15 })
      if (this.fromText !== '') {
        Text(this.fromText)
          .fontSize(17)
          .lineHeight(21)
          .fontColor($r('app.color.theme_secondary_text'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, bottom: 40 })
  }
}

@Entry
@Component
struct OnThisDayViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // events: [WMFFeedOnThisDayEvent] — svc_feed (feed_onthisday); S4 loads it.
  @State items: WMFFeedOnThisDayEvent[] = [];
  // header fields — configureFor(eventCount:firstEvent:lastEvent:midnightUTCDate:), S4 fills.
  @State headerEventsText: string = '';
  @State headerOnText: string = '';
  @State headerFromText: string = '';
  // load status — the source renders the timeline only once the content group resolved.
  @State loading: boolean = true;
  @State loadFailed: boolean = false;
  private itemsSource: OnThisDayEventDataSource = new OnThisDayEventDataSource();

  aboutToAppear(): void {
    this.load();
  }

  // OnThisDayViewController is initialized with `events` + `midnightUTCDate` from the feed
  // content group Explore persisted (WMFOnThisDayContentSource); its fullContent carries the
  // full event list, and a cold entry falls back to the live feed_onthisday fetch (svc_feed).
  private async load(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    // Every read below (the store AND LanguageStore.appLanguage) goes through the RDB store,
    // so the store has to be open before any of them — a cold deep-link into this page has
    // no Explore ahead of it to have opened it.
    try {
      await Database.init(getContext(this) as common.UIAbilityContext);
    } catch (e) {
      console.error('onthisday: database init failed: ' + this.describeError(e));
      this.loading = false;
      this.loadFailed = true;
      return;
    }
    const group: WMFContentGroup | null = await this.newestGroup();
    let events: WMFFeedOnThisDayEvent[] = await this.storedEvents(group);
    if (events.length === 0) {
      events = await this.fetchedEvents();
    }
    const midnightUTCMs: number = group === null || group.midnightUTCDate === null ?
      Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()) :
      (group.midnightUTCDate ?? 0);
    this.loading = false;
    this.items = events;
    this.itemsSource.reload(events);
    this.applyHeader(events, midnightUTCMs);
  }

  // Renders the caught value diagnosable in hilog: message + stack for Errors,
  // String(e) otherwise (a throw is not guaranteed to be an Error).
  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message + (e.stack !== undefined ? ' | ' + e.stack : '');
    }
    return String(e);
  }

  private async newestGroup(): Promise<WMFContentGroup | null> {
    try {
      return await FeedStore.newestGroupOfKind(ContentGroupKind.OnThisDay, true);
    } catch (e) {
      console.error('onthisday: content group lookup failed: ' + this.describeError(e));
      return null;
    }
  }

  private async storedEvents(group: WMFContentGroup | null): Promise<WMFFeedOnThisDayEvent[]> {
    if (group === null) {
      return [];
    }
    try {
      const key: string = group.key ?? '';
      const content: WMFContent | null =
        key === '' ? null : await FeedStore.fullContentForGroup(key);
      const json: string = content === null ?
        (group.contentPreviewJSON ?? '') : (content.objectJSON ?? '');
      if (json === '') {
        return [];
      }
      return JSON.parse(json) as WMFFeedOnThisDayEvent[];
    } catch (e) {
      console.error('onthisday: stored events unavailable: ' + this.describeError(e));
      return [];
    }
  }

  private async fetchedEvents(): Promise<WMFFeedOnThisDayEvent[]> {
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      const now = new Date();
      return await FeedService.fetchOnThisDayEvents(lang.languageCode + '.wikipedia.org',
        lang.languageCode, now.getUTCMonth() + 1, now.getUTCDate());
    } catch (e) {
      console.error('onthisday: feed fetch failed: ' + this.describeError(e));
      this.loadFailed = true;
      return [];
    }
  }

  // OnThisDayViewControllerHeader.configureFor(eventCount:firstEvent:lastEvent:midnightUTCDate:)
  private applyHeader(events: WMFFeedOnThisDayEvent[], midnightUTCMs: number): void {
    const count: number = events.length;
    const ctx = getContext(this);
    // CommonStrings.onThisDayAdditionalEventsMessage, uppercased in the UI language (Turkish
    // needs its own dotted capital I).
    this.headerEventsText = pluralString(ctx, $r('app.string.on_this_day_detail_header_title'), count)
      .toLocaleUpperCase(i18n.System.getSystemLanguage());
    // DateFormatter.wmf_monthNameDayNumberGMTFormatter — GMT month name + day number.
    this.headerOnText = new intl.DateTimeFormat(i18n.System.getSystemLocale(),
      { month: 'long', day: 'numeric', timeZone: 'UTC' }).format(new Date(midnightUTCMs));
    // CommonStrings.onThisDayHeaderDateRangeMessage(lastEvent:firstEvent:) — both years needed.
    if (count > 0 && events[0].year !== null && events[count - 1].year !== null) {
      this.headerFromText = formatString(ctx, $r('app.string.on_this_day_detail_header_date_range'),
        [this.yearString(events[count - 1].year), this.yearString(events[0].year)]);
    } else {
      this.headerFromText = '';
    }
  }

  // WMFFeedOnThisDayEvent.yearString — negative years render with the BC era suffix.
  private yearString(year: number | null): string {
    const value: number = year ?? 0;
    return value < 0 ? String(-value) + ' BC' : String(value);
  }

  // CollectionViewHeader (style .detail) — headerTitle only; headerSubtitle is nil for
  // .onThisDay (WMFContentGroup+DetailViewControllers.swift:84).
  @Builder
  detailHeader() {
    Column() {
      Text($r('app.string.on_this_day_title'))
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 41 })
  }

  // Load / empty / error visuals for the svc_feed-bound event timeline. The detail header
  // stays visible; only the content region changes.
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
          'These events could not be loaded. Check your connection and try again.' :
          'No historical events available.')
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
      // WMFNavigationBarTitleConfig(title:, alignment: .hidden) — the title rides on the
      // back button (chevron + title), the bar itself is empty (capture S0344: [16,62]-[155,106]).
      Row() {
        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
            Text($r('app.string.on_this_day_title'))
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
        // section 0 — CollectionViewHeader (detail style), large title only
        ListItem() {
          this.detailHeader()
        }

        // section 1 header — the only non-blank supplementary view
        ListItem() {
          OnThisDayViewControllerHeader({
            eventsText: this.headerEventsText,
            onText: this.headerOnText,
            fromText: this.headerFromText
          })
        }

        if (this.loading || this.items.length === 0) {
          ListItem() {
            this.statusBlock()
          }
        }

        LazyForEach(this.itemsSource, (event: WMFFeedOnThisDayEvent) => {
          ListItem() {
            OnThisDayCollectionViewCell({
              event: event,
              onSelectArticle: (articleTitle: string): void => {
                this.openArticle(articleTitle);
              }
              // shouldSelectItemAt returns false in the source: the cell itself is not
              // tappable, only its article previews are — so no onTap is wired.
            })
          }
          // list row — shared id, index-resolved by replay (Rule 12 exception)
          .id('onthisday_itemroot')
        }, (event: WMFFeedOnThisDayEvent, index: number) => String(event.year ?? 0) + '_' + index)
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
    .id('OnThisDayViewController')
    .width('100%')
    .height('100%')
    // ColumnarCollectionViewController default — theme.colors.paperBackground
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private openArticle(articleTitle: string): void {
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }
}
