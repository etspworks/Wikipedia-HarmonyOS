// WMFCaptchaViewController (WMFCaptchaViewController.storyboard): "CAPTCHA security check", the
// "Can't see the image? Request account." line (account creation only), the captcha image
// in a bordered box with the refresh and info buttons beside it, then "Enter the text you see
// above" over the CAPTCHA text field. Refresh shows "Obtaining a new CAPTCHA..." and asks the
// host screen for a new captcha (captchaReloadPushed); info opens Special:Captcha/help.
import { router, promptAction } from '@kit.ArkUI';
import { formatParts } from '../common/Plural';

@Component
export struct WMFCaptchaView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // the captcha image path from authmanagerinfo (captchaInfo), relative to the wiki
  @Prop captchaURL: string = '';
  @Prop host: string = 'en.wikipedia.org';
  // captchaHideSubtitle: the login screen hides the Request account line
  @Prop hideSubtitle: boolean = false;
  @Link captchaText: string;
  onReload: () => void = () => {};

  private imageURL(): string {
    if (this.captchaURL.startsWith('http')) {
      return this.captchaURL;
    }
    return 'https://' + this.host + (this.captchaURL.startsWith('/') ? '' : '/') + this.captchaURL;
  }

  private openWeb(url: string): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
  }

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.account_creation_captcha_title'))
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      if (!this.hideSubtitle) {
        Text() {
          Span(formatParts(getContext(this), $r('app.string.account_creation_captcha_cannot_see_image'))[0])
          Span($r('app.string.account_creation_captcha_request_account'))
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.openWeb('https://en.wikipedia.org/wiki/Wikipedia:Request_an_account');
            })
        }
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
      }
      // "Container for borders": image | divider | refresh / divider / info
      Row() {
        Image(this.imageURL())
          .id('captcha_image')
          .layoutWeight(1)
          .height(70)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.White)
        Divider()
          .vertical(true)
          .height(70)
          .color($r('app.color.theme_border'))
        Column() {
          Button() {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_link')])
          }
            .id('captcha_refresh')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(35)
            .onClick(() => {
              promptAction.showToast({ message: getContext(this).resourceManager.getStringSync(
                $r('app.string.account_creation_captcha_obtaining').id) });
              this.onReload();
            })
          Divider()
            .width(48)
            .color($r('app.color.theme_border'))
          Button() {
            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_link')])
          }
            .id('captcha_info')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(35)
            .onClick(() => {
              this.openWeb('https://en.wikipedia.org/wiki/Special:Captcha/help');
            })
        }
      }
      .width('100%')
      .border({ width: 1, color: $r('app.color.theme_border'), radius: 4 })
      .clip(true)
      Text($r('app.string.field_captcha_title'))
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 4 })
      TextInput({ placeholder: $r('app.string.field_captcha_placeholder'), text: this.captchaText })
        .id('captchaField')
        .width('100%')
        .height(36)
        .padding({ left: 0, right: 0 })
        .fontSize(17)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .border({ width: { bottom: 1 }, color: $r('app.color.theme_border') })
        .onChange((value: string) => {
          this.captchaText = value;
        })
    }
    .width('100%')
  }
}
