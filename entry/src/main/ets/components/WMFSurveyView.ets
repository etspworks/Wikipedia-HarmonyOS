// Ported from WMFComponents WMFSurveyView / WMFSurveyViewModel: an inset grouped list on the
// base background under an inline title with Cancel (leading) and Submit (trailing, enabled
// once an option is picked or other text typed). The subtitle (and optional italic
// instructions) in secondary text, the option rows with a checkmark (single or multi
// selection), then the "other" text field with its own checkmark. Submit hands back the
// picked option identifiers ("other" added when text was typed) and the text.

export class SurveyOption {
  text: ResourceStr;
  apiIdentifier: string;

  constructor(text: ResourceStr, apiIdentifier: string) {
    this.text = text;
    this.apiIdentifier = apiIdentifier;
  }
}

@Component
export struct WMFSurveyView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';

  title: ResourceStr = '';
  subtitle: ResourceStr = '';
  instructions: ResourceStr = '';
  otherPlaceholder: ResourceStr = '';
  options: SurveyOption[] = [];
  multiSelect: boolean = false;
  onCancel: () => void = () => {};
  onSubmit: (selected: string[], otherText: string) => void = () => {};

  @State selected: string[] = [];
  @State otherText: string = '';

  private canSubmit(): boolean {
    return this.selected.length > 0 || this.otherText !== '';
  }

  private toggle(id: string): void {
    if (this.multiSelect) {
      this.selected = this.selected.indexOf(id) >= 0
        ? this.selected.filter((s: string) => s !== id) : this.selected.concat([id]);
    } else {
      this.selected = [id];
    }
  }

  @Builder
  checkmark(on: boolean) {
    SymbolGlyph(on ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
      .fontSize(22)
      .fontColor([on ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text')])
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.cancel'))
          .id('survey_cancel')
          .fontSize(17)
          .fontColor($r('app.color.theme_link'))
          .onClick(() => {
            this.onCancel();
          })
        Text(this.title)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Text($r('app.string.survey_submit'))
          .id('survey_submit')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canSubmit() ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
          .onClick(() => {
            if (!this.canSubmit()) {
              return;
            }
            const picked: string[] = this.otherText !== '' ? this.selected.concat(['other']) : this.selected;
            this.onSubmit(picked, this.otherText);
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          Text(this.subtitle)
            .width('100%')
            .fontSize(16)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          if (this.instructions !== '') {
            Text(this.instructions)
              .width('100%')
              .fontSize(16)
              .fontStyle(FontStyle.Italic)
              .fontColor($r('app.color.theme_secondary_text'))
              .padding({ left: 16, right: 16, bottom: 8 })
          }
          Column() {
            ForEach(this.options, (option: SurveyOption, i: number) => {
              Column() {
                Row() {
                  Text(option.text)
                    .layoutWeight(1)
                    .fontSize(17)
                    .fontColor($r('app.color.theme_text'))
                  this.checkmark(this.selected.indexOf(option.apiIdentifier) >= 0)
                }
                .width('100%')
                .constraintSize({ minHeight: 48 })
                .padding({ left: 16, right: 16 })
                if (i < this.options.length - 1) {
                  Divider()
                    .margin({ left: 16 })
                    .color($r('app.color.theme_border'))
                }
              }
              .id('survey_option_' + option.apiIdentifier)
              .onClick(() => {
                this.toggle(option.apiIdentifier);
              })
            }, (option: SurveyOption) => option.apiIdentifier + (this.selected.indexOf(option.apiIdentifier) >= 0 ? '_on' : '_off'))
          }
          .width('100%')
          .borderRadius(10)
          .margin({ top: 8 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          Row() {
            TextInput({ placeholder: this.otherPlaceholder, text: this.otherText })
              .id('survey_other')
              .layoutWeight(1)
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => {
                this.otherText = value;
              })
            this.checkmark(this.otherText !== '')
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .margin({ top: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('WMFSurveyView')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }
}
