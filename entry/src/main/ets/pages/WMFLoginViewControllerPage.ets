// screen_login — presentation: modal. NOW A ROUTED PAGE (see LoginPage at the foot of this
// file). It used to be a .bindContentCover on WMFProfileView's root, which already carried a
// second bindContentCover for Year in Review: a node honours only ONE modal binding, so the
// later call won and the login cover was dead. Routing it also takes the four auth overlays
// out of a cover-inside-a-sheet, which is the nesting that left other screens half-built.
// Ported from Wikipedia/Code/WMFLoginViewController.swift (viewDidLoad + the
// WMFLoginViewController.xib outlets): close_button in the nav bar, then, inside the
// scrollContainer, titleLabel ("Log in to your account"), createAccountButton
// ("Don't have an account? Join Wikipedia."), usernameTitleLabel + usernameField,
// passwordTitleLabel + passwordField + passwordAlertLabel, forgotPasswordButton,
// captchaContainer (WMFCaptchaViewController, added only when a captcha is required)
// and loginButton.
// Hosts overlays: WMFAccountCreationView, WMFForgotPasswordView,
// WMFTwoFactorPasswordView, WMFChangePasswordView (modal covers).
// S5: styled from captured S0171 — white modal, white-circle close chrome, and the form on
// the iOS readableContentGuide column (288pt wide, centred) with underlined fields and the
// pill Log in button.
//
// NOTE: this screen's controlInventory carries a control "w" (sourceRef "w"). That is the
// iOS on-screen keyboard's `w` key, recorded because the capture (S0171) settled with the
// keyboard raised — WMFLoginViewController defines no such control. Per THE ONE INVARIANT
// the source wins, so it is not rendered here.
import { formatParts } from '../common/Plural';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WMFAccountCreationView } from './WMFAccountCreationViewControllerPage';
import { WMFForgotPasswordView } from './WMFForgotPasswordViewControllerPage';
import { WMFTwoFactorPasswordView } from './WMFTwoFactorPasswordViewControllerPage';
import { WMFChangePasswordView } from './WMFChangePasswordViewControllerPage';
import { AuthService, AccountCreationInfo, LoginResult } from '../common/AuthService';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { Database } from '../common/Database';
import { Prefs } from '../common/Prefs';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';
import { WMFCaptchaView } from '../components/WMFCaptchaView';

@Component
export struct WMFLoginView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // ONE bindContentCover per node: repeated bindContentCover calls override each other, so
  // the four auth overlays share one flag plus a kind discriminator, branched in
  // coverBuilder. Chained, only the last binding (change password) was ever live and
  // "Join Wikipedia", "Forgot your password?" and the 2FA step all did nothing.
  @State showCover: boolean = false;
  @State activeCover: string = '';
  // spec stateVars
  @State username: string = '';
  @State password: string = '';
  // svc_auth.clientLogin() response status ('' | 'PASS' | 'FAIL' | 'UI')
  @State loginStatus: string = '';
  // WMFCaptchaViewController is only meaningful once the API demands a captcha
  // (captchaContainer stays empty otherwise).
  @State captchaRequired: boolean = false;
  @State captchaText: string = '';
  // WMFCaptcha.classicInfo.captchaURL — the image the captcha view shows
  @State captchaURL: string = '';
  // showTwoFactorViewController(isEmailAuth:)
  @State twoFactorIsEmailAuth: boolean = false;
  // passwordAlertLabel — hidden while empty
  @State passwordAlert: string = '';
  // the sheet's dismiss callback (loginDismissedCompletion)
  onClose?: () => void;
  // WMFCaptchaViewController.captcha.classicInfo.captchaID, carried into clientlogin
  private captchaID: string | null = null;
  // the wiki the login posts to (siteURL) — resolved from the app language
  private host: string = 'en.wikipedia.org';
  // save(): setViewControllerUserInteraction(enabled:false) + the sticky "Logging in..."
  // toast for the length of the request — @State so the form actually re-renders.
  @State isSaving: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    Database.init(ctx).then(() => {
      LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
        this.host = lang.languageCode + '.wikipedia.org';
      }).catch((e: Error) => {
        console.error('login: app language failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('login: db init failed: ' + e.message);
    });
  }

  // All four hosted overlays behind the single bindContentCover, branched by activeCover.
  @Builder
  coverBuilder() {
    if (this.activeCover === 'accountCreation') {
      WMFAccountCreationView({ onClose: (): void => { this.showCover = false; } })
    } else if (this.activeCover === 'forgotPassword') {
      WMFForgotPasswordView({ onClose: (): void => { this.showCover = false; } })
    } else if (this.activeCover === 'twoFactorPassword') {
      this.twoFactorPasswordBuilder()
    } else if (this.activeCover === 'changePassword') {
      this.changePasswordBuilder()
    }
  }

  @Builder
  twoFactorPasswordBuilder() {
    WMFTwoFactorPasswordView({
      userName: this.username,
      password: this.password,
      captchaID: this.captchaID ?? '',
      captchaWord: this.captchaText,
      isEmailAuth: this.twoFactorIsEmailAuth,
      onClose: (): void => { this.showCover = false; },
      onLoginSuccess: (): void => { this.loginSucceeded(); }
    })
  }

  @Builder
  changePasswordBuilder() {
    WMFChangePasswordView({
      userName: this.username,
      onClose: (): void => { this.showCover = false; },
      onLoginSuccess: (): void => { this.loginSucceeded(); }
    })
  }

  build() {
    Column() {
      // navigationItem.leftBarButtonItem -> closeButtonPushed (the sheet's dismiss)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
          // Id scoping: this screen is an overlay, so its nodes share the host page's
          // component tree. The source slug is the part after the dot: close_button.
          .id('WMFLoginViewController.close_button')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.closeButtonPushed();
          })
        Blank()
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20 })

      Scroll() {
        Column() {
          // titleLabel
          Text($r('app.string.login_title'))
            .width('100%')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))

          // createAccountButton (WMFAuthLinkLabel + tap recognizer)
          Text() {
            Span(this.noAccountParts()[0])
              .fontColor($r('app.color.theme_secondary_text'))
            Span($r('app.string.login_join_wikipedia'))
              .fontColor($r('app.color.theme_link'))
            Span(this.noAccountParts()[1])
              .fontColor($r('app.color.theme_secondary_text'))
          }
            .id('don_t_have_an')
            .width('100%')
            .fontSize(17)
            .margin({ top: 3 })
            .onClick(() => {
              this.openAccountCreation();
            })

          // usernameTitleLabel + usernameField
          Text($r('app.string.field_username_title'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 26 })
          TextInput({ placeholder: $r('app.string.field_username_placeholder'), text: this.username })
            .id('usernameField')
            .width('100%')
            .height(36)
            .padding({ left: 0, right: 0 })
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .placeholderFont({ size: 17 })
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .border({ width: { bottom: 1 }, color: $r('app.color.theme_border') })
            .margin({ top: 6 })
            .onChange((value: string) => {
              this.username = value;
            })

          // passwordTitleLabel + passwordField
          Text($r('app.string.field_password_title'))
            .width('100%')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 19 })
          TextInput({ placeholder: $r('app.string.field_password_placeholder'), text: this.password })
            .id('passwordField')
            .type(InputType.Password)
            .width('100%')
            .height(36)
            .padding({ left: 0, right: 0 })
            .fontSize(17)
            .fontColor(this.passwordAlert !== ''
              ? $r('app.color.theme_destructive') : $r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .placeholderFont({ size: 17 })
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .border({ width: { bottom: 1 }, color: $r('app.color.theme_border') })
            .margin({ top: 6 })
            .onChange((value: string) => {
              this.password = value;
            })

          // passwordAlertLabel
          if (this.passwordAlert !== '') {
            Text(this.passwordAlert)
              .width('100%')
              .fontSize(15)
              .fontColor($r('app.color.theme_destructive'))
              .margin({ top: 8 })
          }

          // forgotPasswordButton (UILabel + tap recognizer)
          Text($r('app.string.login_forgot_password'))
            .id('forgot_your_password')
            .width('100%')
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .margin({ top: 14 })
            .onClick(() => {
              this.openForgotPassword();
            })

          // captchaContainer — the captcha child controller's field, present only when
          // the clientlogin response demanded one.
          if (this.captchaRequired) {
            Column() {
              WMFCaptchaView({
                captchaURL: this.captchaURL,
                host: this.host,
                hideSubtitle: true,
                captchaText: $captchaText,
                onReload: (): void => {
                  this.getCaptcha();
                }
              })
            }
            .width('100%')
            .margin({ top: 16 })
          }

          // loginButton -> loginButtonTapped -> save(). WMFAuthButton renders its
          // shouldProgressiveButtonBeEnabled() state (username + password populated) as the
          // filled/dimmed fill — the source's own condition, not an invented guard.
          Button($r('app.string.main_menu_account_login'))
            .id('loginButton')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontSize(17)
            .enabled(!this.isSaving && this.username !== '' && this.password !== '')
            .backgroundColor(!this.isSaving && this.username !== '' && this.password !== ''
              ? $r('app.color.theme_link') : $r('app.color.gray100'))
            .fontColor(!this.isSaving && this.username !== '' && this.password !== ''
              ? $r('app.color.wmf_white') : $r('app.color.theme_secondary_text'))
            .margin({ top: 34 })
            .onClick(() => {
              this.loginButtonTapped();
            })
        }
        .width('100%')
        // iOS readableContentGuide: the form column is capped and centred, never full-bleed.
        .constraintSize({ maxWidth: 288 })
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 30 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .enabled(!this.isSaving)

      // WMFToastManager sticky "Logging in..." toast, shown for the request's lifetime.
      if (this.isSaving) {
        Row() {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.wmf_white'))
          Text($r('app.string.account_creation_logging_in'))
            .fontSize(15)
            .fontColor($r('app.color.wmf_white'))
            .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.theme_text'))
        .borderRadius(20)
        .margin({ bottom: 24 })
      }
    }
    .id('WMFLoginViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindContentCover($$this.showCover, this.coverBuilder())
  }

  // loginButtonTapped(withSender:) -> save().
  private loginButtonTapped(): void {
    this.save().catch((e: Error) => {
      this.passwordAlert = this.describeFailure(e);
      this.isSaving = false;
    });
  }

  private text(res: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(res);
    } catch (e) {
      return '';
    }
  }

  // login-no-account "Don't have an account? $1": the text around the "Join Wikipedia." link,
  // split at the placeholder so a translation that puts the link first still reads in order.
  private noAccountParts(): string[] {
    const parts: string[] = formatParts(getContext(this), $r('app.string.login_no_account'));
    return [parts[0] ?? '', parts[1] ?? ''];
  }

  // A request that never reached the server (NetworkKit 23000xx: DNS, connect, timeout) reads
  // as the source's "No internet connection", not as the raw socket message ("Failed to
  // resolve the host name").
  private describeFailure(e: Error): string {
    const code: number = (e as BusinessError).code ?? 0;
    if (code >= 2300000 && code < 2301000) {
      try {
        return getContext(this).resourceManager.getStringSync($r('app.string.no_internet_connection').id);
      } catch (err) {
        return e.message;
      }
    }
    return e.message;
  }

  // save() (WMFLoginViewController.swift:237): clientlogin, then the success /
  // needsOathTokenFor2FA / wrongPassword branches, refreshing the captcha on any failure.
  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    this.passwordAlert = '';
    try {
      const result: LoginResult = await AuthService.login(
        this.host, this.username, this.password, null, null,
        this.captchaID, this.captchaText !== '' ? this.captchaText : null);
      this.loginStatus = result.status;
      if (result.succeeded) {
        // loginSuccessCompletion -> dismiss(animated:)
        this.username = '';
        this.password = '';
        this.captchaText = '';
        this.captchaRequired = false;
        this.closeButtonPushed();
        return;
      }
      // status == "UI": temporaryPasswordNeedsChange -> showChangeTempPasswordViewController,
      // needsOathTokenFor2FA / needsEmailAuthToken -> showTwoFactorViewController(isEmailAuth:)
      if (result.needs === 'retype') {
        this.openChangePassword();
      } else if (result.needs === 'oath' || result.needs === 'email') {
        this.twoFactorIsEmailAuth = result.needs === 'email';
        this.openTwoFactorPassword();
      } else {
        // statusNotPass / wrongPassword: clear the password and surface the message.
        this.passwordAlert = result.message ?? this.text($r('app.string.error_unknown'));
        this.password = '';
      }
      // "Captcha's appear to be one-time, so always try to get a new one on failure."
      await this.getCaptcha();
    } finally {
      this.isSaving = false;
    }
  }

  // getCaptcha() — the authmanagerinfo captcha the next attempt must answer.
  private async getCaptcha(): Promise<void> {
    try {
      const info: AccountCreationInfo = await AuthService.fetchAccountCreationInfo(this.host);
      this.captchaID = info.captchaID;
      this.captchaURL = info.captchaInfo ?? '';
      this.captchaRequired = info.captchaID !== null;
      this.captchaText = '';
    } catch (e) {
      console.error('login: captcha refresh failed: ' + (e as Error).message);
    }
  }

  // loginSuccessCompletion after the verification or change password step: close that cover
  // and the login screen with it, as the source dismisses back to its presenter.
  private loginSucceeded(): void {
    this.showCover = false;
    this.username = '';
    this.password = '';
    this.captchaText = '';
    this.captchaRequired = false;
    this.closeButtonPushed();
  }

  private closeButtonPushed(): void {
    if (this.onClose !== undefined) {
      this.onClose();
    }
  }

  private openAccountCreation(): void {
    this.activeCover = 'accountCreation';
      this.showCover = true;
  }

  private openForgotPassword(): void {
    this.activeCover = 'forgotPassword';
      this.showCover = true;
  }

  private openTwoFactorPassword(): void {
    this.activeCover = 'twoFactorPassword';
      this.showCover = true;
  }

  private openChangePassword(): void {
    this.activeCover = 'changePassword';
      this.showCover = true;
  }
}

// The routed host. Presenters push this instead of binding a cover; `onClose` pops back to
// whatever pushed it (the profile sheet's host, or Settings).
@Entry
@Component
struct LoginPage {
  build() {
    Column() {
      WMFLoginView({
        onClose: (): void => {
          router.back();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
