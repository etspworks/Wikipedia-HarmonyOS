// screen_account_creation — presentation: modal, hosted by WMFLoginView
// (.bindContentCover). NOT a routed page.
// S3 structure from Wikipedia/Code/WMFAccountCreationViewController.swift (viewDidLoad +
// the WMFAccountCreationViewController.xib outlets, confirmed by capture S0175):
//   close_button ("Cancel") in the nav bar, then inside scrollContainer/stackView:
//   titleLabel ("Create a new account"), loginButton (WMFAuthLinkLabel "Already have an
//   account? Log in."), usernameTitleLabel + usernameField + usernameAlertLabel,
//   passwordTitleLabel + passwordField, passwordRepeatTitleLabel + passwordRepeatField +
//   passwordRepeatAlertLabel ("Passwords do not match"), emailTitleLabel ("Email (optional)")
//   + emailField, captchaContainer (WMFCaptchaViewController — added only when the
//   authmanagerinfo response carries a classic captcha), createAccountButton ("Create your
//   account") and hcaptchaFinePrintTextView with its Privacy Policy / Terms of Service links.
//   The temp-accounts toast is added only when authStateIsTemporary.
// The createaccount POST (svc_auth) and the field validation wiring are S4's pass.
// S5/S6 style (capture S0175, 402x874pt): white page, form inset 57pt each side — a white
// 44pt circle close at [16,62], then the storyboard's own type scale: Headline (17 semibold)
// title at y145, Subhead (15) gray+link sub-line, repeated Caption1 (12) gray label over a
// Body (17) underlined field, 34pt from one rule to the next label, the 40pt capsule
// "Create your account" at y535 (DISABLED in the capture) and the centered Caption1 hCaptcha
// fine print with theme_link links.
// Id scoping: WMFLoginView mounts this screen as a .bindContentCover overlay, so its nodes
// share ONE ArkUI tree with the login form's. ArkUI ids are global to that tree while the
// iOS outlet names they mirror are per-view-controller, so the shared field slugs collided
// (ArkTS: "The current component id ... is duplicate with ..."). The overlays carry their
// own screen root id as a prefix and the host screen keeps the bare slug; the source slug
// is still exactly the part after the dot.
import { formatParts } from '../common/Plural';
import { topSafeInset } from '../common/SafeArea';
import { router } from '@kit.ArkUI';
import { AuthService, AccountCreationInfo, LoginResult } from '../common/AuthService';
import { SessionStore } from '../common/SessionStore';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { WMFCurrentUser } from '../model/WMFCurrentUser';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';
import { WMFCaptchaView } from '../components/WMFCaptchaView';

@Component
export struct WMFAccountCreationView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // usernameField / passwordField / passwordRepeatField / emailField
  @State username: string = '';
  @State password: string = '';
  @State passwordRepeat: string = '';
  @State email: string = '';
  // usernameAlertLabel — hidden while empty (checkingUsernameAvailability result)
  @State usernameAlert: string = '';
  // passwordRepeatAlertLabel — "Passwords do not match"
  @State passwordRepeatAlert: string = '';
  // captcha?.classicInfo != nil -> captchaContainer holds the captcha child controller
  @State captchaRequired: boolean = false;
  @State captchaText: string = '';
  // WMFCaptcha.classicInfo.captchaURL — the image the captcha view shows
  @State captchaURL: string = '';
  // authManager.authStateIsTemporary -> WMFTempAccountsToastHostingController
  @State isTempAccount: boolean = false;
  // save() keeps the form disabled for the length of the request
  @State isSaving: boolean = false;
  // closeButtonPushed(_:) — the host dismisses the cover
  onClose?: () => void;
  // WMFCaptchaViewController.captcha.classicInfo.captchaID, carried into createaccount
  private captchaID: string | null = null;
  // the wiki the createaccount POST goes to (siteURL) — resolved from the app language
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
      this.host = lang.languageCode + '.wikipedia.org';
      this.refreshCaptcha();
    }).catch((e: Error) => {
      console.error('account creation: app language failed: ' + e.message);
      this.refreshCaptcha();
    });
  }

  // enableProgressiveButtonIfNecessary(): username + password + matching repeat.
  private shouldEnableCreateAccountButton(): boolean {
    return !this.isSaving && this.username !== '' && this.password !== ''
      && this.passwordRepeat !== '' && this.password === this.passwordRepeat;
  }

  private hcaptchaParts(): string[] {
    const parts: string[] = formatParts(getContext(this), $r('app.string.account_creation_hcaptcha_notice'));
    return [parts[0] ?? '', parts[1] ?? '', parts[2] ?? ''];
  }

  // Plain-string slots (alerts, toasts, computed labels) resolve their catalogue value here.
  private text(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res);
    } catch (e) {
      return '';
    }
  }

  build() {
    Column() {
      // navigationItem close button (capture S0175: Button "Cancel", id close_button)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFAccountCreationViewController.close_button')
        .accessibilityText($r('app.string.action_cancel'))
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          this.closeButtonPushed();
        })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })

      // WMFTempAccountsToastHostingController — only while the auth state is temporary
      if (this.isTempAccount) {
        Row() {
          Text($r('app.string.temp_account_warning_title'))
            .layoutWeight(1)
            .fontSize(15)
            .fontColor($r('app.color.theme_text'))
          Text($r('app.string.temp_account_toast_read_more_title'))
            .id('read_more')
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.didTapReadMore();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      }

      Scroll() {
        Column() {
          // titleLabel
          Text($r('app.string.account_creation_title'))
            .width('100%')
            .fontSize(17)
            .fontWeight(600)
            .fontColor($r('app.color.theme_text'))

          // loginButton (WMFAuthLinkLabel + tap recognizer -> loginButtonPushed)
          Text() {
            Span(formatParts(getContext(this), $r('app.string.account_creation_have_account'))[0])
              .fontColor($r('app.color.theme_secondary_text'))
            Span($r('app.string.account_creation_log_in'))
              .fontColor($r('app.color.theme_link'))
          }
          .id('already_have_an')
          .width('100%')
          .fontSize(15)
          .margin({ top: 3 })
          .onClick(() => {
            this.loginButtonPushed();
          })

          // usernameTitleLabel + usernameField + usernameAlertLabel
          Text($r('app.string.field_username_title'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 26 })
          TextInput({ placeholder: $r('app.string.field_username_placeholder'), text: this.username })
            .id('WMFAccountCreationViewController.usernameField')
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
          if (this.usernameAlert !== '') {
            Text(this.usernameAlert)
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.theme_destructive'))
              .margin({ top: 4 })
          }

          // passwordTitleLabel + passwordField
          Text($r('app.string.field_password_title'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 34 })
          TextInput({ placeholder: $r('app.string.field_password_placeholder'), text: this.password })
            .id('WMFAccountCreationViewController.passwordField')
            .type(InputType.Password)
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
              this.password = value;
            })
          Divider()
            .width('100%')
            .strokeWidth(1)
            .color($r('app.color.theme_secondary_text'))

          // passwordRepeatTitleLabel + passwordRepeatField + passwordRepeatAlertLabel
          Text($r('app.string.field_password_confirm_title'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 34 })
          TextInput({ placeholder: $r('app.string.field_password_confirm_placeholder'), text: this.passwordRepeat })
            .id('passwordRepeatField')
            .type(InputType.Password)
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
              this.passwordRepeat = value;
              // passwordFieldsMatch() -> passwordRepeatAlertLabel
              this.passwordRepeatAlert =
                value !== '' && value !== this.password ? this.text($r('app.string.field_alert_password_confirm_mismatch')) : '';
            })
          Divider()
            .width('100%')
            .strokeWidth(1)
            .color($r('app.color.theme_secondary_text'))
          if (this.passwordRepeatAlert !== '') {
            Text(this.passwordRepeatAlert)
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.theme_destructive'))
              .margin({ top: 4 })
          }

          // emailTitleLabel + emailField
          Text($r('app.string.field_email_title_optional'))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 34 })
          TextInput({ placeholder: $r('app.string.field_email_placeholder'), text: this.email })
            .id('WMFAccountCreationViewController.emailField')
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

          // captchaContainer — the classic-captcha child controller's field
          if (this.captchaRequired) {
            Column() {
              WMFCaptchaView({
                captchaURL: this.captchaURL,
                host: this.host,
                hideSubtitle: false,
                captchaText: $captchaText,
                onReload: (): void => {
                  this.refreshCaptcha();
                }
              })
            }
            .width('100%')
            .margin({ top: 26 })
          }

          // createAccountButton (WMFAuthButton)
          Button($r('app.string.account_creation_create_account'))
            .id('createAccountButton')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontSize(17)
            .fontColor(this.shouldEnableCreateAccountButton()
              ? $r('app.color.wmf_white') : $r('app.color.gray400'))
            .backgroundColor(this.shouldEnableCreateAccountButton()
              ? $r('app.color.theme_link') : $r('app.color.gray200'))
            .margin({ top: 34 })
            .enabled(this.shouldEnableCreateAccountButton())
            .onClick(() => {
              this.createAccountButtonTapped();
            })

          // hcaptchaFinePrintTextView — hidden when a classic captcha is shown
          if (!this.captchaRequired) {
            Column() {
              // One sentence with the two links as Spans, so a translation wraps as prose
              // instead of the English three-piece layout.
              Text() {
                Span(this.hcaptchaParts()[0])
                  .fontColor($r('app.color.theme_secondary_text'))
                Span($r('app.string.account_creation_hcaptcha_privacy'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.theme_link'))
                  .onClick(() => {
                    this.openWeb('https://www.hcaptcha.com/privacy');
                  })
                Span(this.hcaptchaParts()[1])
                  .fontColor($r('app.color.theme_secondary_text'))
                Span($r('app.string.account_creation_hcaptcha_terms'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.theme_link'))
                  .onClick(() => {
                    this.openWeb('https://www.hcaptcha.com/terms');
                  })
                Span(this.hcaptchaParts()[2])
                  .fontColor($r('app.color.theme_secondary_text'))
              }
              .width('100%')
              .fontSize(12)
              .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 20 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 57, right: 57, top: 29, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('WMFAccountCreationViewController')
    // Presented as a cover, which draws under the status bar: start below it.
    .padding({ top: topSafeInset() })
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // createAccountButtonTapped(withSender:) -> save()
  private createAccountButtonTapped(): void {
    this.save().catch((e: Error) => {
      this.usernameAlert = e.message;
      this.isSaving = false;
    });
  }

  // save() (WMFAccountCreationViewController.swift): the createaccount POST, then the
  // success / failure branches; the captcha is refreshed on every failure.
  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    this.usernameAlert = '';
    try {
      const result: LoginResult = await AuthService.createAccount(
        this.host, this.username, this.password, this.passwordRepeat,
        this.email !== '' ? this.email : null,
        this.captchaID, this.captchaText !== '' ? this.captchaText : null);
      if (result.succeeded) {
        // loginSuccessCompletion: the new account is signed in, then the form dismisses.
        await this.adoptCurrentUser();
        this.password = '';
        this.passwordRepeat = '';
        this.captchaText = '';
        this.closeButtonPushed();
        return;
      }
      this.usernameAlert = result.message ?? this.text($r('app.string.error_unknown'));
      await this.getCaptcha();
    } finally {
      this.isSaving = false;
    }
  }

  // WMFCurrentUserFetcher — the account that was just created becomes the session user.
  private async adoptCurrentUser(): Promise<void> {
    const user: WMFCurrentUser | null = await AuthService.fetchCurrentUser(this.host);
    if (user !== null) {
      SessionStore.setCurrentUser(user);
    }
  }

  // getCaptcha() — the authmanagerinfo (amirequestsfor=create) captcha this form must answer.
  private async getCaptcha(): Promise<void> {
    const info: AccountCreationInfo = await AuthService.fetchAccountCreationInfo(this.host);
    this.captchaID = info.captchaID;
    this.captchaURL = info.captchaInfo ?? '';
    this.captchaRequired = info.captchaID !== null;
    this.captchaText = '';
  }

  private refreshCaptcha(): void {
    this.getCaptcha().catch((e: Error) => {
      console.error('account creation: captcha fetch failed: ' + e.message);
    });
  }

  // loginButtonPushed(_:) — dismisses and presents WMFLoginViewController (its host)
  private loginButtonPushed(): void {
    this.closeButtonPushed();
  }

  // WMFTempAccountsToastViewModel.didTapReadMore -> TempAccountSheetCoordinator
  private didTapReadMore(): void {
    router.pushUrl({ url: 'pages/TempAccountsSettingsViewControllerPage' });
  }

  // the fine-print links open in the in-app web view
  private openWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private closeButtonPushed(): void {
    const cb: (() => void) | undefined = this.onClose;
    if (cb !== undefined) {
      cb();
    }
  }
}
