// screen_page_issues_table — presentation: sheet, hosted by screen_article
// (.bindSheet in ArticleViewControllerPage). NOT a routed page.
// Ported from Wikipedia/Code/PageIssuesTableViewController.swift: a UITableViewController
// whose single section renders one word-wrapping, NON-interactive cell per entry of
// `issues` (the strings the article's JS bridge hands over), under a centred
// "Page issues" title with a leading plain-X close button (WMFLargeCloseButtonConfig).
// No separators, automatic row height.
// S5: no capture — styled from the source roles + the app baseline tokens. iOS renders
// the inline nav title CENTRED and the plain-X on the leading edge (mapping-tables §7).
import { ArticleService } from '../common/ArticleService';
import { ArticleCacheStore } from '../common/ArticleCacheStore';

// showPageIssues(with payload:) — the PCS footer's page-issues payload: every .mbox-text-span of
// the document (a Multiple issues box's own message, which holds its listed issues too, then each
// issue), with .hide-when-compact and .collapsed removed, its HTML stripped (String.removingHTML).
// This port has no bridge, so the spans are read out of the mobile-html document.
function extractPageIssues(html: string): string[] {
  const out: string[] = [];
  const open: RegExp = /<div\b[^>]*class="mbox-text-span"[^>]*>/g;
  let m: RegExpExecArray | null = open.exec(html);
  while (m !== null && out.length < 20) {
    const inner: string = html.substring(open.lastIndex, closingDiv(html, open.lastIndex));
    const text: string = stripIssue(withoutHidden(inner));
    if (text !== '') {
      out.push(text);
    }
    m = open.exec(html);
  }
  return out;
}

// Where the <div> whose content starts at `from` closes, counting nested <div>s.
function closingDiv(html: string, from: number): number {
  const rx: RegExp = /<(\/?)div\b[^>]*>/gi;
  rx.lastIndex = from;
  let depth: number = 1;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    depth += m[1] === '' ? 1 : -1;
    if (depth === 0) {
      return m.index;
    }
    m = rx.exec(html);
  }
  return html.length;
}

// Drops the elements carrying hide-when-compact or collapsed, nested tags of the same name included.
function withoutHidden(html: string): string {
  const rx: RegExp = /<(span|div|small)\b[^>]*class="[^"]*\b(?:hide-when-compact|collapsed)\b[^"]*"[^>]*>/i;
  let out: string = html;
  let m: RegExpExecArray | null = rx.exec(out);
  while (m !== null) {
    const tag: string = m[1].toLowerCase();
    const tags: RegExp = new RegExp('<(/?)' + tag + '\\b[^>]*>', 'gi');
    tags.lastIndex = m.index;
    let depth: number = 0;
    let end: number = out.length;
    let t: RegExpExecArray | null = tags.exec(out);
    while (t !== null) {
      depth += t[1] === '' ? 1 : -1;
      if (depth === 0) {
        end = t.index + t[0].length;
        break;
      }
      t = tags.exec(out);
    }
    out = out.substring(0, m.index) + out.substring(end);
    m = rx.exec(out);
  }
  return out;
}

// Inline tags go without a trace ("<b>talk page</b>." stays "talk page."); block tags (a listed
// issue's table, a line break) leave a space so neighbouring sentences do not run together.
function stripIssue(html: string): string {
  return html
    .replace(/<style\b[\s\S]*?<\/style>/gi, '')
    .replace(/<\/?(?:div|table|tbody|tr|td|p|br|ul|ol|li)\b[^>]*>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

@Component
export struct PageIssuesTableView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // the presenting ArticleViewController's article — the issues belong to that document
  @Prop articleTitle: string = '';
  @Prop host: string = 'en.wikipedia.org';
  // @objc var issues = [String]() — the stripped page-issue strings of that document.
  // spec stateVar: items <- pageIssues
  @State items: string[] = [];
  // S6: the visual states of the document fetch S4 already wired.
  @State isLoading: boolean = true;
  @State loadError: string = '';
  onClose?: () => void;

  aboutToAppear(): void {
    this.load().catch((e: Error) => {
      console.error('pageIssues: load failed: ' + e.message);
      this.loadError = 'The page issues could not be loaded.';
      this.isLoading = false;
    });
  }

  private async load(): Promise<void> {
    if (this.articleTitle === '') {
      this.isLoading = false;
      return;
    }
    const articleKey: string =
      'https://' + this.host + '/wiki/' + this.articleTitle.replace(/ /g, '_');
    let html: string | null = null;
    try {
      html = await ArticleCacheStore.cachedHtml(articleKey);
    } catch (e) {
      html = null;
    }
    if (html === null || html === '') {
      html = await ArticleService.fetchMobileHtml(this.host, this.articleTitle);
    }
    this.items = extractPageIssues(html);
    this.isLoading = false;
  }

  build() {
    Column() {
      // configureNavigationBar(titleConfig: "Page issues", closeButtonConfig: .plainX leading)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          // Id scoping: this screen is an overlay, so its nodes share the host page's
          // component tree. The source slug is the part after the dot: close_button.
          .id('PageIssuesTableViewController.close_button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            const cb: (() => void) | undefined = this.onClose;
            if (cb !== undefined) {
              cb();
            }
          })
        Text('Page issues')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        // trailing spacer of the same width as the close button, so the title stays
        // optically centred the way the iOS bar renders it
        Row()
          .width(44)
          .height(44)
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      if (this.isLoading) {
        // S6 loading visual — the mobile-html document is still being read.
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('page_issues_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        // S6 empty/error visual — the document carries no maintenance templates.
        Column() {
          Text(this.loadError !== '' ? this.loadError : 'This article has no page issues.')
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .id('page_issues_empty')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
      // tableView: one non-interactive cell per issue (cell.isUserInteractionEnabled = false)
      List() {
        ForEach(this.items, (issue: string, index: number) => {
          ListItem() {
            Text(issue)
              .width('100%')
              .fontSize(17)
              .lineHeight(24)
              .fontColor($r('app.color.theme_text'))
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          }
        }, (issue: string, index: number) => index.toString() + '_' + issue)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      }
    }
    .id('PageIssuesTableViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
