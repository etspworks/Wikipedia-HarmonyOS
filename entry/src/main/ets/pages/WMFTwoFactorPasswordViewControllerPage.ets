// screen_two_factor_password — presentation: modal, hosted by WMFLoginView
// (.bindContentCover). NOT a routed page.
// S3 structure from Wikipedia/Code/WMFTwoFactorPasswordViewController.swift (the xib outlets
// + the `displayMode` didSet, confirmed by captures S0179/S0180):
//   close_button ("Cancel"), titleLabel ("Log in to your account"), subTitleLabel ("Please
//   enter two factor verification code"), tokenLabel, then the displayMode branch —
//   .shortNumeric shows oathTokenFieldsStackView (the six single-character oathTokenFields,
//   label "Verification code") and hides backupOathTokenField, while .longAlphaNumeric shows
//   backupOathTokenField (label "Backup code") and hides the stack view. displayModeToggle
//   flips between them and re-labels itself "Use one of your backup codes" /
//   "Use verification code". tokenAlertLabel sits under the fields, and loginButton
//   ("Continue log in") is enabled by areRequiredFieldsPopulated() — every OATH field filled,
//   or a non-empty backup code.
// isEmailAuth (needsEmailAuthToken): .shortAlphanumeric — backupOathTokenField labelled "Email
// code", no toggle, "Please enter email verification code".
// The clientlogin resubmission goes through svc_auth (AuthService.login), which sends the code
// as both OATHToken and token, as the source does.
// S5/S6 style (captures S0179/S0180, 402x874pt): white page, form inset 57pt each side —
// white 44pt circle close at [16,62], then the storyboard's type scale: Headline (17
// semibold) title at y146, Subhead (15) gray subtitle, Caption1 (12) gray token label, then
// either six 40pt-wide Headline OATH cells (10pt apart, y234-262) or the single full-width
// Body backup field, the Subhead theme_link toggle at y278 and the 40pt capsule
// "Continue log in" at y322 (DISABLED in both captures).
import { topSafeInset } from '../common/SafeArea';
import { AuthService, LoginResult } from '../common/AuthService';
import { SessionStore } from '../common/SessionStore';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { WMFCurrentUser } from '../model/WMFCurrentUser';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';

@Component
export struct WMFTwoFactorPasswordView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // displayMode: 'shortNumeric' (oathTokenFields) | 'longAlphaNumeric' (backupOathTokenField)
  // | 'shortAlphanumeric' (backupOathTokenField as the emailed code)
  @State displayMode: string = 'shortNumeric';
  // oathTokenFields — six single-character fields
  @State token0: string = '';
  @State token1: string = '';
  @State token2: string = '';
  @State token3: string = '';
  @State token4: string = '';
  @State token5: string = '';
  // backupOathTokenField
  @State backupToken: string = '';
  // tokenAlertLabel — hidden while empty
  @State tokenAlert: string = '';
  @State isSaving: boolean = false;
  // cancelAction — the host dismisses the cover
  onClose?: () => void;
  // loginSuccessCompletion: the host closes the whole login, not only this cover
  onLoginSuccess?: () => void;
  // userName / password / captchaID / captchaWord — the credentials of the login attempt
  // that came back status "UI"; the host sets them, so they are @Prop (never plain members).
  @Prop userName: string = '';
  @Prop password: string = '';
  @Prop captchaID: string = '';
  @Prop captchaWord: string = '';
  // isEmailAuth: the server asked for the code EmailAuth emailed (needsEmailAuthToken), not
  // an authenticator code — one "Email code" field, no backup-code toggle.
  @Prop isEmailAuth: boolean = false;
  // the wiki the clientlogin resubmission goes to — resolved from the app language
  private host: string = 'en.wikipedia.org';

  aboutToAppear(): void {
    if (this.isEmailAuth) {
      this.displayMode = 'shortAlphanumeric';
    }
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
      this.host = lang.languageCode + '.wikipedia.org';
    }).catch((e: Error) => {
      console.error('two factor: app language failed: ' + e.message);
    });
  }

  // token() — the six OATH fields joined, or the backup code.
  private token(): string {
    if (this.displayMode !== 'shortNumeric') {
      return this.backupToken;
    }
    return this.token0 + this.token1 + this.token2 + this.token3 + this.token4 + this.token5;
  }

  // tokenLabel per displayMode
  private tokenLabelText(): string {
    if (this.displayMode === 'shortAlphanumeric') {
      return this.text($r('app.string.field_backup_token_title_email'));
    }
    return this.text(this.displayMode === 'longAlphaNumeric' ? $r('app.string.field_backup_token_title') : $r('app.string.field_token_title'));
  }

  // displayModeToggle per displayMode
  private toggleText(): string {
    return this.displayMode === 'longAlphaNumeric'
      ? this.text($r('app.string.two_factor_login_with_regular_code'))
      : this.text($r('app.string.two_factor_login_with_backup_code'));
  }

  // areRequiredFieldsPopulated()
  private areRequiredFieldsPopulated(): boolean {
    if (this.displayMode !== 'shortNumeric') {
      return this.backupToken !== '';
    }
    return this.token0 !== '' && this.token1 !== '' && this.token2 !== ''
      && this.token3 !== '' && this.token4 !== '' && this.token5 !== '';
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
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFTwoFactorPasswordViewController.close_button')
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
          Text($r('app.string.two_factor_login_title'))
            .width('100%')
            .fontSize(17)
            .fontWeight(600)
            .fontColor($r('app.color.theme_text'))
          // subTitleLabel
          Text(this.isEmailAuth ? $r('app.string.two_factor_email_login_instructions')
            : $r('app.string.two_factor_login_instructions'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 3 })
          // tokenLabel
          Text(this.tokenLabelText())
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 26 })

          if (this.displayMode !== 'shortNumeric') {
            // backupOathTokenField
            TextInput({ text: this.backupToken })
              .id('backupOathTokenField')
              .width('100%')
              .height(28)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .caretColor($r('app.color.theme_link'))
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .padding({ left: 0, right: 0, top: 0, bottom: 0 })
              .margin({ top: 3 })
              .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
              .onChange((value: string) => {
                this.backupToken = value;
              })
          } else {
            // oathTokenFieldsStackView — six single-character token fields; only the first
            // carries the source slug so the id stays unique within the page.
            Row({ space: 10 }) {
              TextInput({ text: this.token0 })
                .id('tokenFields')
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token0 = value;
                })
              TextInput({ text: this.token1 })
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token1 = value;
                })
              TextInput({ text: this.token2 })
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token2 = value;
                })
              TextInput({ text: this.token3 })
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token3 = value;
                })
              TextInput({ text: this.token4 })
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token4 = value;
                })
              TextInput({ text: this.token5 })
                .type(InputType.Number)
                .maxLength(1)
                .layoutWeight(1)
                .height(28)
                .fontSize(17)
                .fontWeight(600)
                .fontColor($r('app.color.theme_text'))
                .textAlign(TextAlign.Center)
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .border({ width: { bottom: 1 }, color: $r('app.color.theme_secondary_text') })
                .onChange((value: string) => {
                  this.token5 = value;
                })
            }
            .width('100%')
            .margin({ top: 3 })
          }

          // tokenAlertLabel
          if (this.tokenAlert !== '') {
            Text(this.tokenAlert)
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.theme_destructive'))
              .margin({ top: 4 })
          }

          // displayModeToggle (UILabel + tap recognizer -> displayModeToggleTapped); hidden
          // for an emailed code
          if (!this.isEmailAuth) {
            Text(this.toggleText())
              .id('use_one_of_your')
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.theme_link'))
              .margin({ top: 16 })
              .onClick(() => {
                this.displayModeToggleTapped();
              })
          }

          // loginButton (WMFAuthButton)
          Button(this.isEmailAuth ? $r('app.string.two_factor_email_login_continue')
            : $r('app.string.two_factor_login_continue'))
            .id('continue_log_in')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontSize(17)
            .fontColor(!this.isSaving && this.areRequiredFieldsPopulated()
              ? $r('app.color.wmf_white') : $r('app.color.gray400'))
            .backgroundColor(!this.isSaving && this.areRequiredFieldsPopulated()
              ? $r('app.color.theme_link') : $r('app.color.gray200'))
            .margin({ top: 26 })
            .enabled(!this.isSaving && this.areRequiredFieldsPopulated())
            .onClick(() => {
              this.loginButtonTapped();
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
    .id('WMFTwoFactorPasswordViewController')
    // Presented as a cover, which draws under the status bar: start below it.
    .padding({ top: topSafeInset() })
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // displayModeToggleTapped(_:) — flips shortNumeric <-> longAlphaNumeric and clears the
  // fields, exactly as the displayMode didSet does.
  private displayModeToggleTapped(): void {
    this.displayMode = this.displayMode === 'longAlphaNumeric' ? 'shortNumeric' : 'longAlphaNumeric';
    this.clearTokens();
  }

  private clearTokens(): void {
    this.token0 = '';
    this.token1 = '';
    this.token2 = '';
    this.token3 = '';
    this.token4 = '';
    this.token5 = '';
    this.backupToken = '';
    this.tokenAlert = '';
  }

  // loginButtonTapped(withSender:) -> save()
  private loginButtonTapped(): void {
    this.save().catch((e: Error) => {
      this.tokenAlert = e.message;
      this.isSaving = false;
    });
  }

  // save() (WMFTwoFactorPasswordViewController.swift:326) — resubmits clientlogin with the
  // OATH token; success signs the session in and dismisses, failure shows tokenAlertLabel.
  private async save(): Promise<void> {
    if (this.isSaving || !this.areRequiredFieldsPopulated()) {
      return;
    }
    this.isSaving = true;
    this.tokenAlert = '';
    try {
      const result: LoginResult = await AuthService.login(
        this.host, this.userName, this.password, null, this.token(),
        this.captchaID !== '' ? this.captchaID : null,
        this.captchaWord !== '' ? this.captchaWord : null);
      if (result.succeeded) {
        const user: WMFCurrentUser | null = await AuthService.fetchCurrentUser(this.host);
        if (user !== null) {
          SessionStore.setCurrentUser(user);
        }
        this.clearTokens();
        const done: (() => void) | undefined = this.onLoginSuccess;
        if (done !== undefined) {
          done();
        } else {
          this.closeButtonPushed();
        }
        return;
      }
      this.tokenAlert = result.message ?? this.text($r('app.string.error_unknown'));
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
