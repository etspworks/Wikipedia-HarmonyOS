// Ported from Wikipedia/Code/EditNoticesView.swift + EditNoticesViewController.swift: a plain-X
// close at the trailing edge, the exclamationmark.circle.fill image, "Edit notices" (bold
// title 1), "Please read before editing", the notices as attributed HTML (text, bold, italics
// and links only, leading and repeated line breaks removed), and the "Always display edit
// notices" switch in the footer, stored in WMFAlwaysDisplayEditNotices (default on).
import { LengthMetrics } from '@kit.ArkUI';
import { htmlRuns, HtmlRun } from '../common/SimpleHtml';
import { Prefs, PrefKeys } from '../common/Prefs';

// the notices as runs: HTML whitespace collapsed, one break where the source had several
export function noticeRuns(notices: string[]): HtmlRun[] {
  const out: HtmlRun[] = [];
  for (const run of htmlRuns(notices.join(''))) {
    if (run.text === '\n') {
      if (out.length > 0 && out[out.length - 1].text !== '\n') {
        out.push(run);
      }
      continue;
    }
    run.text = run.text.replace(/\s+/g, ' ');
    const atLineStart: boolean = out.length === 0 || out[out.length - 1].text === '\n';
    if (atLineStart) {
      run.text = run.text.replace(/^ /, '');
    }
    if (run.text !== '') {
      out.push(run);
    }
  }
  while (out.length > 0 && out[out.length - 1].text === '\n') {
    out.pop();
  }
  return out;
}

@Component
export struct EditNoticesView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  runs: HtmlRun[] = [];
  onClose: () => void = () => {};
  // a link in a notice, relative ones against the site (textView(_:primaryActionFor:))
  onLink: (href: string) => void = () => {};
  @State alwaysDisplay: boolean = Prefs.getBoolean(PrefKeys.alwaysDisplayEditNotices, true);

  build() {
    Column() {
      Row() {
        Blank()
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('edit_notices_close')
        .type(ButtonType.Normal)
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .padding({ top: 16, right: 8 })

      Scroll() {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize(50)
            .fontColor([$r('app.color.theme_text')])
          Text($r('app.string.edit_notices'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })
          Text($r('app.string.edit_notices_please_read'))
            .fontSize(16)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
            .margin({ top: 6 })
          Text() {
            ForEach(this.runs, (run: HtmlRun) => {
              Span(run.text)
                .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
                .fontColor(run.href !== '' ? $r('app.color.theme_link') : $r('app.color.theme_text'))
                .onClick(() => {
                  if (run.href !== '') {
                    this.onLink(run.href);
                  }
                })
            })
          }
          .id('edit_notices_text')
          .width('100%')
          .fontSize(16)
          .lineSpacing(LengthMetrics.vp(3))
          .margin({ top: 32 })
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Row({ space: 20 }) {
        Text($r('app.string.edit_notices_always_display'))
          .layoutWeight(1)
          .fontSize(16)
          .fontColor($r('app.color.theme_text'))
        Toggle({ type: ToggleType.Switch, isOn: this.alwaysDisplay })
          .id('edit_notices_always_display')
          .onChange((isOn: boolean) => {
            this.alwaysDisplay = isOn;
            Prefs.putBoolean(PrefKeys.alwaysDisplayEditNotices, isOn);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }
    .id('EditNoticesView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
