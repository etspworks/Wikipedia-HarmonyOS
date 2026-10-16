// screen_talk_page_topic_compose — presentation: modal, hosted by
// TalkPageViewControllerPage (.bindContentCover). NOT a routed page.
// Ported from Wikipedia/Code/TalkPageTopicComposeViewController.swift (+ its
// +TalkPageFormattingToolbar extension): nav bar "Topic" with a leading close button (which
// asks "Are you sure you want to discard this new topic?" once either field has text) and a
// trailing Publish button that swaps for a spinner while publishing; the body is
// containerScrollView > containerStackView > inputContainerView holding titleTextField
// (placeholder "Topic title"), divView, bodyTextView (placeholder "Description") and the
// conditional ipTempButton, followed by finePrintTextView (Terms of Use / CC BY-SA 4.0 /
// GFDL). While the body field has focus the input accessory is TalkPageFormattingToolbarView
// (bold / italics / insert link).
// S5: no capture — styled from the source roles + the app baseline tokens (centred
// inline title, link-blue bar buttons, plain-field compose body, formatting toolbar).
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { TalkPageService } from '../common/TalkPageService';
import { SessionStore } from '../common/SessionStore';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs } from '../common/Prefs';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { topSafeInset } from '../common/SafeArea';

@Component
export struct TalkPageTopicComposeView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // titleTextField.text / bodyTextView.text
  @State topicTitle: string = '';
  @State topicBody: string = '';
  // setupNavigationBar(isPublishing:) — spinner replaces the publish button
  @State isPublishing: boolean = false;
  // bodyTextView.isFirstResponder — gates the formatting toolbar
  @State isBodyFocused: boolean = false;
  // presentDismissConfirmationActionSheet (shouldBlockDismissal)
  @State showDiscardConfirm: boolean = false;
  // viewModel.wikiHasTempAccounts + authState (.ip / .temp) — the ipTempButton: the source
  // shows it only while the editor is NOT a permanent (logged-in) account.
  @State showIPTempButton: boolean = false;
  // viewModel.pageTitle / siteURL — the talk page this topic is published to, handed over by
  // the talk page itself. Read from router params, it was empty whenever the talk page was
  // opened from an article, so Publish silently did nothing.
  @Prop talkPageTitle: string = '';
  @Prop host: string = '';
  @State publishError: string = '';
  onClose?: () => void;
  onTappedIPTemp?: () => void;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    this.showIPTempButton = !SessionStore.isLoggedIn;
    if (this.host === '') {
      LanguageStore.appLanguage().then((lang: MWKLanguageLink): void => {
        this.host = lang.languageCode + '.wikipedia.org';
      }).catch((e: Error): void => {
        console.warn('topicCompose: app language unavailable: ' + e.message);
      });
    }
  }

  // tappedPublish -> discussiontoolsedit addtopic POST (svc_talk), the publish button
  // replaced by the spinner while it runs.
  private async publish(): Promise<void> {
    if (this.isPublishing || this.talkPageTitle === '') {
      this.publishError = this.talkPageTitle === ''
        ? 'This topic has no talk page to publish to.' : this.publishError;
      return;
    }
    // The source keeps Publish disabled until both fields have text; this cover does not
    // redraw on its own state, so the check runs on the tap instead.
    if (this.topicTitle.trim() === '' || this.topicBody.trim() === '') {
      this.getUIContext().getPromptAction().showToast({ message: 'Add a topic title and a description' });
      return;
    }
    this.isPublishing = true;
    this.publishError = '';
    try {
      await TalkPageService.postTopic(this.host, this.talkPageTitle, this.topicTitle,
        this.topicBody);
      this.isPublishing = false;
      this.topicTitle = '';
      this.topicBody = '';
      this.dismiss();
    } catch (e) {
      this.isPublishing = false;
      this.publishError = e instanceof Error ? e.message : JSON.stringify(e);
      this.getUIContext().getPromptAction().showToast({
        message: 'Could not publish this topic'
      });
    }
  }

  private requestClose(): void {
    if (this.topicTitle.length > 0 || this.topicBody.length > 0) {
      this.showDiscardConfirm = true;
      return;
    }
    this.dismiss();
  }

  private dismiss(): void {
    const cb: (() => void) | undefined = this.onClose;
    if (cb !== undefined) {
      cb();
    }
  }

  @Builder
  discardConfirmBuilder() {
    Column() {
      Text('Are you sure you want to discard this new topic?')
        .fontSize(17)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 16 })
      Button('Discard Topic')
        .id('topic_discard')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontColor($r('app.color.theme_destructive'))
        .width('100%')
        .height(52)
        .onClick(() => {
          this.showDiscardConfirm = false;
          this.dismiss();
        })
      Divider()
        .strokeWidth(1)
        .color($r('app.color.gray200'))
      Button('Keep editing')
        .id('topic_keep_editing')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .width('100%')
        .height(52)
        .onClick(() => {
          this.showDiscardConfirm = false;
        })
    }
    .width('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  build() {
    Column() {
      // configureNavigationBar(titleConfig: "Topic", closeButtonConfig: leading)
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          // Id scoping: this screen is an overlay, so its nodes share the host page's
          // component tree. The source slug is the part after the dot: close_button.
          .id('TalkPageTopicComposeViewController.close_button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            this.requestClose();
          })
        Text('Topic')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        if (this.isPublishing) {
          // spinnerToolbarItem
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.theme_link'))
            .margin({ right: 10 })
        } else {
          Button('Publish')
            .id('publish_topic')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_link'))
            .height(44)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              this.publish().catch((e: Error) => {
                console.error('topicCompose: publish failed: ' + e.message);
              });
            })
        }
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      Scroll() {
        Column() {
          // inputContainerView
          Column() {
            TextInput({ placeholder: 'Topic title', text: this.topicTitle })
              .id('topic_title')
              .width('100%')
              .height(52)
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .padding({ left: 16, right: 16 })
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_text'))
              .placeholderColor($r('app.color.theme_secondary_text'))
              .placeholderFont({ size: 20, weight: FontWeight.Medium })
              .onChange((value: string) => {
                this.topicTitle = value;
              })
            // divView
            Divider()
              .width('100%')
              .strokeWidth(1)
              .color($r('app.color.gray200'))
            TextArea({ placeholder: 'Description', text: this.topicBody })
              .id('topic_body')
              .width('100%')
              .height(220)
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .padding({ left: 16, right: 16, top: 12 })
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .placeholderColor($r('app.color.theme_secondary_text'))
              .placeholderFont({ size: 17 })
              .onFocus(() => {
                this.isBodyFocused = true;
              })
              .onBlur(() => {
                this.isBodyFocused = false;
              })
              .onChange((value: string) => {
                this.topicBody = value;
              })
            // ipTempButton — only on wikis with temp accounts, for ip/temp auth states
            if (this.showIPTempButton) {
              Button('Temporary account')
                .id('topic_ip_temp')
                .type(ButtonType.Normal)
                .backgroundColor(Color.Transparent)
                .fontSize(15)
                .fontColor($r('app.color.theme_link'))
                .height(44)
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  // tappedIPTempButton -> the temp-account explainer
                  const cb: (() => void) | undefined = this.onTappedIPTemp;
                  if (cb !== undefined) {
                    cb();
                    return;
                  }
                  this.getUIContext().getPromptAction().showToast({
                    message: 'Your edit will be attributed to a temporary account. '
                      + 'Log in to keep your contributions together.'
                  });
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.publishError !== '') {
            Text(this.publishError)
              .id('topic_publish_error')
              .width('100%')
              .fontSize(15)
              .lineHeight(20)
              .fontColor($r('app.color.theme_destructive'))
              .padding({ left: 16, right: 16, top: 12 })
          }

          // finePrintTextView — Terms of Use / CC BY-SA 4.0 / GFDL
          Text('By publishing changes, you agree to the Terms of Use, and you irrevocably ' +
            'agree to release your contribution under the CC BY-SA 4.0 License and the GFDL.')
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 20, bottom: 20 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)

      // inputAccessoryView: TalkPageFormattingToolbarView while the body has focus
      if (this.isBodyFocused) {
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.bold'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_text')])
          }
            .id('topic_format_bold')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(44)
            .onClick(() => {
              // wikitext bold is a matched pair of three apostrophes
              this.topicBody = this.topicBody + "''''''";
            })
          Button() {
            SymbolGlyph($r('sys.symbol.italic'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_text')])
          }
            .id('topic_format_italics')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(44)
            .onClick(() => {
              this.topicBody = this.topicBody + "''''";
            })
          Button() {
            SymbolGlyph($r('sys.symbol.link'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_text')])
          }
            .id('topic_format_link')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(44)
            .onClick(() => {
              this.topicBody = this.topicBody + '[[]]';
            })
        }
        .width('100%')
        .height(48)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8 })
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      }
    }
    .id('TalkPageTopicComposeViewController')
    .width('100%')
    .height('100%')
    // a full-screen cover: without the status-bar inset, X and Publish sat under the clock
    // and the system bar took their taps
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .bindSheet($$this.showDiscardConfirm, this.discardConfirmBuilder(), { showClose: false })
  }
}
