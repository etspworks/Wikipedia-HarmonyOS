// LibraryUsedViewController (Wikipedia/Code/LibrariesUsed.swift): pushed from Libraries used, the
// library's name as the title and its licence text in a scrolling, inset text view.
import { router } from '@kit.ArkUI';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// normalizeWhitespaceForBetterReadability: blank-line runs become one paragraph break, other
// line breaks and whitespace runs a single space (the plist keeps the licences' hard wraps).
export function normalizeLicenseText(text: string): string {
  const placeholder: string = '#temporary_placeholder#';
  return text
    .replace(/\r?\n\s*\r?\n/g, placeholder)
    .replace(/\r?\n/g, ' ')
    .replace(/\s+/g, ' ')
    .split(placeholder).join('\n\n')
    .trim();
}

@Entry
@Component
struct LibraryUsedViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @State libraryTitle: string = '';
  @State licenseText: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.libraryTitle = params['title'] ?? '';
      this.licenseText = normalizeLicenseText(params['licenseText'] ?? '');
    }
  }

  build() {
    Column() {
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
          .id('BackButton')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText('Back')
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        Text(this.libraryTitle)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 56, right: 56 })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })

      Scroll() {
        Text(this.licenseText)
          .id('library_license_text')
          .width('100%')
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_text'))
          .padding(10)
          .copyOption(CopyOptions.LocalDevice)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
