// comp_talk_page_reply_compose — ported from Wikipedia/Code/TalkPageReplyComposeController.swift
// + TalkPageReplyComposeContentView.swift: the panel that slides up over the lower 60% of the
// talk page when a Reply button is tapped. A drag handle, close (X) on the leading edge and
// Publish on the trailing edge (a spinner while publishing), the reply text view with its
// "Reply to <author>" placeholder, the info button and the fine print (Terms of Use /
// CC BY-SA 4.0 / GFDL), which hides once the reader types and the info button brings back.
// While the text view has focus the input accessory is TalkPageFormattingToolbarView.
// Hosted by TalkPageViewControllerPage.
import { formatString } from '../common/Plural';

@Component
export struct TalkPageReplyComposeView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // commentViewModel.author
  @Prop author: string = '';
  // TalkPageReplyComposeController.isLoading
  @Prop isPublishing: boolean = false;
  @State text: string = '';
  @State showFinePrint: boolean = true;
  @State isFocused: boolean = false;
  @State showDiscardConfirm: boolean = false;
  onPublish: (text: string) => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    // setupAndDisplay: the text view becomes first responder
    setTimeout(() => {
      focusControl.requestFocus('talk_reply_text');
    }, 300);
  }

  // attemptClose: a reply with text asks before it is discarded
  private attemptClose(): void {
    if (this.text !== '') {
      this.showDiscardConfirm = true;
      return;
    }
    this.onClose();
  }

  private finePrint(): string {
    return formatString(getContext(this), $r('app.string.talk_page_reply_terms_and_licenses_ccsa4'),
      ['', '', '', '', '', '']);
  }

  // TalkPageFormattingToolbarView: wikitext markup inserted at the end of the reply
  @Builder
  formatButton(id: string, symbol: Resource, markup: string) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(22)
        .fontColor([$r('app.color.theme_text')])
    }
      .id(id)
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(48)
      .height(44)
      .onClick(() => {
        this.text = this.text + markup;
      })
  }

  // presentDismissConfirmationActionSheet
  @Builder
  discardConfirmBuilder() {
    Column() {
      Text($r('app.string.talk_pages_reply_compose_close_confirmation_title'))
        .fontSize(17)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 16 })
      Button($r('app.string.talk_pages_topic_compose_close_confirmation_discard_reply'))
        .id('talk_reply_discard')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(17)
        .fontColor($r('app.color.theme_destructive'))
        .width('100%')
        .height(52)
        .onClick(() => {
          this.showDiscardConfirm = false;
          this.onClose();
        })
      Divider()
        .strokeWidth(1)
        .color($r('app.color.gray200'))
      Button($r('app.string.talk_pages_compose_close_confirmation_keep'))
        .id('talk_reply_keep_editing')
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
      // dragHandleView
      Row()
        .width(36)
        .height(5)
        .borderRadius(2)
        .backgroundColor($r('app.color.gray675'))
        .margin({ top: 8 })
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('talk_reply_close')
          .accessibilityText($r('app.string.talk_page_rply_close_button_accessibility_hint'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            this.attemptClose();
          })
        Blank()
        if (this.isPublishing) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.theme_text'))
            .margin({ right: 10 })
        } else {
          // publishButton: enabled once the reply has text
          Button($r('app.string.button_publish'))
            .id('talk_reply_publish')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor(this.text.trim() !== '' ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
            .enabled(this.text.trim() !== '')
            .height(44)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              this.onPublish(this.text);
            })
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Scroll() {
        Column({ space: 5 }) {
          TextArea({ placeholder: formatString(getContext(this), $r('app.string.talk_page_reply_placeholder_format'),
            [this.author]), text: this.text })
            .id('talk_reply_text')
            .width('100%')
            .constraintSize({ minHeight: 120 })
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .padding({ left: 16, right: 16 })
            .fontSize(16)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .placeholderFont({ size: 16 })
            .onFocus(() => {
              this.isFocused = true;
              this.showFinePrint = false;
            })
            .onBlur(() => {
              this.isFocused = false;
            })
            .onChange((value: string) => {
              this.text = value;
              this.showFinePrint = false;
            })
          // footerButtonStackView: infoButton, shown while the fine print is hidden
          Row() {
            if (!this.showFinePrint) {
              Button() {
                SymbolGlyph($r('sys.symbol.info_circle'))
                  .fontSize(20)
                  .fontColor([$r('app.color.theme_secondary_text')])
              }
                .id('talk_reply_info')
                .type(ButtonType.Circle)
                .backgroundColor(Color.Transparent)
                .width(32)
                .height(32)
                .onClick(() => {
                  this.showFinePrint = true;
                })
            }
          }
          .width('100%')
          .height(32)
          .justifyContent(FlexAlign.End)
          .padding({ right: 12 })
          if (this.showFinePrint) {
            Text(this.finePrint())
              .id('talk_reply_fine_print')
              .width('100%')
              .fontSize(13)
              .lineHeight(18)
              .fontColor($r('app.color.theme_secondary_text'))
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)

      if (this.isFocused) {
        Row() {
          this.formatButton('talk_reply_format_bold', $r('sys.symbol.bold'), "''''''")
          this.formatButton('talk_reply_format_italics', $r('sys.symbol.italic'), "''''")
          this.formatButton('talk_reply_format_link', $r('sys.symbol.link'), '[[]]')
        }
        .width('100%')
        .height(48)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8 })
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      }
    }
    .id('TalkPageReplyComposeController')
    .width('100%')
    .height('60%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius({ topLeft: 8, topRight: 8 })
    .shadow({ radius: 5, color: '#33000000', offsetY: -2 })
    .bindSheet($$this.showDiscardConfirm, this.discardConfirmBuilder(), { showClose: false, height: SheetSize.FIT_CONTENT })
  }
}
