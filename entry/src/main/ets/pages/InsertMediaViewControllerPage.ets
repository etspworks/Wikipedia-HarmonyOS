// Ported from Wikipedia/Code/InsertMediaViewController.swift and its children
// (InsertMediaSelectedImageViewController, InsertMediaSearchViewController,
// InsertMediaSearchResultsCollectionViewController, InsertMediaImageInfoView,
// InsertMediaSearchResultPreviewingViewController): "Insert media" with the plain-X close and Next
// (enabled once the chosen image has loaded). Above the results, and scrolling away with them: the
// chosen image (30% of the screen; "Select a file from Wikimedia Commons" until one is chosen)
// with its title and license over its bottom edge, and the search bar (the article title as
// placeholder and first search). The results are Commons files in three columns; a tap chooses
// one, a long press previews it with Select image / More information / Cancel.
import { router, display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CommonsService } from '../common/CommonsService';
import { MWKSearchResult } from '../model/MWKSearchResult';
import { MWKImageInfo } from '../model/MWKImageInfo';
import { InsertMediaSession, fileDisplayTitle, thumbnailURL, licenseIconNames } from '../common/InsertMedia';
import { decodeEntities } from '../common/WebDocument';

// WMFMaxSearchResultLimit
const RESULT_LIMIT: number = 24;
const COLUMN_SPACING: number = 12;
const ROW_SPACING: number = 38;
const SIDE_INSET: number = 16;

// $r needs literal names
function licenseIcon(name: string): Resource {
  switch (name) {
    case 'license_cc': return $r('app.media.license_cc');
    case 'license_by': return $r('app.media.license_by');
    case 'license_sa': return $r('app.media.license_sa');
    case 'license_cc0': return $r('app.media.license_cc0');
    case 'license_pd': return $r('app.media.license_pd');
    case 'license_non_commercial': return $r('app.media.license_non_commercial');
    default: return $r('app.media.license_no_derivatives');
  }
}

@Entry
@Component
struct InsertMediaViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  @StorageProp('WMFAppThemeName') themeName: string = '';

  @State term: string = '';
  @State results: MWKSearchResult[] = [];
  // emptyViewType: '' none, 'noResults', 'offline'
  @State emptyType: string = '';
  @State selectedTitle: string = '';
  @State selectedImageURL: string = '';
  @State isImageLoaded: boolean = false;
  // bumped when image info arrives, so the rows that read it redraw
  @State infoVersion: number = 0;
  // the result whose long-press menu is open
  @State menuTitle: string = '';
  private infos: Map<string, MWKImageInfo> = new Map<string, MWKImageInfo>();
  private generation: number = 0;
  private screenWidth: number = 360;
  private imageAreaHeight: number = 240;

  aboutToAppear(): void {
    const d: display.Display = display.getDefaultDisplaySync();
    this.screenWidth = px2vp(d.width);
    this.imageAreaHeight = Math.round(px2vp(d.height) * 0.3);
    // viewDidLoad: search for the article title straight away
    this.search(InsertMediaSession.articleTitle);
  }

  private itemSize(): number {
    return Math.floor((this.screenWidth - 2 * SIDE_INSET - 2 * COLUMN_SPACING) / 3);
  }

  private isDark(): boolean {
    return this.themeName.startsWith('dark') || this.themeName.startsWith('black');
  }

  // InsertMediaSearchViewController.search(for:): a prefix search, then, under 12 results, a
  // full-text search merged in after it; an empty field searches the article title
  private search(text: string): void {
    const term: string = text.trim() === '' ? InsertMediaSession.articleTitle : text;
    const generation: number = ++this.generation;
    const deliver = (results: MWKSearchResult[]): void => {
      if (generation !== this.generation) {
        return;
      }
      this.results = results;
      this.emptyType = results.length === 0 ? 'noResults' : '';
      this.fetchImageInfo(results, generation);
    };
    CommonsService.searchFiles(term, RESULT_LIMIT, false).then((prefix: MWKSearchResult[]) => {
      const withThumbs: MWKSearchResult[] = prefix.filter((r: MWKSearchResult) => (r.thumbnailURL ?? '') !== '');
      if (withThumbs.length >= 12) {
        deliver(withThumbs);
        return;
      }
      if (withThumbs.length > 0) {
        deliver(withThumbs);
      }
      CommonsService.searchFiles(term, RESULT_LIMIT, true).then((full: MWKSearchResult[]) => {
        const seen: Set<string> = new Set<string>(withThumbs.map((r: MWKSearchResult) => r.displayTitle ?? ''));
        deliver(withThumbs.concat(full.filter((r: MWKSearchResult) =>
          (r.thumbnailURL ?? '') !== '' && !seen.has(r.displayTitle ?? ''))));
      }).catch(() => {
        deliver(withThumbs);
      });
    }).catch((e: Error) => {
      console.error('insertMedia: search failed: ' + e.message);
      if (generation === this.generation) {
        this.results = [];
        this.emptyType = 'offline';
      }
    });
  }

  // MWKImageInfoFetcher for the results, on the article's wiki (license, description, file page)
  private fetchImageInfo(results: MWKSearchResult[], generation: number): void {
    const titles: string[] = results.map((r: MWKSearchResult) => r.title ?? '')
      .filter((t: string) => t !== '' && !this.infos.has(t));
    for (let i = 0; i < titles.length; i += 50) {
      CommonsService.fetchImageInfo(InsertMediaSession.host, titles.slice(i, i + 50), 500)
        .then((infos: MWKImageInfo[]) => {
          for (const info of infos) {
            this.infos.set(info.canonicalPageTitle ?? '', info);
          }
          if (generation === this.generation) {
            this.infoVersion++;
          }
        }).catch((e: Error) => {
          console.error('insertMedia: image info failed: ' + e.message);
        });
    }
  }

  private info(result: MWKSearchResult): MWKImageInfo | undefined {
    return this.infoVersion >= 0 ? this.infos.get(result.title ?? '') : undefined;
  }

  // didSelect: the full image for the screen width loads into the top area; Next waits for it
  private select(result: MWKSearchResult): void {
    this.selectedTitle = result.title ?? '';
    this.isImageLoaded = false;
    const info: MWKImageInfo | undefined = this.info(result);
    this.selectedImageURL = (result.thumbnailURL ?? '') !== '' ?
      thumbnailURL(result.thumbnailURL ?? '', vp2px(this.screenWidth)) : (info?.canonicalFileURL ?? '');
    InsertMediaSession.fileTitle = result.title ?? '';
    InsertMediaSession.displayTitle = fileDisplayTitle(result.title ?? '');
    InsertMediaSession.imageURL = this.selectedImageURL;
    InsertMediaSession.imageDescription = this.description(result);
    InsertMediaSession.filePageURL = info?.filePageURL ?? '';
  }

  // MWKImageInfoFetcher: the description with its HTML removed and its whitespace collapsed
  private description(result: MWKSearchResult): string {
    const html: string = this.info(result)?.imageDescription ?? '';
    return decodeEntities(html.replace(/<[^>]*>/g, '')).replace(/\s+/g, ' ').trim();
  }

  private selectedResult(): MWKSearchResult | undefined {
    return this.results.find((r: MWKSearchResult) => r.title === this.selectedTitle);
  }

  // More information: the file's Commons page in the browser
  private openFilePage(result: MWKSearchResult | undefined): void {
    const url: string = result !== undefined ? (this.info(result)?.filePageURL ?? '') : '';
    if (url === '') {
      return;
    }
    (getContext(this) as common.UIAbilityContext).openLink(url).catch((e: Error) => {
      console.error('insertMedia: open file page failed: ' + e.message);
    });
  }

  private rows(): MWKSearchResult[][] {
    const rows: MWKSearchResult[][] = [];
    for (let i = 0; i < this.results.length; i += 3) {
      rows.push(this.results.slice(i, i + 3));
    }
    return rows;
  }

  // InsertMediaImageInfoView: title, license icons and short name, and the info button
  @Builder
  imageInfo(result: MWKSearchResult, showLicenseName: boolean, showMoreInformation: boolean) {
    Column({ space: 6 }) {
      Text(fileDisplayTitle(result.title ?? ''))
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      Row({ space: 4 }) {
        ForEach(licenseIconNames(this.info(result)?.license?.code ?? ''), (name: string) => {
          Image(licenseIcon(name))
            .width(16)
            .height(16)
            .fillColor($r('app.color.theme_text'))
        })
        if (showLicenseName) {
          Text(this.info(result)?.license?.shortDescription ?? '')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .margin({ left: 4 })
        }
        Blank()
        if (showMoreInformation) {
          // info-white tinted with the link colour
          SymbolGlyph($r('sys.symbol.info_circle'))
            .id('insert_media_more_information')
            .fontSize(20)
            .fontColor([$r('app.color.theme_link')])
            .onClick(() => {
              this.openFilePage(result);
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 })
  }

  @Builder
  selectedImageArea() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.selectedImageURL === '') {
        // WMFEmptyView insertMedia: the blank image over the title
        Column({ space: 12 }) {
          Image($r('app.media.blank'))
            .width(120)
            .objectFit(ImageFit.Contain)
          Text($r('app.string.empty_insert_media_title'))
            .fontSize(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Image(this.selectedImageURL)
          .id('insert_media_selected_image')
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .onComplete(() => {
            this.isImageLoaded = true;
          })
        if (!this.isImageLoaded) {
          LoadingProgress()
            .width(40)
            .height(40)
            .position({ x: '50%', y: '50%' })
            .translate({ x: -20, y: -20 })
        } else if (this.selectedResult() !== undefined) {
          Column() {
            this.imageInfo(this.selectedResult() as MWKSearchResult, true, true)
          }
          .width('100%')
          .opacity(0.8)
          .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
        }
      }
    }
    .width('100%')
    .height(this.imageAreaHeight)
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }

  // InsertMediaSearchResultPreviewingViewController: the image, then title, description and
  // license icons
  @Builder
  preview(result: MWKSearchResult) {
    Column() {
      Image(thumbnailURL(result.thumbnailURL ?? '', vp2px(this.screenWidth)))
        .width(this.screenWidth - 64)
        .height(240)
        .objectFit(ImageFit.Contain)
      Column() {
        this.imageInfo(result, false, false)
        if (this.description(result) !== '') {
          Text(this.description(result))
            .width('100%')
            .fontSize(13)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.theme_text'))
            .padding({ left: 12, right: 12, bottom: 12 })
        }
      }
      .width(this.screenWidth - 64)
    }
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // the long-pressed result's preview and menu
  @Builder
  previewCard() {
    if (this.menuResult() !== undefined) {
      this.preview(this.menuResult() as MWKSearchResult)
    }
  }

  private menuResult(): MWKSearchResult | undefined {
    return this.results.find((r: MWKSearchResult) => r.title === this.menuTitle);
  }

  @Builder
  contextMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.insert_media_image_preview_select_image_action_title') })
        .id('insert_media_menu_select')
        .onClick(() => {
          const result: MWKSearchResult | undefined = this.menuResult();
          if (result !== undefined) {
            this.select(result);
          }
        })
      MenuItem({ content: $r('app.string.insert_media_image_preview_more_information_action_title') })
        .onClick(() => {
          this.openFilePage(this.menuResult());
        })
      MenuItem({ content: $r('app.string.action_cancel') })
    }
  }

  @Builder
  cell(result: MWKSearchResult) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(thumbnailURL(result.thumbnailURL ?? '', vp2px(this.itemSize())))
          .width(this.itemSize())
          .height(this.itemSize())
          .objectFit(ImageFit.Contain)
        if (result.title === this.selectedTitle) {
          Image(this.isDark() ? $r('app.media.selected_dark') : $r('app.media.selected'))
            .width(Math.min(35, this.itemSize() * 0.2))
            .height(Math.min(35, this.itemSize() * 0.2))
        }
      }
      Text(fileDisplayTitle(result.title ?? ''))
        .width(this.itemSize())
        .fontSize(13)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('app.color.theme_text'))
    }
    .id('insert_media_result')
    .onClick(() => {
      this.select(result);
    })
    .parallelGesture(LongPressGesture({ duration: 500 }).onAction(() => {
      this.menuTitle = result.title ?? '';
    }))
    .bindContextMenu(this.menuTitle === result.title, this.contextMenu(), {
      preview: this.previewCard(),
      onDisappear: () => {
        if (this.menuTitle === result.title) {
          this.menuTitle = '';
        }
      }
    })
  }

  build() {
    Column() {
      // nav bar: X, "Insert media", Next
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('insert_media_close')
        .type(ButtonType.Normal)
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })
        Text($r('app.string.insert_media_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Button() {
          Text($r('app.string.button_next'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isImageLoaded ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
        }
        .id('insert_media_next')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .enabled(this.isImageLoaded)
        .onClick(() => {
          router.pushUrl({ url: 'pages/InsertMediaSettingsViewControllerPage' });
        })
      }
      .width('100%')
      .height(54)
      .padding({ left: 8, right: 12 })

      Scroll() {
        Column() {
          this.selectedImageArea()
          Search({ value: this.term, placeholder: InsertMediaSession.articleTitle })
            .id('insert_media_search')
            .height(40)
            .margin(8)
            .enterKeyType(EnterKeyType.Done)
            .onChange((value: string) => {
              this.term = value;
              this.search(value);
            })
          if (this.emptyType !== '') {
            Column({ space: 12 }) {
              if (this.emptyType === 'offline') {
                Image($r('app.media.no_internet_blank'))
                  .width(80)
                  .objectFit(ImageFit.Contain)
              }
              Text(this.emptyType === 'offline' ? $r('app.string.no_internet_connection') :
                $r('app.string.empty_no_search_results_message'))
                .fontSize(17)
                .fontColor($r('app.color.theme_secondary_text'))
            }
            .width('100%')
            .padding({ top: 48 })
          }
          Column({ space: ROW_SPACING }) {
            ForEach(this.rows(), (row: MWKSearchResult[]) => {
              Row({ space: COLUMN_SPACING }) {
                ForEach(row, (result: MWKSearchResult) => {
                  this.cell(result)
                }, (result: MWKSearchResult) => (result.title ?? '') + this.selectedTitle + this.infoVersion)
              }
              .width('100%')
            }, (row: MWKSearchResult[]) => row.map((r: MWKSearchResult) => r.title ?? '').join('|') +
              this.selectedTitle + this.infoVersion)
          }
          .width('100%')
          .padding({ left: SIDE_INSET, right: SIDE_INSET, top: 12, bottom: 38 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('InsertMediaViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
