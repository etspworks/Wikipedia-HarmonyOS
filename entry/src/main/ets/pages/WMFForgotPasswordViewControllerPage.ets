// screen_forgot_password — presentation: modal, hosted by WMFLoginView
// (.bindContentCover). NOT a routed page.
// S3 structure from Wikipedia/Code/WMFForgotPasswordViewController.swift (viewDidLoad + the
// WMFForgotPasswordViewController.xib outlets, confirmed by capture S0177):
//   configureNavigationBar(): title alignment .hidden, leading plain-X close button
//   (capture: Button "Cancel", id close_button). Then the scroll view's form:
//   titleLabel ("Reset password"), subTitleLabel ("Fill in one of the fields below to receive
//   password reset instructions via email"), usernameTitleLabel + usernameField, orLabel
//   ("Or"), emailTitleLabel + emailField, resetPasswordButton ("Reset").
//   The button starts DISABLED and textFieldDidChange enables it as soon as EITHER field
//   holds text (enableProgressiveButton(!username.isEmpty || !email.isEmpty)) — the source's
//   own condition.
// The resetpassword POST goes through svc_auth (AuthService.resetPassword).
// S5/S6 style (capture S0177, 402x874pt): white page, form inset 57pt each side — white 44pt
// circle close at [16,62], then the storyboard's type scale: Headline (17 semibold) "Reset
// password" at y146, Subhead (15) two-line gray subtitle, Caption1 (12) gray label over a
// Body (17) underlined field, a Headline "Or" between the two groups, and the 40pt capsule
// "Reset" at y414 (DISABLED in the capture).
// Id scoping: WMFLoginView mounts this screen as a .bindContentCover overlay, so its nodes
// share ONE ArkUI tree with the login form's. ArkUI ids are global to that tree while the
// iOS outlet names they mirror are per-view-controller, so the shared field slugs collided
// (ArkTS: "The current component id ... is duplicate with ..."). The overlays carry their
// own screen root id as a prefix and the host screen keeps the bare slug; the source slug
// is still exactly the part after the dot.
import { topSafeInset } from '../common/SafeArea';
import { promptAction } from '@kit.ArkUI';
import { AuthService } from '../common/AuthService';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';

@Component
export struct WMFForgotPasswordView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // usernameField.text / emailField.text
  @State username: string = '';
  @State email: string = '';
  // save() keeps the form busy for the length of the request
  @State isSaving: boolean = false;
  // closeButtonPushed(_:) — the host dismisses the cover
  onClose?: () => void;
  // the wiki the resetpassword POST goes to (siteURL) — resolved from the app language
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
      this.host = lang.languageCode + '.wikipedia.org';
    }).catch((e: Error) => {
      console.error('forgot password: app language failed: ' + e.message);
    });
  }

  // enableProgressiveButton(!username.isEmpty || !email.isEmpty)
  private shouldEnableResetButton(): boolean {
    return !this.isSaving && (this.username !== '' || this.email !== '');
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFForgotPasswordViewController.close_button')
        .accessibilityText($r('app.string.action_cancel'))
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          this.closeButtonPushed();
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      Scroll() {
        Column() {
          // titleLabel
          Text($r('app.string.forgot_password_title'))
            .width('100%')
            .fontSize(17)
            .fontWeight(600)
            .fontColor($r('app.color.theme_text'))
          // subTitleLabel
          Text($r('app.string.forgot_password_instructions'))
            .width('100%')
            .fontSize(15)
            .lineHeight(20)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 3 })

          // usernameTitleLabel + usernameField
          Text($r('app.string.field_username_title'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 26 })
          TextInput({ placeholder: $r('app.string.field_username_placeholder'), text: this.username })
            .id('WMFForgotPasswordViewController.usernameField')
            .width('100%')
            .height(28)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .placeholderFont({ size: 17 })
            .caretColor($r('app.color.theme_link'))
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0, top: 0, bottom: 0 })
            .margin({ top: 5 })
            .onChange((value: string) => {
              this.username = value;
            })
          Divider()
            .width('100%')
            .strokeWidth(1)
            .color($r('app.color.theme_secondary_text'))

          // orLabel
          Text($r('app.string.forgot_password_username_or_email_title'))
            .width('100%')
            .fontSize(17)
            .fontWeight(600)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 16 })

          // emailTitleLabel + emailField
          Text($r('app.string.field_email_title'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 16 })
          TextInput({ placeholder: $r('app.string.field_email_placeholder'), text: this.email })
            .id('WMFForgotPasswordViewController.emailField')
            .type(InputType.Email)
            .width('100%')
            .height(28)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .placeholderFont({ size: 17 })
            .caretColor($r('app.color.theme_link'))
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0, top: 0, bottom: 0 })
            .margin({ top: 5 })
            .onChange((value: string) => {
              this.email = value;
            })
          Divider()
            .width('100%')
            .strokeWidth(1)
            .color($r('app.color.theme_secondary_text'))

          // resetPasswordButton (WMFAuthButton)
          Button($r('app.string.forgot_password_button_title'))
            .id('resetPasswordButton')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontSize(17)
            .fontColor(this.shouldEnableResetButton()
              ? $r('app.color.wmf_white') : $r('app.color.gray400'))
            .backgroundColor(this.shouldEnableResetButton()
              ? $r('app.color.theme_link') : $r('app.color.gray200'))
            .margin({ top: 31 })
            .enabled(this.shouldEnableResetButton())
            .onClick(() => {
              this.resetPasswordButtonTapped();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 57, right: 57, top: 30, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('WMFForgotPasswordViewController')
    // Presented as a cover, which draws under the status bar: start below it.
    .padding({ top: topSafeInset() })
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // resetPasswordButtonTapped(withSender:) -> save() -> sendPasswordResetEmail
  private resetPasswordButtonTapped(): void {
    this.save().catch((e: Error) => {
      this.isSaving = false;
      promptAction.showToast({ message: e.message });
    });
  }

  // save(): the resetpassword POST, then showSuccessAlert + dismiss, or the error alert.
  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    try {
      const status: string = await AuthService.resetPassword(
        this.host, this.username !== '' ? this.username : null,
        this.email !== '' ? this.email : null);
      if (status === 'success') {
        promptAction.showToast({ message: $r('app.string.forgot_password_email_sent') });
        this.username = '';
        this.email = '';
        this.closeButtonPushed();
        return;
      }
      promptAction.showToast({ message: $r('app.string.error_unknown') });
    } finally {
      this.isSaving = false;
    }
  }

  private closeButtonPushed(): void {
    const cb: (() => void) | undefined = this.onClose;
    if (cb !== undefined) {
      cb();
    }
  }
}
