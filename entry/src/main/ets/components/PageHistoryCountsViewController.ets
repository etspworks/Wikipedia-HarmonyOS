// comp_history_counts — ported from Wikipedia/Code/PageHistoryCountsViewController.swift
// (+ its child PageHistoryFilterCountsViewController). Section-0 header of the page-history
// list: the uppercased "Revision history" title, the page title, the counts label
// ("{{PLURAL:$1|$1 edit|$1 edits}} since $2"), the edits sparkline (accessibility label
// "Graph of edits over time"), a separator, and the filter-count cells the fetcher
// produced (logged-in / unregistered / bot / minor), each an icon over an abbreviated
// count over its title.
// Users: screen_page_history.
// S5 (capture S0316): styled from the source's own apply(theme:)/updateFonts —
// titleLabel .mediumFootnote secondaryText, pageTitleLabel .boldTitle1 primaryText,
// countsLabel .boldSubheadline accent, separator theme.colors.border, and each filter
// count cell .callout primaryText over .footnote secondaryText with a link-tinted icon
// and a trailing border separator. The sparkline keeps its bar rendering (the capture's
// line chart plots the same series) in the capture's link blue.
import { upperText } from '../common/LocaleText';
import { common } from '@kit.AbilityKit';
import { formatString } from '../common/Plural';

// One PageHistoryFilterCountsViewController.Count (title + image + count).
export class PageHistoryEditCount {
  title: string = '';
  // 'user-edit' | 'user-anonymous' | 'bot' | 'm', as the source's Count.image names them.
  iconName: string = '';
  count: number = 0;
}

@Component
export struct PageHistoryCountsViewController {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop pageTitle: string = '';
  // totalEditCount + the year of firstEditDate; -1 until the counts request resolves.
  @Prop totalEditCount: number = -1;
  @Prop firstEditYear: string = '';
  // timeseriesOfEditsCounts -> sparklineView.dataValues
  @Prop timeseries: number[] = [];
  // editCountsGroupedByType -> the filter-count cells
  @Prop editCounts: PageHistoryEditCount[] = [];

  private countIcon(name: string): Resource {
    if (name === 'user-anonymous') {
      return $r('app.media.user_anonymous');
    }
    if (name === 'bot') {
      return $r('app.media.bot');
    }
    if (name === 'm') {
      return $r('app.media.m');
    }
    return $r('app.media.user_edit');
  }

  // NumberFormatter.localizedThousandsStringFromNumber
  private displayCount(count: number): string {
    if (count >= 1000) {
      return (Math.round(count / 100) / 10).toString() + 'K';
    }
    return count.toString();
  }

  // page-history-stats-text: "{{PLURAL:$1|$1 edit|$1 edits}} since $2", from the resources
  // so it follows the device language ("2003 sonrasında 5842 düzenleme").
  private countsText(): string {
    return formatString(getContext(this) as common.Context, $r('app.string.page_history_stats_text'),
      [this.totalEditCount.toString(), this.firstEditYear]);
  }

  // The filter-count labels arrive as the source's keys; show them translated.
  private countTitle(key: string): Resource {
    if (key === 'bot') {
      return $r('app.string.page_history_bot_edits');
    }
    if (key === 'unregistered') {
      return $r('app.string.page_history_unregistered_edits');
    }
    if (key === 'minor') {
      return $r('app.string.page_history_minor_edits');
    }
    return $r('app.string.page_history_logged_in_edits');
  }

  private maxSeries(): number {
    let max: number = 1;
    for (const v of this.timeseries) {
      if (v > max) {
        max = v;
      }
    }
    return max;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(upperText(getContext(this) as common.Context, $r('app.string.page_history_revision_history_title')))
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_secondary_text'))
          Text(this.pageTitle)
            .width('100%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 10 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.totalEditCount >= 0) {
            Text(this.countsText())
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_accent'))
              .margin({ top: 10 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // sparklineView — one bar per timeseries sample.
        Row() {
          ForEach(this.timeseries, (value: number) => {
            Column()
              .layoutWeight(1)
              .height(Math.max(1, Math.round(60 * value / this.maxSeries())))
              .margin({ left: 0.5, right: 0.5 })
              .backgroundColor($r('app.color.theme_link'))
          }, (value: number, index: number) => index.toString())
        }
        .layoutWeight(1)
        .height(60)
        .margin({ left: 24, top: 12 })
        .alignItems(VerticalAlign.Bottom)
        .accessibilityText('Graph of edits over time')
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16, top: 30, bottom: 26 })

      // separator
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.theme_border'))

      // filterCountsContainerView — removed entirely when no counts are available.
      if (this.editCounts.length > 0) {
        Row() {
          ForEach(this.editCounts, (item: PageHistoryEditCount) => {
            Column() {
              Row() {
                Image(this.countIcon(item.iconName))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                Text(this.displayCount(item.count))
                  .fontSize(16)
                  .fontColor($r('app.color.theme_text'))
                  .margin({ left: 8 })
              }
              .alignItems(VerticalAlign.Center)

              Text(this.countTitle(item.title))
                .fontSize(13)
                .fontColor($r('app.color.theme_secondary_text'))
                .margin({ top: 6 })
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .border({
              width: { right: 0.5 },
              color: { right: $r('app.color.theme_border') }
            })
          }, (item: PageHistoryEditCount) => item.title)
        }
        .width('100%')
        .height(61)

        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.theme_border'))
      }
    }
    .width('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
