// screen_fundraising_announcement_panel — presentation: modal over the article
// (ArticleViewControllerPage coverBuilder). NOT a routed page.
// Ported from Wikipedia/Code/FundraisingAnnouncementPanel.swift (FundraisingAnnouncementPanel
// ViewController, a ScrollableEducationPanelViewController, .updatedStyle): a card 90% of
// the width over the dimmed article, the close X, the campaign text (subheadingHTML, natural
// alignment), then the filled primary button (actions[0], "Donate now"), the secondary
// (actions[1] "Maybe later" while it may still be shown, else actions[2] "I already donated")
// and, with Maybe later shown, the optional actions[2]; the footer HTML (donor policy link).
// Tapping outside dismisses (dismissWhenTappedOutside).
import { CampaignAsset } from '../common/FundraisingCampaignStore';
import { htmlRuns, HtmlRun } from '../common/SimpleHtml';

@Component
export struct FundraisingAnnouncementPanelView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  asset: CampaignAsset = new CampaignAsset();
  // showOptionalButton: Maybe later is offered (not the campaign's last day)
  showOptionalButton: boolean = true;
  onPrimary: () => void = () => {};
  onSecondary: () => void = () => {};
  onOptional: () => void = () => {};
  // traceableDismissHandler(.tappedClose)
  onClose: () => void = () => {};
  // dismissed by a tap outside: nothing recorded
  onDismiss: () => void = () => {};
  onFooterLink: (url: string) => void = () => {};

  private actionTitle(index: number): string {
    return index < this.asset.actions.length ? this.asset.actions[index].title : '';
  }

  @Builder
  html(html: string, size: number, color: ResourceColor, linkable: boolean) {
    Text() {
      ForEach(htmlRuns(html), (run: HtmlRun) => {
        Span(run.text)
          .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
          .fontColor(run.href !== '' ? $r('app.color.theme_link') : color)
          .onClick(() => {
            if (linkable && run.href !== '') {
              this.onFooterLink(run.href);
            }
          })
      })
    }
    .width('100%')
    .fontSize(size)
    .lineHeight(size * 1.4)
    .fontColor(color)
  }

  build() {
    Stack() {
      // the dimmed background: a tap outside the card dismisses
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.onDismiss();
        })
      Column({ space: 10 }) {
        Row() {
          Blank()
          // the close button: a filled grey circle with the x
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.gray400')])
          }
            .id('announcement_close')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(36)
            .height(36)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        Scroll() {
          this.html(this.asset.textHtml, 15, $r('app.color.theme_text'), false)
        }
        .width('100%')
        .constraintSize({ maxHeight: 380 })
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
        Button(this.actionTitle(0))
          .id('announcement_action')
          .type(ButtonType.Normal)
          .borderRadius(8)
          .width('100%')
          .height(48)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.theme_link'))
          .margin({ top: 10 })
          .onClick(() => {
            this.onPrimary();
          })
        Button(this.showOptionalButton ? this.actionTitle(1) : this.actionTitle(2))
          .id('announcement_secondary')
          .type(ButtonType.Normal)
          .width('100%')
          .height(40)
          .backgroundColor(Color.Transparent)
          .fontSize(16)
          .fontColor($r('app.color.theme_link'))
          .onClick(() => {
            this.onSecondary();
          })
        if (this.showOptionalButton) {
          Button(this.actionTitle(2))
            .id('announcement_optional')
            .type(ButtonType.Normal)
            .width('100%')
            .height(40)
            .backgroundColor(Color.Transparent)
            .fontSize(16)
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.onOptional();
            })
        }
        Divider()
          .color($r('app.color.theme_border'))
          .margin({ top: 6, bottom: 6 })
        this.html(this.asset.footerHtml, 13, $r('app.color.theme_secondary_text'), true)
      }
      .id('FundraisingAnnouncementPanelViewController')
      .width('90%')
      .padding({ left: 20, right: 20, top: 8, bottom: 20 })
      .borderRadius(16)
      // isUrgent: the campaign panel's red outline
      .border({ width: 2, color: $r('app.color.red700'), radius: 16 })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
