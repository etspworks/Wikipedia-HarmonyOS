// comp_explore_card_vc — ported from WMF Framework/ExploreCardCollectionViewCell.swift
// (card chrome: titleLabel, subtitleLabel, customizationButton "overflow", cardContent slot,
// footerButton) + Wikipedia/Code/ExploreCardViewController.swift (the content the host page
// dispatches per WMFContentGroupKind into the slot). S3: structure only, unstyled.
import { i18n } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { formatString } from '../common/Plural';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { ContentGroupKind, midnightUTCFromLocal } from '../common/FeedStore';
import { localizedLanguageName } from '../common/LanguageService';

// Tint black template PNGs (overflow.png, chevron_right.png) to the app link blue
// #3366CC — iOS tints these template images with theme.colors.link.
// The On this day card renders three events; persistGroup stores the full set's size.
const ON_THIS_DAY_CARD_EVENTS: number = 3;

const BLUE_TINT: number[] = [
  0, 0, 0, 0, 0.2,
  0, 0, 0, 0, 0.4,
  0, 0, 0, 0, 0.8,
  0, 0, 0, 1, 0
];

@Component
export struct ExploreCardViewController {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop group: WMFContentGroup = new WMFContentGroup();
  @BuilderParam content: () => void = this.defaultContent;
  onFooterTap?: () => void;
  onDismissCard?: (groupKey: string) => void;
  onHideAllCards?: (kind: number, cardName: string) => void;
  onCustomizeFeed?: () => void;

  @Builder
  defaultContent() {
    Column() {
    }
  }

  // Every card string is a Resource. As literals these ignored the device language, which
  // is what the Turkish-locale cases reported across the whole feed.
  private headerTitle(): Resource {
    const kind: number = this.group.contentGroupKindInteger;
    if (kind === ContentGroupKind.FeaturedArticle) { return $r('app.string.explore_featured_article_heading'); }
    if (kind === ContentGroupKind.TopRead) { return $r('app.string.explore_most_read_generic_heading'); }
    if (kind === ContentGroupKind.PictureOfTheDay) { return $r('app.string.explore_potd_heading'); }
    if (kind === ContentGroupKind.OnThisDay) { return $r('app.string.on_this_day_title'); }
    if (kind === ContentGroupKind.News) { return $r('app.string.in_the_news_title'); }
    if (kind === ContentGroupKind.Random) { return $r('app.string.explore_random_article_heading'); }
    if (kind === ContentGroupKind.ContinueReading) { return $r('app.string.explore_continue_reading_heading'); }
    if (kind === ContentGroupKind.RelatedPages) { return $r('app.string.explore_because_you_read_heading'); }
    // the source's nearby card reads 'Places near' / 'Yakındaki yerler', not the tab title
    if (kind === ContentGroupKind.Location) { return $r('app.string.explore_nearby_heading'); }
    if (kind === ContentGroupKind.DailyGame) { return $r('app.string.explore_games_title'); }
    if (kind === ContentGroupKind.SuggestedEdits) { return $r('app.string.suggested_edits_title'); }
    return $r('app.string.empty_string');
  }

  // The site's language, named in the reader's locale ("On Turkish Wikipedia", not "On tr").
  private languageName(): string {
    const host: string = this.group.siteURLString ?? '';
    const code: string = host.replace('https://', '').split('.')[0];
    return localizedLanguageName(code, code);
  }

  // header subtitle per capture: featured "From English Wikipedia", top read and games
  // "On English Wikipedia", POTD "From Wikimedia Commons".
  private headerSubtitle(): ResourceStr {
    const kind: number = this.group.contentGroupKindInteger;
    if (kind === ContentGroupKind.FeaturedArticle || kind === ContentGroupKind.Random) {
      return $r('app.string.explore_from_wikipedia_format', this.languageName());
    }
    // a game is per language too: without the line two "Games" cards could not be told apart
    if (kind === ContentGroupKind.TopRead || kind === ContentGroupKind.DailyGame) {
      return $r('app.string.explore_on_wikipedia_format', this.languageName());
    }
    if (kind === ContentGroupKind.PictureOfTheDay) { return $r('app.string.explore_from_commons'); }
    // The On this day header carries the day it is about. Without it the card read as
    // undated, which is what "the card always shows today" came down to.
    if (kind === ContentGroupKind.OnThisDay) { return this.groupDateText(); }
    // Continue reading / Because you read: the day the article was read, relative to today.
    if (kind === ContentGroupKind.ContinueReading || kind === ContentGroupKind.RelatedPages) {
      const days: number = Math.round((midnightUTCFromLocal(Date.now()) -
        (this.group.midnightUTCDate ?? midnightUTCFromLocal(this.group.date ?? Date.now()))) / 86400000);
      if (days <= 0) { return $r('app.string.today_title'); }
      if (days === 1) { return $r('app.string.yesterday_title'); }
      return this.groupDateText();
    }
    if (kind === ContentGroupKind.Location) {
      // the string's placeholder is escaped ('\\$1'), which only formatString fills
      return formatString(getContext(this) as common.Context,
        $r('app.string.explore_nearby_sub_heading_your_location_from_language_wikipedia'), [this.languageName()]);
    }
    return '';
  }

  // The day the group is about, in the reader's locale.
  private groupDateText(): string {
    const ms: number | null = this.group.date;
    if (ms === null) {
      return '';
    }
    try {
      const locale: string = i18n.System.getSystemLocale();
      return new Intl.DateTimeFormat(locale, {
        month: 'long',
        day: 'numeric'
      }).format(new Date(ms));
    } catch (e) {
      return '';
    }
  }

  private footerTitle(): ResourceStr {
    const kind: number = this.group.contentGroupKindInteger;
    if (kind === ContentGroupKind.TopRead) { return $r('app.string.explore_top_read_footer'); }
    if (kind === ContentGroupKind.OnThisDay) {
      // "More on this day" said nothing about how much more there is. The card shows three
      // events; the footer names the rest.
      const remaining: number = (this.group.countOfFullContent ?? 0) - ON_THIS_DAY_CARD_EVENTS;
      if (remaining > 0) {
        return $r('app.string.explore_on_this_day_footer_count', remaining.toString());
      }
      return $r('app.string.explore_on_this_day_footer');
    }
    if (kind === ContentGroupKind.News) { return $r('app.string.explore_in_the_news_footer'); }
    if (kind === ContentGroupKind.SuggestedEdits) { return $r('app.string.explore_suggested_edits_footer'); }
    if (kind === ContentGroupKind.Random) { return $r('app.string.explore_random_footer'); }
    if (kind === ContentGroupKind.Location) { return $r('app.string.home_nearby_footer'); }
    if (kind === ContentGroupKind.RelatedPages) { return $r('app.string.explore_because_you_read_footer'); }
    return '';
  }

  private dismissCard(): void {
    if (this.onDismissCard !== undefined && this.group.key !== null) {
      this.onDismissCard(this.group.key);
    }
  }

  // The card name as it reads in the header, for the "Hide all ..." row. ActionSheet takes a
  // ResourceStr per row, but the format argument has to be a plain string, so the header
  // resource is resolved here rather than nested as a resource inside a resource.
  private cardName(): string {
    try {
      return getContext(this).resourceManager.getStringSync(this.headerTitle());
    } catch (e) {
      console.error('exploreCard: card name unavailable: ' + (e as Error).message);
      return '';
    }
  }

  // ExploreCardViewController.presentCardActionSheet — the source's customizationButton
  // raises a UIAlertController action sheet: the card name over three actions in one rounded
  // group with separators, and Cancel in its own group below.
  @State showOptions: boolean = false;

  private showCardOptions(): void {
    this.showOptions = true;
  }

  private chooseOption(index: number): void {
    this.showOptions = false;
    if (index === 0) {
      this.dismissCard();
    } else if (index === 1 && this.onHideAllCards !== undefined) {
      this.onHideAllCards(this.group.contentGroupKindInteger, this.cardName());
    } else if (index === 2 && this.onCustomizeFeed !== undefined) {
      this.onCustomizeFeed();
    }
  }

  @Builder
  optionRow(label: ResourceStr, index: number, rowId: string) {
    Column() {
      Divider().color($r('app.color.theme_border'))
      Text(label)
        .width('100%')
        .height(56)
        .fontSize(18)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_link'))
        .maxLines(2)
        .padding({ left: 16, right: 16 })
    }
    .id(rowId)
    .accessibilityGroup(true)
    .onClick(() => {
      this.chooseOption(index);
    })
  }

  @Builder
  optionsSheet() {
    Column({ space: 8 }) {
      Column() {
        Text(this.cardName())
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14, left: 16, right: 16 })
        this.optionRow($r('app.string.explore_hide_this_card'), 0, 'explore_card_hide_this')
        this.optionRow($r('app.string.explore_hide_all_cards_format', this.cardName()), 1, 'explore_card_hide_all')
        this.optionRow($r('app.string.explore_customize_feed'), 2, 'explore_card_customize_feed')
      }
      .width('100%')
      .borderRadius(14)
      .backgroundColor($r('app.color.theme_paper_background'))
      Text($r('app.string.action_cancel'))
        .id('explore_card_options_cancel')
        .width('100%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_link'))
        .borderRadius(14)
        .backgroundColor($r('app.color.theme_paper_background'))
        .onClick(() => {
          this.showOptions = false;
        })
    }
    .width('100%')
    .padding({ left: 8, right: 8, bottom: 28 })
  }

  build() {
    Column() {
      // header: titleLabel + subtitleLabel + customizationButton — sits on the page
      // background, above the white card (ExploreCardCollectionViewCell layout).
      Row() {
        Column() {
          Text(this.headerTitle())
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
          if (this.group.placemarkTitle !== null) {
            Text(this.group.placemarkTitle ?? '')
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ top: 2 })
          } else if (this.headerSubtitle() !== '') {
            Text(this.headerSubtitle())
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button() {
          Image($r('app.media.overflow'))
            .height(22)
            .objectFit(ImageFit.Contain)
            .colorFilter(new ColorFilter(BLUE_TINT))
        }
        .id('overflow')
        .accessibilityText($r('app.string.explore_card_more_options'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => {
          this.showCardOptions();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .bindSheet($$this.showOptions, this.optionsSheet(), {
        height: SheetSize.FIT_CONTENT, dragBar: false, showClose: false,
        backgroundColor: Color.Transparent, maskColor: '#66000000'
      })

      // white card surface: cornerRadius 10, shadow radius 10 / offset (0,2)
      // (Theme.exploreCardCornerRadius + ExploreCardCollectionViewCell shadow constants)
      Column() {
        this.content()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(10)
      .clip(true)
      .shadow({ radius: 10, color: '#1F000000', offsetY: 2 })
      .margin({ top: 12 })

      if (this.footerTitle() !== '') {
        // AlignedImageButton footer — blue text + trailing chevron, right-aligned below the card
        Row() {
          Button() {
            Row() {
              Text(this.footerTitle())
                .fontSize(15)
                .fontColor($r('app.color.theme_link'))
              Image($r('app.media.chevron_right'))
                .height(16)
                .objectFit(ImageFit.Contain)
                .colorFilter(new ColorFilter(BLUE_TINT))
                .margin({ left: 6 })
            }
            .alignItems(VerticalAlign.Center)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.onFooterTap !== undefined) {
              this.onFooterTap();
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
  }
}
