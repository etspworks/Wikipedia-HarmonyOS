// screen_change_password — presentation: modal, hosted by WMFLoginView
// (.bindContentCover). NOT a routed page. No outgoing nav edges.
//
// S3 structure from Wikipedia/Code/WMFChangePasswordViewController.swift (a
// WMFScrollViewController over its xib outlets, set in viewDidLoad):
//   configureNavigationBar: the title is .hidden, with a leading plainX close button
//   (closeButtonPushed -> dismiss) — the contract's implicit dismiss affordance.
//   titleLabel "Set your password" ("new-password-title") over subTitleLabel
//   "You logged in with a temporary password. To finish logging in set a new password here."
//   ("new-password-instructions").
//   passwordTitleLabel "New password" over passwordField (placeholder "enter new password",
//   secure), then retypeTitleLabel "Confirm new password" over retypeField (placeholder
//   "re-enter new password", secure).
//   saveButton (WMFAuthButton): enabled only while BOTH fields are non-empty
//   (textFieldDidChange -> enableProgressiveButton(!password.isEmpty && !retype.isEmpty)),
//   and save() first checks passwordFieldsMatch() — on a mismatch it clears both fields and
//   shows the "Password fields do not match." toast — before calling
//   authenticationManager.login(username:password:retypePassword:…) and dismissing on
//   success. The save button is defined by the source and carried by the capture, but is not
//   listed in this screen's controlInventory; the source wins (a change-password sheet with
//   no submit is not the source screen).
//   textFieldShouldReturn moves the caret from passwordField to retypeField, and submits
//   from retypeField.
// Rule 12: passwordField / retypeField / close_button are the SOURCE slugs (the first two
// from the plan's controlInventory, close_button from the capture).
// Id scoping: WMFLoginView mounts this screen as a .bindContentCover overlay, so its nodes
// share ONE ArkUI tree with the login form's. ArkUI ids are global to that tree while the
// iOS outlet names they mirror are per-view-controller, so the shared field slugs collided
// (ArkTS: "The current component id ... is duplicate with ..."). The overlays carry their
// own screen root id as a prefix and the host screen keeps the bare slug; the source slug
// is still exactly the part after the dot.
import { topSafeInset } from '../common/SafeArea';
import { AuthService, LoginResult } from '../common/AuthService';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';
import { formatString } from '../common/Plural';
import { promptAction } from '@kit.ArkUI';

@Component
export struct WMFChangePasswordView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // the temporary-password login this sheet finishes; the host hands over the user name.
  @Prop userName: string = '';
  // dismissal of the cover this view is mounted in (closeButtonPushed -> dismiss).
  onClose?: () => void;
  // loginSuccessCompletion: the host closes the whole login, not only this cover
  onLoginSuccess?: () => void;

  @State password: string = '';
  @State retypePassword: string = '';
  // saveButton.isEnabled (enableProgressiveButton)
  @State saveEnabled: boolean = false;
  @State errorMessage: string = '';
  // S6: the in-flight visual for the login round-trip wired in S4.
  @State isSaving: boolean = false;
  private host: string = 'en.wikipedia.org';

  // textFieldDidChange(_:)
  private textFieldDidChange(): void {
    this.saveEnabled = this.password !== '' && this.retypePassword !== '';
  }

  private passwordFieldsMatch(): boolean {
    return this.password === this.retypePassword;
  }

  // S5 (capture S0178 — pages/WMFChangePasswordViewController/base.png): white page, a round
  // title-bar plainX button at the 16 vp margin, and the auth form constrained to the source's 288 vp
  // column, centred. Everything in that column is theme_secondary_text (#72777D): the 18 vp
  // bold title, the 17/24 instructions inside their #FEF6E7 box with the yellow600 hairline,
  // the 13 vp field labels, and the underlined transparent fields. The Save button is a
  // full-width 40 vp capsule — gray200 with gray text while disabled, theme_link once both
  // fields are filled.
  build() {
    Column() {
      // WMFNavigationBar: hidden title, leading plainX close button.
      Row() {
        Button() {
          Image($r('app.media.close'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
        }
        // Id scoping: this screen is an overlay, so its nodes share the host page's
        // component tree. The source slug is the part after the dot: close_button.
        .id('WMFChangePasswordViewController.close_button')
        .attributeModifier(NAV_ICON_BUTTON)
        .accessibilityText('Cancel')
        .onClick(() => {
          this.closeButtonPushed();
        })
        Blank()
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })

      Scroll() {
        Column() {
          Text('Set your password')
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 44, bottom: 12 })
          Text('You logged in with a temporary password. To finish logging in set a new password here.')
            .width('100%')
            .fontSize(17)
            .lineHeight(24)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding(16)
            .backgroundColor('#FEF6E7')
            .border({ width: 1, color: $r('app.color.yellow600') })

          Text('New password')
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 28, bottom: 2 })
          TextInput({ text: this.password, placeholder: 'enter new password' })
            .id('WMFChangePasswordViewController.passwordField')
            .type(InputType.Password)
            .width('100%')
            .height(44)
            .fontSize(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0 })
            .border({
              width: { bottom: 1 },
              color: { bottom: $r('app.color.theme_secondary_text') }
            })
            .onChange((value: string) => {
              this.password = value;
              this.textFieldDidChange();
            })

          Text('Confirm new password')
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 24, bottom: 2 })
          TextInput({ text: this.retypePassword, placeholder: 're-enter new password' })
            .id('retypeField')
            .type(InputType.Password)
            .width('100%')
            .height(44)
            .fontSize(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 0, right: 0 })
            .border({
              width: { bottom: 1 },
              color: { bottom: $r('app.color.theme_secondary_text') }
            })
            .onChange((value: string) => {
              this.retypePassword = value;
              this.textFieldDidChange();
            })
            .onSubmit(() => {
              this.save();
            })

          // the mismatch / login-failure toast text.
          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .lineHeight(18)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ top: 12 })
          }

          // saving -> the source's progress HUD, kept in the form column.
          if (this.isSaving) {
            Row() {
              LoadingProgress()
                .width(20)
                .height(20)
                .color($r('app.color.theme_secondary_text'))
                .margin({ right: 10 })
              Text('Setting your password')
                .layoutWeight(1)
                .fontSize(13)
                .fontColor($r('app.color.theme_secondary_text'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 12 })
          }

          Button('Save')
            .id('save')
            .enabled(this.saveEnabled)
            .type(ButtonType.Capsule)
            .width('100%')
            .height(40)
            .fontSize(17)
            .fontColor(this.saveEnabled ? (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')) : '#B6B8BC')
            .backgroundColor(this.saveEnabled ?
              $r('app.color.theme_link') : $r('app.color.gray200'))
            .margin({ top: 32 })
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .constraintSize({ maxWidth: 288 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .align(Alignment.Top)
    }
    .id('WMFChangePasswordViewController')
    // Presented as a cover, which draws under the status bar: start below it.
    .padding({ top: topSafeInset() })
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private closeButtonPushed(): void {
    if (this.onClose !== undefined) {
      this.onClose();
    }
  }

  private save(): void {
    this.performSave().catch((e: Error) => {
      console.error('change password: save failed: ' + e.message);
    });
  }

  private async performSave(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    // guard passwordFieldsMatch() — clear both fields and surface the mismatch.
    if (!this.passwordFieldsMatch()) {
      this.password = '';
      this.retypePassword = '';
      this.saveEnabled = false;
      this.errorMessage = 'Password fields do not match.';
      return;
    }
    this.isSaving = true;
    this.saveEnabled = false;
    this.errorMessage = '';
    try {
      const result: LoginResult = await AuthService.login(
        this.host, this.userName, this.password, this.retypePassword, null, null, null);
      if (result.succeeded) {
        // "Logged in as <username>" toast, then loginSuccessCompletion -> dismiss(animated:)
        promptAction.showToast({ message: formatString(getContext(this),
          $r('app.string.main_menu_account_title_logged_in'), [this.userName]) });
        this.password = '';
        this.retypePassword = '';
        const done: (() => void) | undefined = this.onLoginSuccess;
        if (done !== undefined) {
          done();
        } else {
          this.closeButtonPushed();
        }
        return;
      }
      this.errorMessage = result.message ?? 'Login failed';
      this.password = '';
      this.retypePassword = '';
    } finally {
      this.isSaving = false;
      this.textFieldDidChange();
    }
  }
}
