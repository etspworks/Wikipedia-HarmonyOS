// screen_libraries_used — presentation: page, pushed from screen_about. No outgoing nav edges.
//
// S3 structure from Wikipedia/Code/LibrariesUsed.swift (class LibrariesUsedViewController):
//   configureNavigationBar: centerCompact title "Libraries used" ("about-libraries") plus a
//   leading plainX close button (closeButtonPushed -> dismiss); on this screen's contract
//   that is the implicit push-navigation back affordance.
//   tableView.tableHeaderView = a centred footnote label reading
//   "We love open source software 💖" ("about-libraries-licenses-title").
//   ONE section, libraries.count rows; each row is a default UITableViewCell whose textLabel
//   is library.title. `libraries` is read from the bundled LibrariesUsed.plist (not from any
//   service — this screen has no bindingContract and no models/services in the plan), each
//   entry capitalized on its first character and the list sorted by title, which is exactly
//   the order the capture shows.
//   didSelectRowAt pushes LibraryUsedViewController (LibraryUsedViewControllerPage) with that
//   library's licenseText.
import { router } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// LibraryUsed — the plist record (Title / LicenseName / LicenseText).
export interface LibraryUsed {
  title: string;
  licenseName: string;
  licenseText: string;
}

// The bundled LibrariesUsed.plist "LibrariesUsed" array (rawfile/libraries-used.json, converted
// from the source's plist), first character capitalized and sorted by title as
// librariesUsed(from:) does.
export function librariesUsed(context: Context): LibraryUsed[] {
  try {
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('libraries-used.json');
    return JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as LibraryUsed[];
  } catch (e) {
    console.error('libraries: list unavailable: ' + (e as Error).message);
    return [];
  }
}

@Entry
@Component
struct LibrariesUsedViewControllerPage {
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  private libraries: LibraryUsed[] = [];

  aboutToAppear(): void {
    this.libraries = librariesUsed(getContext(this));
  }

  // S5 (capture S0170 — pages/LibrariesUsedViewController/base.png): a PLAIN (not grouped)
  // table — white page, edge-to-edge 52 vp rows of 17 vp primary text at the 20 vp cell
  // inset, no separators — under the gray200 tableHeaderView band carrying the centred
  // footnote. The capture is of the sheet body alone and shows no navigation bar; the
  // source's configureNavigationBar does define one, so the bar stays and uses the app's
  // title-bar buttons.
  build() {
    Column() {
      // WMFNavigationBar: the leading close/back affordance + the centerCompact title.
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

        Text('Libraries used')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })

      Scroll() {
        Column() {
          // tableHeaderView
          Text('We love open source software 💖')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(13)
            .fontColor($r('app.color.theme_text'))
            .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
            .padding({ left: 16, right: 16, top: 18, bottom: 18 })

          ForEach(this.libraries, (library: LibraryUsed) => {
            Text(library.title)
              .id('library_row')
              .width('100%')
              .padding({ left: 20, right: 20, top: 15, bottom: 15 })
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              // selectedBackgroundView: midBackground while pressed
              .stateStyles({ pressed: { .backgroundColor($r('app.color.theme_mid_background')) } })
              .onClick(() => {
                router.pushUrl({ url: 'pages/LibraryUsedViewControllerPage',
                  params: { 'title': library.title, 'licenseText': library.licenseText } });
              })
          }, (library: LibraryUsed) => library.title)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('LibrariesUsedViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
