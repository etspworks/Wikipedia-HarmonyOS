// screen_reference — presentation: sheet, hosted by ArticleViewControllerPage
// (.bindSheet). NOT a routed page.
// Ported from Wikipedia/Code/ReferenceViewController.swift (+ its ReferenceBackLinksViewController
// subclass): a custom UINavigationBar whose title is "Reference %@" (referenceLinkText, e.g.
// "[1]"), with backToReferenceButton ("reference_detail_back_to_reference", jump to the
// article's reference section) leading and the plain-X close button trailing; the body is the
// citation HTML handed over by the article's JS bridge, and the back-links toolbar
// (previousButton / countLabel / nextButton) steps through the places the citation is used.
// S5: no capture — styled from the source roles + the app baseline tokens (centred
// inline title, link-blue bar buttons, 17/24 body).
import { ArticleService } from '../common/ArticleService';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { decodeEntities } from '../common/WebDocument';
import { formatString } from '../common/Plural';
import { common } from '@kit.AbilityKit';
import { ArticleSegment, parseInlineSegments } from './ArticleViewControllerPage';

// The JS bridge hands the citation html over in the source; this port reads the same
// citations out of the mobile-html document (the `cite_note-*` list items PCS emits).
export class ReferenceEntry {
  id: string = '';                 // cite_note-3
  text: string = '';
  html: string = '';               // the citation body, styles and hidden maintenance spans removed
}

// A PCS reference item is the "[n]" back-link plus div.pcs-ref-body. The body carries the
// citation template's TemplateStyles <style> and CSS-hidden cs1 maintenance spans: read as
// text they filled the panel with ".mw-parser-output cite.citation{...}".
function referenceBodyHtml(itemHtml: string): string {
  const bodyAt: number = itemHtml.indexOf('pcs-ref-body');
  let body: string = bodyAt >= 0 ? itemHtml.substring(itemHtml.indexOf('>', bodyAt) + 1) : itemHtml;
  body = body.replace(/<style[\s\S]*?<\/style>/gi, '');
  body = body.replace(/<span[^>]*class="[^"]*cs1-(?:maint|hidden-error)[^"]*"[^>]*>[\s\S]*?<\/span>/gi, '');
  return body;
}

export function extractReferenceEntries(html: string): ReferenceEntry[] {
  const out: ReferenceEntry[] = [];
  const rx: RegExp = /<li[^>]*id="(cite_note[^"]*)"[^>]*>([\s\S]*?)<\/li>/g;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null && out.length < 200) {
    const body: string = referenceBodyHtml(m[2]);
    const text: string = decodeEntities(body.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();
    if (text !== '') {
      const entry = new ReferenceEntry();
      entry.id = m[1];
      entry.text = text;
      entry.html = body;
      out.push(entry);
    }
    m = rx.exec(html);
  }
  return out;
}

export function extractReferences(html: string): string[] {
  return extractReferenceEntries(html).map((e: ReferenceEntry): string => e.text);
}

@Component
export struct ReferenceView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // the presenting ArticleViewController's article
  @Prop articleTitle: string = '';
  @Prop host: string = 'en.wikipedia.org';
  // The tapped marker: its footnote id (cite_note-3) and label ([3]). The sheet opened on
  // the first reference whatever marker was tapped.
  @Prop referenceAnchor: string = '';
  @Prop referenceLabel: string = '';
  private ids: string[] = [];
  // referenceLinkText — the citation marker the article was tapped on
  @State referenceLinkText: string = '';
  // the reference html of the visible citation
  @State refHtml: string = '';
  // backLinks + index (ReferenceBackLinksViewController)
  @State backLinkCount: number = 0;
  @State backLinkIndex: number = 0;
  // spec stateVar: items <- refHtml (the extracted citation htmls; refHtml holds the visible one)
  @State items: string[] = [];
  // S6: the visual states of the citation fetch S4 already wired.
  @State isLoading: boolean = true;
  @State loadError: string = '';
  onClose?: () => void;
  onJumpToReferenceSection?: () => void;
  // a link in the citation: the article routes it (wiki, external) as it does its own links
  onOpenLink?: (seg: ArticleSegment) => void;
  // the visible citation as runs, its links tappable
  @State segments: ArticleSegment[] = [];

  aboutToAppear(): void {
    this.load().catch((e: Error) => {
      console.error('reference: load failed: ' + e.message);
      this.loadError = getContext(this).resourceManager.getStringSync($r('app.string.fetcher_error_generic'));
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
    const entries: ReferenceEntry[] = extractReferenceEntries(html);
    this.items = entries.map((e: ReferenceEntry): string => e.html);
    this.ids = entries.map((e: ReferenceEntry): string => e.id);
    this.backLinkCount = this.items.length;
    this.showReference(Math.max(this.ids.indexOf(this.referenceAnchor), 0));
    this.isLoading = false;
  }

  // currentReference — the panel body plus its "[n]" marker.
  private showReference(index: number): void {
    if (this.items.length === 0) {
      return;
    }
    const bounded: number = Math.min(Math.max(index, 0), this.items.length - 1);
    this.backLinkIndex = bounded;
    this.refHtml = this.items[bounded];
    this.segments = parseInlineSegments(this.refHtml);
    this.referenceLinkText = this.ids[bounded] === this.referenceAnchor && this.referenceLabel !== ''
      ? this.referenceLabel : '[' + (bounded + 1).toString() + ']';
  }

  private fire(cb: (() => void) | undefined): void {
    if (cb !== undefined) {
      cb();
    }
  }

  build() {
    Column() {
      // customNavigationBar: leading backToReferenceButton, title, trailing close
      Row() {
        Button($r('app.string.reference_section_button_accessibility_label'))
          .id('reference_detail_back_to_reference')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
          .fontColor($r('app.color.theme_link'))
          .padding({ left: 0, right: 8 })
          .onClick(() => {
            this.fire(this.onJumpToReferenceSection);
          })
        Text(formatString(getContext(this) as common.Context, $r('app.string.reference_title'),
          [this.referenceLinkText]))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        // closeButtonPressed -> referenceViewControllerUserDidTapClose (dismisses the panel)
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_link')])
        }
          .id('reference_close')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .padding({ left: 8, right: 0 })
          .onClick(() => {
            this.fire(this.onClose);
          })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16 })
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      if (this.isLoading) {
        // S6 loading visual — the citation is still being read out of the document.
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('reference_loading')
        .width('100%')
        .height(140)
        .justifyContent(FlexAlign.Center)
      } else if (this.refHtml === '') {
        // S6 empty/error visual — no citation matched, or the fetch failed.
        Column() {
          Text(this.loadError !== '' ? this.loadError : getContext(this).resourceManager.getStringSync($r('app.string.fetcher_error_generic')))
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .id('reference_empty')
        .width('100%')
        .height(140)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
      // the citation body
      Scroll() {
        Text() {
          ForEach(this.segments, (seg: ArticleSegment) => {
            if (seg.kind === 'wiki' || seg.kind === 'external') {
              Span(seg.text)
                .fontColor($r('app.color.theme_link'))
                .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
                .fontWeight(seg.bold ? FontWeight.Bold : FontWeight.Normal)
                .onClick(() => {
                  const cb: ((seg: ArticleSegment) => void) | undefined = this.onOpenLink;
                  if (cb !== undefined) {
                    cb(seg);
                  }
                })
            } else {
              Span(seg.text)
                .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
                .fontWeight(seg.bold ? FontWeight.Bold : FontWeight.Normal)
            }
          }, (seg: ArticleSegment, i: number) => i.toString() + seg.text)
        }
          .width('100%')
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_text'))
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      }

      // back-links toolbar — only present when the citation has more than one back link
      if (this.backLinkCount > 1) {
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_link')])
          }
            .id('reference_backlinks_previous')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showReference(this.backLinkIndex - 1);
            })
          // countLabel — "index of count"
          Text((this.backLinkIndex + 1).toString() + '/' + this.backLinkCount.toString())
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_link')])
          }
            .id('reference_backlinks_next')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showReference(this.backLinkIndex + 1);
            })
        }
        .width('100%')
        .height(52)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      }
    }
    .id('ReferenceViewController')
    .width('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
