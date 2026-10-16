// Ported from Wikipedia/Code/TempAccountExpiryViewController.swift: "Temporary Account" over the
// temp-account explanation ("You are using a temporary account." in bold, the 90-day expiry,
// then a paragraph break and the log-in prompt) and a filled "Log in or create account" button
// that opens Log in. Pushed from the launch toast's Learn more.
import { router } from '@kit.ArkUI';
import { formatParts } from '../common/Plural';

@Entry
@Component
struct TempAccountExpiryViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('BackButton')
          .type(ButtonType.Normal)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .width(44)
          .height(44)
          .borderRadius(22)
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.back();
          })
        Text($r('app.string.temporary_account'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Blank()
          .width(44)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // informationLabel: $1 bold open, $2 bold close, $3 the paragraph break
      Text() {
        Span(formatParts(getContext(this), $r('app.string.temp_account_alert_read_more_information'))[1])
          .fontWeight(FontWeight.Bold)
        Span(formatParts(getContext(this), $r('app.string.temp_account_alert_read_more_information'))[2] + '\n\n')
        Span(formatParts(getContext(this), $r('app.string.temp_account_alert_read_more_information'))[3])
      }
        .id('temp_account_information')
        .width('100%')
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
        .padding({ left: 16, right: 16, top: 16 })

      // logInButton
      Row() {
        Button($r('app.string.reading_list_login_or_create_account_button_title'))
          .id('temp_account_login')
          .type(ButtonType.Normal)
          .width('100%')
          .height(44)
          .borderRadius(8)
          .fontSize(17)
          .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .backgroundColor($r('app.color.theme_link'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
              console.error('temp account: login route failed: ' + e.message);
            });
          })
      }
      .width('100%')
      .padding({ left: 13, right: 13 })
      .margin({ top: 20 })
    }
    .id('TempAccountExpiryViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
