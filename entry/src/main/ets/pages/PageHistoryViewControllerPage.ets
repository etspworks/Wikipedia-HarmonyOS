// screen_page_history — presentation: page.
// Structure from Wikipedia/Code/PageHistoryViewController.swift: a centerCompact "History"
// nav title with a right Compare bar-button (swapped for Cancel while comparing), a
// collection whose section-0 header is PageHistoryCountsViewController and whose sections
// are date-titled groups of PageHistoryCollectionViewCell revision rows (paged through
// PageHistoryFetcher's rvcontinue on scroll), and the bottom
// PageHistoryComparisonSelectionViewController bar shown only in compare (editing) mode:
// two revision-selection buttons plus its own Compare button, enabled at two selections.
// Nav edge page_history -> diff_container skipped: screen_diff_container absent from plan
// screens[], so the comparison Compare button has no push target to wire.
// S5 (captures S0316/S0317): WMF nav chrome — a white 44pt back circle carrying the back
// chevron, a centred 17pt semibold title, and the Compare bar button as a white pill that
// fills with theme.colors.link while comparing (capture S0317 "Cancel"). Section headers
// are CollectionViewHeader .pageHistory (.semiboldHeadline secondaryText, margins 10/30);
// rows are inset 16 with the source layout's 20pt interItemSpacing; the comparison
// selection bar sits on the mid background.
import { router, promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { WMFPageHistoryRevision } from '../model/Revision';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { PageHistoryService, PageHistoryPage, PageHistoryEditCounts, PageHistoryCountEntry }
  from '../common/PageHistoryService';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs } from '../common/Prefs';
import { decodeEntities } from '../common/WebDocument';
import { PageHistoryCollectionViewCell } from '../components/PageHistoryCollectionViewCell';
import { PageHistoryCountsViewController, PageHistoryEditCount } from '../components/PageHistoryCountsViewController';
import { NAV_ICON_BUTTON, NAV_TEXT_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// One collection row: a revision, plus the date section title when it opens a section
// (configure(header:forSectionAt:) puts the relative date above the first item).
class RevisionRow {
  sectionTitle: string = '';
  revision: WMFPageHistoryRevision = new WMFPageHistoryRevision();
}

class RevisionDataSource implements IDataSource {
  private items: RevisionRow[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): RevisionRow {
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

  reload(items: RevisionRow[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct PageHistoryViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State items: RevisionRow[] = [];
  // state == .editing — compare selection mode.
  @State isCompareMode: boolean = false;
  // indexPathsSelectedForComparisonGroupedByButtonTags (at most two).
  @State selectedRevisionIDs: number[] = [];
  @State totalEditCount: number = -1;
  @State firstEditYear: string = '';
  @State timeseries: number[] = [];
  @State editCounts: PageHistoryEditCount[] = [];
  @State isLoadingData: boolean = false;
  // S6: the source surfaces a fetch failure through WMFAlertManager.showErrorAlert; the
  // list itself has no error view, so the failure is rendered in the empty content region.
  @State loadFailed: boolean = false;
  private itemsSource: RevisionDataSource = new RevisionDataSource();
  private pageTitle: string = '';
  private host: string = '';
  // pageHistoryFetcherParams — rvcontinue of the last batch; null once batchComplete.
  private continueKey: string | null = null;
  private batchComplete: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.pageTitle = params['articleTitle'] ?? '';
      // The article's own wiki. Without it the history was fetched from the app-language
      // wiki, which is a different page (or none) when the article came from another one.
      const code: string = params['languageCode'] ?? '';
      if (code !== '') {
        this.host = code + '.wikipedia.org';
      }
    }
    this.getPageHistory().catch((e: Error) => {
      console.error('pageHistory: load failed: ' + e.message);
    });
    this.getEditCounts().catch((e: Error) => {
      console.error('pageHistory: edit counts failed: ' + e.message);
    });
  }

  // getEditCounts() — the counts header: fetchFirstRevision + fetchEditCounts feed the
  // "$1 edits since $2" label and the filter-count cells; fetchEditMetrics feeds the
  // sparkline (an empty series on failure, as the source does).
  private async getEditCounts(): Promise<void> {
    if (this.pageTitle === '') {
      return;
    }
    await this.resolveHost();
    try {
      const counts: PageHistoryEditCounts =
        await PageHistoryService.fetchEditCounts(this.host, this.pageTitle);
      this.totalEditCount = counts.totalEditCount;
      this.firstEditYear = counts.firstEditDate !== null
        ? new Date(counts.firstEditDate).getUTCFullYear().toString() : '';
      const cells: PageHistoryEditCount[] = [];
      const entries: PageHistoryCountEntry[] = counts.entries;
      for (const entry of entries) {
        const cell = new PageHistoryEditCount();
        cell.title = entry.title;
        cell.iconName = entry.iconName;
        cell.count = entry.count;
        cells.push(cell);
      }
      this.editCounts = cells;
    } catch (e) {
      console.error('pageHistory: counts request failed');
    }
    try {
      this.timeseries = await PageHistoryService.fetchEditMetrics(this.host, this.pageTitle);
    } catch (e) {
      this.timeseries = [];
    }
  }

  private async resolveHost(): Promise<void> {
    if (this.host === '') {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.host = lang.languageCode + '.wikipedia.org';
    }
  }

  // getPageHistory() — fetchRevisionInfo, appended section by section.
  private async getPageHistory(): Promise<void> {
    if (this.isLoadingData || this.batchComplete || this.pageTitle === '') {
      return;
    }
    this.isLoadingData = true;
    this.loadFailed = false;
    try {
      await this.resolveHost();
      const page: PageHistoryPage =
        await PageHistoryService.fetchRevisions(this.host, this.pageTitle, this.continueKey);
      this.continueKey = page.continueKey;
      this.batchComplete = page.continueKey === null;
      this.appendSections(page.revisions);
    } catch (e) {
      this.loadFailed = true;
      console.error('pageHistory: fetchRevisions failed');
    } finally {
      this.isLoadingData = false;
    }
  }

  private appendSections(revisions: WMFPageHistoryRevision[]): void {
    const rows: RevisionRow[] = this.items.slice();
    let lastTitle: string = rows.length > 0 ? this.sectionTitleOf(rows[rows.length - 1]) : '';
    for (const revision of revisions) {
      const title: string = this.dateTitle(revision.revisionDate);
      const row = new RevisionRow();
      row.revision = revision;
      row.sectionTitle = title === lastTitle ? '' : title;
      lastTitle = title;
      rows.push(row);
    }
    this.items = rows;
    this.itemsSource.reload(rows);
  }

  private sectionTitleOf(row: RevisionRow): string {
    return this.dateTitle(row.revision.revisionDate);
  }

  // The section header date, spelled out in the device language ("20 Nisan 2026",
  // "April 20, 2026"). toLocaleDateString() gave the numeric "4/20/2026" whatever the language.
  private dateTitle(iso: string | null): string {
    if (iso === null || iso === '') {
      return '';
    }
    const fmt = new Intl.DateTimeFormat(i18n.System.getSystemLocale(),
      { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
    return fmt.format(new Date(iso));
  }

  // parsedcomment is HTML (section links, user-talk links); the row shows its text.
  private plainComment(html: string | null): string {
    if (html === null) {
      return '';
    }
    return decodeEntities(html.replace(/<[^>]*>/g, '')).trim();
  }

  // The comparison slot label: the selected revision's time over its author, as the source's
  // PageHistoryComparisonSelectionViewController buttons read.
  private slotLines(index: number): string[] {
    if (index >= this.selectedRevisionIDs.length) {
      return ['', ''];
    }
    const r: WMFPageHistoryRevision | null = this.revisionById(this.selectedRevisionIDs[index]);
    return r === null ? ['', ''] : [this.displayTime(r.revisionDate), r.user ?? ''];
  }

  @Builder
  slotLabel(index: number) {
    Column() {
      Text(this.slotLines(index)[0])
        .fontSize(13)
        .fontColor($r('app.color.theme_text'))
        .maxLines(1)
      Text(this.slotLines(index)[1])
        .fontSize(13)
        .fontColor($r('app.color.theme_link'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 6, right: 6 })
  }

  private revisionById(id: number): WMFPageHistoryRevision | null {
    for (const row of this.items) {
      if (row.revision.revisionID === id) {
        return row.revision;
      }
    }
    return null;
  }

  // DateFormatter.wmf_24hshortTimeWithUTCTimeZone
  private displayTime(iso: string | null): string {
    if (iso === null || iso === '') {
      return '';
    }
    const d = new Date(iso);
    const h: number = d.getUTCHours();
    const m: number = d.getUTCMinutes();
    const hh: string = h < 10 ? '0' + h.toString() : h.toString();
    const mm: string = m < 10 ? '0' + m.toString() : m.toString();
    return hh + ':' + mm + ' GMT';
  }

  // compare(_:) — state = .editing; cancelComparison(_:) — state = .idle.
  private toggleCompareMode(): void {
    this.isCompareMode = !this.isCompareMode;
    this.selectedRevisionIDs = [];
  }

  // collectionView(_:didSelectItemAt:) in editing mode, capped at two selections.
  private onRowTapped(row: RevisionRow): void {
    if (!this.isCompareMode) {
      // showDiff(from: parent, to: revision, type: .single)
      this.openDiff(row.revision.parentID, row.revision.revisionID);
      return;
    }
    const id: number = row.revision.revisionID;
    const at: number = this.selectedRevisionIDs.indexOf(id);
    if (at >= 0) {
      const next: number[] = this.selectedRevisionIDs.slice();
      next.splice(at, 1);
      this.selectedRevisionIDs = next;
      return;
    }
    if (this.selectedRevisionIDs.length >= 2) {
      // page-history-revisions-comparison-warning
      promptAction.showToast({ message: $r('app.string.page_history_revisions_comparison_warning') });
      return;
    }
    this.selectedRevisionIDs = this.selectedRevisionIDs.concat([id]);
  }

  // showDiff(from:to:type: .compare) — older revision on the left, newer on the right.
  private compareSelectedRevisions(): void {
    if (this.selectedRevisionIDs.length !== 2) {
      return;
    }
    const a: number = this.selectedRevisionIDs[0];
    const b: number = this.selectedRevisionIDs[1];
    this.openDiff(Math.min(a, b), Math.max(a, b));
  }

  private openDiff(fromID: number, toID: number): void {
    const to: WMFPageHistoryRevision | null = this.revisionById(toID);
    const from: WMFPageHistoryRevision | null = this.revisionById(fromID);
    const params: Record<string, string> = {
      'host': this.host,
      'articleTitle': this.pageTitle,
      'fromID': fromID.toString(),
      'toID': toID.toString(),
      'toTime': to !== null ? (to.revisionDate ?? '') : '',
      'toUser': to !== null ? (to.user ?? '') : '',
      'toComment': to !== null ? this.plainComment(to.parsedComment) : '',
      'toSize': to !== null ? to.revisionSize.toString() : '0',
      'fromTime': from !== null ? (from.revisionDate ?? '') : '',
      'fromUser': from !== null ? (from.user ?? '') : '',
      'mode': this.isCompareMode ? 'compare' : 'single'
    };
    router.pushUrl({ url: 'pages/DiffContainerViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('pageHistory: diff route failed: ' + e.message);
      });
  }

  @Builder
  countsHeader() {
    PageHistoryCountsViewController({
      pageTitle: this.pageTitle,
      totalEditCount: this.totalEditCount,
      firstEditYear: this.firstEditYear,
      timeseries: this.timeseries,
      editCounts: this.editCounts
    })
  }

  build() {
    Column() {
      // configureNavigationBar(titleConfig: "History", alignment: .centerCompact)
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
        }
        .id('BackButton')
        .accessibilityText('History')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          router.back();
        })
        Text($r('app.string.history_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        // navigationItem.rightBarButtonItem: compareButton / cancelComparisonButton
        // (text title-bar capsule; the label alone tells Compare from Cancel)
        Button(this.isCompareMode
          ? $r('app.string.action_cancel')
          : $r('app.string.page_history_compare_title'))
          .id('compare')
          .attributeModifier(NAV_TEXT_BUTTON)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_link'))
          .onClick(() => {
            this.toggleCompareMode();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      List() {
        ListItem() {
          this.countsHeader()
        }

        if (this.items.length === 0) {
          // Empty content region: spinner while the first batch is in flight, the
          // fetcher's generic error text when it failed. Never beside the rows.
          ListItem() {
            Column() {
              if (this.isLoadingData) {
                LoadingProgress()
                  .width(36)
                  .height(36)
                  .color($r('app.color.theme_secondary_text'))
              } else if (this.loadFailed) {
                Text($r('app.string.fetcher_error_generic'))
                  .fontSize(15)
                  .fontColor($r('app.color.theme_secondary_text'))
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 32, right: 32, top: 60, bottom: 60 })
            .justifyContent(FlexAlign.Center)
          }
        } else {
          LazyForEach(this.itemsSource, (row: RevisionRow) => {
            ListItem() {
              Column() {
                if (row.sectionTitle !== '') {
                  Text(row.sectionTitle)
                    .width('100%')
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.theme_secondary_text'))
                    .padding({ left: 6, right: 6, top: 20, bottom: 20 })
                }
                PageHistoryCollectionViewCell({
                  displayTime: this.displayTime(row.revision.revisionDate),
                  author: row.revision.user ?? '',
                  isAnon: row.revision.isAnon,
                  isTemp: row.revision.isTemp,
                  sizeDiff: row.revision.revisionSize,
                  comment: this.plainComment(row.revision.parsedComment),
                  isMinor: row.revision.isMinor,
                  isEditing: this.isCompareMode,
                  isSelected: this.selectedRevisionIDs.indexOf(row.revision.revisionID) >= 0,
                  isEditingEnabled: this.selectedRevisionIDs.length < 2
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .margin({ bottom: 20 })
              .id('revisionrow_itemroot')
              .onClick(() => {
                this.onRowTapped(row);
              })
            }
          }, (row: RevisionRow) => row.revision.revisionID.toString())

          // paging spinner — shouldLoadNewData fired for the next rvcontinue batch.
          if (this.isLoadingData) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(28)
                  .height(28)
                  .color($r('app.color.theme_secondary_text'))
              }
              .width('100%')
              .padding({ top: 12, bottom: 24 })
              .justifyContent(FlexAlign.Center)
            }
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      // the collection view's scroll indicator
      .scrollBar(BarState.Auto)
      // scrollViewDidScroll -> shouldLoadNewData -> getPageHistory()
      .onReachEnd(() => {
        this.getPageHistory().catch((e: Error) => {
          console.error('pageHistory: paging failed: ' + e.message);
        });
      })

      // comparisonSelectionViewController — hidden while state == .idle.
      if (this.isCompareMode) {
        Row() {
          Button() {
            this.slotLabel(0)
          }
            .id('comparison_selection_button_1')
            .type(ButtonType.Normal)
            .borderRadius(6)
            .layoutWeight(1)
            .height(48)
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .border({ width: 1, color: $r('app.color.gray300') })
            .onClick(() => {
              this.selectedRevisionIDs = [];
            })
          Button() {
            this.slotLabel(1)
          }
            .id('comparison_selection_button_2')
            .type(ButtonType.Normal)
            .borderRadius(6)
            .layoutWeight(1)
            .height(48)
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .border({ width: 1, color: $r('app.color.gray300') })
            .margin({ left: 10, right: 10 })
            .onClick(() => {
              this.selectedRevisionIDs = this.selectedRevisionIDs.slice(0, 1);
            })
          Button($r('app.string.page_history_compare_title'))
            .id('comparison_compare_button')
            .enabled(this.selectedRevisionIDs.length === 2)
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedRevisionIDs.length === 2
              ? $r('app.color.theme_link')
              : $r('app.color.theme_secondary_text'))
            .onClick(() => {
              this.compareSelectedRevisions();
            })
        }
        .width('100%')
        .height(60)
        .padding({ left: 20, right: 20 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      }
    }
    .id('PageHistoryViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
