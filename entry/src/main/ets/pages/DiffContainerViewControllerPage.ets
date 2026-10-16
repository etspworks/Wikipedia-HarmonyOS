// screen_diff_container — Wikipedia/Code/DiffContainerViewController.swift. Page History's row
// tap shows that revision against its parent (.single); the Watchlist (Special:MobileDiff
// old...new) and Page History's Compare show two revisions (.compare).
// Header = DiffHeaderView: .single — date, bytes, edit summary, editor; .compare —
// DiffHeaderTitleView ("COMPARE REVISIONS", the article title as a link, the bold size change,
// the 80 pt lead image) over DiffHeaderCompareView (PREVIOUS EDIT in the compare accent,
// DISPLAYED EDIT in link blue: date, minor flag + summary, user capsule with its menu).
// Body = DiffListViewController from the REST compare endpoint (DiffFetcher.swift:95), grouped
// as DiffTransformer.viewModelsForCompare does: runs of changed lines are one "Lines a - b"
// block, runs of context lines a collapsible block, and a jump in line numbers an
// "N Lines Unedited" row. Changed text is bold on light green/red (DiffListChangeItemViewModel).
import { router, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { WatchlistService, WatchStatus, UndoOrRollbackResult } from '../common/WatchlistService';
import { SessionStore } from '../common/SessionStore';
import { presentChooseExpiryActionSheet } from '../components/WatchlistExpirySheet';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { PageHistoryService } from '../common/PageHistoryService';
import { ArticleService } from '../common/ArticleService';
import { formatString, pluralString } from '../common/Plural';
import { decodeEntities } from '../common/WebDocument';
import { DiffResponse, DiffItem, DiffItemType, DiffHighlightRangeType } from '../model/DiffResponse';
import { WMFPageHistoryRevision } from '../model/Revision';
import { ArticleSummary } from '../model/ArticleSummary';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

class DiffPiece {
  text: string = '';
  mark: number = -1;                // -1 plain, else DiffHighlightRangeType
}

// DiffListGroupViewModel: 0 change (DiffListChangeViewModel), 1 context (DiffListContextViewModel),
// 2 unedited (DiffListUneditedViewModel)
class DiffBlock {
  key: string = '';
  kind: number = 0;
  heading: string = '';
  lines: DiffPiece[][] = [];
  count: number = 0;
}

// One side of DiffHeaderCompareView.
class CompareSide {
  date: string = '';
  user: string = '';
  summary: string = '';
  isMinor: boolean = false;
  isTemp: boolean = false;
}

// tappedUndo's alert: "Undo", the message, a summary field, Cancel and Undo (enabled once a
// reason is typed).
@CustomDialog
struct DiffUndoDialog {
  controller: CustomDialogController;
  @State summary: string = '';
  onUndo: (summary: string) => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.action_undo'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      Text($r('app.string.diff_undo_message'))
        .fontSize(13)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
      TextInput({ text: this.summary })
        .id('diff_undo_summary')
        .defaultFocus(true)
        .height(40)
        .fontSize(15)
        .onChange((v: string) => {
          this.summary = v;
        })
      Row() {
        Button($r('app.string.cancel'))
          .id('diff_undo_cancel')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.theme_link'))
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.action_undo'))
          .id('diff_undo_confirm')
          .layoutWeight(1)
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_destructive'))
          .enabled(this.summary.trim() !== '')
          .opacity(this.summary.trim() !== '' ? 1 : 0.4)
          .onClick(() => {
            this.controller.close();
            this.onUndo(this.summary);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 12 })
  }
}

@Entry
@Component
struct DiffContainerViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  @StorageProp('wmfIsDark') wmfIsDark: boolean = false;

  @State blocks: DiffBlock[] = [];
  @State expanded: string[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State empty: boolean = false;
  @State fromSide: CompareSide = new CompareSide();
  @State toSide: CompareSide = new CompareSide();
  @State byteChange: number = 0;
  @State imageURL: string = '';
  private host: string = '';
  @State articleTitle: string = '';
  private fromID: number = 0;
  private toID: number = 0;
  private isCompare: boolean = false;
  @State toTime: string = '';
  @State toUser: string = '';
  @State toComment: string = '';
  // DiffToolbarView state: the adjacent revisions (prevModel / nextModel), the editor's
  // anonymity, the More menu's rollback / watch items and whether thanks were sent
  @State nextFromID: number = 0;
  @State nextToID: number = 0;
  @State prevFromID: number = -1;
  @State prevToID: number = 0;
  @State toIsAnon: boolean = true;
  @State watchStatus: WatchStatus | null = null;
  @State isThankSelected: boolean = false;
  private undoDialog: CustomDialogController = new CustomDialogController({
    builder: DiffUndoDialog({
      onUndo: (summary: string): void => {
        this.performUndo(summary);
      }
    }),
    autoCancel: true
  });

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string> | undefined;
    if (p !== undefined && p !== null) {
      this.host = p['host'] ?? '';
      this.articleTitle = p['articleTitle'] ?? '';
      this.fromID = Number.parseInt(p['fromID'] ?? '0', 10);
      this.toID = Number.parseInt(p['toID'] ?? '0', 10);
      this.isCompare = p['mode'] === 'compare';
      this.toTime = p['toTime'] ?? '';
      this.toUser = p['toUser'] ?? '';
      this.toComment = p['toComment'] ?? '';
      this.byteChange = Number.parseInt(p['toSize'] ?? '0', 10);
      if (p['resolveRevisions'] === 'true') {
        this.resolveFromLink().then(() => {
          this.load();
          this.loadToolbarState();
        });
        return;
      }
    }
    this.load();
    this.loadToolbarState();
    if (this.isCompare) {
      this.loadCompareHeader();
    }
  }

  // A diff link names revision ids only (Router .articleDiff): the side it leaves out (diff=prev
  // -> the parent, diff=next -> the following revision), the title and the header's
  // time/user/comment/size come from the API.
  private async resolveFromLink(): Promise<void> {
    try {
      if (this.toID === 0 && this.fromID > 0) {
        this.toID = await PageHistoryService.nextRevisionId(this.host, this.fromID);
      }
      if (this.toID > 0) {
        const revs: WMFPageHistoryRevision[] = await PageHistoryService.fetchRevisionsByIds(this.host, [this.toID]);
        if (revs.length > 0) {
          const to: WMFPageHistoryRevision = revs[0];
          if (this.fromID === 0) {
            this.fromID = to.parentID;
          }
          this.toTime = to.revisionDate ?? '';
          this.toUser = to.user ?? '';
          this.toComment = decodeEntities((to.parsedComment ?? '').replace(/<[^>]*>/g, '')).trim();
          // the size change against the other side of the diff
          if (this.fromID > 0) {
            const others: WMFPageHistoryRevision[] =
              await PageHistoryService.fetchRevisionsByIds(this.host, [this.fromID]);
            if (others.length > 0) {
              this.byteChange = to.articleSizeAtRevision - others[0].articleSizeAtRevision;
            }
          }
        }
        if (this.articleTitle === '') {
          this.articleTitle = await PageHistoryService.pageTitleForRevision(this.host, this.toID);
        }
      }
    } catch (e) {
      console.error('diff: link revisions unavailable: ' + (e as Error).message);
    }
  }

  // populatePrevNextModelsForToolbar + fetchWatchAndRollbackStatus (single diffs only)
  private async loadToolbarState(): Promise<void> {
    if (this.isCompare || this.toID <= 0) {
      return;
    }
    try {
      const next: number = await PageHistoryService.nextRevisionId(this.host, this.toID);
      if (next > 0) {
        this.nextFromID = this.toID;
        this.nextToID = next;
      }
      const ids: number[] = this.fromID > 0 ? [this.toID, this.fromID] : [this.toID];
      const revs: WMFPageHistoryRevision[] = await PageHistoryService.fetchRevisionsByIds(this.host, ids);
      const to: WMFPageHistoryRevision | undefined = revs.find((r: WMFPageHistoryRevision) => r.revisionID === this.toID);
      this.toIsAnon = to !== undefined ? (to.isAnon || to.isTemp) : true;
      if (this.toUser === '' && to !== undefined) {
        this.toUser = to.user ?? '';
      }
      // previous: the diff ending at this one's older side; on the second revision of the
      // history the first revision shown on its own
      const from: WMFPageHistoryRevision | undefined = revs.find((r: WMFPageHistoryRevision) => r.revisionID === this.fromID);
      if (from !== undefined) {
        this.prevFromID = from.parentID;
        this.prevToID = from.revisionID;
      }
    } catch (e) {
      console.error('diff: adjacent revisions unavailable: ' + (e as Error).message);
    }
    if (SessionStore.isLoggedIn && this.articleTitle !== '') {
      try {
        this.watchStatus = await WatchlistService.fetchWatchStatus(this.host, this.articleTitle, true);
      } catch (e) {
        console.error('diff: watch status unavailable: ' + (e as Error).message);
      }
    }
  }

  // replaceLastAndPush: the adjacent diff takes this one's place
  private openDiff(fromID: number, toID: number): void {
    router.replaceUrl({ url: 'pages/DiffContainerViewControllerPage', params: {
      'host': this.host, 'articleTitle': this.articleTitle, 'fromID': fromID.toString(),
      'toID': toID.toString(), 'mode': 'single', 'resolveRevisions': 'true'
    } });
  }

  // tappedPrevious / tappedNext
  private tappedPrevious(): void {
    if (this.prevFromID >= 0 && this.prevToID > 0) {
      this.openDiff(this.prevFromID, this.prevToID);
    }
  }

  private tappedNext(): void {
    if (this.nextToID > 0) {
      this.openDiff(this.nextFromID, this.nextToID);
    }
  }

  // fullRevisionDiffURL: /w/index.php?title=<title>&diff=<to>&oldid=<from or the parent>
  private fullRevisionDiffURL(): string {
    return 'https://' + this.host + '/w/index.php?title=' + encodeURIComponent(this.articleTitle.replace(/ /g, '_')) +
      '&diff=' + this.toID + '&oldid=' + this.fromID;
  }

  // tappedShare: the share sheet with the diff URL
  private tappedShare(): void {
    const record: systemShare.SharedRecord = { utd: 'general.hyperlink', content: this.fullRevisionDiffURL(),
      title: this.articleTitle };
    try {
      new systemShare.ShareController(new systemShare.SharedData(record)).show(getContext(this) as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL
      }).catch((e: Error) => console.error('diff: share panel failed: ' + e.message));
    } catch (e) {
      console.error('diff: share panel unavailable: ' + (e as Error).message);
    }
  }

  // tappedUndo -> the reason alert -> performUndo
  private tappedUndo(): void {
    this.undoDialog.open();
  }

  private performUndo(summary: string): void {
    WatchlistService.undo(this.host, this.articleTitle, this.toID, summary, this.toUser)
      .then((r: UndoOrRollbackResult | null) => this.completeRollbackOrUndo(r, false))
      .catch((e: Error) => {
        console.error('diff: undo failed: ' + e.message);
        this.completeRollbackOrUndo(null, false);
      });
  }

  // tappedRollback: "Rollback edits" / "Are you sure you want to rollback the edits?"
  private tappedRollback(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.diff_rollback_alert_title'),
      message: $r('app.string.diff_rollback_alert_message'),
      primaryButton: { value: $r('app.string.cancel'), action: () => {} },
      secondaryButton: {
        value: $r('app.string.diff_rollback'), fontColor: $r('app.color.theme_destructive'),
        action: () => {
          WatchlistService.rollback(this.host, this.articleTitle, this.toUser)
            .then((r: UndoOrRollbackResult | null) => this.completeRollbackOrUndo(r, true))
            .catch((e: Error) => {
              console.error('diff: rollback failed: ' + e.message);
              this.completeRollbackOrUndo(null, true);
            });
        }
      }
    });
  }

  // completeRollbackOrUndo: the resulting diff replaces this one, then the success toast
  private completeRollbackOrUndo(r: UndoOrRollbackResult | null, isRollback: boolean): void {
    if (r === null) {
      promptAction.showToast({ message: this.ctx().resourceManager.getStringSync($r('app.string.fetcher_error_generic').id) });
      return;
    }
    const message: string = this.ctx().resourceManager.getStringSync(
      (isRollback ? $r('app.string.diff_rollback_success') : $r('app.string.diff_undo_success')).id);
    this.openDiff(r.oldRevisionID, r.newRevisionID);
    setTimeout(() => {
      promptAction.showToast({ message: message });
    }, 1000);
  }

  // tappedThank -> ThanksGiving.tappedThank: anonymous editors and unsigned readers get a hint,
  // otherwise "Publicly send 'Thanks'" confirms before action=thank.
  private tappedThank(): void {
    const rm = this.ctx().resourceManager;
    if (this.isThankSelected) {
      promptAction.showToast({ message: rm.getStringSync($r('app.string.diff_thanks_sent_already').id) });
      return;
    }
    if (this.toIsAnon) {
      promptAction.showToast({ message: rm.getStringSync($r('app.string.diff_thanks_anonymous_no_thanks').id) });
      return;
    }
    if (!SessionStore.isLoggedIn) {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.diff_thanks_login_title'),
        message: $r('app.string.diff_thanks_login_subtitle'),
        primaryButton: { value: $r('app.string.cancel'), action: () => {} },
        secondaryButton: { value: $r('app.string.main_menu_account_login'), action: () => {
          router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' });
        } }
      });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: $r('app.string.diff_thanks_send_title'),
      message: $r('app.string.diff_thanks_send_subtitle'),
      primaryButton: { value: $r('app.string.cancel'), action: () => {} },
      secondaryButton: { value: $r('app.string.diff_thanks_send_button_title'), action: () => {
        WatchlistService.thank(this.host, this.toID).then((ok: boolean) => {
          if (ok) {
            this.isThankSelected = true;
            promptAction.showToast({ message: formatString(this.ctx(), $r('app.string.diff_thanks_sent'), [this.toUser]) });
          }
        }).catch((e: Error) => console.error('diff: thank failed: ' + e.message));
      } }
    });
  }

  // tappedWatch / tappedUnwatch -> WatchlistController: the expiry sheet before a watch
  private toggleWatch(watch: boolean): void {
    if (!watch) {
      WatchlistService.unwatch(this.host, this.articleTitle).then((ok: boolean) => {
        if (ok) {
          this.setWatched(false, null);
          promptAction.showToast({ message: this.ctx().resourceManager.getStringSync($r('app.string.watchlist_removed').id) });
        }
      }).catch((e: Error) => console.error('diff: unwatch failed: ' + e.message));
      return;
    }
    presentChooseExpiryActionSheet(this.getUIContext(), (expiry: string, toast: Resource) => {
      WatchlistService.watch(this.host, this.articleTitle, expiry).then((ok: boolean) => {
        if (ok) {
          this.setWatched(true, expiry === 'never' ? null : expiry);
          promptAction.showToast({ message: this.ctx().resourceManager.getStringSync(toast.id) });
        }
      }).catch((e: Error) => console.error('diff: watch failed: ' + e.message));
    });
  }

  private setWatched(watched: boolean, expiry: string | null): void {
    const status = new WatchStatus();
    status.watched = watched;
    status.watchlistExpiry = expiry;
    status.userHasRollbackRights = this.watchStatus?.userHasRollbackRights ?? false;
    this.watchStatus = status;
  }

  // createMoreButton: Rollback (with rollback rights), Share, Watch / Unwatch, Article edit history
  private moreMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    const tint = (r: Resource): SymbolGlyphModifier => new SymbolGlyphModifier(r).fontColor([$r('app.color.theme_text')]);
    if (this.watchStatus?.userHasRollbackRights ?? false) {
      items.push({ value: $r('app.string.diff_rollback'), symbolIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_counterclockwise'))
        .fontColor([$r('app.color.theme_destructive')]), action: () => this.tappedRollback() });
    }
    items.push({ value: $r('app.string.article_share'), symbolIcon: tint($r('sys.symbol.share')), action: () => this.tappedShare() });
    if (this.watchStatus !== null) {
      if (!this.watchStatus.watched) {
        items.push({ value: $r('app.string.watch'), symbolIcon: tint($r('sys.symbol.star')), action: () => this.toggleWatch(true) });
      } else {
        // ponytail: star.leadinghalf.filled (a temporary watch) has no system symbol; both show the filled star
        items.push({ value: $r('app.string.unwatch'), symbolIcon: tint($r('sys.symbol.star_fill')),
          action: () => this.toggleWatch(false) });
      }
    }
    items.push({ value: $r('app.string.diff_article_revision_history'), icon: $r('app.media.edit_history_2'), action: () => {
      router.pushUrl({ url: 'pages/PageHistoryViewControllerPage',
        params: { 'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0] } });
    } });
    return items;
  }

  // read inside the builder: a @Builder's by-value arguments do not follow state changes
  private isToolbarItemEnabled(id: string): boolean {
    if (id === 'diff_next') {
      return this.nextToID > 0;
    }
    if (id === 'diff_previous') {
      return this.prevToID > 0;
    }
    return !this.loading && !this.failed;
  }

  private thankIcon(): Resource {
    return this.isThankSelected ? $r('app.media.diff_smile_filled') : $r('app.media.diff_smile');
  }

  @Builder
  toolbarIcon(id: string, icon: Resource, label: Resource, action: () => void) {
    Button() {
      Image(id === 'diff_thank' ? this.thankIcon() : icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.theme_text'))
    }
      .id(id)
      .accessibilityText(label)
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(48)
      .height(48)
      .enabled(this.isToolbarItemEnabled(id))
      .opacity(this.isToolbarItemEnabled(id) ? 1 : 0.35)
      .onClick(action)
  }

  // DiffToolbarView: [next, previous, undo, thank, more] spread by flexible spaces
  @Builder
  diffToolbar() {
    Row() {
      this.toolbarIcon('diff_next', $r('app.media.chevron_up'), $r('app.string.action_next_revision_accessibility'),
        () => this.tappedNext())
      this.toolbarIcon('diff_previous', $r('app.media.chevron_down'), $r('app.string.action_previous_revision_accessibility'),
        () => this.tappedPrevious())
      this.toolbarIcon('diff_undo', $r('app.media.revert'), $r('app.string.action_undo'),
        () => this.tappedUndo())
      this.toolbarIcon('diff_thank', $r('app.media.diff_smile'), $r('app.string.action_thank_user_accessibility'),
        () => this.tappedThank())
      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize(22)
          .fontColor([$r('app.color.theme_text')])
      }
        .id('diff_more')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .width(48)
        .height(48)
        .bindMenu(this.moreMenu())
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .border({ width: { top: 0.5 }, color: $r('app.color.theme_border') })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  private async load(): Promise<void> {
    try {
      // A page's first revision has no parent (0): diff it against itself so the body is its
      // content rather than an error.
      const from: number = this.fromID > 0 ? this.fromID : this.toID;
      const resp: DiffResponse = await PageHistoryService.fetchDiff(this.host, from, this.toID);
      this.blocks = this.isCompare ? this.compareBlocks(resp.diff) : this.singleBlocks(resp.diff);
      this.empty = this.blocks.every((b: DiffBlock) => b.kind !== 0);
    } catch (e) {
      console.error('diff: load failed: ' + (e as Error).message);
      this.failed = true;
    }
    this.loading = false;
  }

  // DiffHeaderCompareViewModel(fromModel:toModel:) + the title view's lead image.
  private async loadCompareHeader(): Promise<void> {
    try {
      const revs: WMFPageHistoryRevision[] =
        await PageHistoryService.fetchRevisionsByIds(this.host, [this.fromID, this.toID]);
      const from: WMFPageHistoryRevision | undefined =
        revs.find((r: WMFPageHistoryRevision) => r.revisionID === this.fromID);
      const to: WMFPageHistoryRevision | undefined =
        revs.find((r: WMFPageHistoryRevision) => r.revisionID === this.toID);
      if (from !== undefined) {
        this.fromSide = this.side(from);
      }
      if (to !== undefined) {
        this.toSide = this.side(to);
      }
      if (from !== undefined && to !== undefined) {
        this.byteChange = to.articleSizeAtRevision - from.articleSizeAtRevision;
      }
    } catch (e) {
      console.error('diff: revisions failed: ' + (e as Error).message);
    }
    try {
      const summary: ArticleSummary = await ArticleService.fetchSummary(this.host, this.articleTitle);
      this.imageURL = summary.thumbnail?.source ?? '';
    } catch (e) {
      console.warn('diff: no lead image');
    }
  }

  private side(r: WMFPageHistoryRevision): CompareSide {
    const s = new CompareSide();
    s.date = this.when(r.revisionDate ?? '');
    s.user = r.user ?? '';
    s.summary = decodeEntities((r.parsedComment ?? '').replace(/<[^>]*>/g, '')).trim();
    s.isMinor = r.isMinor;
    s.isTemp = r.isTemp;
    return s;
  }

  private lineHeading(first: number, last: number): string {
    return first === last
      ? formatString(this.ctx(), $r('app.string.diff_single_line_format'), [first.toString()])
      : formatString(this.ctx(), $r('app.string.diff_multi_line_format'), [first.toString(), last.toString()]);
  }

  // DiffTransformer.viewModelsForCompare: line numbers carried forward to items without one.
  private compareBlocks(items: DiffItem[]): DiffBlock[] {
    const out: DiffBlock[] = [];
    let run: DiffItem[] = [];
    let runNumbers: number[] = [];
    let runKind: number = -1;
    let lastLine: number | null = null;
    let previous: number | null = null;
    const flush = () => {
      if (run.length === 0) {
        return;
      }
      const b = new DiffBlock();
      b.key = 'b' + out.length.toString();
      b.kind = runKind;
      // calculateHeadingsFromLineNumbers: an empty deleted line has no number of its own
      const numbers: number[] = runNumbers.filter((n: number, i: number) =>
        !(run[i].type === DiffItemType.deleteLine && run[i].text === '') && n >= 0);
      if (numbers.length > 0) {
        b.heading = run.length === 1 ? this.lineHeading(numbers[0], numbers[0])
          : this.lineHeading(numbers[0], numbers[numbers.length - 1]);
      }
      b.lines = run.map((item: DiffItem) => this.pieces(item));
      out.push(b);
      run = [];
      runNumbers = [];
    };
    for (const item of items) {
      if (item.lineNumber !== null) {
        lastLine = item.lineNumber;
      }
      const line: number = lastLine ?? -1;
      if (previous !== null && line >= 0 && line - previous > 1) {
        flush();
        const gap = new DiffBlock();
        gap.key = 'u' + out.length.toString();
        gap.kind = 2;
        gap.count = line - previous;
        out.push(gap);
      }
      const kind: number = item.type === DiffItemType.context ? 1 : 0;
      if (kind !== runKind) {
        flush();
        runKind = kind;
      }
      run.push(item);
      runNumbers.push(line);
      if (line >= 0) {
        previous = line;
      }
    }
    flush();
    return out;
  }

  // .single: one block per changed line, unchanged runs counted.
  private singleBlocks(items: DiffItem[]): DiffBlock[] {
    const out: DiffBlock[] = [];
    let folded: number = 0;
    const flush = () => {
      if (folded > 0) {
        const b = new DiffBlock();
        b.key = 'u' + out.length.toString();
        b.kind = 2;
        b.count = folded;
        out.push(b);
        folded = 0;
      }
    };
    items.forEach((item: DiffItem, i: number) => {
      if (item.type === DiffItemType.context) {
        folded++;
        return;
      }
      flush();
      const b = new DiffBlock();
      b.key = 'd' + i.toString();
      if (item.lineNumber !== null) {
        b.heading = this.lineHeading(item.lineNumber, item.lineNumber);
      }
      b.lines = [this.pieces(item)];
      out.push(b);
    });
    flush();
    return out;
  }

  // highlightRanges count UTF-8 bytes; walk the text converting byte offsets to characters.
  // Whole added / deleted lines are one highlight (updateParamsForAddDeleteLine).
  private pieces(item: DiffItem): DiffPiece[] {
    const whole: number = item.type === DiffItemType.addLine || item.type === DiffItemType.moveDestination
      ? DiffHighlightRangeType.add
      : item.type === DiffItemType.deleteLine || item.type === DiffItemType.moveSource
        ? DiffHighlightRangeType.deleteRange : -1;
    if (whole >= 0 || item.highlightRanges.length === 0) {
      const one = new DiffPiece();
      one.text = item.text !== '' ? item.text : ' ';
      one.mark = whole;
      return [one];
    }
    const chars: string[] = Array.from(item.text);
    const byteAt: number[] = [];
    let b: number = 0;
    for (const c of chars) {
      byteAt.push(b);
      const cp: number = c.codePointAt(0) ?? 0;
      b += cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
    }
    byteAt.push(b);
    const marks: number[] = chars.map((): number => -1);
    for (const range of item.highlightRanges) {
      for (let k: number = 0; k < chars.length; k++) {
        if (byteAt[k] >= range.start && byteAt[k] < range.start + range.length) {
          marks[k] = range.type;
        }
      }
    }
    const out: DiffPiece[] = [];
    for (let k: number = 0; k < chars.length; k++) {
      if (out.length === 0 || out[out.length - 1].mark !== marks[k]) {
        const piece = new DiffPiece();
        piece.mark = marks[k];
        out.push(piece);
      }
      out[out.length - 1].text += chars[k];
    }
    return out;
  }

  private ctx(): common.Context {
    return getContext(this) as common.Context;
  }

  // DiffHeaderViewModel.dateFormatter: UTC, dateStyle .medium, timeStyle .short —
  // "Oct 3, 2026 at 2:42 PM".
  private when(iso: string): string {
    if (iso === '') {
      return '';
    }
    const locale: string = i18n.System.getSystemLocale();
    const d: Date = new Date(iso);
    const day: string = d.toLocaleDateString(locale,
      { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' });
    const time: string = d.toLocaleTimeString(locale, { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' });
    return day + ' at ' + time;
  }

  private bytesText(): string {
    return this.byteChange >= 0
      ? pluralString(this.ctx(), $r('app.string.diff_single_header_subtitle_bytes_added'), this.byteChange)
      : pluralString(this.ctx(), $r('app.string.diff_single_header_subtitle_bytes_removed'), -this.byteChange);
  }

  private isLight(): boolean {
    return !this.wmfIsDark && this.wmfPaperBg === '';
  }

  // diffHighlightAdd / diffHighlightDelete: light only
  private markBackground(mark: number): ResourceColor {
    if (mark < 0 || !this.isLight()) {
      return Color.Transparent;
    }
    return mark === DiffHighlightRangeType.add ? '#D5FDF4' : '#FEE7E6';
  }

  // diffTextAdd / diffTextDelete
  private markColor(mark: number): ResourceColor {
    if (mark < 0 || this.isLight()) {
      return $r('app.color.theme_text');
    }
    if (mark === DiffHighlightRangeType.add) {
      return '#00AF89';
    }
    return this.wmfIsDark ? '#DD3333' : '#B32424';
  }

  private openWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private wikiUrl(title: string): string {
    return 'https://' + this.host + '/wiki/' + encodeURIComponent(title.replace(/ /g, '_'));
  }

  // DiffHeaderCompareView.userButtonMenuItems
  private userMenu(user: string): MenuElement[] {
    return [
      { value: $r('app.string.watchlist_user_button_user_contributions'),
        action: () => { this.openWeb(this.wikiUrl('Special:Contributions/' + user)); } },
      { value: $r('app.string.watchlist_user_button_user_talk_page'),
        action: () => { this.openWeb(this.wikiUrl('User_talk:' + user)); } },
      { value: $r('app.string.watchlist_user_button_user_page'),
        action: () => { this.openWeb(this.wikiUrl('User:' + user)); } }
    ];
  }

  // WMFSmallMenuButton: capsule tinted with its primary colour at 15 %
  // reads the @State side itself: a by-value builder parameter does not redraw when it changes
  @Builder
  userCapsule(isFrom: boolean) {
    Row({ space: 6 }) {
      if ((isFrom ? this.fromSide : this.toSide).isTemp) {
        Image($r('app.media.tempaccounticon'))
          .width(13)
          .height(13)
          .fillColor(isFrom ? $r('app.color.theme_diff_compare_accent') : $r('app.color.theme_link'))
      } else {
        SymbolGlyph($r('sys.symbol.person_fill'))
          .fontSize(13)
          .fontColor([isFrom ? $r('app.color.theme_diff_compare_accent') : $r('app.color.theme_link')])
      }
      Text((isFrom ? this.fromSide : this.toSide).user)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(isFrom ? $r('app.color.theme_diff_compare_accent') : $r('app.color.theme_link'))
    }
    .padding(8)
    .borderRadius(100)
    .backgroundColor(isFrom ? '#26FF9500' : (this.wmfIsDark ? '#266699FF' : '#263366CC'))
    .bindMenu(this.userMenu((isFrom ? this.fromSide : this.toSide).user))
  }

  @Builder
  compareColumn(isFrom: boolean) {
    Column({ space: 6 }) {
      Text(isFrom ? $r('app.string.diff_compare_header_from_info_heading')
        : $r('app.string.diff_compare_header_to_info_heading'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_secondary_text'))
        .textCase(TextCase.UpperCase)
      Text((isFrom ? this.fromSide : this.toSide).date)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(isFrom ? $r('app.color.theme_warning') : $r('app.color.theme_link'))
      if ((isFrom ? this.fromSide : this.toSide).isMinor || (isFrom ? this.fromSide : this.toSide).summary !== '') {
        Text() {
          if ((isFrom ? this.fromSide : this.toSide).isMinor) {
            ImageSpan($r('app.media.minor_edit'))
              .width(14)
              .height(10.5)
              .verticalAlign(ImageSpanAlignment.CENTER)
            Span('  ')
          }
          Span((isFrom ? this.fromSide : this.toSide).summary)
        }
        .fontSize(15)
        .fontColor($r('app.color.theme_text'))
        .maxLines((isFrom ? this.fromSide : this.toSide).isMinor ? 1 : 100)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if ((isFrom ? this.fromSide : this.toSide).user !== '') {
        this.userCapsule(isFrom)
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  header() {
    if (this.isCompare) {
      Column() {
        // DiffHeaderTitleView + lead image
        Row({ space: 16 }) {
          Column({ space: 2 }) {
            Text($r('app.string.diff_compare_header_heading'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_secondary_text'))
              .textCase(TextCase.UpperCase)
            Text(this.articleTitle)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                const params: Record<string, string> = {
                  'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0]
                };
                router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
              })
            Text(this.bytesText())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.byteChange >= 0 ? $r('app.color.theme_accent') : $r('app.color.theme_destructive'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          if (this.imageURL !== '') {
            Image(this.imageURL)
              .width(80)
              .height(80)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .border({ width: { bottom: 1 }, color: this.baseBg() })

        // DiffHeaderCompareView
        Row({ space: 16 }) {
          this.compareColumn(true)
          this.compareColumn(false)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .border({ width: { bottom: 2 }, color: this.baseBg() })
      }
      .width('100%')
    } else {
      Column({ space: 8 }) {
        Text(this.when(this.toTime))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        Text(this.bytesText())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.byteChange >= 0 ? $r('app.color.theme_accent') : $r('app.color.theme_destructive'))
        Text($r('app.string.diff_single_header_summary_heading'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 8 })
        Text(this.toComment !== '' ? this.toComment : this.ctx().resourceManager.getStringSync(
          $r('app.string.empty_edit_summary')))
          .fontSize(15)
          .fontStyle(FontStyle.Italic)
          .fontColor($r('app.color.theme_text'))
        Text($r('app.string.diff_single_header_editor_title'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 8 })
        Text(this.toUser)
          .fontSize(15)
          .fontColor($r('app.color.theme_link'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .border({ width: { bottom: 1 }, color: this.baseBg() })
    }
  }

  private baseBg(): ResourceColor {
    return this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background');
  }

  // DiffListChangeItemViewModel text: subheadline, line spacing 4, changed ranges bold
  @Builder
  diffText(pieces: DiffPiece[]) {
    Text() {
      ForEach(pieces, (piece: DiffPiece) => {
        Span(piece.text)
          .fontWeight(piece.mark >= 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.markColor(piece.mark))
          .decoration({
            type: piece.mark === DiffHighlightRangeType.deleteRange ? TextDecorationType.LineThrough
              : TextDecorationType.None,
            color: this.isLight() ? '#202122' : this.markColor(piece.mark)
          })
          .textBackgroundStyle({ color: this.markBackground(piece.mark) })
      })
    }
    .width('100%')
    .fontSize(15)
    .lineHeight(26)
    .fontColor($r('app.color.theme_text'))
  }

  @Builder
  blockHeading(text: string) {
    Text(text)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.theme_secondary_text'))
  }

  @Builder
  diffBlock(b: DiffBlock) {
    if (b.kind === 2) {
      // DiffListUneditedCell: text.localizedCapitalized
      Text(pluralString(this.ctx(), $r('app.string.diff_unedited_lines_format'), b.count).split(' ')
        .map((w: string): string => w.charAt(0).toUpperCase() + w.substring(1)).join(' '))
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_secondary_text'))
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    } else if (b.kind === 1) {
      // DiffListContextCell: heading + expand chevron; expanded lines in bordered boxes
      Column() {
        Row() {
          this.blockHeading(b.heading)
          Blank()
          SymbolGlyph(this.expanded.indexOf(b.key) >= 0 ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_link')])
        }
        .width('100%')
        .height(46)
        .onClick(() => {
          this.expanded = this.expanded.indexOf(b.key) >= 0
            ? this.expanded.filter((k: string) => k !== b.key) : this.expanded.concat([b.key]);
        })
        if (this.expanded.indexOf(b.key) >= 0) {
          ForEach(b.lines, (line: DiffPiece[], i: number) => {
            Column() {
              this.diffText(line)
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ bottom: 15 })
            .borderRadius(5)
            .border({ width: 1, color: this.isLight() ? '#A2A9B1' : '#54595D' })
            .backgroundColor(this.isLight() ? '#F8F9FA' : '#202122')
          }, (line: DiffPiece[], i: number) => b.key + '-' + i.toString())
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    } else {
      // DiffListChangeCell: heading, then the changed lines
      Column({ space: 20 }) {
        if (b.heading !== '') {
          this.blockHeading(b.heading)
        }
        Column() {
          ForEach(b.lines, (line: DiffPiece[], i: number) => {
            this.diffText(line)
          }, (line: DiffPiece[], i: number) => b.key + '-' + i.toString())
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 14, bottom: 18 })
    }
  }

  build() {
    Column() {
      // the source's diff navigation bar: back button only (the title shows when scrolled)
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
        }
        .id('BackButton')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          router.back();
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      List() {
        ListItem() {
          this.header()
        }
        if (this.loading) {
          ListItem() {
            LoadingProgress().width(36).height(36).margin({ top: 40 })
          }
          .width('100%')
        } else if (this.failed || this.empty) {
          ListItem() {
            Text(this.failed ? $r('app.string.diff_revision_error_title')
              : this.isCompare ? $r('app.string.empty_diff_compare_title') : $r('app.string.empty_diff_single_title'))
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 40 })
          }
        } else {
          ForEach(this.blocks, (b: DiffBlock) => {
            ListItem() {
              this.diffBlock(b)
            }
          }, (b: DiffBlock) => b.key)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 1, color: this.baseBg() })

      if (!this.isCompare) {
        this.diffToolbar()
      }
    }
    .id('DiffContainerViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
