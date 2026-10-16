// The article footer, as the source's page shows it (PCS Footer.add from
// ArticleViewController.setupFooter, styled by the PCS footer CSS): the "About this article"
// menu, "Read more" and the licence block. Shared by the Article and Random article screens.
//
// Text sizes are the CSS's px scaled as the body text is: the source's body is 16 px and ours
// 17 vp, and the footer is part of the source's page, so the article text size setting scales it
// too (at 80 % its titles were drawn about 1.2x the source's, next to a body that matched).
// Spacing in px, the icons and the wordmark stay at 1 vp per px. Colours are its theme variables
// (--background-color-neutral-subtle, --border-color-subtle, --color-subtle, --color-emphasized,
// --color-base) for the default, sepia and dark/black themes.
import { common } from '@kit.AbilityKit';
import { upperText } from '../common/LocaleText';
import { WMFTheme } from '../common/ThemeManager';
import { ArticleSummary } from '../model/ArticleSummary';
import { externalLinkMark } from './ArticleBlockViews';

class FooterPalette {
  band: string = '#F8F9FA';
  border: string = '#C8CCD1';
  subtle: string = '#54595D';
  emphasized: string = '#101418';
  base: string = '#202122';
  icon: string = '#72777D';
}

const LIGHT: FooterPalette = new FooterPalette();
const SEPIA: FooterPalette = { band: '#F0E6D6', border: '#CBC8C1', subtle: '#54595D', emphasized: '#101418',
  base: '#202122', icon: '#646059' };
// our body size against the PCS body size (17 vp / 16 px)
const PX_TO_VP: number = 17 / 16;

const DARK: FooterPalette = { band: '#202122', border: '#54595D', subtle: '#A2A9B1', emphasized: '#F8F9FA',
  base: '#EAECF0', icon: '#C8CCD1' };

// alpha kept, RGB replaced: tints the (grey) similar-pages PNG to the palette's icon colour
function tint(hex: string): ColorFilter {
  const n: number = Number.parseInt(hex.substring(1), 16);
  return new ColorFilter([0, 0, 0, 0, ((n >> 16) & 255) / 255, 0, 0, 0, 0, ((n >> 8) & 255) / 255,
    0, 0, 0, 0, (n & 255) / 255, 0, 0, 0, 1, 0]);
}

// .pcs-footer-menu-item: a 20 px icon centred at the leading edge, the title 36 px in, 13 px
// above and 17 px below. A component (not a @Builder) so a subtitle that arrives later, such
// as "Updated 3 days ago", redraws it.
@Component
struct FooterMenuItem {
  @Prop icon: Resource = $r('app.media.footer_talk_page');
  // the similar-pages icon is the CSS's PNG; the others are its SVGs
  @Prop png: boolean = false;
  @Prop title: ResourceStr = '';
  @Prop subtitle: string = '';
  @Prop palette: FooterPalette = LIGHT;
  // the footer's text scale (ArticleFooterView.fs)
  @Prop textScale: number = 1;
  onTap: () => void = (): void => {};

  build() {
    Row() {
      if (this.png) {
        Image(this.icon)
          .width(20)
          .height(20)
          .colorFilter(tint(this.palette.icon))
      } else {
        Image(this.icon)
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .fillColor(this.palette.icon)
      }
      Column() {
        Text(this.title)
          .fontSize(16 * this.textScale)
          .lineHeight(22 * this.textScale)
          .fontColor(this.palette.emphasized)
        if (this.subtitle !== '') {
          Text(this.subtitle)
            .fontSize(14 * this.textScale)
            .lineHeight(16 * this.textScale)
            .fontColor(this.palette.subtle)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 16 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 13, bottom: 17 })
    .onClick(() => {
      this.onTap();
    })
  }
}

@Component
export struct ArticleFooterView {
  @StorageProp('WMFAppThemeName') theme: string = 'light';
  @StorageProp('WMFArticleFontSizeMultiplier') fontPercent: number = 100;
  // "Updated 3 days ago" ('' when unknown: the row then has no subtitle)
  @Prop lastEdited: string = '';
  // the article carries maintenance boxes: the source then lists Page issues
  @Prop hasPageIssues: boolean = false;
  // the article has coordinates: the source then lists View on a map (setupFooter .coordinate)
  @Prop hasCoordinates: boolean = false;
  @Prop related: ArticleSummary[] = [];
  @Prop rtl: boolean = false;
  onTalkPage: () => void = (): void => {};
  onEditHistory: () => void = (): void => {};
  onPageIssues: () => void = (): void => {};
  onSimilarPages: () => void = (): void => {};
  onViewOnMap: () => void = (): void => {};
  onRelated: (title: string) => void = (title: string): void => {};
  onLicense: () => void = (): void => {};
  onBrowser: () => void = (): void => {};
  // where "Read more" starts inside the footer (the table of contents jumps there)
  onReadMoreOffset: (y: number) => void = (y: number): void => {};

  private palette(): FooterPalette {
    if (WMFTheme.isDarkThemeName(this.theme)) {
      return DARK;
    }
    return this.theme.startsWith('sepia') ? SEPIA : LIGHT;
  }

  // a CSS font size (or an em-based length) in vp at the article's text size
  private fs(px: number): number {
    return px * PX_TO_VP * this.fontPercent / 100;
  }

  private dark(): boolean {
    return WMFTheme.isDarkThemeName(this.theme);
  }

  // license-footer-text around its $1 (the licence name, drawn as a link)
  private licenseParts(): string[] {
    let raw: string = 'Content is available under $1 unless otherwise noted.';
    try {
      raw = getContext(this).resourceManager.getStringSync($r('app.string.license_footer_text')).replace(/\\\$/g, '$');
    } catch (e) {
      console.error('footer: licence text unavailable');
    }
    const at: number = raw.indexOf('$1');
    return at < 0 ? [raw, ''] : [raw.substring(0, at), raw.substring(at + 2)];
  }

  // h2#pcs-footer-container-menu-heading / -readmore-heading: a 12 pt upper-case caption on the
  // neutral band, 1.5 em above and 0.5 em below, a 0.5 px rule above and below
  @Builder
  heading(label: Resource) {
    Text(upperText(getContext(this) as common.Context, label))
      .width('100%')
      .fontSize(this.fs(16))
      .letterSpacing(0.5)
      .fontColor(this.palette().subtle)
      .padding({ left: 16, right: 16, top: this.fs(24), bottom: this.fs(8) })
      .backgroundColor(this.palette().band)
      .border({ width: { top: 0.5, bottom: 0.5 }, color: this.palette().border })
  }

  build() {
    Column() {
      this.heading($r('app.string.article_about_title'))
      FooterMenuItem({
        icon: $r('app.media.footer_talk_page'),
        title: $r('app.string.page_talk_page'),
        subtitle: getContext(this).resourceManager.getStringSync($r('app.string.page_talk_page_subtitle')),
        palette: this.palette(),
        textScale: this.fs(1),
        onTap: (): void => {
          this.onTalkPage();
        }
      })
        .id('view_talk_page_discuss')
      FooterMenuItem({
        icon: $r('app.media.footer_last_edited'),
        title: $r('app.string.page_edit_history'),
        subtitle: this.lastEdited,
        palette: this.palette(),
        textScale: this.fs(1),
        onTap: (): void => {
          this.onEditHistory();
        }
      })
        .id('view_edit_history_updated')
      if (this.hasPageIssues) {
        FooterMenuItem({
          icon: $r('app.media.footer_page_issues'),
          title: $r('app.string.page_issues'),
          subtitle: getContext(this).resourceManager.getStringSync($r('app.string.page_issues_subtitle')),
          palette: this.palette(),
          textScale: this.fs(1),
          onTap: (): void => {
            this.onPageIssues();
          }
        })
          .id('page_issues')
      }
      FooterMenuItem({
        icon: $r('app.media.footer_similar_pages'),
        png: true,
        title: $r('app.string.page_similar_titles'),
        palette: this.palette(),
        textScale: this.fs(1),
        onTap: (): void => {
          this.onSimilarPages();
        }
      })
        .id('similar_pages')
      if (this.hasCoordinates) {
        FooterMenuItem({
          icon: $r('app.media.footer_coordinate'),
          title: $r('app.string.page_location'),
          palette: this.palette(),
          textScale: this.fs(1),
          onTap: (): void => {
            this.onViewOnMap();
          }
        })
          .id('view_on_a_map')
      }

      // Read more: text-only rows, title and description each on one line, cut with "..."
      if (this.related.length > 0) {
        Column() {
          this.heading($r('app.string.article_read_more_title'))
        }
        .id('read_more_title')
        .onAreaChange((_o: Area, n: Area) => {
          this.onReadMoreOffset(Number(n.position.y));
        })
        ForEach(this.related, (a: ArticleSummary) => {
          Column() {
            Text(a.displayTitle !== null ? a.displayTitle : (a.title !== null ? a.title : ''))
              .width('100%')
              .fontSize(this.fs(16))
              .lineHeight(this.fs(22))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.palette().base)
            if (a.articleDescription !== null && a.articleDescription !== '') {
              Text(a.articleDescription)
                .width('100%')
                .fontSize(this.fs(14))
                .lineHeight(this.fs(16))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(this.palette().subtle)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 72 })
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16, top: 11, bottom: 11 })
          .onClick(() => {
            this.onRelated(a.title !== null ? a.title : '');
          })
        }, (a: ArticleSummary) => a.title !== null ? a.title : '')
      }

      // section#pcs-footer-container-legal: the wordmark (115 x 18) over a hairline, the licence
      // line (0.75 em, the licence an inline link with its external mark) and the browser link
      Column() {
        Image($r('app.media.footer_wikipedia_wordmark'))
          .width(115)
          .height(18)
          .objectFit(ImageFit.Contain)
          .fillColor(this.dark() ? '#FFFFFF' : '#000000')
        Divider()
          .strokeWidth(1)
          .color(this.palette().border)
          .margin({ top: 10, bottom: 12 })
        Text() {
          Span(this.licenseParts()[0])
          Span('CC BY-SA 4.0')
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              this.onLicense();
            })
          ImageSpan(externalLinkMark(this.dark(), this.rtl))
            .width(this.fs(11))
            .height(this.fs(11))
            .margin({ left: 2, right: 2 })
            .verticalAlign(ImageSpanAlignment.CENTER)
          Span(this.licenseParts()[1])
        }
        .id('cc_by_sa_4')
        .width('100%')
        .fontSize(this.fs(12))
        .lineHeight(this.fs(18))
        .fontColor(this.palette().subtle)
        Text($r('app.string.view_in_browser_footer_link'))
          .id('view_article_in_browser')
          .fontSize(this.fs(12))
          .lineHeight(this.fs(18))
          .fontColor($r('app.color.theme_link'))
          .margin({ top: 10 })
          .onClick(() => {
            this.onBrowser();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 35, bottom: 35 })
      .backgroundColor(this.palette().band)
      .border({ width: { top: 0.5 }, color: this.palette().border })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .direction(this.rtl ? Direction.Rtl : Direction.Ltr)
  }
}
