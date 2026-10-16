// The non-text blocks of an article body, shared by the article and random-article screens:
// a figure (image + caption) and a table PCS collapses behind a header ("Quick facts",
// "More information"). Both screens render the blocks parseArticle produces.
import { ComponentUtils, componentUtils, window } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { versionedUserAgent } from '../common/HttpClient';
import { NAV_INDICATOR_INSET_KEY, topSafeInset } from '../common/SafeArea';
import { readableInlineColor, swatchPixelMap } from '../common/Swatch';
import {
  ArticleBlock, ArticleSegment, GridCell, GridRow, QuickFact, TableImage, TableImageLine, TableMarker
} from '../pages/ArticleViewControllerPage';

// PCS draws its external-link mark after links with the "external" class (light / dark link
// colour, mirrored for RTL).
export function externalLinkMark(dark: boolean, rtl: boolean): Resource {
  if (rtl) {
    return dark ? $r('app.media.external_link_mark_rtl_dark') : $r('app.media.external_link_mark_rtl_light');
  }
  return dark ? $r('app.media.external_link_mark_dark') : $r('app.media.external_link_mark_light');
}

// A figure: the image at its own aspect ratio, its caption centred below in small text. A
// video figure shows its poster at the video's own width with the source's play button (a
// 60 vp dark disc) over it; a tap plays the clip full screen with the standard controls.
@Component
export struct ArticleFigureView {
  block: ArticleBlock = new ArticleBlock();
  @Prop fontPercent: number = 100;
  @Prop imageOpacity: number = 1;
  @Prop rtl: boolean = false;
  @Prop dark: boolean = false;
  onLink: (seg: ArticleSegment) => void = (seg: ArticleSegment): void => {};
  // a tap on the image (not a video): the article opens its gallery there
  onImage: (block: ArticleBlock) => void = (block: ArticleBlock): void => {};
  @State private playing: boolean = false;
  // the source being tried: a file the player cannot open moves on to the next one
  @State private source: number = 0;

  private fs(size: number): number {
    return size * this.fontPercent / 100;
  }

  // the source's full-screen player hides the status bar while it is up
  private statusBar(shown: boolean): void {
    window.getLastWindow(getContext(this)).then((w: window.Window) => {
      return w.setSpecificSystemBarEnabled('status', shown);
    }).catch((e: Error) => {
      console.warn('figure: status bar not toggled: ' + e.message);
    });
  }

  @Builder
  player() {
    Stack({ alignContent: Alignment.TopStart }) {
      // the black runs under the gesture strip; the player and its controls stay above it
      Video({ src: this.block.videoURLs[this.source] ?? '', previewUri: this.block.imageURL })
        .width('100%')
        .height('100%')
        .padding({ bottom: AppStorage.get<number>(NAV_INDICATOR_INSET_KEY) ?? 0 })
        .autoPlay(true)
        .controls(true)
        .objectFit(ImageFit.Contain)
        .onError(() => {
          console.warn('figure: video source ' + this.source + ' failed');
          if (this.source < this.block.videoURLs.length - 1) {
            this.source++;
          }
        })
      SymbolGlyph($r('sys.symbol.xmark'))
        .id('video_player_close')
        .fontSize(22)
        .fontColor([Color.White])
        .padding(12)
        .margin({ top: topSafeInset(), left: 4 })
        .onClick(() => {
          this.playing = false;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .onAppear(() => {
      this.statusBar(false);
    })
    .onDisAppear(() => {
      this.statusBar(true);
    })
  }

  build() {
    Column({ space: 6 }) {
      if (this.block.videoURLs.length > 0) {
        Stack() {
          Image(this.block.imageURL)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .opacity(this.imageOpacity)
          Stack() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(24)
              .fontColor([Color.White])
              .margin({ left: 3 })
          }
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor('#D93C3C3C')
          .backdropBlur(10)
        }
        .id('article_video')
        .width(this.block.imageWidth > 0 ? this.block.imageWidth : '100%')
        .constraintSize({ maxWidth: '100%' })
        .aspectRatio(this.block.imageRatio > 0 ? 1 / this.block.imageRatio : 4 / 3)
        .backgroundColor(Color.Black)
        .onClick(() => {
          this.source = 0;
          this.playing = true;
        })
        .bindContentCover($$this.playing, this.player(), { modalTransition: ModalTransition.DEFAULT, backgroundColor: Color.Black })
      } else {
        Image(this.block.imageURL)
          .width('100%')
          .aspectRatio(this.block.imageRatio > 0 ? 1 / this.block.imageRatio : 1.5)
          .objectFit(ImageFit.Contain)
          .opacity(this.imageOpacity)
          .onClick(() => {
            this.onImage(this.block);
          })
      }
      if (this.block.segments.length > 0) {
        Text() {
          ForEach(this.block.segments, (seg: ArticleSegment, i: number) => {
            if (seg.kind === 'swatch') {
              ImageSpan(swatchPixelMap(seg.color, seg.borderColor))
                .width(this.fs(13))
                .height(this.fs(13))
                .margin({ right: 4 })
                .verticalAlign(ImageSpanAlignment.CENTER)
            } else {
              Span(seg.text)
                .fontColor(seg.kind !== 'text' ? $r('app.color.theme_link')
                  : (readableInlineColor(seg.color, this.dark) !== '' ? readableInlineColor(seg.color, this.dark)
                    : $r('app.color.theme_secondary_text')))
                .textBackgroundStyle({ color: seg.background !== '' && !this.dark ? seg.background : Color.Transparent })
                .onClick(() => {
                  if (seg.kind !== 'text') {
                    this.onLink(seg);
                  }
                })
              if (seg.externalMark) {
                ImageSpan(externalLinkMark(this.dark, this.rtl))
                  .width(this.fs(12))
                  .height(this.fs(12))
                  .margin({ left: 2 })
                  .verticalAlign(ImageSpanAlignment.CENTER)
              }
            }
          }, (seg: ArticleSegment, i: number) => this.block.key + '_c' + i)
        }
        .width('100%')
        // the source's caption size measured against its body text (same words): ~0.9 of 17
        .fontSize(this.fs(15))
        .lineHeight(this.fs(21))
        .textAlign(TextAlign.Center)
        .direction(this.rtl ? Direction.Rtl : Direction.Ltr)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}

// maps.wikimedia.org answers 403 to a request without a Referer or the app's User-Agent, and
// Image cannot send headers (the interactive map stayed blank): fetch it with the app's
// User-Agent and draw the decoded pixels. The server also rate-limits (429 for about a second
// after a burst), which left the map blank: a failed fetch is retried after a short wait, and
// a map once decoded is kept for the session, so reopening a table does not ask again.
// ponytail: unbounded session cache; only infobox maps go through here, a handful per session.
const fetchedPixels: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
const RETRY_DELAYS_MS: number[] = [1200, 3000, 6000];

@Component
struct FetchedImage {
  url: string = '';
  ratio: number = 0.75;
  @Prop imageOpacity: number = 1;
  @State private pixels: image.PixelMap | undefined = undefined;
  private gone: boolean = false;

  aboutToAppear(): void {
    this.pixels = fetchedPixels.get(this.url);
    if (this.pixels === undefined) {
      this.fetch(0);
    }
  }

  aboutToDisappear(): void {
    this.gone = true;
  }

  private fetch(attempt: number): void {
    const req: http.HttpRequest = http.createHttp();
    req.request(this.url, {
      header: { 'User-Agent': versionedUserAgent() },
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    }).then(async (res: http.HttpResponse) => {
      if (res.responseCode !== 200) {
        throw new Error('HTTP ' + res.responseCode);
      }
      const source: image.ImageSource = image.createImageSource(res.result as ArrayBuffer);
      const pixels: image.PixelMap = await source.createPixelMap();
      source.release();
      fetchedPixels.set(this.url, pixels);
      this.pixels = pixels;
    }).catch((e: Error) => {
      console.warn('table: map image failed (attempt ' + (attempt + 1) + '): ' + e.message);
      if (attempt < RETRY_DELAYS_MS.length) {
        setTimeout(() => {
          if (!this.gone) {
            this.fetch(attempt + 1);
          }
        }, RETRY_DELAYS_MS[attempt]);
      }
    }).finally(() => {
      req.destroy();
    });
  }

  build() {
    Stack() {
      if (this.pixels !== undefined) {
        Image(this.pixels)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .opacity(this.imageOpacity)
      }
    }
    .width('100%')
    .aspectRatio(1 / this.ratio)
  }
}

// A collapsed table, drawn as the source draws PCS's: a grey bar with "Quick facts" in bold and
// the teaser text, opening in place to the rows (see QuickFact for the row kinds) and ending
// with a Close bar. Links in the rows open like links in the text. It starts open only under
// "Expand tables" (defaultOpen); a change of that setting resets it.
@Component
export struct ArticleTableView {
  block: ArticleBlock = new ArticleBlock();
  @Prop @Watch('onDefaultChanged') defaultOpen: boolean = false;
  @Prop fontPercent: number = 100;
  @Prop imageOpacity: number = 1;
  @Prop rtl: boolean = false;
  // the chevron glyph is a black PNG; dark themes recolour it
  @Prop dark: boolean = false;
  @Prop panelColor: ResourceColor = $r('app.color.theme_mid_background');
  toggleId: string = 'collapse_table_toggle_itemroot';
  onLink: (seg: ArticleSegment) => void = (seg: ArticleSegment): void => {};
  // the article body's Scroll and its id: closing from the bottom bar brings the box's top
  // back into view, as PCS does, instead of leaving the reader far down the article
  scroller: Scroller | null = null;
  scrollId: string = '';
  @State private open: boolean = false;

  aboutToAppear(): void {
    this.open = this.defaultOpen;
  }

  onDefaultChanged(): void {
    this.open = this.defaultOpen;
  }

  private fs(size: number): number {
    return size * this.fontPercent / 100;
  }

  private closeFromBottom(): void {
    if (this.scroller !== null && this.scrollId !== '') {
      const utils: ComponentUtils = this.getUIContext().getComponentUtils();
      const box: componentUtils.ComponentInfo = utils.getRectangleById('table_' + this.block.key);
      const view: componentUtils.ComponentInfo = utils.getRectangleById(this.scrollId);
      const dy: number = this.getUIContext().px2vp(box.windowOffset.y - view.windowOffset.y);
      if (dy < 0) {
        this.scroller.scrollBy(0, dy);
      }
    }
    this.open = false;
  }

  private textDirection(): Direction {
    return this.rtl ? Direction.Rtl : Direction.Ltr;
  }

  private chevronFilter(): ColorFilter {
    return new ColorFilter(this.dark
      ? [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0]
      : [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
  }

  // A cell's runs: links in the link colour (tappable), bold/italic kept, superscripts raised
  // and smaller, flag icons inline.
  @Builder
  cellText(segs: ArticleSegment[], size: number, bold: boolean, align: TextAlign, key: string) {
    // one Text per paragraph, half a line apart (the source's <p> / list margins); lines inside
    // a paragraph or list stay tight
    Column({ space: this.fs(size * 0.5) }) {
      ForEach(this.paragraphs(segs), (paragraph: ArticleSegment[], p: number) => {
        this.paragraphText(paragraph, size, bold, align, key + '_p' + p)
      }, (paragraph: ArticleSegment[], p: number) => key + '_p' + p)
    }
    .width('100%')
  }

  private paragraphs(segs: ArticleSegment[]): ArticleSegment[][] {
    const out: ArticleSegment[][] = [[]];
    for (const seg of segs) {
      if (seg.kind === 'para') {
        out.push([]);
      } else {
        out[out.length - 1].push(seg);
      }
    }
    return out.filter((p: ArticleSegment[]) => p.length > 0);
  }

  @Builder
  paragraphText(segs: ArticleSegment[], size: number, bold: boolean, align: TextAlign, key: string) {
    Text() {
      ForEach(segs, (seg: ArticleSegment) => {
        if (seg.kind === 'icon') {
          ImageSpan(seg.target)
            .width(seg.iconWidth)
            .height(seg.iconHeight)
            .verticalAlign(ImageSpanAlignment.CENTER)
            .margin({ right: 4 })
        } else if (seg.kind === 'swatch') {
          ImageSpan(swatchPixelMap(seg.color, seg.borderColor))
            .width(this.fs(size * 0.85))
            .height(this.fs(size * 0.85))
            .margin({ right: 4 })
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(seg.text)
            .fontSize(this.fs(seg.sup ? size * 0.7 : size))
            .fontWeight(bold || seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
            .fontColor(seg.kind !== 'text' ? $r('app.color.theme_link')
              : (readableInlineColor(seg.color, this.dark) !== '' ? readableInlineColor(seg.color, this.dark)
                : $r('app.color.theme_text')))
            .textBackgroundStyle({ color: seg.background !== '' && !this.dark ? seg.background : Color.Transparent })
            .onClick(() => {
              if (seg.kind !== 'text') {
                this.onLink(seg);
              }
            })
          if (seg.externalMark) {
            ImageSpan(externalLinkMark(this.dark, this.rtl))
              .width(this.fs(size * 0.8))
              .height(this.fs(size * 0.8))
              .margin({ left: 2 })
              .verticalAlign(ImageSpanAlignment.CENTER)
          }
        }
      }, (seg: ArticleSegment, i: number) => key + '_' + i)
    }
    .width('100%')
    .fontSize(this.fs(size))
    .lineHeight(this.fs(size * 1.4))
    // superscripts (km², [2]) are the smaller spans set at the top of the line: raised like the
    // source's without a baselineOffset, which made that line taller and its cell start lower
    // than the cell beside it
    .textVerticalAlign(TextVerticalAlign.TOP)
    .textAlign(align)
    .direction(this.textDirection())
  }

  // One picture with its caption and, on a location map, its pins (placed in vp from the map's
  // display size: % positions resolved against the wrong box and drew the pins under it).
  @Builder
  tableImage(img: TableImage) {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (img.boxHeight > 0) {
          Image(img.url)
            .width('100%')
            .height(img.boxHeight)
            .objectFit(ImageFit.Cover)
            .opacity(this.imageOpacity)
        } else if (img.url.indexOf('//maps.wikimedia.org/') >= 0) {
          FetchedImage({ url: img.url, ratio: img.ratio, imageOpacity: this.imageOpacity })
        } else {
          Image(img.url)
            .width('100%')
            .aspectRatio(1 / img.ratio)
            .objectFit(ImageFit.Contain)
            .opacity(this.imageOpacity)
        }
        ForEach(img.markers, (pin: TableMarker) => {
          Row({ space: 3 }) {
            if (pin.side === 'l') {
              Text(pin.label).fontSize(this.fs(12)).fontColor('#202122')
            }
            Circle({ width: 8, height: 8 }).fill('#D33333').stroke('#FFFFFF').strokeWidth(1)
            if (pin.side !== 'l') {
              Text(pin.label).fontSize(this.fs(12)).fontColor('#202122')
            }
          }
          .height(16)
          .position({ x: img.width * pin.left / 100 - 4, y: img.width * img.ratio * pin.top / 100 - 8 })
          .translate({ x: pin.side === 'l' ? '-100%' : 0 })
        }, (pin: TableMarker) => pin.key)
      }
      .width(img.width)
      .constraintSize({ maxWidth: '100%' })
      if (img.caption.length > 0) {
        // the source's caption size measured against its body text (same words): ~0.9 of 17
        this.cellText(img.caption, 15, false,
          img.captionAlign === 'start' ? TextAlign.Start : (img.captionAlign === 'end' ? TextAlign.End : TextAlign.Center),
          img.key + '_c')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // A spanning cell's pictures, line by line and centred.
  @Builder
  imageLines(fact: QuickFact) {
    ForEach(fact.lines, (line: TableImageLine) => {
      if (line.equal) {
        Row() {
          ForEach(line.images, (img: TableImage) => {
            Column() {
              this.tableImage(img)
            }
            .layoutWeight(1)
          }, (img: TableImage) => img.key)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 4, bottom: 4 })
      } else {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(line.images, (img: TableImage) => {
            Column() {
              this.tableImage(img)
            }
            .width(img.width)
            .constraintSize({ maxWidth: '100%' })
            .margin(1)
          }, (img: TableImage) => img.key)
        }
        .width('100%')
        .margin({ top: 4, bottom: 4 })
      }
    }, (line: TableImageLine) => line.key)
  }

  @Builder
  rowView(fact: QuickFact) {
    Column() {
      if (fact.kind === 'pair') {
        Row({ space: 8 }) {
          if (fact.labelSegs.length > 0) {
            Column() {
              this.cellText(fact.labelSegs, 15, true, TextAlign.Start, fact.key + '_l')
            }
            .width(fact.valueSegs.length > 0 ? '48%' : '100%')
          }
          if (fact.valueSegs.length > 0) {
            Column() {
              this.cellText(fact.valueSegs, 15, false, TextAlign.Start, fact.key + '_v')
            }
            .layoutWeight(1)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .direction(this.textDirection())
      } else if (fact.kind === 'full') {
        this.imageLines(fact)
        if (fact.valueSegs.length > 0) {
          this.cellText(fact.valueSegs, 15, false, TextAlign.Center, fact.key + '_v')
        }
      } else {
        // above / subheader / header: centred; the bands are light colours, kept to the light
        // themes so dark text stays readable. A header boxed by its template (an inline-bordered
        // div) keeps that frame, in its own colour in every theme.
        if (fact.frameWidth > 0) {
          Column() {
            this.cellText(fact.valueSegs, 15, true, TextAlign.Center, fact.key + '_v')
          }
          .width('100%')
          .padding({ top: 2, bottom: 2, left: 4, right: 4 })
          .border({ width: fact.frameWidth, color: fact.frame })
        } else {
          this.cellText(fact.valueSegs, fact.kind === 'above' ? 17 : 15, fact.kind !== 'above',
            fact.alignStart ? TextAlign.Start : TextAlign.Center, fact.key + '_v')
        }
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(fact.band !== '' && !this.dark ? fact.band : Color.Transparent)
    .border({ width: { top: fact.kind === 'above' ? 0 : 0.5 }, color: $r('app.color.theme_border') })
  }

  private gridWidth(): number {
    return this.block.columnWidths.reduce((sum: number, w: number) => sum + w, 0);
  }

  // A wikitable as the source draws it: bordered cells in columns, header cells bold on the
  // header grey, the grid scrolling sideways when wider than the screen.
  @Builder
  gridView() {
    Scroll() {
      Column() {
        ForEach(this.block.grid, (row: GridRow) => {
          Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
            ForEach(row.cells, (cell: GridCell) => {
              Column() {
                if (!cell.filler) {
                  // the source sets wikitable text at the body size
                  this.cellText(cell.segs, 17, cell.header,
                    cell.align === 'center' ? TextAlign.Center : (cell.align === 'end' ? TextAlign.End : TextAlign.Start),
                    cell.key)
                }
              }
              .width(cell.width)
              .padding(8)
              .justifyContent(FlexAlign.Center)
              // the light cell colours are kept to the light themes, as the infobox bands
              .backgroundColor(this.dark ? Color.Transparent
                : (cell.background !== '' ? cell.background : (cell.header ? '#EAECF0' : Color.Transparent)))
              .border({ width: { right: 0.5, bottom: cell.open ? 0 : 0.5 }, color: $r('app.color.theme_border') })
            }, (cell: GridCell) => cell.key)
          }
          .width(this.gridWidth())
        }, (row: GridRow) => row.key)
      }
      .alignItems(HorizontalAlign.Start)
      .border({ width: { top: 0.5, left: 0.5 }, color: $r('app.color.theme_border') })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .align(Alignment.TopStart)
    .width('100%')
    .direction(this.textDirection())
  }

  build() {
    Column() {
      Row() {
        Text() {
          Span(this.block.title)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
          if (this.block.teaser !== '') {
            Span(' ' + this.block.teaser)
              .fontColor($r('app.color.theme_secondary_text'))
          }
        }
          .layoutWeight(1)
          .fontSize(this.fs(16))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Image(this.open ? $r('app.media.chevron_up') : $r('app.media.chevron_down'))
          .colorFilter(this.chevronFilter())
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .margin({ left: 12 })
      }
      .id(this.toggleId)
      .width('100%')
      .padding(12)
      .direction(this.textDirection())
      .alignItems(VerticalAlign.Center)
      .accessibilityText(this.open ? 'Collapse table' : 'Expand table')
      .onClick(() => {
        this.open = !this.open;
      })
      if (this.open) {
        if (this.block.grid.length > 0) {
          this.gridView()
        } else {
          ForEach(this.block.rows, (fact: QuickFact) => {
            this.rowView(fact)
          }, (fact: QuickFact) => fact.key)
        }
        // PCS's pcs-collapse-table-collapsed-bottom: "Close" in the subtle colour, chevron up
        Row() {
          Text($r('app.string.close_button_accessibility_label'))
            .layoutWeight(1)
            .fontSize(this.fs(16))
            .fontColor($r('app.color.theme_secondary_text'))
          Image($r('app.media.chevron_up'))
            .colorFilter(this.chevronFilter())
            .width(16)
            .height(16)
            .objectFit(ImageFit.Contain)
        }
        .id(this.toggleId + '_close')
        .width('100%')
        .padding(12)
        .direction(this.textDirection())
        .alignItems(VerticalAlign.Center)
        .border({ width: { top: 0.5 }, color: $r('app.color.theme_border') })
        .onClick(() => {
          this.closeFromBottom();
        })
      }
    }
    .id('table_' + this.block.key)
    .width('calc(100% - 32vp)')
    .alignItems(HorizontalAlign.Start)
    .margin({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.panelColor)
    .borderRadius(2)
    .clip(true)
  }
}

// A Template:Pie chart: the pie drawn natively (the chart's background, then each slice from
// 12 o'clock clockwise, then a thin outline), its bold caption, and the legend (a swatch and a
// label per line), sized and spaced as measured against the source.
@Component
export struct ArticlePieView {
  block: ArticleBlock = new ArticleBlock();
  @Prop fontPercent: number = 100;
  @Prop rtl: boolean = false;
  @Prop @Watch('draw') dark: boolean = false;
  onLink: (seg: ArticleSegment) => void = (seg: ArticleSegment): void => {};
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private fs(size: number): number {
    return size * this.fontPercent / 100;
  }

  // The template's size is in CSS px. Measured against the same body text on both phones, the
  // source draws a 200 px chart at the size our 166 vp is, so CSS px -> vp is 0.83.
  private chartSize(): number {
    return Math.min((this.block.pieSize > 0 ? this.block.pieSize : 200) * 0.83, 300);
  }

  draw(): void {
    const size: number = this.chartSize();
    const c: CanvasRenderingContext2D = this.context;
    const center: number = size / 2;
    const radius: number = size / 2 - 1;
    c.clearRect(0, 0, size, size);
    c.beginPath();
    c.arc(center, center, radius, 0, Math.PI * 2);
    c.fillStyle = this.block.pieBackground;
    c.fill();
    for (const slice of this.block.slices) {
      const from: number = -Math.PI / 2 + Math.PI * 2 * slice.start;
      c.beginPath();
      c.moveTo(center, center);
      c.arc(center, center, radius, from, from + Math.PI * 2 * slice.extent);
      c.closePath();
      c.fillStyle = slice.color;
      c.fill();
    }
    c.beginPath();
    c.arc(center, center, radius, 0, Math.PI * 2);
    c.lineWidth = 1;
    c.strokeStyle = this.dark ? '#a2a9b1' : '#202122';
    c.stroke();
  }

  @Builder
  line(segs: ArticleSegment[], bold: boolean, key: string) {
    Text() {
      ForEach(segs, (seg: ArticleSegment) => {
        if (seg.kind === 'swatch') {
          ImageSpan(swatchPixelMap(seg.color, seg.borderColor))
            .width(this.fs(13))
            .height(this.fs(13))
            .margin({ right: 8 })
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else if (seg.kind !== 'icon' && seg.kind !== 'para') {
          Span(seg.text)
            .fontWeight(bold || seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(seg.italic ? FontStyle.Italic : FontStyle.Normal)
            // the source's legend text is the body colour (#202122), links in the link colour
            .fontColor(seg.kind !== 'text' ? $r('app.color.theme_link') : $r('app.color.theme_text'))
            .onClick(() => {
              if (seg.kind !== 'text') {
                this.onLink(seg);
              }
            })
        }
      }, (seg: ArticleSegment, i: number) => key + '_' + i)
    }
    .width('100%')
    // the legend's size measured against the source with the same words (caption "Seat share of
    // parties in the election": 777 px there, body text equal on both phones)
    .fontSize(this.fs(16.5))
    .lineHeight(this.fs(24.5))
    .direction(this.rtl ? Direction.Rtl : Direction.Ltr)
  }

  build() {
    // legend lines 8 vp apart: the source's line pitch (line-height 1.5 + li margin), measured
    Column({ space: 8 }) {
      Canvas(this.context)
        .width(this.chartSize())
        .height(this.chartSize())
        .margin({ bottom: 8 })
        .onReady(() => {
          this.draw();
        })
      if (this.block.segments.length > 0) {
        this.line(this.block.segments, true, this.block.key + '_cap')
      }
      ForEach(this.block.legend, (segs: ArticleSegment[], i: number) => {
        this.line(segs, false, this.block.key + '_l' + i)
      }, (segs: ArticleSegment[], i: number) => this.block.key + '_l' + i)
    }
    .width('100%')
    .alignItems(this.rtl ? HorizontalAlign.End : HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}
