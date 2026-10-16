// Ported from Wikipedia/Code/Advanced Settings/: one route for the four plain tables, picked by the
// 'screen' param.
// - advanced (InsertMediaAdvancedSettingsViewController): the Wrap text around image switch (on),
//   then Image position (off while wrap is off, then None), Image type and Image size, each with
//   its current value.
// - position (InsertMediaImagePositionSettingsViewController): Right / Left / Center, one checked.
// - type (InsertMediaImageTypeSettingsViewController): Thumbnail / Frameless / Frame / Basic, one
//   checked, and the footer about thumbnails.
// - size (InsertMediaImageSizeSettingsViewController): the Custom switch (off) over Width and
//   Height in px (220 x 124), editable only while it is on; switching it resets them.
// The choices live in InsertMediaSession.settings.
import { router } from '@kit.ArkUI';
import { InsertMediaSession, InsertMediaSettings, ImagePosition, ImageType, DEFAULT_IMAGE_WIDTH,
  DEFAULT_IMAGE_HEIGHT } from '../common/InsertMedia';

class Choice {
  value: string;
  title: Resource;

  constructor(value: string, title: Resource) {
    this.value = value;
    this.title = title;
  }
}

const POSITIONS: Choice[] = [
  new Choice('right', $r('app.string.insert_media_image_position_setting_right')),
  new Choice('left', $r('app.string.insert_media_image_position_setting_left')),
  new Choice('center', $r('app.string.insert_media_image_position_setting_center'))
];
const TYPES: Choice[] = [
  new Choice('thumb', $r('app.string.insert_media_image_type_setting_thumbnail')),
  new Choice('frameless', $r('app.string.insert_media_image_type_setting_frameless')),
  new Choice('frame', $r('app.string.insert_media_image_type_setting_frame')),
  new Choice('basic', $r('app.string.insert_media_image_type_setting_basic'))
];

@Entry
@Component
struct InsertMediaAdvancedSettingsViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @State screen: string = 'advanced';
  // a copy of the settings, re-read when a sub-screen returns (viewWillAppear reloads the table)
  @State wrap: boolean = true;
  @State positionValue: string = 'right';
  @State typeValue: string = 'thumb';
  @State customSize: boolean = false;
  @State widthValue: string = String(DEFAULT_IMAGE_WIDTH);
  @State heightValue: string = String(DEFAULT_IMAGE_HEIGHT);

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.screen = params?.['screen'] ?? 'advanced';
    this.read();
  }

  onPageShow(): void {
    this.read();
  }

  private read(): void {
    const s: InsertMediaSettings = InsertMediaSession.settings;
    this.wrap = s.wrapTextAroundImage;
    this.positionValue = s.position;
    this.typeValue = s.type;
    this.customSize = s.customSize;
    this.widthValue = s.width;
    this.heightValue = s.height;
  }

  private title(): Resource {
    if (this.screen === 'position') {
      return $r('app.string.insert_media_image_position_settings_title');
    } else if (this.screen === 'type') {
      return $r('app.string.insert_media_image_type_settings_title');
    } else if (this.screen === 'size') {
      return $r('app.string.insert_media_image_size_settings_title');
    }
    return $r('app.string.advanced_settings_title');
  }

  private positionTitle(): Resource {
    if (!this.wrap) {
      return $r('app.string.insert_media_image_position_setting_none');
    }
    return (POSITIONS.find((c: Choice) => c.value === this.positionValue) ?? POSITIONS[0]).title;
  }

  private typeTitle(): Resource {
    return (TYPES.find((c: Choice) => c.value === this.typeValue) ?? TYPES[0]).title;
  }

  @Builder
  separator() {
    Divider()
      .strokeWidth(0.5)
      .color($r('app.color.theme_border'))
  }

  // UITableViewCell .value1 with a disclosure indicator
  @Builder
  // detail and enabled are read through functions: plain @Builder arguments do not update
  disclosureRow(title: Resource, detail: () => Resource, id: string, enabled: () => boolean, screen: string) {
    Row({ space: 8 }) {
      Text(title)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor(enabled() ? $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
      Text(detail())
        .fontSize(17)
        .fontColor($r('app.color.theme_secondary_text'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('app.color.theme_secondary_text')])
    }
    .id(id)
    .width('100%')
    .height(48)
    .padding({ left: 15, right: 15 })
    .enabled(enabled())
    .onClick(() => {
      router.pushUrl({ url: 'pages/InsertMediaAdvancedSettingsViewControllerPage', params: { 'screen': screen } });
    })
  }

  @Builder
  switchRow(title: Resource, id: string, isOn: boolean, onChange: (isOn: boolean) => void) {
    Row() {
      Text(title)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .id(id)
        .onChange((on: boolean) => {
          onChange(on);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 15, right: 15 })
  }

  @Builder
  // the selection is read through a function: a @Builder's plain arguments do not update it
  checkRows(choices: Choice[], selected: () => string, idPrefix: string, onSelect: (value: string) => void) {
    ForEach(choices, (choice: Choice) => {
      Column() {
        Row() {
          Text(choice.title)
            .layoutWeight(1)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([$r('app.color.theme_link')])
            .visibility(choice.value === selected() ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%')
        .height(48)
        .padding({ left: 15, right: 15 })
        this.separator()
      }
      .id(idPrefix + choice.value)
      .onClick(() => {
        onSelect(choice.value);
      })
    }, (choice: Choice) => choice.value)
  }

  // InsertMediaCustomImageSizeSettingTableViewCell: title, number field, px
  @Builder
  sizeRow(title: Resource, value: () => string, id: string, onChange: (v: string) => void) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(16)
        .fontColor(this.customSize ? $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
      TextInput({ text: value() })
        .id(id)
        .layoutWeight(1)
        .type(InputType.Number)
        .textAlign(TextAlign.End)
        .fontSize(16)
        .fontColor(this.customSize ? $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
        .backgroundColor(Color.Transparent)
        .enabled(this.customSize)
        .onChange((v: string) => {
          onChange(v);
        })
      Text($r('app.string.insert_media_image_size_settings_px_unit_name'))
        .fontSize(16)
        .fontColor(this.customSize ? $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 8, bottom: 8 })
  }

  build() {
    Column() {
      Stack() {
        Text(this.title())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_link')])
          }
          .id('advanced_settings_back')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')
        .padding({ left: 8 })
      }
      .width('100%')
      .height(54)

      Scroll() {
        Column() {
          this.separator()
          if (this.screen === 'advanced') {
            this.switchRow($r('app.string.insert_media_image_text_wrapping_setting'), 'advanced_wrap_switch',
              this.wrap, (on: boolean) => {
                this.wrap = on;
                InsertMediaSession.settings.wrapTextAroundImage = on;
              })
            this.separator()
            this.disclosureRow($r('app.string.insert_media_image_position_settings_title'), () => this.positionTitle(),
              'advanced_image_position', () => this.wrap, 'position')
            this.separator()
            this.disclosureRow($r('app.string.insert_media_image_type_settings_title'), () => this.typeTitle(),
              'advanced_image_type', () => true, 'type')
            this.separator()
            this.disclosureRow($r('app.string.insert_media_image_size_settings_title'),
              () => this.customSize ? $r('app.string.insert_media_image_size_setting_custom') :
                $r('app.string.insert_media_image_size_setting_default'), 'advanced_image_size', () => true, 'size')
            this.separator()
          } else if (this.screen === 'position') {
            this.checkRows(POSITIONS, () => this.positionValue, 'position_', (value: string) => {
              this.positionValue = value;
              InsertMediaSession.settings.position = value as ImagePosition;
            })
          } else if (this.screen === 'type') {
            this.checkRows(TYPES, () => this.typeValue, 'type_', (value: string) => {
              this.typeValue = value;
              InsertMediaSession.settings.type = value as ImageType;
            })
            // InsertMediaLabelTableFooterView
            Text($r('app.string.insert_media_image_type_settings_footer_title'))
              .width('100%')
              .fontSize(13)
              .fontColor($r('app.color.theme_secondary_text'))
              .padding({ left: 15, right: 15, top: 5 })
          } else {
            this.switchRow($r('app.string.insert_media_image_size_setting_custom'), 'size_custom_switch',
              this.customSize, (on: boolean) => {
                this.customSize = on;
                this.widthValue = String(DEFAULT_IMAGE_WIDTH);
                this.heightValue = String(DEFAULT_IMAGE_HEIGHT);
                InsertMediaSession.settings.customSize = on;
                InsertMediaSession.settings.width = this.widthValue;
                InsertMediaSession.settings.height = this.heightValue;
              })
            this.separator()
            this.sizeRow($r('app.string.insert_media_image_size_settings_measure_width'), () => this.widthValue, 'size_width',
              (v: string) => {
                this.widthValue = v;
                InsertMediaSession.settings.width = v;
              })
            this.separator()
            this.sizeRow($r('app.string.insert_media_image_size_settings_measure_height'), () => this.heightValue, 'size_height',
              (v: string) => {
                this.heightValue = v;
                InsertMediaSession.settings.height = v;
              })
            this.separator()
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .id('InsertMediaAdvancedSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
