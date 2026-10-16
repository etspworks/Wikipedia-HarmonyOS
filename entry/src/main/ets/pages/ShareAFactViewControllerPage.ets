// screen_share_a_fact — presentation: modal, hosted by ArticleViewControllerPage
// (.bindContentCover). NOT a routed page; never registered in main_pages.json.
// Ported from Wikipedia/Code/ShareViewController.swift: over the paper background (90%),
// "Building Share-a-fact card…" with Cancel while the lead image loads, then the card
// (ShareAFactViewController, see ShareAFactCard) rendered to an image is shown and the share
// panel opens with it and the share text ("“text” from “title”: url"). Closing the panel
// dismisses the cover, as the activity controller's completion handler does.
import { http } from '@kit.NetworkKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import common from '@ohos.app.ability.common';
import { formatString } from '../common/Plural';
import { shareAFactCard, ShareAFactCardModel } from '../components/ShareAFactCard';

@Component
export struct ShareAFactView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // ShareViewController(text:article:theme:)
  @Prop selectedText: string = '';
  @Prop articleTitle: string = '';
  @Prop imageURL: string = '';
  @Prop articleURL: string = '';
  onShare?: () => void;

  @State cardPath: string = '';
  private cancelled: boolean = false;

  aboutToAppear(): void {
    this.build_card();
  }

  private finish(): void {
    const cb: (() => void) | undefined = this.onShare;
    if (cb !== undefined) {
      cb();
    }
  }

  private async download(url: string, path: string): Promise<boolean> {
    const request = http.createHttp();
    try {
      const resp: http.HttpResponse = await request.request(url.startsWith('//') ? 'https:' + url : url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      this.write(path, resp.result as ArrayBuffer);
      return true;
    } catch (e) {
      return false;
    } finally {
      request.destroy();
    }
  }

  private write(path: string, data: ArrayBuffer): void {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE |
      fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      fileIo.closeSync(file);
    }
  }

  @Builder
  cardBuilder(model: ShareAFactCardModel) {
    shareAFactCard(model)
  }

  // loadImage -> createShareAFactCard -> showActivityViewController(with:)
  private async build_card(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      const model: ShareAFactCardModel = new ShareAFactCardModel();
      model.text = this.selectedText;
      model.articleTitle = this.articleTitle;
      model.madeWith = ctx.resourceManager.getStringSync($r('app.string.share_a_fact_made_with').id);
      const leadPath: string = ctx.cacheDir + '/share_a_fact_lead';
      if (this.imageURL !== '' && await this.download(this.imageURL, leadPath)) {
        model.imagePath = leadPath;
      }
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot()
        .createFromBuilder(() => { this.cardBuilder(model); }, 300);
      const packer: image.ImagePacker = image.createImagePacker();
      const png: ArrayBuffer = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
      packer.release();
      const path: string = ctx.cacheDir + '/share_a_fact.png';
      this.write(path, png);
      if (this.cancelled) {
        return;
      }
      this.cardPath = path;
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: 'general.png',
        uri: fileUri.getUriFromPath(path)
      });
      // ShareAFactActivityTextItemProvider.defaultRepresentation
      data.addRecord({
        utd: 'general.text',
        content: formatString(ctx, $r('app.string.share_default_format'),
          [this.selectedText, this.articleTitle, this.articleURL])
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      controller.on('dismiss', () => {
        this.finish();
      });
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (e) {
      console.error('shareAFact: card failed: ' + (e as Error).message);
      this.finish();
    }
  }

  build() {
    Column() {
      if (this.cardPath === '') {
        // busyView: spinner + "Building Share-a-fact card…" and the Cancel button
        Column({ space: 12 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
          Text($r('app.string.share_building'))
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          Button($r('app.string.cancel'))
            .id('share_a_fact_cancel')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.cancelled = true;
              this.finish();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // imageView: the rendered card, pinned towards the top once the share panel rises
        Image('file://' + this.cardPath)
          .id('share_a_fact_card')
          .width('100%')
          .aspectRatio(512 / 291)
          .objectFit(ImageFit.Contain)
          .margin({ top: 80 })
          .shadow({ radius: 12, color: '#33000000' })
      }
    }
    .id('ShareAFactViewController')
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .opacity(1)
  }
}
