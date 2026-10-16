// screen_image_gallery — presentation: modal, hosted by screen_explore
// (coverBuilder branch in ExploreViewControllerPage). NOT a routed page.
// S3 structure from Wikipedia/Code/WMFImageGalleryViewController.m (+Extensions.swift):
// paged photo viewer (NYTPhotosViewController analog = Swiper), overlay top bar with
// close (left) + share (right), bottom WMFImageGalleryDetailOverlayView caption
// (image description, license + owner link, save-to-photos). Images + captions bound
// to svc_commons imageinfo (S4 fills).
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { MWKImageInfo } from '../model/MWKImageInfo';
import { CommonsService } from '../common/CommonsService';

class ImageInfoDataSource implements IDataSource {
  private items: MWKImageInfo[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): MWKImageInfo {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: MWKImageInfo[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Component
export struct WMFImageGalleryView {
  // MWKImageInfoFetcher: the gallery resolves its own image info from the Commons file
  // title the presenter hands over.
  @Prop fileTitle: string = '';
  @Prop fallbackImageURL: string = '';
  @Prop fallbackDescription: string = '';
  // From an article: every image of it (Commons file titles + the URLs it showed), opened on
  // initialIndex; swiping pages through them, as the source's gallery does.
  @Prop fileTitles: string[] = [];
  @Prop imageURLs: string[] = [];
  @Prop initialIndex: number = 0;
  @State items: MWKImageInfo[] = [];
  @State currentIndex: number = 0;
  onClose?: () => void;
  private imagesSource: ImageInfoDataSource = new ImageInfoDataSource();

  aboutToAppear(): void {
    if (this.fileTitles.length > 0) {
      this.loadArticleImages();
      return;
    }
    this.setItems([this.fallbackInfo()]);
    if (this.fileTitle === '') {
      return;
    }
    CommonsService.fetchCommonsImageInfo(this.fileTitle, 640).then((info: MWKImageInfo | null) => {
      if (info !== null) {
        this.setItems([info]);
      }
    }).catch((e: Error) => {
      console.error('gallery: imageinfo fetch failed: ' + e.message);
    });
  }

  private loadArticleImages(): void {
    const shown: MWKImageInfo[] = this.fileTitles.map((title: string, i: number): MWKImageInfo => {
      const info = new MWKImageInfo();
      info.canonicalPageTitle = title;
      info.canonicalFileURL = this.imageURLs[i] ?? '';
      info.imageThumbURL = this.imageURLs[i] ?? '';
      return info;
    });
    this.currentIndex = Math.min(Math.max(this.initialIndex, 0), shown.length - 1);
    this.setItems(shown);
    CommonsService.fetchCommonsImageInfos(this.fileTitles, 640).then((infos: MWKImageInfo[]) => {
      const byTitle: Map<string, MWKImageInfo> = new Map<string, MWKImageInfo>();
      for (const info of infos) {
        byTitle.set(info.canonicalPageTitle ?? '', info);
      }
      this.setItems(shown.map((s: MWKImageInfo): MWKImageInfo => byTitle.get(s.canonicalPageTitle ?? '') ?? s));
    }).catch((e: Error) => {
      console.error('gallery: imageinfo fetch failed: ' + e.message);
    });
  }

  private setItems(items: MWKImageInfo[]): void {
    this.items = items;
    if (this.currentIndex >= items.length) {
      this.currentIndex = 0;
    }
    this.imagesSource.reload(items);
  }

  // the feed's own copy of the image keeps the gallery usable offline
  private fallbackInfo(): MWKImageInfo {
    const info = new MWKImageInfo();
    info.canonicalPageTitle = this.fileTitle;
    info.canonicalFileURL = this.fallbackImageURL;
    info.imageThumbURL = this.fallbackImageURL;
    info.imageDescription = this.fallbackDescription;
    return info;
  }

  build() {
    Stack() {
      // S5 (source WMFImageGalleryViewController is a full-screen black photo viewer):
      // black backdrop, white chrome glyphs, caption over a dark scrim.
      // image pager
      Swiper() {
        LazyForEach(this.imagesSource, (info: MWKImageInfo) => {
          Image(info.imageThumbURL !== null ? info.imageThumbURL : (info.canonicalFileURL !== null ? info.canonicalFileURL : ''))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
          // The key has to carry the URL: the feed's own copy is shown first and the Commons
          // imageinfo replaces it a moment later under the same file title, so a key of the
          // title alone let LazyForEach keep the node it had already built and the swapped-in
          // URL never reached the Image.
        }, (info: MWKImageInfo) => (info.canonicalPageTitle ?? '') + '|' +
          (info.imageThumbURL ?? info.canonicalFileURL ?? ''))
      }
      .index($$this.currentIndex)
      .loop(false)
      .width('100%')
      .height('100%')
      .indicator(false)
      .backgroundColor($r('app.color.wmf_black'))

      Column() {
        // overlay top bar: close (left) + share (right)
        Row() {
          Button() {
            // source close is tinted white for the always-dark gallery — the app's own
            // inverse (light-on-dark) close asset carries that without a raster tint
            Image($r('app.media.close_inverse'))
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)
          }
            .id('gallery_close')
            .accessibilityText('Close')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)
            .onClick(() => {
              this.dismiss();
            })
          Blank()
          Button() {
            // source share glyph (raster template — the app ships it pre-tinted;
            // the blue variant is the only non-black one available)
            Image($r('app.media.places_share'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
          }
            .id('gallery_share')
            .accessibilityText('Share')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)
            .onClick(() => {
              this.share();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8, top: 8 })

        Blank()

        // WMFImageGalleryDetailOverlayView caption
        Column({ space: 8 }) {
          Text(this.descriptionText())
            .fontSize(15)
            .lineHeight(21)
            .fontColor($r('app.color.wmf_white'))
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            Text(this.licenseText())
              .id('gallery_license')
              .layoutWeight(1)
              .fontSize(13)
              .fontColor($r('app.color.wmf_white'))
              .opacity(0.7)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.openLicense();
              })
            Button('Save image')
              .id('gallery_save')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .fontSize(15)
              .fontColor($r('app.color.wmf_white'))
              .height(40)
              .padding({ left: 12 })
              .onClick(() => {
                this.saveImage();
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .backgroundColor('#B3000000')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      // the chrome sits over the pager: its empty middle passes swipes through to the Swiper
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .id('WMFImageGalleryViewController')
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.wmf_black'))
  }

  private currentInfo(): MWKImageInfo | null {
    if (this.currentIndex >= 0 && this.currentIndex < this.items.length) {
      return this.items[this.currentIndex];
    }
    return null;
  }

  // Commons extmetadata is HTML: the description carries markup and the artist/licence
  // fields are anchor tags. Rendered raw, the licence line read
  // 'CC BY 4.0 <a href="//commons.wikimedia.org/wiki/...'.
  private static plain(html: string): string {
    return html.replace(/<[^>]*>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private descriptionText(): string {
    const info = this.currentInfo();
    if (info !== null && info.imageDescription !== null) {
      return WMFImageGalleryView.plain(info.imageDescription);
    }
    return '';
  }

  private licenseText(): string {
    const info = this.currentInfo();
    if (info === null) {
      return '';
    }
    const license: string = info.license !== null && info.license.shortDescription !== null ? info.license.shortDescription : '';
    const owner: string = info.owner !== null ? info.owner : '';
    return WMFImageGalleryView.plain(license + ' ' + owner);
  }

  private dismiss(): void {
    if (this.onClose !== undefined) {
      this.onClose();
      return;
    }
    router.back();
  }

  private currentImageURL(): string {
    const info = this.currentInfo();
    if (info === null) {
      return '';
    }
    if (info.canonicalFileURL !== null && info.canonicalFileURL !== '') {
      return info.canonicalFileURL;
    }
    return info.imageThumbURL ?? '';
  }

  // No ShareKit in this SDK: clipboard + toast so the control never silently no-ops
  // (self-signed-capabilities.md).
  private share(): void {
    const info = this.currentInfo();
    const title: string = info !== null && info.canonicalPageTitle !== null ? info.canonicalPageTitle : '';
    const text: string = (title + ' ' + this.currentImageURL()).trim();
    if (text === '') {
      return;
    }
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: 'Image link copied' });
    }).catch((e: Error) => {
      console.error('gallery: share failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not share this image' });
    });
  }

  private saveImage(): void {
    this.saveCurrentImage().catch((e: Error) => {
      console.error('gallery: save failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not save this image' });
    });
  }

  // Save-to-photos without any media permission: the asset-creation dialog grants a
  // one-shot write uri that the downloaded bytes are copied into.
  private async saveCurrentImage(): Promise<void> {
    const url: string = this.currentImageURL();
    if (url === '') {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const request = http.createHttp();
    let buffer: ArrayBuffer;
    try {
      const resp: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      buffer = resp.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
    const extension: string = this.extensionFor(url);
    const cachePath: string = ctx.cacheDir + '/gallery_image.' + extension;
    const cached: fileIo.File = fileIo.openSync(cachePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(cached.fd, buffer);
    } finally {
      fileIo.closeSync(cached);
    }
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
    const config: photoAccessHelper.PhotoCreationConfig = {
      title: this.saveTitle(),
      fileNameExtension: extension,
      photoType: photoAccessHelper.PhotoType.IMAGE
    };
    const targets: string[] =
      await helper.showAssetsCreationDialog([fileUri.getUriFromPath(cachePath)], [config]);
    if (targets.length === 0) {
      return;
    }
    const target: fileIo.File = fileIo.openSync(targets[0], fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(target.fd, buffer);
    } finally {
      fileIo.closeSync(target);
    }
    this.getUIContext().getPromptAction().showToast({ message: 'Image saved to Photos' });
  }

  private saveTitle(): string {
    const info = this.currentInfo();
    const raw: string = info !== null && info.canonicalPageTitle !== null ? info.canonicalPageTitle : 'image';
    return raw.replace(/^File:/, '').replace(/\.[a-zA-Z0-9]+$/, '');
  }

  private extensionFor(url: string): string {
    const match: RegExpMatchArray | null = url.match(/\.([a-zA-Z0-9]+)(?:\?|$)/);
    if (match === null) {
      return 'jpg';
    }
    const ext: string = match[1].toLowerCase();
    return ext === 'jpeg' ? 'jpg' : ext;
  }

  private openLicense(): void {
    const info = this.currentInfo();
    if (info !== null && info.license !== null && info.license.url !== null) {
      const params: Record<string, string> = { 'url': info.license.url };
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
    }
  }
}


// Routed host. The gallery was presented with .bindContentCover over the Explore feed and
// came up as an empty black screen: the photo never reached the Image. Routed as a page it
// keeps its own lifetime, which is the fix this port has applied to every other cover that
// loads over the network.
@Entry
@Component
struct ImageGalleryPage {
  @State fileTitle: string = '';
  @State fallbackImageURL: string = '';
  @State fallbackDescription: string = '';
  @State fileTitles: string[] = [];
  @State imageURLs: string[] = [];
  @State initialIndex: number = 0;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined) {
      this.fileTitle = params['fileTitle'] ?? '';
      this.fallbackImageURL = params['fallbackImageURL'] ?? '';
      this.fallbackDescription = params['fallbackDescription'] ?? '';
      if ((params['fileTitles'] ?? '') !== '') {
        this.fileTitles = JSON.parse(params['fileTitles']) as string[];
        this.imageURLs = JSON.parse(params['imageURLs'] ?? '[]') as string[];
        this.initialIndex = Number.parseInt(params['initialIndex'] ?? '0', 10);
      }
    }
  }

  build() {
    Column() {
      WMFImageGalleryView({
        fileTitle: this.fileTitle,
        fallbackImageURL: this.fallbackImageURL,
        fallbackDescription: this.fallbackDescription,
        fileTitles: this.fileTitles,
        imageURLs: this.imageURLs,
        initialIndex: this.initialIndex,
        onClose: (): void => {
          router.back();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
