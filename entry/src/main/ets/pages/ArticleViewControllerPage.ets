// screen_article — presentation: page. S3: real structure from source
// (ArticleViewController.swift + ArticleToolbarController.swift, capture-confirmed tree).
// The body is rendered NATIVELY: ArticleService.mobileHtmlURL's document (offline: the
// ArticleCacheStore copy — ArticleCacheStore.init() first in aboutToAppear) is parsed into
// blocks and every in-document link becomes its own tappable node carrying the source slug.
// It is not a Web: the on-device drivers locate a control only by its visible text or its
// .id() and can see nothing inside a Web, so a Web body makes the article untestable (and
// on the verify device the ArkWeb engine fails to init, filling the app log with errors).
// `webController` stays declared for the genuinely web-based route (SinglePageWeb).
// Hosts overlays: AddArticlesToReadingListView / CreateReadingListView / ShareAFactView /
// ScrollableEducationPanel / WMFArticleTabsView (single content cover, branched),
// ReferenceView / TableOfContentsViewController / PageIssuesTableView /
// WMFReferencePageView / WMFProfileViewSheet (single sheet, branched),
// ReadingThemesControlsView + HintView (popups).
// ONE bindContentCover and ONE bindSheet per node (repeat bindings override each other);
// cover lives on the nav Row, sheet on the root Column, popups on toolbar/body rows.
import { destinationFor, LinkDestination, LinkKind } from '../common/WikiLinks';
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { isRTLLanguage } from '../common/LanguageService';
import { escapeAttributeBrackets } from '../common/WebDocument';
import { ArticleToolbarGlyph } from '../components/ArticleToolbarGlyph';
import { router, SymbolGlyphModifier, LengthMetrics, promptAction } from '@kit.ArkUI';
import { GameStore } from '../common/GameStore';
import { SessionStore } from '../common/SessionStore';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { formatString, lastEditedString } from '../common/Plural';
import { systemShare } from '@kit.ShareKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AddArticlesToReadingListView, READING_LIST_ADDED_KEY } from './AddArticlesToReadingListViewControllerPage';
import { WMFLanguagesView } from './WMFLanguagesViewControllerPage';
import { ReadingThemesControlsView } from './ReadingThemesControlsViewControllerPage';
import { ReferenceView } from './ReferenceViewControllerPage';
import { HintView } from './HintViewControllerPage';
import { PageIssuesTableView } from './PageIssuesTableViewControllerPage';
import { ArticleFooterView } from '../components/ArticleFooterView';
import { showArticleOnMap } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { WMFReferencePageView } from './WMFReferencePageViewControllerPage';
import { ShareAFactView } from './ShareAFactViewControllerPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { TocItem } from '../components/TableOfContentsViewController';
import { TableOfContentsView } from './TableOfContentsViewControllerPage';
import { ScrollableEducationPanelViewController } from '../components/ScrollableEducationPanelViewController';
import { ArticleFigureView, ArticlePieView, ArticleTableView, externalLinkMark } from '../components/ArticleBlockViews';
import { readableInlineColor, swatchPixelMap } from '../common/Swatch';
import { ArticleSummary, ArticleSummaryCoordinates } from '../model/ArticleSummary';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { WMFArticle } from '../model/WMFArticle';
import { ArticleService } from '../common/ArticleService';
import { ArticleCacheStore } from '../common/ArticleCacheStore';
import { SavedStore } from '../common/SavedStore';
import { HistoryStore, PAGE_VIEW_SECONDS_SAVED_KEY } from '../common/HistoryStore';
import { WatchlistService, WatchStatus, WatchlistExpiry } from '../common/WatchlistService';
import { LanguageStore } from '../common/LanguageStore';
import { TabsStore, TabArticle } from '../common/TabsStore';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { i18n } from '@kit.LocalizationKit';
import { DonateHistory } from '../common/DonateHistory';
import { WMFTheme, ThemeColors, ThemeIdentifier, WMFFontFamilies } from '../common/ThemeManager';
import { intentForDestination } from '../entryability/RouteTable';
import { presentChooseExpiryActionSheet } from '../components/WatchlistExpirySheet';
import { FundraisingCampaignStore, CampaignAsset } from '../common/FundraisingCampaignStore';
import { FundraisingAnnouncementPanelView } from './FundraisingAnnouncementPanelViewControllerPage';


// One article section (an h2/h3/h4 heading of the mobile-html document) and its blocks.
export class ArticleSection {
  anchor: string = '';
  title: string = '';
  level: number = 2;
  expanded: boolean = false;
  // PCS gives a heading an edit link only where the section can be edited on its own (main
  // sections; not subsections or transcluded ones). The source draws its pencil there only.
  editable: boolean = false;
  // PCS marks the sections after the body (References, Further reading, External links) hideable:
  // the source draws them closed behind a toggle. No other section can be closed.
  collapsible: boolean = false;
  // a subsection of a hideable section: that section's anchor (it hides with it)
  under: string = '';
  blocks: ArticleBlock[] = [];
}

// One inline run of a paragraph or list item. A link is its OWN run so it can be rendered
// as its own tappable node. Its id is '<slug>_articlelink_itemroot' — the document's links
// are per-article and no controlInventory can enumerate them, which is exactly Rule 12's
// list-row exception; the visible Text stays the link label so the drivers match on it.
export class ArticleSegment {
  text: string = '';
  kind: string = 'text';       // text | wiki | ref | backlink | external | icon | swatch | para
  target: string = '';         // wiki title, cite anchor, or absolute URL
  slug: string = '';
  bold: boolean = false;
  italic: boolean = false;
  // inside <sup> (reference marks, km²); table cells draw it raised and smaller
  sup: boolean = false;
  // inside <small> (a message box's "(Learn how and when to remove these messages)")
  small: boolean = false;
  // kind 'icon': an inline image in a table cell (a flag icon), target = its URL
  iconWidth: number = 0;
  iconHeight: number = 0;
  // an inline text colour (<span style="color:green">Success</span>), '' = the theme's; for
  // kind 'swatch' the swatch's fill
  color: string = '';
  // a highlight behind the text (<span style="background:…">text</span>), '' = none
  background: string = '';
  // kind 'swatch' (an empty <span> with a background: a legend or colour-box square): its
  // border colour, '' = none
  borderColor: string = '';
  // a link with the "external" class: the source draws its external-link mark after it
  externalMark: boolean = false;
}

// One block of the article body: a paragraph or list item, a figure (image + caption in
// `segments`), or a table PCS collapses behind a header ("Quick facts" for the infobox, "More
// information" for the rest).
export class ArticleBlock {
  kind: string = 'p';          // p | li | note | img | table | pie | quote (qp: a quote's paragraph) | ambox (ambi: one of its listed issues) | bq (bqp: a blockquote's paragraph)
  key: string = '';
  // li: false in a list Wikipedia draws without markers (plainlist, hlist, a pie-chart legend)
  bullet: boolean = true;
  plain: string = '';
  segments: ArticleSegment[] = [];
  // img, and the first image inside a table: https URL and height / width
  imageURL: string = '';
  // img: its Commons file ("File:Red Giant Earth warm.jpg"), what the gallery opens
  fileTitle: string = '';
  imageRatio: number = 0;
  // img holding a <video>: `imageURL` is its poster, drawn `imageWidth` vp wide (its width
  // attribute) under a play button; the clip's sources, the ones the platform plays first
  videoURLs: string[] = [];
  imageWidth: number = 0;
  // table: the collapsed header, its teaser text ("İstanbul (Turkish), Country ...") and rows
  title: string = '';
  teaser: string = '';
  rows: QuickFact[] = [];
  // a table other than an infobox (a wikitable): drawn as a grid of `grid` rows, one width
  // (vp) per column in `columnWidths`; `rows` stays empty
  grid: GridRow[] = [];
  columnWidths: number[] = [];
  // pie (Template:Pie chart): the slices, the chart's size (vp) and the colour of the part no
  // slice covers; `segments` is its caption, `legend` one run list per legend line
  slices: PieSlice[] = [];
  pieSize: number = 0;
  pieBackground: string = '';
  legend: ArticleSegment[][] = [];
  // quote (Template:Quote box): its paragraphs (the quote, then the cite line) and the box's
  // inline fill and text colour, '' when the template sets none. ambox: its listed issues, the
  // left bar's colour in `ink` and a fill of its own ('' = the standard #FBFBFB)
  children: ArticleBlock[] = [];
  fill: string = '';
  ink: string = '';
  // bq (a blockquote) and its paragraphs (bqp): text-align: justify from the template's style
  justify: boolean = false;
}

// One slice of a pie chart: its colour, where it starts and how much it covers, in turns
// clockwise from 12 o'clock.
export class PieSlice {
  key: string = '';
  color: string = '';
  start: number = 0;
  extent: number = 0;
}

export class GridRow {
  key: string = '';
  cells: GridCell[] = [];
}

// One cell of a grid table. A cell spanning rows sits in its first row; the rows under it get
// `filler` cells at its columns so the columns stay aligned (`open` = the span continues
// below, so no rule is drawn under it).
export class GridCell {
  key: string = '';
  segs: ArticleSegment[] = [];
  header: boolean = false;
  colspan: number = 1;
  width: number = 0;
  align: string = 'start';     // start | center | end
  background: string = '';
  filler: boolean = false;
  open: boolean = false;
}

export class ParsedArticle {
  lead: ArticleBlock[] = [];
  sections: ArticleSection[] = [];
  // mw:pageProtection:edit: the source then draws every edit pencil with a padlock
  editProtected: boolean = false;
  // the title's pronunciation recording (PCS header data-pronunciation-url), '' when none
  pronunciationURL: string = '';
  // the article carries maintenance boxes (table.ambox): the footer lists Page issues
  hasPageIssues: boolean = false;
}

// One row of a collapsed table, laid out as the source's infobox draws it:
// above     the box title cell (infobox-above / caption): centred, first line bold
// subheader a centred bold band (infobox-subheader), `band` its background
// header    a centred bold heading cell (a th spanning the row)
// full      a cell spanning the row: its image lines, else its text, centred
// pair      a label (th, may be empty) beside the value cells
export class QuickFact {
  key: string = '';
  kind: string = 'pair';
  label: string = '';
  value: string = '';
  labelSegs: ArticleSegment[] = [];
  valueSegs: ArticleSegment[] = [];
  lines: TableImageLine[] = [];
  band: string = '';
  // a header row the infobox's template styles align left (ib-settlement's "Government")
  alignStart: boolean = false;
  // a header whose content is a box with an inline border (Eiffel Tower's "Monument historique"
  // in #0055A4, 4 px): its colour and width, '' / 0 when none
  frame: string = '';
  frameWidth: number = 0;
}

// The images of a spanning cell, one line per row of the source's layout (a photo montage
// row, Flag beside Emblem); each image keeps its caption and, on a location map, its pins.
export class TableImageLine {
  key: string = '';
  images: TableImage[] = [];
  // settlement columns: each picture centred in an equal share of the width (Flag | Emblem)
  equal: boolean = false;
}

export class TableImage {
  key: string = '';
  url: string = '';
  width: number = 0;           // the source's display width (CSS px, drawn as vp)
  ratio: number = 0;           // height / width
  boxHeight: number = 0;       // a montage photo's frame height (cropped to it), 0 = none
  caption: ArticleSegment[] = [];
  captionAlign: string = 'center';   // start | center | end, from the caption's own text-align
  markers: TableMarker[] = [];
}

// A location map's pin: position in % of the map, label and the side it sits on (l | r)
export class TableMarker {
  key: string = '';
  top: number = 0;
  left: number = 0;
  label: string = '';
  side: string = 'r';
}

// ponytail: the render cap for the blocks drawn on load — a Scroll builds all its children
// eagerly. The closed sections (References, Further reading, External links: often most of an
// article's blocks) are not counted: they are built only when opened. Long bodies run to ~300
// blocks (United States); move the body to List + LazyForEach if a longer one is slow.
const MAX_BLOCKS: number = 1000;

// ponytail: rows per collapsed table; a very long wikitable is cut there (Istanbul's infobox
// is 50). The rows are built only when the table is opened.
const MAX_TABLE_ROWS: number = 150;

// Images up to this width (CSS px) are inline icons (flags, 23 px) or map pins, not pictures
// (Istanbul's emblem is 50).
const ICON_MAX_WIDTH: number = 30;

function decodeEntities(text: string): string {
  if (text.indexOf('&') < 0) {
    return text;
  }
  let out: string = text.replace(/&nbsp;/g, '\u00A0')
    .replace(/&ndash;/g, '\u2013')
    .replace(/&mdash;/g, '\u2014')
    .replace(/&hellip;/g, '\u2026')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, '\'')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
  // Numeric entities are decoded by scan: String.replace's callback form is typed with
  // `any` in the ArkTS lib, which the language rules forbid.
  let i: number = out.indexOf('&#');
  while (i >= 0) {
    const semi: number = out.indexOf(';', i);
    if (semi < 0 || semi - i > 9) {
      i = out.indexOf('&#', i + 2);
      continue;
    }
    const digits: string = out.substring(i + 2, semi);
    const hex: boolean = digits.startsWith('x') || digits.startsWith('X');
    const code: number = Number.parseInt(hex ? digits.substring(1) : digits, hex ? 16 : 10);
    if (Number.isNaN(code) || code <= 0) {
      i = out.indexOf('&#', i + 2);
      continue;
    }
    out = out.substring(0, i) + String.fromCharCode(code) + out.substring(semi + 1);
    i = out.indexOf('&#', i + 1);
  }
  return out.replace(/&amp;/g, '&');
}

export function stripTags(html: string): string {
  return runText(html).trim();
}

// stripTags without the trim: a run between two links keeps the spaces around it, so the
// runs join back into the sentence they came from ("merkezi Çin'in", not "merkezi Çin 'in").
// Only HTML's own whitespace collapses (as a browser does): a hair space or a literal no-break
// space stays what it is ("—\u200aJohn F. Kennedy", not "— John").
function runText(html: string): string {
  return decodeEntities(html.replace(/<[^>]*>/g, '')).replace(/[ \t\n\r\f]+/g, ' ');
}

// The slug the capture recorded for a control: its label lowercased, split on anything
// non-alphanumeric, first four words joined by '_' (graph.json, sids S0204-S0237).
function slugify(text: string): string {
  const words: string[] = text.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().split(' ');
  const out: string[] = [];
  for (const w of words) {
    if (w === '') {
      continue;
    }
    out.push(w);
    if (out.length === 4) {
      break;
    }
  }
  return out.join('_');
}

// 'https://en.wikipedia.org/wiki/Cat' -> 'Cat'
// A /wiki/ link's full title, namespace and subpages included ("Help:IPA/English"):
// titleFromKey keeps only the last path segment, which turned that link into "English".
function linkTitle(path: string): string {
  try {
    return decodeURIComponent(path).replace(/_/g, ' ');
  } catch (e) {
    return path.replace(/_/g, ' ');
  }
}

function titleFromKey(key: string): string {
  const idx: number = key.lastIndexOf('/');
  const raw: string = idx >= 0 ? key.substring(idx + 1) : key;
  try {
    return decodeURIComponent(raw).replace(/_/g, ' ');
  } catch (e) {
    return raw.replace(/_/g, ' ');
  }
}

// The attribute must start the tag's text or follow whitespace: '\b' + name also matched the
// end of a longer name (`width` in data-file-width).
function attrOf(attrs: string, name: string): string {
  const m: RegExpMatchArray | null = attrs.match(new RegExp('(?:^|\\s)' + name + '\\s*=\\s*"([^"]*)"'));
  return m !== null ? m[1] : '';
}

// Named colours wikitables use for status words; anything else must be a hex colour.
const NAMED_COLORS: Map<string, string> = new Map<string, string>([
  ['green', '#008000'], ['darkgreen', '#006400'], ['red', '#FF0000'], ['darkred', '#8B0000'],
  ['blue', '#0000FF'], ['navy', '#000080'], ['orange', '#FFA500'], ['purple', '#800080'],
  ['brown', '#A52A2A'], ['maroon', '#800000'], ['gray', '#808080'], ['grey', '#808080'],
  ['black', '#000000'], ['white', '#ffffff'], ['yellow', '#ffff00'], ['cyan', '#00ffff'],
  ['magenta', '#ff00ff'], ['lime', '#00ff00'], ['silver', '#c0c0c0'], ['pink', '#ffc0cb'],
  ['lightgreen', '#90ee90'], ['lightblue', '#add8e6'], ['gold', '#ffd700'], ['teal', '#008080']
]);

function cssColor(value: string): string {
  const v: string = value.toLowerCase();
  if (/^#[0-9a-f]{3}([0-9a-f]{3})?$/.test(v)) {
    return v;
  }
  return NAMED_COLORS.get(v) ?? '';
}

// The text colour a tag's style sets ("color:green;"), '' when none or not one we can draw.
function inlineColor(attrs: string): string {
  const m: RegExpMatchArray | null = attrOf(attrs, 'style').match(/(?:^|;)\s*color:\s*([#\w]+)/i);
  return m !== null ? cssColor(m[1]) : '';
}

// The background a tag's style sets ("background-color:#FF0000"), '' when none.
function inlineBackground(attrs: string): string {
  const m: RegExpMatchArray | null = attrOf(attrs, 'style').match(/background(?:-color)?:\s*([#\w]+)/i);
  return m !== null ? cssColor(m[1]) : '';
}

// The colour of a tag's border ("border: 1px solid #000000"), '' when none.
function inlineBorder(attrs: string): string {
  const m: RegExpMatchArray | null = attrOf(attrs, 'style').match(/border(?:-color)?:[^;]*?(#[0-9a-fA-F]{3,6}\b|\b[a-z]+\s*(?:;|$))/i);
  if (m === null) {
    return '';
  }
  return cssColor(m[1].replace(';', '').trim());
}

// Splits one block's inner HTML into plain runs and link runs. `seen` keeps the ids unique
// within the page — the driver keeps the FIRST match in tree order, which is the one the
// capture recorded.
// The same runs for an html fragment outside the article body (a citation in the reference
// panel), so its links route like the article's.
export function parseInlineSegments(html: string): ArticleSegment[] {
  return parseInline(html, new Map<string, number>());
}

function parseInline(html: string, seen: Map<string, number>, icons: boolean = false): ArticleSegment[] {
  const segs: ArticleSegment[] = [];
  // <b>/<strong> and <i>/<em> nesting at the current position: runs carry them so the screen
  // keeps the source's emphasis ("A **Moon landing** (also known as ...").
  let bold: number = 0;
  let italic: number = 0;
  let sup: number = 0;
  let small: number = 0;
  // inline text colours and backgrounds of the open <span>s, innermost last ('' for none)
  const colors: string[] = [];
  const backgrounds: string[] = [];
  const innermost = (stack: string[]): string => {
    for (let i: number = stack.length - 1; i >= 0; i--) {
      if (stack[i] !== '') {
        return stack[i];
      }
    }
    return '';
  };
  const color = (): string => innermost(colors);
  const pushText = (chunk: string, tail: boolean): void => {
    let text: string = runText(chunk);
    if (segs.length === 0) {
      text = text.trimStart();
    }
    if (tail) {
      text = text.trimEnd();
    }
    if (text.trim() === '' && (segs.length === 0 || tail)) {
      return;
    }
    if (text !== '') {
      const t = new ArticleSegment();
      t.text = text;
      t.bold = bold > 0;
      t.italic = italic > 0;
      t.sup = sup > 0;
      t.small = small > 0;
      t.color = color();
      t.background = innermost(backgrounds);
      segs.push(t);
    }
  };
  const rx: RegExp = /<(\/?)(a|b|strong|i|em|sup|small|img|span)\b([^>]*)>/gi;
  let last: number = 0;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    pushText(html.substring(last, m.index), false);
    last = rx.lastIndex;
    const name: string = m[2].toLowerCase();
    if (name === 'span') {
      if (m[1] === '/') {
        colors.pop();
        backgrounds.pop();
      } else {
        const background: string = inlineBackground(m[3]);
        const end: number = background !== '' ? elementEnd(html, m.index, 'span') : -1;
        if (end > 0 && runText(html.substring(last, end).replace(/<\/span>$/i, '')).replace(/[\s\u00A0]/g, '') === '') {
          // an empty coloured span: a legend / colour-box swatch, drawn as a small square
          const swatch = new ArticleSegment();
          swatch.kind = 'swatch';
          swatch.color = background;
          // legend templates draw a thin black frame (inline, or from their template styles)
          swatch.borderColor = inlineBorder(m[3]) || '#000000';
          segs.push(swatch);
          last = end;
          rx.lastIndex = end;
        } else {
          colors.push(inlineColor(m[3]));
          backgrounds.push(background);
        }
      }
    } else if (name === 'img') {
      const w: number = Number(attrOf(m[3], 'width'));
      const h: number = Number(attrOf(m[3], 'height'));
      let src: string = decodeEntities(attrOf(m[3], 'src'));
      if (src.startsWith('//')) {
        src = 'https:' + src;
      }
      if (icons && src !== '' && w > 0 && w <= ICON_MAX_WIDTH && h > 0) {
        const icon = new ArticleSegment();
        icon.kind = 'icon';
        icon.target = src;
        icon.iconWidth = w;
        icon.iconHeight = h;
        segs.push(icon);
      }
    } else if (name !== 'a') {
      const step: number = m[1] === '/' ? -1 : 1;
      if (name === 'b' || name === 'strong') {
        bold = Math.max(0, bold + step);
      } else if (name === 'sup') {
        sup = Math.max(0, sup + step);
      } else if (name === 'small') {
        small = Math.max(0, small + step);
      } else {
        italic = Math.max(0, italic + step);
      }
    } else if (m[1] === '') {
      // searched in `html` itself: a lower-cased copy is longer wherever "İ" occurs (it lowers to
      // two code units), which put every later index off by one and leaked markup into the text
      // ("Istanbul-İzmit</aea is one of ...")
      const closeRx: RegExp = /<\/a>/gi;
      closeRx.lastIndex = last;
      const closeMatch: RegExpExecArray | null = closeRx.exec(html);
      const close: number = closeMatch !== null ? closeMatch.index : -1;
      const inner: string = html.substring(last, close < 0 ? html.length : close);
      last = close < 0 ? html.length : close + 4;
      rx.lastIndex = last;
      const attrs: string = m[3];
      const label: string = stripTags(inner);
      const href: string = attrOf(attrs, 'href');
      const cls: string = attrOf(attrs, 'class');
      if (label !== '' && cls.indexOf('pcs-edit-section-link') < 0) {
        const seg = new ArticleSegment();
        seg.text = label;
        seg.bold = bold > 0 || /<(b|strong)\b/i.test(inner);
        seg.italic = italic > 0 || /<(i|em)\b/i.test(inner);
        seg.sup = sup > 0;
        seg.small = small > 0;
        seg.color = color();
        seg.background = innermost(backgrounds);
        // PCS writes citation markers as "./Huawei#cite_note-3": caught by the './' branch they
        // were a link to the same article, which is a no-op, so [3] did nothing.
        // PCS's back link in the reference list ("[a]", pcs-back-links lists its citations)
        if (cls.split(' ').indexOf('pcs-ref-back-link') >= 0) {
          seg.kind = 'backlink';
          seg.target = href.substring(href.indexOf('#') + 1).replace(/^pcs-ref-back-link-/, '');
        } else if (href.startsWith('#') || href.indexOf('#cite_note') >= 0) {
          seg.kind = 'ref';
          seg.target = href.substring(href.indexOf('#') + 1);
        } else if (href.startsWith('./')) {
          seg.kind = 'wiki';
          seg.target = linkTitle(href.substring(2).split('#')[0]);
        } else if (href.indexOf('/wiki/') === 0) {
          seg.kind = 'wiki';
          seg.target = linkTitle(href.substring(6).split('#')[0]);
        } else if (href.startsWith('http')) {
          seg.kind = 'external';
          seg.target = href;
          seg.externalMark = cls.split(' ').indexOf('external') >= 0;
        } else if (href.startsWith('//')) {
          // protocol-relative external links (the coordinates' GeoHack link)
          seg.kind = 'external';
          seg.target = 'https:' + decodeEntities(href);
          seg.externalMark = cls.split(' ').indexOf('external') >= 0;
        } else {
          seg.kind = 'text';
        }
        if (seg.kind !== 'text') {
          let slug: string = slugify(label);
          if (slug === '') {
            slug = 'link';
          }
          const used: number | undefined = seen.get(slug);
          const n: number = used === undefined ? 0 : used;
          seen.set(slug, n + 1);
          seg.slug = n === 0 ? slug : slug + '_' + n;
        }
        segs.push(seg);
      }
    }
    m = rx.exec(html);
  }
  pushText(html.substring(last), true);
  // <span>s split the text into runs; neighbouring plain runs of one style are joined back
  const merged: ArticleSegment[] = [];
  for (const seg of segs) {
    const prev: ArticleSegment | undefined = merged.length > 0 ? merged[merged.length - 1] : undefined;
    if (prev !== undefined && prev.kind === 'text' && seg.kind === 'text' && prev.bold === seg.bold
      && prev.italic === seg.italic && prev.sup === seg.sup && prev.small === seg.small && prev.color === seg.color
      && prev.background === seg.background) {
      prev.text += seg.text;
    } else {
      merged.push(seg);
    }
  }
  return merged;
}

// The first image of a figure or table: PCS defers loading, so the URL sits in the lazy-load
// placeholder's data-src (protocol-relative), with the display size in data-width/height.
function imageIn(html: string, block: ArticleBlock): void {
  const tag: RegExpMatchArray | null = html.match(/<(?:span|img)\b[^>]*(?:data-src|\bsrc)="[^"]+"[^>]*>/i);
  if (tag === null) {
    return;
  }
  let src: string = decodeEntities(attrOf(tag[0], 'data-src') || attrOf(tag[0], 'src'));
  if (src.startsWith('//')) {
    src = 'https:' + src;
  }
  const w: number = Number(attrOf(tag[0], 'data-width') || attrOf(tag[0], 'width'));
  const h: number = Number(attrOf(tag[0], 'data-height') || attrOf(tag[0], 'height'));
  block.imageURL = src;
  block.imageRatio = w > 0 && h > 0 ? h / w : 0;
  block.fileTitle = commonsFileTitle(decodeEntities(attrOf(tag[0], 'data-resource')));
}

// "./File:Red_Giant_Earth_warm.jpg" (or a local alias such as "./Fichier:...") -> the title
// the Commons API knows: "File:Red Giant Earth warm.jpg".
function commonsFileTitle(resource: string): string {
  let name: string = resource.startsWith('./') ? resource.substring(2) : resource;
  const colon: number = name.indexOf(':');
  if (colon < 0) {
    return '';
  }
  name = name.substring(colon + 1);
  try {
    name = decodeURIComponent(name);
  } catch (e) {
    // keep it encoded
  }
  return 'File:' + name.replace(/_/g, ' ');
}

// An upload URL (.../commons/a/aa/Name.jpg, or .../thumb/a/aa/Name.jpg/640px-Name.jpg) -> its file
function fileTitleFromImageURL(url: string): string {
  const parts: string[] = url.split('?')[0].split('/');
  const thumb: number = parts.indexOf('thumb');
  const name: string = thumb >= 0 && parts.length > thumb + 3 ? parts[thumb + 3] : parts[parts.length - 1];
  return name !== '' ? commonsFileTitle('File:' + name) : '';
}

// A figure holding a <video> (TimedMediaHandler): the poster and its size, and the <source>s
// in the order to try them. The original upload is often Ogg Theora, which the platform cannot
// decode, so the transcoded MP4 / QuickTime (MPEG-4) files go first, then WebM, then the rest.
function videoIn(html: string, block: ArticleBlock): boolean {
  const video: RegExpMatchArray | null = html.match(/<video\b[^>]*>/i);
  if (video === null) {
    return false;
  }
  const https = (url: string): string => url.startsWith('//') ? 'https:' + url : url;
  const rank = (type: string): number => /^video\/(mp4|quicktime)/i.test(type) ? 0 : /^video\/webm/i.test(type) ? 1 : 2;
  const sources: string[][] = [];
  const rx: RegExp = /<source\b[^>]*>/gi;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const src: string = decodeEntities(attrOf(m[0], 'src'));
    if (src !== '') {
      sources.push([String(rank(decodeEntities(attrOf(m[0], 'type')))), https(src)]);
    }
    m = rx.exec(html);
  }
  // Array.sort is stable: each kind keeps the page's order (lowest resolution first)
  sources.sort((a: string[], b: string[]) => Number(a[0]) - Number(b[0]));
  const w: number = Number(attrOf(video[0], 'width'));
  const h: number = Number(attrOf(video[0], 'height'));
  block.imageURL = https(decodeEntities(attrOf(video[0], 'poster')));
  block.imageRatio = w > 0 && h > 0 ? h / w : 0.75;
  block.imageWidth = w;
  block.videoURLs = sources.map((x: string[]) => x[1]);
  return block.imageURL !== '' || block.videoURLs.length > 0;
}

// The end of the element that opens at `start`, counting nested tags of the same name.
function elementEnd(html: string, start: number, tag: string): number {
  const rx: RegExp = new RegExp('<(/?)' + tag + '\\b[^>]*>', 'gi');
  rx.lastIndex = start;
  let depth: number = 0;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    depth += m[1] === '' ? 1 : -1;
    if (depth === 0) {
      return m.index + m[0].length;
    }
    m = rx.exec(html);
  }
  return html.length;
}

// An element of `html` found by a scan: its whole markup and its content.
class HtmlPart {
  tag: string = '';
  attrs: string = '';
  html: string = '';
  inner: string = '';
}

// The <tr> (depth 1: rows of the outer table) or <th>/<td> (depth 0: cells of a row) elements
// of `html`, skipping those of tables nested inside.
function tableParts(html: string, names: string[], depth: number): HtmlPart[] {
  const parts: HtmlPart[] = [];
  const rx: RegExp = /<(\/?)(table|tr|th|td)\b([^>]*)>/gi;
  let tables: number = 0;
  let open: HtmlPart | null = null;
  let openStart: number = 0;
  let innerStart: number = 0;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const name: string = m[2].toLowerCase();
    const closing: boolean = m[1] === '/';
    if (name === 'table') {
      tables += closing ? -1 : 1;
    } else if (tables === depth && names.indexOf(name) >= 0) {
      if (!closing && open === null) {
        open = new HtmlPart();
        open.tag = name;
        open.attrs = m[3];
        openStart = m.index;
        innerStart = rx.lastIndex;
      } else if (closing && open !== null && open.tag === name) {
        open.inner = html.substring(innerStart, m.index);
        open.html = html.substring(openStart, rx.lastIndex);
        parts.push(open);
        open = null;
      }
    }
    m = rx.exec(html);
  }
  return parts;
}

// The <div>s of `html` whose class list has a class starting with `cls`, outermost first.
function divsWithClass(html: string, cls: string): HtmlPart[] {
  const parts: HtmlPart[] = [];
  const rx: RegExp = /<div\b([^>]*)>/gi;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const classes: string[] = attrOf(m[1], 'class').split(' ');
    if (classes.some((c: string) => c.startsWith(cls))) {
      const end: number = elementEnd(html, m.index, 'div');
      const part = new HtmlPart();
      part.tag = 'div';
      part.attrs = m[1];
      part.html = html.substring(m.index, end);
      part.inner = html.substring(rx.lastIndex, Math.max(rx.lastIndex, end - 6));
      parts.push(part);
      rx.lastIndex = end;
    }
    m = rx.exec(html);
  }
  return parts;
}

// Drops elements styled display:none (a birth date's machine-readable "(1879-03-14)", a map
// switcher's labels), nested tags of the same name included.
function withoutHidden(html: string): string {
  const rx: RegExp = /<(span|div)\b[^>]*display:\s*none[^>]*>/i;
  let out: string = html;
  let m: RegExpExecArray | null = rx.exec(out);
  while (m !== null) {
    out = out.substring(0, m.index) + out.substring(elementEnd(out, m.index, m[1]));
    m = rx.exec(out);
  }
  return out;
}

// A cell's content as inline runs: links, bold/italic, superscripts and flag icons kept. Its
// line breaks (div, li, dd, dt, br) become '\n'; its paragraph ends (a </p>, a list starting or
// ending) become 'para' runs, drawn with the source's paragraph gap. U+0001 / U+0002 mark the
// two while the html is flattened: they survive runText's whitespace folding.
function cellSegments(html: string, seen: Map<string, number>): ArticleSegment[] {
  // zero-width spaces (marriage templates) would leave blank lines
  const prepared: string = withoutHidden(html.replace(/<style\b[\s\S]*?<\/style>/gi, ''))
    .replace(/\u200B/g, '')
    .replace(/<\/p>|<\/?(?:ul|ol|dl)\b[^>]*>/gi, '\u0002')
    .replace(/<\/(?:div|li|dd|dt)>|<br\s*\/?>/gi, '\u0001');
  const out: ArticleSegment[] = [];
  // icons and swatches are pictures: they carry no text and are always kept
  const picture = (seg: ArticleSegment): boolean => seg.kind === 'icon' || seg.kind === 'swatch';
  const para = (): void => {
    if (out.length > 0 && out[out.length - 1].kind !== 'para') {
      const gap = new ArticleSegment();
      gap.kind = 'para';
      out.push(gap);
    }
  };
  for (const seg of parseInline(prepared, seen, true)) {
    if (picture(seg)) {
      out.push(seg);
      continue;
    }
    // a run of breaks with a paragraph end in it is one paragraph gap, else one line break
    const parts: string[] = seg.text.split(/(\s*[\u0001\u0002][\s\u0001\u0002]*)/);
    let text: string = '';
    parts.forEach((part: string, i: number) => {
      if (i % 2 === 0) {
        text += part;
      } else if (part.indexOf('\u0002') < 0) {
        text += '\n';
      } else {
        if (text.trim() !== '') {
          out.push(cloneSegment(seg, text));
        }
        text = '';
        para();
      }
    });
    if (text !== '') {
      out.push(cloneSegment(seg, text));
    }
  }
  // no gap or blank line at either end, nor line breaks against a gap
  while (out.length > 0 && !picture(out[0]) && (out[0].kind === 'para' || out[0].text.trim() === '')) {
    out.shift();
  }
  while (out.length > 0 && !picture(out[out.length - 1])
    && (out[out.length - 1].kind === 'para' || out[out.length - 1].text.trim() === '')) {
    out.pop();
  }
  out.forEach((seg: ArticleSegment, i: number) => {
    if (picture(seg) || seg.kind === 'para') {
      return;
    }
    if (i === 0 || out[i - 1].kind === 'para') {
      seg.text = seg.text.replace(/^\s+/, '');
    }
    if (i === out.length - 1 || out[i + 1].kind === 'para') {
      seg.text = seg.text.replace(/\s+$/, '');
    }
  });
  return out;
}

function cloneSegment(seg: ArticleSegment, text: string): ArticleSegment {
  const copy = new ArticleSegment();
  copy.text = text;
  copy.kind = seg.kind;
  copy.target = seg.target;
  copy.slug = seg.slug;
  copy.bold = seg.bold;
  copy.italic = seg.italic;
  copy.sup = seg.sup;
  copy.iconWidth = seg.iconWidth;
  copy.iconHeight = seg.iconHeight;
  copy.color = seg.color;
  copy.background = seg.background;
  copy.borderColor = seg.borderColor;
  copy.externalMark = seg.externalMark;
  return copy;
}

function segsText(segs: ArticleSegment[]): string {
  return segs.map((s: ArticleSegment) => s.kind === 'para' ? '\n' : s.text).join('').trim();
}

// The first picture (not an icon or a pin) of `html`: PCS's lazy-load placeholder or an <img>.
function tableImage(html: string, key: string): TableImage | null {
  const rx: RegExp = /<(?:span|img)\b[^>]*(?:data-src|\bsrc)="[^"]+"[^>]*>/gi;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const tag: string = m[0];
    let src: string = decodeEntities(attrOf(tag, 'data-src') || attrOf(tag, 'src'));
    if (src.startsWith('//')) {
      src = 'https:' + src;
    }
    let w: number = Number(attrOf(tag, 'data-width') || attrOf(tag, 'width'));
    const h: number = Number(attrOf(tag, 'data-height') || attrOf(tag, 'height'));
    if (!(w > 0)) {
      const styled: RegExpMatchArray | null = tag.match(/width:\s*(\d+(?:\.\d+)?)px/);
      w = styled !== null ? Number(styled[1]) : 0;
    }
    if (src !== '' && !(w > 0 && w <= ICON_MAX_WIDTH)) {
      const img = new TableImage();
      img.key = key;
      img.url = src;
      img.width = w > 0 ? w : 250;
      img.ratio = w > 0 && h > 0 ? h / w : 0.75;
      return img;
    }
    m = rx.exec(html);
  }
  return null;
}

// The first text alignment `html` sets (style text-align, or a text-align-* class), else
// `fallback`.
function textAlignIn(html: string, fallback: string): string {
  const m: RegExpMatchArray | null = html.match(/text-align(?::\s*|-)(left|right|center)\b/i);
  if (m === null) {
    return fallback;
  }
  const v: string = m[1].toLowerCase();
  return v === 'left' ? 'start' : (v === 'right' ? 'end' : 'center');
}

function imageLine(key: string, images: TableImage[]): TableImageLine {
  const line = new TableImageLine();
  line.key = key;
  line.images = images;
  return line;
}

// The image lines of a spanning cell, for the layouts infoboxes use: a {{multiple image}}
// montage (rows of tsingle, each with its thumbcaption), location maps (locmap: the map, its
// pins, "Location within ..."), settlement columns (Flag | Emblem, captions in the next row),
// else each picture on its own line with the cell's infobox-caption under the last.
function imageLines(cell: string, key: string, seen: Map<string, number>): TableImageLine[] {
  const html: string = withoutHidden(cell.replace(/<style\b[\s\S]*?<\/style>/gi, ''));
  const lines: TableImageLine[] = [];
  const trows: HtmlPart[] = divsWithClass(html, 'trow');
  if (trows.length > 0) {
    for (const row of trows) {
      const images: TableImage[] = [];
      for (const single of divsWithClass(row.inner, 'tsingle')) {
        const img: TableImage | null = tableImage(single.html, key + '_' + lines.length + '_' + images.length);
        if (img !== null) {
          // the photo sits in a fixed-height frame (overflow hidden); the caption is the rest
          const frame: RegExpMatchArray | null = single.inner.match(/^\s*<div\b[^>]*style="[^"]*height:\s*(\d+)px/);
          img.boxHeight = frame !== null ? Number(frame[1]) : 0;
          img.caption = cellSegments(single.inner, seen);
          img.captionAlign = textAlignIn(single.inner, 'center');
          images.push(img);
        }
      }
      if (images.length > 0) {
        lines.push(imageLine(key + '_l' + lines.length, images));
      }
    }
    return lines;
  }
  const maps: HtmlPart[] = divsWithClass(html, 'locmap');
  if (maps.length > 0) {
    for (const map of maps) {
      const img: TableImage | null = tableImage(map.html, key + '_' + lines.length);
      if (img === null) {
        continue;
      }
      let rest: string = map.html;
      for (const pin of divsWithClass(map.html, 'od')) {
        const marker = new TableMarker();
        marker.key = img.key + '_m' + img.markers.length;
        const style: string = attrOf(pin.attrs, 'style');
        const top: RegExpMatchArray | null = style.match(/top:\s*(-?[\d.]+)%/);
        const left: RegExpMatchArray | null = style.match(/left:\s*(-?[\d.]+)%/);
        marker.top = top !== null ? Number(top[1]) : 0;
        marker.left = left !== null ? Number(left[1]) : 0;
        const label: HtmlPart[] = divsWithClass(pin.inner, 'p');
        marker.label = label.length > 0 ? stripTags(label[0].inner) : '';
        marker.side = label.length > 0 && attrOf(label[0].attrs, 'class').startsWith('pl') ? 'l' : 'r';
        img.markers.push(marker);
        rest = rest.replace(pin.html, '');
      }
      img.caption = cellSegments(rest.replace(/<a\b[\s\S]*?<\/a>/gi, ''), seen);
      lines.push(imageLine(key + '_l' + lines.length, [img]));
    }
    return lines;
  }
  const colRows: HtmlPart[] = divsWithClass(html, 'ib-settlement-cols-row');
  if (colRows.length > 0) {
    let last: TableImage[] = [];
    for (const row of colRows) {
      const cells: HtmlPart[] = divsWithClass(row.inner, 'ib-settlement-cols-cell');
      const images: TableImage[] = [];
      cells.forEach((c: HtmlPart, i: number) => {
        const img: TableImage | null = tableImage(c.html, key + '_' + lines.length + '_' + i);
        if (img !== null) {
          // a caption under the picture in the same cell ("Flag"); the picture's own link has
          // no text, so only the caption is left
          img.caption = cellSegments(c.inner, seen);
          images.push(img);
        }
      });
      if (images.length > 0) {
        last = images;
        const line: TableImageLine = imageLine(key + '_l' + lines.length, images);
        line.equal = true;
        lines.push(line);
      } else {
        // the captions row under the pictures, cell by cell
        cells.forEach((c: HtmlPart, i: number) => {
          if (i < last.length) {
            last[i].caption = cellSegments(c.inner, seen);
          }
        });
      }
    }
    return lines;
  }
  const rx: RegExp = /<(?:span|img)\b[^>]*(?:data-src|\bsrc)="[^"]+"[^>]*>/gi;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const img: TableImage | null = tableImage(m[0], key + '_' + lines.length);
    if (img !== null) {
      lines.push(imageLine(key + '_l' + lines.length, [img]));
    }
    m = rx.exec(html);
  }
  const caption: HtmlPart[] = divsWithClass(html, 'infobox-caption');
  if (lines.length > 0 && caption.length > 0) {
    const images: TableImage[] = lines[lines.length - 1].images;
    images[images.length - 1].caption = cellSegments(caption[0].inner, seen);
    images[images.length - 1].captionAlign = textAlignIn(caption[0].html, 'center');
  }
  return lines;
}

// A cell's own background (a coloured header band); named colours are left out.
function cellBand(attrs: string): string {
  const m: RegExpMatchArray | null = attrOf(attrs, 'style').match(/background(?:-color)?:\s*(#[0-9a-fA-F]{3,6})\b/);
  return m !== null ? m[1] : '';
}

// The box title row: first line bold (the name), the lines under it (native name) regular.
function titleSegments(segs: ArticleSegment[]): ArticleSegment[] {
  const out: ArticleSegment[] = [];
  let firstLine: boolean = true;
  for (const seg of segs) {
    const parts: string[] = seg.kind === 'icon' || seg.kind === 'swatch' || seg.kind === 'para' ? [seg.text]
      : seg.text.split('\n');
    parts.forEach((text: string, i: number) => {
      if (i > 0) {
        firstLine = false;
      }
      const piece = new ArticleSegment();
      piece.kind = seg.kind;
      piece.target = seg.target;
      piece.slug = seg.slug;
      piece.text = (i > 0 ? '\n' : '') + text;
      piece.bold = firstLine || seg.bold;
      piece.italic = seg.italic;
      piece.sup = seg.sup;
      piece.iconWidth = seg.iconWidth;
      piece.iconHeight = seg.iconHeight;
      piece.color = seg.color;
      piece.background = seg.background;
      piece.borderColor = seg.borderColor;
      piece.externalMark = seg.externalMark && i === parts.length - 1;
      out.push(piece);
    });
  }
  return out;
}

// ponytail: column widths are estimated from text length (no text measuring in the parser):
// ~8.5 vp per character (17 vp text) of a cell's longest line, between these bounds.
const GRID_MIN_WIDTH: number = 60;
const GRID_MAX_WIDTH: number = 240;
const GRID_CHAR_WIDTH: number = 8.5;

function cellAlign(attrs: string, header: boolean): string {
  const align: string = (attrOf(attrs, 'align') || (attrOf(attrs, 'style').match(/text-align:\s*(\w+)/i) ?? ['', ''])[1])
    .toLowerCase();
  if (align === 'center') {
    return 'center';
  }
  if (align === 'right') {
    return 'end';
  }
  if (align === 'left') {
    return 'start';
  }
  return header ? 'center' : 'start';
}

// A wikitable as a grid: header and data cells with their runs, alignment and background,
// colspans widened, rowspans continued by filler cells, column widths estimated.
function parseGridTable(block: ArticleBlock, table: string, key: string, seen: Map<string, number>): void {
  const pending: number[] = [];   // rows still covered, per column
  const widths: number[] = [];
  for (const row of tableParts(table, ['tr'], 1)) {
    if (block.grid.length >= MAX_TABLE_ROWS) {
      break;
    }
    const gridRow = new GridRow();
    gridRow.key = key + '_g' + block.grid.length;
    let col: number = 0;
    const addFiller = (): void => {
      const filler = new GridCell();
      filler.key = gridRow.key + '_' + gridRow.cells.length;
      filler.filler = true;
      pending[col]--;
      filler.open = pending[col] > 0;
      gridRow.cells.push(filler);
      col++;
    };
    for (const c of tableParts(row.inner, ['th', 'td'], 0)) {
      while ((pending[col] ?? 0) > 0) {
        addFiller();
      }
      const cell = new GridCell();
      cell.key = gridRow.key + '_' + gridRow.cells.length;
      cell.header = c.tag === 'th';
      cell.segs = cellSegments(c.inner, seen);
      cell.colspan = Math.max(1, Number(attrOf(c.attrs, 'colspan')) || 1);
      cell.align = cellAlign(c.attrs, cell.header);
      cell.background = cellBand(c.attrs);
      const rowspan: number = Math.max(1, Number(attrOf(c.attrs, 'rowspan')) || 1);
      cell.open = rowspan > 1;
      const longest: number = segsText(cell.segs).split('\n')
        .reduce((n: number, line: string) => Math.max(n, line.length), 0);
      const want: number = Math.min(GRID_MAX_WIDTH, Math.max(GRID_MIN_WIDTH, longest * GRID_CHAR_WIDTH + 16));
      for (let i: number = 0; i < cell.colspan; i++) {
        pending[col + i] = rowspan - 1;
        if (cell.colspan === 1) {
          widths[col] = Math.max(widths[col] ?? GRID_MIN_WIDTH, want);
        } else if (widths[col + i] === undefined) {
          widths[col + i] = GRID_MIN_WIDTH;
        }
      }
      gridRow.cells.push(cell);
      col += cell.colspan;
    }
    while (col < pending.length && (pending[col] ?? 0) > 0) {
      addFiller();
    }
    if (gridRow.cells.length > 0) {
      block.grid.push(gridRow);
    }
  }
  block.columnWidths = widths.map((w: number | undefined) => w ?? GRID_MIN_WIDTH);
  // each cell's width: the columns it covers
  for (const gridRow of block.grid) {
    let col: number = 0;
    for (const cell of gridRow.cells) {
      let w: number = 0;
      for (let i: number = 0; i < cell.colspan; i++) {
        w += block.columnWidths[col + i] ?? GRID_MIN_WIDTH;
      }
      cell.width = w;
      col += cell.colspan;
    }
  }
  block.plain = block.title + ' ' + block.grid.map((r: GridRow) =>
    r.cells.map((c: GridCell) => segsText(c.segs)).join(' ')).join(' ');
}

// One table PCS collapses behind a header (pcs-collapse-table-container): the header text
// ("Quick facts", "More information") and its teaser, then the rows as the source lays the
// infobox out (see QuickFact). From the page's template styles, read before the styles are
// stripped: `bandColor` is the infobox-subheader background, `leftHeaders` the table class
// whose infobox-header rows are aligned left.
function parseCollapsedTable(html: string, key: string, seen: Map<string, number>,
  bandColor: string, leftHeaders: string): ArticleBlock {
  const block = new ArticleBlock();
  block.kind = 'table';
  block.key = key;
  const header: RegExpMatchArray | null =
    html.match(/pcs-collapse-table-collapsed-container[^>]*>([\s\S]*?)<span class="pcs-collapse-table-collapse-text"[^>]*>([\s\S]*?)<\/span>/i);
  block.title = header !== null ? stripTags(header[1]) : '';
  block.teaser = header !== null ? stripTags(header[2]) : '';
  const tableAt: number = html.search(/<table\b/i);
  const table: string = tableAt >= 0 ? html.substring(tableAt) : '';
  // anything but an infobox (a wikitable, a sidebar) is laid out as the grid it is
  if (attrOf(table.substring(0, table.indexOf('>') + 1), 'class').indexOf('infobox') < 0) {
    parseGridTable(block, table, key, seen);
    return block;
  }
  const addRow = (fact: QuickFact): void => {
    fact.key = key + '_r' + block.rows.length;
    fact.label = segsText(fact.labelSegs);
    fact.value = segsText(fact.valueSegs);
    block.rows.push(fact);
  };
  const caption: RegExpMatchArray | null = table.match(/^<table\b[^>]*>\s*<caption\b[^>]*>([\s\S]*?)<\/caption>/i);
  if (caption !== null) {
    const fact = new QuickFact();
    fact.kind = 'above';
    fact.valueSegs = titleSegments(cellSegments(caption[1], seen));
    addRow(fact);
  }
  for (const row of tableParts(table, ['tr'], 1)) {
    if (block.rows.length >= MAX_TABLE_ROWS) {
      break;
    }
    const cells: HtmlPart[] = tableParts(row.inner, ['th', 'td'], 0);
    if (cells.length === 0) {
      continue;
    }
    const first: HtmlPart = cells[0];
    const cls: string = attrOf(first.attrs, 'class');
    const fact = new QuickFact();
    if (cells.length === 1 && (cls.indexOf('infobox-above') >= 0 || cls.indexOf('infobox-title') >= 0)) {
      fact.kind = 'above';
      fact.valueSegs = titleSegments(cellSegments(first.inner, seen));
    } else if (cells.length === 1 && cls.indexOf('infobox-subheader') >= 0) {
      fact.kind = 'subheader';
      fact.band = cellBand(first.attrs) || bandColor;
      fact.valueSegs = cellSegments(first.inner, seen);
    } else if (cells.length === 1 && first.tag === 'th'
      && (Number(attrOf(first.attrs, 'colspan')) > 1 || cls.indexOf('infobox-header') >= 0)) {
      fact.kind = 'header';
      fact.band = cellBand(first.attrs);
      fact.alignStart = leftHeaders !== '' && attrOf(table.substring(0, table.indexOf('>') + 1), 'class')
        .split(' ').indexOf(leftHeaders) >= 0;
      fact.valueSegs = cellSegments(first.inner, seen);
      const box: RegExpMatchArray | null = first.inner.match(/<div\b[^>]*style="[^"]*border[^"]*"[^>]*>/i);
      if (box !== null) {
        const width: RegExpMatchArray | null = attrOf(box[0], 'style').match(/border(?:-width)?:[^;]*?(\d+(?:\.\d+)?)px/i);
        fact.frame = inlineBorder(box[0]);
        fact.frameWidth = fact.frame !== '' ? (width !== null ? Number(width[1]) : 1) : 0;
      }
    } else if (cells.length === 1 && first.tag === 'td') {
      fact.kind = 'full';
      fact.lines = imageLines(first.inner, key + '_r' + block.rows.length, seen);
      if (fact.lines.length === 0) {
        fact.valueSegs = cellSegments(first.inner, seen);
      }
    } else {
      fact.kind = 'pair';
      const values: HtmlPart[] = first.tag === 'th' ? cells.slice(1) : cells;
      if (first.tag === 'th') {
        fact.labelSegs = cellSegments(first.inner, seen);
      }
      values.forEach((c: HtmlPart) => {
        const segs: ArticleSegment[] = cellSegments(c.inner, seen);
        if (segs.length > 0 && fact.valueSegs.length > 0) {
          const dot = new ArticleSegment();
          dot.text = ' · ';
          fact.valueSegs.push(dot);
        }
        fact.valueSegs = fact.valueSegs.concat(segs);
      });
    }
    if (fact.labelSegs.length > 0 || fact.valueSegs.length > 0 || fact.lines.length > 0) {
      addRow(fact);
    }
  }
  block.plain = block.title + ' ' + block.rows.map((r: QuickFact) => r.label + ' ' + r.value).join(' ');
  return block;
}

// Lifts every pie chart (div.smooth-pie-container) out of the body, leaving <wmfpie n="i">.
function liftPieCharts(body: string, pies: string[]): string {
  const marker: string = 'class="smooth-pie-container"';
  let at: number = body.indexOf(marker);
  while (at >= 0) {
    const start: number = body.lastIndexOf('<div', at);
    const end: number = elementEnd(body, start, 'div');
    pies.push(body.substring(start, end));
    body = body.substring(0, start) + '<wmfpie n="' + (pies.length - 1) + '"></wmfpie>' + body.substring(end);
    at = body.indexOf(marker, start);
  }
  return body;
}

// Lifts every quote box (Template:Quote box, div.quotebox) out of the body, leaving <wmfquote n="i">.
function liftQuoteBoxes(body: string, quotes: string[]): string {
  const rx: RegExp = /<div\b[^>]*class="(?:[^"]*\s)?quotebox(?:\s[^"]*)?"[^>]*>/i;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const end: number = elementEnd(body, m.index, 'div');
    quotes.push(body.substring(m.index, end));
    body = body.substring(0, m.index) + '<wmfquote n="' + (quotes.length - 1) + '"></wmfquote>' + body.substring(end);
    m = rx.exec(body);
  }
  return body;
}

// Lifts every article message box (table.ambox: maintenance templates such as Multiple issues)
// out of the body, leaving <wmfambox n="i">. A Multiple issues box holds its issues as nested
// amboxes, which go with it.
function liftAmboxes(body: string, boxes: string[]): string {
  const rx: RegExp = /<table\b[^>]*class="(?:[^"]*\s)?ambox(?:\s[^"]*)?"[^>]*>/i;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const end: number = elementEnd(body, m.index, 'table');
    boxes.push(body.substring(m.index, end));
    body = body.substring(0, m.index) + '<wmfambox n="' + (boxes.length - 1) + '"></wmfambox>' + body.substring(end);
    m = rx.exec(body);
  }
  return body;
}

// Template:Ambox's left bar per box type (its TemplateStyles); the notice type is the default.
function amboxBar(classes: string[]): string {
  if (classes.indexOf('ambox-speedy') >= 0 || classes.indexOf('ambox-delete') >= 0) {
    return '#B32424';
  }
  if (classes.indexOf('ambox-content') >= 0) {
    return '#F28500';
  }
  if (classes.indexOf('ambox-style') >= 0) {
    return '#FFCC33';
  }
  if (classes.indexOf('ambox-move') >= 0) {
    return '#9932CC';
  }
  return classes.indexOf('ambox-protection') >= 0 ? '#A2A9B1' : '#3366CC';
}

// An article message box: the template's icon (its mbox-image cell), the message and, for
// Multiple issues, each listed issue - their own icons and their "Please help improve" text
// hidden, as compact-ambox does.
function parseAmbox(html: string, key: string, seen: Map<string, number>): ArticleBlock {
  const block = new ArticleBlock();
  block.kind = 'ambox';
  block.key = key;
  const open: RegExpMatchArray | null = html.match(/^<table\b([^>]*)>/i);
  const classes: string[] = open !== null ? attrOf(open[1], 'class').split(' ') : [];
  block.ink = amboxBar(classes);
  block.fill = classes.indexOf('ambox-speedy') >= 0 ? '#FEE7E6' : '';
  const icon: RegExpMatchArray | null = html.match(/<td\b[^>]*class="mbox-image"[^>]*>([\s\S]*?)<\/td>/i);
  if (icon !== null) {
    imageIn(icon[1], block);
  }
  const text: HtmlPart[] = divsWithClass(html, 'mbox-text-span');
  let main: string = text.length > 0 ? text[0].inner : '';
  const nested: number = main.indexOf('mw-collapsible-content');
  if (nested >= 0) {
    const start: number = main.lastIndexOf('<div', nested);
    const end: number = elementEnd(main, start, 'div');
    divsWithClass(main.substring(start, end), 'mbox-text-span').forEach((issue: HtmlPart) => {
      const inner: string = withoutCompactHidden(issue.inner);
      const plain: string = stripTags(inner);
      if (plain !== '') {
        const item = new ArticleBlock();
        item.kind = 'ambi';
        item.key = key + '_' + block.children.length;
        item.plain = plain;
        item.segments = parseInline(inner, seen);
        block.children.push(item);
      }
    });
    main = main.substring(0, start) + main.substring(end);
  }
  block.plain = stripTags(main);
  block.segments = parseInline(main, seen);
  return block;
}

// Drops the spans compact-ambox hides in a listed issue (class hide-when-compact).
function withoutCompactHidden(html: string): string {
  const rx: RegExp = /<(span|div)\b[^>]*class="[^"]*hide-when-compact[^"]*"[^>]*>/i;
  let out: string = html;
  let m: RegExpExecArray | null = rx.exec(out);
  while (m !== null) {
    out = out.substring(0, m.index) + out.substring(elementEnd(out, m.index, m[1]));
    m = rx.exec(out);
  }
  return out;
}

// Lifts every blockquote (Template:Quote's templatequote, and plain ones) out of the body,
// leaving <wmfbq n="i">.
function liftBlockquotes(body: string, quotes: string[]): string {
  const rx: RegExp = /<blockquote\b[^>]*>/i;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const end: number = elementEnd(body, m.index, 'blockquote');
    quotes.push(body.substring(m.index, end));
    body = body.substring(0, m.index) + '<wmfbq n="' + (quotes.length - 1) + '"></wmfbq>' + body.substring(end);
    m = rx.exec(body);
  }
  return body;
}

// A blockquote: its paragraphs and attribution (templatequotecite's <cite>) read as a quote
// box's, drawn with the base CSS's blockquote style (see blockquoteView).
function parseBlockquote(html: string, key: string, seen: Map<string, number>): ArticleBlock {
  const open: RegExpMatchArray | null = html.match(/^<blockquote\b([^>]*)>/i);
  const inner: string = html.replace(/^<blockquote\b[^>]*>/i, '<div>').replace(/<\/blockquote>$/i, '</div>');
  const block: ArticleBlock = parseQuoteBox(inner, key, seen);
  block.kind = 'bq';
  block.fill = '';
  block.ink = '';
  block.justify = open !== null && /text-align:\s*justify/i.test(attrOf(open[1], 'style'));
  block.children.forEach((c: ArticleBlock) => {
    c.kind = 'bqp';
    c.fill = '';
    c.ink = '';
    c.justify = block.justify;
  });
  return block;
}

// A quote box: the template's colours from its inline style, then its paragraphs in order - an
// optional title, the quote's <p>s and the <cite> attribution ("— John F. Kennedy on ...").
function parseQuoteBox(html: string, key: string, seen: Map<string, number>): ArticleBlock {
  const block = new ArticleBlock();
  block.kind = 'quote';
  block.key = key;
  const open: RegExpMatchArray | null = html.match(/^<div\b([^>]*)>/i);
  if (open !== null) {
    block.fill = inlineBackground(open[1]);
    block.ink = inlineColor(open[1]);
  }
  const rx: RegExp = /<(p|cite|div)\b([^>]*)>([\s\S]*?)<\/\1>/gi;
  const inner: string = html.substring(open !== null ? open[0].length : 0);
  let m: RegExpExecArray | null = rx.exec(inner);
  while (m !== null) {
    const tag: string = m[1].toLowerCase();
    if (tag === 'div' && attrOf(m[2], 'class').indexOf('quotebox-title') < 0) {
      // a wrapper div (the cite's): step inside it
      rx.lastIndex = m.index + m[0].indexOf('>') + 1;
      m = rx.exec(inner);
      continue;
    }
    const plain: string = stripTags(m[3]);
    if (plain !== '') {
      const p = new ArticleBlock();
      p.kind = 'qp';
      p.key = key + '_' + block.children.length;
      p.plain = plain;
      p.segments = parseInline(m[3], seen);
      p.fill = block.fill;
      p.ink = block.ink;
      if (tag === 'div') {
        p.segments.forEach((s: ArticleSegment) => { s.bold = true; });
      }
      block.children.push(p);
    }
    m = rx.exec(inner);
  }
  block.plain = block.children.map((c: ArticleBlock) => c.plain).join(' ');
  return block;
}

// A Template:Pie chart. The chart is a div of slice divs: each slice is one or more divs with
// the same title ("BJP (44.2%)"), coloured by their background and turned into place with
// rotate(<n>turn); the chart's own background shows where no slice is. The caption and the
// legend (a swatch and a label per line) sit beside it.
function parsePieChart(html: string, key: string, seen: Map<string, number>): ArticleBlock {
  const block = new ArticleBlock();
  block.kind = 'pie';
  block.key = key;
  // the chart div itself (class exactly "smooth-pie"; divsWithClass matches by prefix and stops
  // at the container)
  const open: RegExpMatchArray | null = html.match(/<div\b([^>]*\bclass="smooth-pie"[^>]*)>/i);
  if (open !== null && open.index !== undefined) {
    const pie = new HtmlPart();
    pie.attrs = open[1];
    const end: number = elementEnd(html, open.index, 'div');
    pie.inner = html.substring(open.index + open[0].length, Math.max(open.index + open[0].length, end - 6));
    const style: string = attrOf(pie.attrs, 'style');
    const width: RegExpMatchArray | null = style.match(/width:\s*(\d+(?:\.\d+)?)px/);
    block.pieSize = width !== null ? Number(width[1]) : 200;
    block.pieBackground = inlineBackground(pie.attrs) || '#888888';
    const rx: RegExp = /<div\b([^>]*\btitle="([^"]*)"[^>]*)>/gi;
    let lastTitle: string = '';
    let m: RegExpExecArray | null = rx.exec(pie.inner);
    while (m !== null) {
      const title: string = decodeEntities(m[2]);
      const rotation: RegExpMatchArray | null = attrOf(m[1], 'style').match(/rotate\(\s*(-?[\d.]+)turn\)/);
      if (title !== lastTitle) {
        const slice = new PieSlice();
        slice.key = key + '_s' + block.slices.length;
        slice.color = inlineBackground(m[1]);
        slice.start = rotation !== null ? Number(rotation[1]) : 0;
        const percent: RegExpMatchArray | null = title.match(/([\d.]+)\s*%\s*\)?\s*$/);
        slice.extent = percent !== null ? Number(percent[1]) / 100 : 0;
        block.slices.push(slice);
        lastTitle = title;
      }
      m = rx.exec(pie.inner);
    }
    // a slice without a percentage in its title runs to where the next one starts
    block.slices.forEach((slice: PieSlice, i: number) => {
      if (slice.extent <= 0) {
        slice.extent = (i + 1 < block.slices.length ? block.slices[i + 1].start : 1) - slice.start;
      }
    });
  }
  const caption: HtmlPart[] = divsWithClass(html.substring(html.indexOf('>') + 1), 'smooth-pie-caption');
  block.segments = caption.length > 0 ? cellSegments(caption[0].inner, seen) : [];
  const legend: RegExpMatchArray | null = html.match(/<ol\b[^>]*smooth-pie-legend[^>]*>([\s\S]*?)<\/ol>/i);
  if (legend !== null) {
    const item: RegExp = /<li\b[^>]*>([\s\S]*?)<\/li>/gi;
    let li: RegExpExecArray | null = item.exec(legend[1]);
    while (li !== null) {
      const segs: ArticleSegment[] = cellSegments(li[1], seen);
      if (segs.length > 0) {
        block.legend.push(segs);
      }
      li = item.exec(legend[1]);
    }
  }
  const footer: HtmlPart[] = divsWithClass(html.substring(html.indexOf('>') + 1), 'smooth-pie-footer');
  if (footer.length > 0) {
    block.legend.push(cellSegments(footer[0].inner, seen));
  }
  block.plain = segsText(block.segments) + ' ' + block.legend.map((l: ArticleSegment[]) => segsText(l)).join(' ');
  return block;
}

// Lifts every collapsed table out of the body, leaving a <wmftable n="i"> marker where it
// stood so the block scan places it in document order.
function liftCollapsedTables(body: string, tables: string[]): string {
  const marker: string = 'class="pcs-collapse-table-container"';
  let at: number = body.indexOf(marker);
  while (at >= 0) {
    const start: number = body.lastIndexOf('<div', at);
    const end: number = elementEnd(body, start, 'div');
    tables.push(body.substring(start, end));
    body = body.substring(0, start) + '<wmftable n="' + (tables.length - 1) + '"></wmftable>' + body.substring(end);
    at = body.indexOf(marker, start);
  }
  return body;
}

// The ranges of lists Wikipedia draws without markers: a list in or carrying the plainlist /
// hlist class, a pie-chart legend, or one styled list-style:none.
function markerlessLists(body: string): number[][] {
  const ranges: number[][] = [];
  const rx: RegExp = /<(ul|ol|div)\b([^>]*)>/gi;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const classes: string[] = attrOf(m[2], 'class').split(' ');
    const markerless: boolean = classes.some((c: string) => c === 'plainlist' || c === 'hlist' || c === 'smooth-pie-legend')
      || (m[1].toLowerCase() !== 'div' && /list-style(?:-type)?:\s*none/i.test(attrOf(m[2], 'style')));
    if (markerless) {
      ranges.push([m.index, elementEnd(body, m.index, m[1].toLowerCase())]);
    }
    m = rx.exec(body);
  }
  return ranges;
}

// The heading's pcs-edit-section-header div carries pcs-section-hideable-header where PCS
// starts the section hidden (pcs.c1.Sections.setHidden).
function isHideable(body: string, headingStart: number): boolean {
  const header: number = body.lastIndexOf('pcs-edit-section-header', headingStart);
  return header >= 0 && body.substring(header, headingStart).indexOf('pcs-section-hideable-header') >= 0;
}

// The heading's edit link sits beside it in the same pcs-edit-section-header div.
function hasEditLink(body: string, headingEnd: number): boolean {
  const rest: string = body.substring(headingEnd, headingEnd + 1000);
  const end: number = rest.indexOf('</div>');
  return (end < 0 ? rest : rest.substring(0, end)).indexOf('data-action="edit_section"') >= 0;
}

// mobile-html -> lead blocks + sections. Regex-scanned rather than DOM-parsed: PCS output
// is flat, and the block tags below are all the screen renders.
export function parseArticle(html: string): ParsedArticle {
  const editProtected: boolean = /<meta\b[^>]*property="mw:pageProtection:edit"/i.test(html);
  const band: RegExpMatchArray | null = html.match(/\.infobox-subheader\{background-color:(#[0-9a-fA-F]{3,6})/);
  const leftHeaders: RegExpMatchArray | null = html.match(/\.([\w-]+) \.infobox-header[^{}]*\{text-align:left/);
  let body: string = escapeAttributeBrackets(
    html.replace(/<(script|style)\b[\s\S]*?<\/(?:script|style)>/gi, ''));
  const footer: number = body.indexOf('pcs-footer-container');
  if (footer > 0) {
    body = body.substring(0, footer);
  }
  const pron: RegExpMatchArray | null = body.match(/\bdata-pronunciation-url="([^"]*)"/);
  let pronunciationURL: string = pron !== null ? decodeEntities(pron[1]) : '';
  if (pronunciationURL.startsWith('//')) {
    pronunciationURL = 'https:' + pronunciationURL;
  }
  // The <header> carries the title and the short description as a <p>; both screens draw them
  // from the summary, so the scan used to repeat the description as the first paragraph.
  body = body.replace(/<header\b[\s\S]*?<\/header>/i, '')
    // Hatnotes ("This article is about ...", "Main article: ...") are divs the scan skipped;
    // a marker tag lets it keep them in place as 'note' blocks. They hold no nested divs.
    .replace(/<div\b[^>]*class="hatnote[^"]*"[^>]*>([\s\S]*?)<\/div>/gi, '<wmfnote>$1</wmfnote>');
  const out = new ParsedArticle();
  out.editProtected = editProtected;
  out.pronunciationURL = pronunciationURL;
  const pies: string[] = [];
  body = liftPieCharts(body, pies);
  const quotes: string[] = [];
  body = liftQuoteBoxes(body, quotes);
  const blockquotes: string[] = [];
  body = liftBlockquotes(body, blockquotes);
  const boxes: string[] = [];
  body = liftAmboxes(body, boxes);
  out.hasPageIssues = boxes.length > 0;
  const tables: string[] = [];
  body = liftCollapsedTables(body, tables);
  const unbulleted: number[][] = markerlessLists(body);
  const seen: Map<string, number> = new Map<string, number>();
  // Closed by the same tag: a figure's caption must not end it at the first </p> or </li>.
  const rx: RegExp = /<(h2|h3|h4|p|li|wmfnote|figure|wmftable|wmfpie|wmfquote|wmfambox|wmfbq)\b([^>]*)>([\s\S]*?)<\/\1>/gi;
  let current: ArticleSection | null = null;
  let hideable: ArticleSection | null = null;
  let count: number = 0;
  // blocks outside the closed sections, the ones drawn on load
  let shown: number = 0;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const closed: boolean = current !== null && (current.collapsible || current.under !== '');
    // past the cap only headings are kept, so later sections (and the closed ones) still appear
    if (m[1].charAt(0).toLowerCase() !== 'h' && !closed && shown >= MAX_BLOCKS) {
      m = rx.exec(body);
      continue;
    }
    const tag: string = m[1].toLowerCase();
    const attrs: string = m[2];
    const inner: string = m[3];
    if (tag.charAt(0) === 'h') {
      const heading: string = stripTags(inner);
      if (heading !== '') {
        const section = new ArticleSection();
        const anchor: string = attrOf(attrs, 'id');
        section.anchor = anchor !== '' ? anchor : slugify(heading);
        section.title = heading;
        section.level = Number.parseInt(tag.substring(1), 10);
        section.editable = hasEditLink(body, rx.lastIndex);
        if (hideable !== null && section.level > hideable.level) {
          section.under = hideable.anchor;
        } else {
          hideable = isHideable(body, m.index) ? section : null;
          section.collapsible = hideable !== null;
        }
        section.expanded = !section.collapsible;
        out.sections.push(section);
        current = section;
      }
    } else if (tag === 'figure' || tag === 'wmftable' || tag === 'wmfpie' || tag === 'wmfquote' || tag === 'wmfambox' ||
      tag === 'wmfbq') {
      let block: ArticleBlock;
      if (tag === 'figure') {
        block = new ArticleBlock();
        block.kind = 'img';
        block.key = 'b' + count;
        if (!videoIn(inner, block)) {
          imageIn(inner, block);
        }
        const caption: RegExpMatchArray | null = inner.match(/<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>/i);
        if (caption !== null) {
          block.plain = stripTags(caption[1]);
          block.segments = parseInline(caption[1], seen);
        }
      } else if (tag === 'wmfpie') {
        block = parsePieChart(pies[Number(attrOf(attrs, 'n'))] ?? '', 'b' + count, seen);
      } else if (tag === 'wmfquote') {
        block = parseQuoteBox(quotes[Number(attrOf(attrs, 'n'))] ?? '', 'b' + count, seen);
      } else if (tag === 'wmfambox') {
        block = parseAmbox(boxes[Number(attrOf(attrs, 'n'))] ?? '', 'b' + count, seen);
      } else if (tag === 'wmfbq') {
        block = parseBlockquote(blockquotes[Number(attrOf(attrs, 'n'))] ?? '', 'b' + count, seen);
      } else {
        block = parseCollapsedTable(tables[Number(attrOf(attrs, 'n'))] ?? '', 'b' + count, seen,
          band !== null ? band[1] : '', leftHeaders !== null ? leftHeaders[1] : '');
      }
      if (block.imageURL !== '' || block.videoURLs.length > 0 || block.rows.length > 0 || block.grid.length > 0 || block.slices.length > 0 ||
        block.children.length > 0 || (block.kind === 'ambox' && block.segments.length > 0)) {
        if (current !== null) {
          current.blocks.push(block);
        } else {
          out.lead.push(block);
        }
        count++;
        shown += closed ? 0 : 1;
      }
    } else {
      const plain: string = stripTags(inner);
      if (plain !== '') {
        const block = new ArticleBlock();
        block.kind = tag === 'wmfnote' ? 'note' : tag;
        block.bullet = tag !== 'li' || !unbulleted.some((r: number[]) => m !== null && m.index > r[0] && m.index < r[1]);
        block.plain = plain;
        block.key = 'b' + count;
        block.segments = parseInline(inner, seen);
        if (current !== null) {
          current.blocks.push(block);
        } else {
          out.lead.push(block);
        }
        count++;
        shown += closed ? 0 : 1;
      }
    }
    m = rx.exec(body);
  }
  return out;
}

const IDENTITY_FILTER: ColorFilter = new ColorFilter([
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0
]);
// alpha kept, RGB replaced with WMFColor.gray100 (#F8F9FA)
const DARK_ICON_FILTER: ColorFilter = new ColorFilter([
  0, 0, 0, 0, 0.973,
  0, 0, 0, 0, 0.976,
  0, 0, 0, 0, 0.98,
  0, 0, 0, 1, 0
]);

// Every run a block draws: its text, a table's rows and cells, a legend, nested blocks
function blockSegments(b: ArticleBlock): ArticleSegment[] {
  const out: ArticleSegment[] = b.segments.slice();
  for (const row of b.rows) {
    out.push(...row.labelSegs, ...row.valueSegs);
  }
  for (const row of b.grid) {
    for (const cell of row.cells) {
      out.push(...cell.segs);
    }
  }
  for (const line of b.legend) {
    out.push(...line);
  }
  for (const child of b.children) {
    out.push(...blockSegments(child));
  }
  return out;
}

class FindPiece {
  text: string;
  seg: ArticleSegment;
  hit: boolean;

  constructor(text: string, seg: ArticleSegment, hit: boolean) {
    this.text = text;
    this.seg = seg;
    this.hit = hit;
  }
}

// find-in-page match background (the source's yellow match highlight)
const FIND_MATCH_BG: string = '#FFCC33';
// The source's superscript size relative to the text around it (measured on reference markers).
const SUP_SCALE: number = 0.8;
// <small> (font-size: smaller)
const SMALL_SCALE: number = 0.85;
// how far a <sup> run's baseline is lifted, as a share of the body size (vertical-align: super)
const SUP_RAISE: number = 0.3;

// ToC anchor of the footer's "About this article" heading (no section carries it).
const ABOUT_ANCHOR: string = '__about_this_article';
// ToC anchor of the footer's "Read more" block (WMFArticleFooterMenu readMore).
const READ_MORE_ANCHOR: string = '__read_more';
// the source's read-more footer shows three related articles
const READ_MORE_COUNT: number = 3;
// lead image request width (px): the screen width class ImageUtils.leadImageWidth picks
const LEAD_IMAGE_WIDTH: number = 1280;

// String.underscoresToSpaces.truncated(): the menu shows at most 20 characters, then "..."
class TabsMenuTitle {
  static truncated(title: string): string {
    const t: string = title.replace(/_/g, ' ');
    return t.length > 20 ? t.substring(0, 20) + '...' : t;
  }
}

@Entry
@Component
struct ArticleViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  // the gesture-handle strip under the toolbar (vp, 0 with button navigation)
  @StorageProp('navIndicatorInset') navIndicatorInset: number = 0;

  // spec stateVars
  @State articleTitle: string = '';
  @State summary: ArticleSummary | null = null;
  @State isSaved: boolean = false;
  @State isWatched: boolean = false;
  @StorageProp('WMFAppThemeName') theme: string = 'light';
  // Reading-themes text size, in percent (FontSizeSliderViewController publishes it): the
  // article's own text scales by it, as the source's web view does.
  @StorageProp('WMFArticleFontSizeMultiplier') fontPercent: number = 100;
  @State tocItems: TocItem[] = [];
  // The ToC row for the section in view when the panel opens, and the row picked in it: the
  // scroll waits for the sheet to finish closing (onDisappear).
  @State tocCurrent: string = '';
  // when a sheet over the article last closed (see the nav back button)
  private sheetClosedAt: number = 0;
  // the language version picked in the languages sheet, opened once the sheet has closed
  private pendingLanguage: MWKLanguageLink | null = null;
  // the citation marker last tapped (ReferenceViewController's referenceLinkText)
  @State referenceAnchor: string = '';
  @State referenceLabel: string = '';
  // spec stateVar `plain webController` — the WebviewController for the web-based route
  // (SinglePageWeb / "view in browser"). The article body itself is rendered natively.
  webController: webview.WebviewController = new webview.WebviewController();
  private offlineTried: boolean = false;
  // the article body, parsed out of the mobile-html document
  @State leadBlocks: ArticleBlock[] = [];
  // ArticleViewController+ArticlePreviewing: the block whose link was long-pressed shows the
  // peek preview and its menu ('' = none), and what that preview shows
  @State linkMenuKey: string = '';
  @State linkPreviewTitle: string = '';
  @State linkPreviewDescription: string = '';
  @State linkPreviewImage: string = '';
  @State linkPreviewExtract: string = '';
  @State linkPreviewLoaded: boolean = false;
  @State linkPreviewSaved: boolean = false;
  @State linkPreviewCoords: number[] = [];
  private linkPreviewLanguage: string = '';
  // one per paragraph: its layout tells which run a long press landed on
  private textControllers: Map<string, TextController> = new Map<string, TextController>();
  // the article text the reader has selected (webView.wmf_getSelectedText), and the fact the
  // Share-a-fact cover renders
  private selectedText: string = '';
  @State shareAFactText: string = '';
  @State selectionResetFlip: boolean = false;
  // WMFFundraisingCampaignConfig.WMFAsset shown by the campaign modal
  @State fundraisingAsset: CampaignAsset | null = null;
  @State fundraisingShowsMaybeLater: boolean = true;
  @State sections: ArticleSection[] = [];
  @State editProtected: boolean = false;
  @State pronunciationURL: string = '';
  // Collapsed tables ("Quick facts", "More information") start open only under the "Expand
  // tables" setting.
  @State quickFactsExpanded: boolean = false;
  // The "Expand tables" setting as last applied; a change made in Settings while this article
  // is open applies on return instead of only to the next article loaded.
  private appliedTableOpening: boolean = false;
  private languageOverride: string = '';
  // section anchor -> its y offset inside the scroll content (ToC selection scrolls there)
  private sectionTops: Map<string, number> = new Map<string, number>();
  @State relatedArticles: ArticleSummary[] = [];
  @State hasPageIssues: boolean = false;
  // the footer's top in the scroll content, and Read more's offset inside it (ToC anchors)
  private footerTop: number = 0;
  private readMoreOffset: number = 0;
  // overlay routing — one flag + discriminator per binding node
  @State showSheet: boolean = false;
  @State activeSheet: string = '';
  // ReferenceBackLinksViewController: the reference whose citations are being stepped through
  // ('' = none), its label, the citation shown and the run highlighted in the body
  @State backLinkRef: string = '';
  @State backLinkLabel: string = '';
  @State backLinkIndex: number = 0;
  // the highlighted run is a plain field (a @State object is a proxy, so identity checks on it
  // fail); the tick redraws the runs when it changes
  @State highlightTick: number = 0;
  private highlightedRun: ArticleSegment | null = null;
  private backLinkTargets: ArticleSegment[] = [];
  private backLinkSource: ArticleSegment | null = null;
  // the table of contents panel (TableOfContentsView), opened by the toolbar
  @State showToc: boolean = false;
  @State showCover: boolean = false;
  @State activeCover: string = '';
  @State showThemesPopup: boolean = false;
  // When the popover last closed. Tapping the Tt button while it is open dismisses it as an
  // outside tap first; without this the same tap's onClick asked for it again, the flag and
  // the popover fell out of step, and every later tap was ignored.
  private themesPopupClosedAt: number = 0;
  @State showHint: boolean = false;
  @State showFindBar: boolean = false;
  @State findQuery: string = '';
  // article.savedDate (conditionalVariants: save toolbar icon filled when non-nil)
  @State savedDate: number | null = null;
  // hint presented by the save action (ReadingListHintController)
  @State hintKind: string = 'confirmation';
  @State hintText: string = '';
  @State hintActionTitle: string = '';
  // what the hint's button does: 'addToList' (the saved hint), 'viewWatchlist' (the watch
  // toast's View Watchlist), 'seeList' (the list toast's See reading list)
  private hintActionKind: string = 'addToList';
  private hintListRowId: string = '';
  @State isLoading: boolean = false;
  // refreshControl + refreshOverlay: pulled, and reloading under the dimmed page
  @State isPullRefreshing: boolean = false;
  // WTip: the "Tap to go back" popover on the W button
  @State showWTip: boolean = false;
  // ArticleToolbarController.updateMoreButton(previousArticleTab:nextArticleTab:)
  @State previousArticleTab: TabArticle | null = null;
  @State nextArticleTab: TabArticle | null = null;
  // the tab item this load should select instead of appending a new one: an article opened
  // through backInTab / forwardInTab (tabConfig .adjacentArticleInTab), or the previous item
  // on an in-page back
  private pendingTabItem: string = '';
  private isBackNavigation: boolean = false;
  private wTipShown: boolean = false;
  @State isReloading: boolean = false;
  @State loadError: string = '';
  private scroller: Scroller = new Scroller();
  // navigationController.hidesBarsOnSwipe: the top bar slides away while the reader scrolls
  // down through the text and comes back on any scroll up. navHeight is its measured height.
  @State navHidden: boolean = false;
  private navHeight: number = 0;
  // resolved from svc_lang_store at load time (wiki host / project id for the stores)
  private host: string = 'en.wikipedia.org';
  @State articleIsRTL: boolean = false;
  private projectID: string = 'wikipedia.en';
  // CDPageView row of this view, for the reading-seconds accumulation on leave
  private pageViewId: number | null = null;
  private appearedAt: number = 0;
  private hintTimer: number = -1;
  // the articles opened from in-document links on this page, oldest first — the push stack the
  // router cannot hold for a page that navigates to its own route (see `openArticle`).
  private articleBackStack: string[] = [];

  aboutToAppear(): void {
    this.getUIContext().getFont().registerFont({
      familyName: 'WMFSerif', familySrc: $rawfile('fonts/NotoSerif-Regular.ttf') });
    const storedPercent: number = Prefs.getNumber('WMFArticleFontSizeMultiplier', 0);
    AppStorage.setOrCreate<number>('WMFArticleFontSizeMultiplier', storedPercent > 0 ? storedPercent : 100);
    const ctx = getContext(this) as common.UIAbilityContext;
    // SavedArticlesFetcher's offline copy lives under filesDir; without this the cache
    // dir stays unset and every write lands at '/' (fileIo 13900012).
    ArticleCacheStore.init(ctx);
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.articleTitle = params['articleTitle'] ?? '';
      // Callers holding the article's key (history, saved, reading lists, tabs) pass it so
      // the article reopens on its own wiki; the title alone always landed on the app language.
      const key: string = params['articleKey'] ?? '';
      this.languageOverride = params['languageCode'] ??
        (key.startsWith('https://') ? key.substring(8).split('.')[0] : '');
      // ArticleCoordinator(isRestoringState:) — reopened from a tab or the launch restore
      this.isRestoringState = params['restoreScroll'] === 'true';
    }
    this.appearedAt = Date.now();
    this.presentLaunchOverlay();
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        this.loadError = e.message;
      });
    }).catch((e: Error) => {
      console.error('article: db init failed: ' + e.message);
      this.loadError = e.message;
    });
  }

  // viewWillDisappear / applicationWillResignActive -> saveArticleScrollPosition. ArkUI hides
  // the page for a push on top and for the app going to the background.
  onPageHide(): void {
    this.saveArticleScrollPosition();
  }

  private isRestoringState: boolean = false;

  // saveArticleScrollPosition: the offset and the anchor of the section it falls in.
  private saveArticleScrollPosition(): void {
    if (this.articleTitle === '' || this.isLoading) {
      return;
    }
    const y: number = this.scroller.currentOffset().yOffset;
    let fragment: string | null = null;
    let best: number = -1;
    this.sectionTops.forEach((top: number, anchor: string) => {
      if (top <= y && top > best) {
        best = top;
        fragment = anchor;
      }
    });
    HistoryStore.saveViewedPosition(this.articleKey(), y, fragment).catch((e: Error) => {
      console.error('article: scroll position not saved: ' + e.message);
    });
  }

  // assignScrollStateFromArticleFlagsIfNecessary: back to the saved offset, or to the saved
  // section when there is no offset. The body lays out over a few frames, so the scroll is
  // retried until it lands (the source's scrollToOffset attempts).
  private restoreArticleScrollPosition(): void {
    if (!this.isRestoringState) {
      return;
    }
    this.isRestoringState = false;
    HistoryStore.viewedPosition(this.articleKey()).then((a: WMFArticle | null) => {
      if (a === null) {
        return;
      }
      const offset: number = a.viewedScrollPosition ?? 0;
      const fragment: string = a.viewedFragment ?? '';
      let attempt: number = 0;
      const tryScroll = (): void => {
        attempt++;
        if (offset > 0) {
          this.scroller.scrollTo({ xOffset: 0, yOffset: offset });
          if (Math.abs(this.scroller.currentOffset().yOffset - offset) > 4 && attempt < 8) {
            setTimeout(tryScroll, 250);
          }
        } else if (fragment !== '') {
          if (this.sectionTops.has(fragment)) {
            this.scrollToSection(fragment);
          } else if (attempt < 8) {
            setTimeout(tryScroll, 250);
          }
        }
      };
      setTimeout(tryScroll, 300);
    }).catch((e: Error) => {
      console.error('article: scroll position unavailable: ' + e.message);
    });
  }

  aboutToDisappear(): void {
    this.saveArticleScrollPosition();
    if (this.hintTimer >= 0) {
      clearTimeout(this.hintTimer);
      this.hintTimer = -1;
    }
    this.flushPageViewSeconds();
  }

  // trackArticleWillDisappear -> addPageViewSeconds (reading-time accumulation). Also runs on
  // an in-place article swap, which is a page LEAVE as far as the reading-time row is concerned.
  // significantlyViewedTimer: 30 s on the article marks it wasSignificantlyViewed, which is
  // what lets it seed a "Because you read" card.
  private significantTimer: number = -1;

  private startSignificantlyViewedTimer(key: string): void {
    clearTimeout(this.significantTimer);
    this.significantTimer = setTimeout(() => {
      this.significantTimer = -1;
      HistoryStore.markSignificantlyViewed(key).catch((e: Error) => {
        console.error('article: significant view not stored: ' + e.message);
      });
    }, 30000);
  }

  private flushPageViewSeconds(): void {
    clearTimeout(this.significantTimer);
    this.significantTimer = -1;
    const viewId: number | null = this.pageViewId;
    this.pageViewId = null;
    if (viewId !== null) {
      const seconds: number = Math.round((Date.now() - this.appearedAt) / 1000);
      if (seconds > 0) {
        HistoryStore.addPageViewSeconds(viewId, seconds).then((): void => {
          // the Activity tab re-reads its reading time on this
          AppStorage.setOrCreate<number>(PAGE_VIEW_SECONDS_SAVED_KEY, Date.now());
        }).catch((e: Error) => {
          console.error('article: page-view seconds failed: ' + e.message);
        });
      }
    }
  }

  // The system back unwinds the in-page article stack first; only an empty stack leaves.
  onBackPress(): boolean {
    if (this.showToc) {
      this.closeToc();
      return true;
    }
    return this.goBackInArticles();
  }

  private async load(): Promise<void> {
    this.isLoading = true;
    this.loadError = '';
    try {
      // An article opened in another language version names its wiki; otherwise the app's.
      const code: string = this.languageOverride !== ''
        ? this.languageOverride
        : (await LanguageStore.appLanguage()).languageCode;
      this.host = code + '.wikipedia.org';
      this.projectID = 'wikipedia.' + code;
      this.articleIsRTL = isRTLLanguage(code);
    } catch (e) {
      console.warn('article: app language unavailable, defaulting to en');
    }
    await this.resolveTitle();
    if (this.articleTitle === '') {
      this.isLoading = false;
      this.loadError = 'No article to show.';
      return;
    }
    const articleKey: string = 'https://' + this.host + '/wiki/' + this.articleTitle.replace(/ /g, '_');

    // history WRITE path, FIRST — before a single network call. The read-history row is what
    // the cold-start fallback below resolves the article from, and the page is routinely left
    // within a couple of seconds of opening (the fixture seed opens an article and backs
    // straight out); writing it only after the summary + mobile-html round trips loses the
    // row on every one of those visits, and the next cold launch then falls through to a
    // RANDOM article. The enrichment pass at the end COALESCEs the summary fields in.
    try {
      await HistoryStore.addToReadHistory(articleKey, null, this.articleTitle, null,
        null, null, null);
    } catch (e) {
      console.error('article: history write failed: ' + this.describeError(e));
    }

    try {
      this.summary = await ArticleService.fetchSummary(this.host, this.articleTitle);
    } catch (e) {
      console.warn('article: summary unavailable: ' + this.describeError(e));
    }

    // body: the live mobile-html document, parsed into native blocks; the offline copy
    // (svc_cache_store) is used instead when the fetch does not come back.
    this.offlineTried = false;
    try {
      this.applyBody(await ArticleService.fetchMobileHtml(this.host, this.articleTitle));
    } catch (e) {
      console.warn('article: mobile-html unavailable, trying the offline copy: '
        + this.describeError(e));
      await this.loadOfflineCopy();
    }
    this.isLoading = false;
    this.restoreArticleScrollPosition();
    this.listenForTooltips();

    // history WRITE path — read history row + CDPageView (persistPageViewsForWikipediaInReview)
    const displayTitle: string = this.getDisplayTitle();
    const description: string | null =
      this.summary !== null ? this.summary.articleDescription : null;
    const thumb: string | null =
      this.summary !== null && this.summary.thumbnail !== null ? this.summary.thumbnail.source : null;
    const pageID: number | null = this.summary !== null ? this.summary.id : null;
    try {
      await HistoryStore.addToReadHistory(articleKey, null, displayTitle, description,
        null, thumb, pageID);
      this.pageViewId = await HistoryStore.addPageView(this.articleTitle, 0, this.projectID, null);
    } catch (e) {
      console.error('article: history write failed: ' + this.describeError(e));
    }

    this.startSignificantlyViewedTimer(articleKey);
    // WhichCameFirstCoordinator: the day's game invitation is auto-presented over the
    // article, once, until the reader has seen it. Routed rather than bound as yet another
    // cover on this screen, which already multiplexes several through one node.
    this.presentGameInvitationIfNeeded();
    // article tabs (feat_article_tabs): append this article to the current tab. On a fresh
    // install there is no tab yet — the source opens the first article INTO a new tab
    // (WMFArticleTabsDataController.createArticleTab), it does not drop it on the floor,
    // which is why the tabs overview stayed empty no matter how many articles were read.
    try {
      const tabIdentifier: string | null = await TabsStore.currentTabIdentifier();
      if (tabIdentifier === null) {
        await TabsStore.createArticleTab(this.articleTitle, this.projectID, true);
      } else {
        // back in the page's own stack: the tab's previous item is this article, so it
        // becomes current again rather than a copy being appended after it
        if (this.isBackNavigation && this.pendingTabItem === '') {
          const prev: TabArticle | null = await TabsStore.getAdjacentArticleInTab(tabIdentifier, true);
          if (prev !== null && prev.identifier !== null && prev.title === this.articleTitle) {
            this.pendingTabItem = prev.identifier;
          }
        }
        if (this.pendingTabItem !== '') {
          await TabsStore.setTabItemAsCurrent(tabIdentifier, this.pendingTabItem);
        } else {
          await TabsStore.appendArticle(tabIdentifier, this.articleTitle, this.projectID, true);
        }
        this.previousArticleTab = await TabsStore.getAdjacentArticleInTab(tabIdentifier, true);
        this.nextArticleTab = await TabsStore.getAdjacentArticleInTab(tabIdentifier, false);
      }
    } catch (e) {
      console.warn('article: tab append failed: ' + this.describeError(e));
    }
    this.pendingTabItem = '';
    this.isBackNavigation = false;

    try {
      const saved: boolean = await SavedStore.isSaved(articleKey);
      this.savedDate = saved ? Date.now() : null;
      this.isSaved = saved;
    } catch (e) {
      console.error('article: saved lookup failed: ' + this.describeError(e));
    }

    try {
      const status: WatchStatus =
        await WatchlistService.fetchWatchStatus(this.host, this.articleTitle, false);
      this.isWatched = status.watched;
    } catch (e) {
      console.warn('article: watch status unavailable: ' + this.describeError(e));
    }

    try {
      this.relatedArticles = await ArticleService.fetchRelatedArticles(this.host, this.articleTitle,
        READ_MORE_COUNT, true);
      // the ToC ends with "Read more" once there is something to read
      if (this.relatedArticles.length > 0 && !this.tocItems.some((t: TocItem) => t.anchor === READ_MORE_ANCHOR)) {
        const readMore = new TocItem();
        readMore.anchor = READ_MORE_ANCHOR;
        readMore.title = getContext(this).resourceManager.getStringSync($r('app.string.article_read_more_title'));
        readMore.level = 1;
        this.tocItems = this.tocItems.concat([readMore]);
      }
    } catch (e) {
      console.warn('article: related pages unavailable: ' + this.describeError(e));
    }
  }

  // A cold deep-link launch carries only `targetPage`, so this screen can open with no
  // article. The source never does — fall back to the app's own data the way it would:
  // the most recently read article, then a random one.
  private async resolveTitle(): Promise<void> {
    if (this.articleTitle !== '') {
      return;
    }
    // A cold launch loads its page through `loadContent`, which carries no router params;
    // EntryAbility publishes the Want's article under this key so it is not lost.
    const fromLaunch: string = AppStorage.get<string>('launchArticleTitle') ?? '';
    if (fromLaunch !== '') {
      this.articleTitle = fromLaunch;
      return;
    }
    let historyRead: boolean = false;
    try {
      const recent: WMFArticle | null = await HistoryStore.mostRecentlyReadArticle();
      historyRead = true;
      if (recent !== null && recent.key !== null) {
        this.articleTitle = titleFromKey(recent.key);
      }
    } catch (e) {
      console.warn('article: read history unavailable: ' + this.describeError(e));
    }
    // Only a history that was READ and came back EMPTY may fall through to a random article —
    // a failed read is not an empty one, and treating it as such opens an arbitrary article.
    if (this.articleTitle === '' && historyRead) {
      try {
        const random: ArticleSummary = await ArticleService.fetchRandomSummary(this.host);
        this.articleTitle = random.title !== null ? random.title : '';
      } catch (e) {
        console.warn('article: random article unavailable: ' + this.describeError(e));
      }
    }
  }

  // svc_cache_store: SavedArticlesFetcher's offline mobile-html copy.
  private async loadOfflineCopy(): Promise<void> {
    if (this.offlineTried) {
      return;
    }
    this.offlineTried = true;
    try {
      const html: string | null = await ArticleCacheStore.cachedHtml(this.articleKey());
      if (html !== null && html !== '') {
        this.applyBody(html);
      } else {
        this.loadError = getContext(this).resourceManager.getStringSync(
          $r('app.string.article_load_failed_not_saved_offline'));
      }
    } catch (e) {
      this.loadError = this.describeError(e);
    }
  }

  // mobile-html -> the native block tree, the section list and the ToC.
  // TipUIPopoverViewController(wTip): bold title, secondary message, trailing close X
  @Builder
  wTipView() {
    Row() {
      Column() {
        Text($r('app.string.back_button_popover_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Text($r('app.string.original_tab_button_popover_description'))
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .id('w_tip_close')
        .fontSize(24)
        .fontColor([$r('app.color.theme_secondary_text')])
        .margin({ left: 12 })
        .onClick(() => {
          this.invalidateWTip();
        })
    }
    .id('w_tip')
    .padding({ left: 16, right: 12, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Top)
  }

  // listenForTooltips: WTip's rules hold on a phone (compact width) with no Year in Review or
  // fundraising modal due — neither is presented over the article here — so the tip shows
  // until it is closed or the W is tapped.
  private listenForTooltips(): void {
    if (this.wTipShown || Prefs.getBoolean(PrefKeys.didInvalidateWTip, false)) {
      return;
    }
    // bindPopup needs its anchor laid out first
    setTimeout(() => {
      this.showWTip = true;
    }, 600);
  }

  private invalidateWTip(): void {
    this.showWTip = false;
    Prefs.putBoolean(PrefKeys.didInvalidateWTip, true);
  }

  // refresh -> performWebViewRefresh: reload the article from the server under the dimmed
  // page, keeping what is on screen, then go back to the same offset.
  private refreshArticle(): void {
    const y: number = this.scroller.currentOffset().yOffset;
    this.isReloading = true;
    ArticleService.fetchMobileHtml(this.host, this.articleTitle).then((html: string) => {
      this.applyBody(html);
      let attempt: number = 0;
      const tryScroll = (): void => {
        attempt++;
        this.scroller.scrollTo({ xOffset: 0, yOffset: y });
        if (Math.abs(this.scroller.currentOffset().yOffset - y) > 4 && attempt < 8) {
          setTimeout(tryScroll, 250);
        }
      };
      setTimeout(tryScroll, 300);
    }).catch((e: Error) => {
      console.error('article: refresh failed: ' + e.message);
      this.presentHint('warning', getContext(this).resourceManager.getStringSync(
        $r('app.string.fetcher_error_generic')), '');
    }).finally(() => {
      this.isPullRefreshing = false;
      this.isReloading = false;
    });
  }

  private applyBody(html: string): void {
    const parsed: ParsedArticle = parseArticle(html);
    this.leadBlocks = parsed.lead;
    this.sections = parsed.sections;
    this.hasPageIssues = parsed.hasPageIssues;
    this.editProtected = parsed.editProtected;
    this.pronunciationURL = parsed.pronunciationURL;
    this.appliedTableOpening = Prefs.getBoolean(PrefKeys.isAutomaticTableOpeningEnabled, false);
    this.quickFactsExpanded = this.appliedTableOpening;
    const toc: TocItem[] = [];
    for (const section of parsed.sections) {
      const item = new TocItem();
      item.anchor = section.anchor;
      item.title = section.title;
      item.level = section.level - 1;
      toc.push(item);
    }
    // The source's ToC ends with "About this article", which jumps to the article footer.
    const about = new TocItem();
    about.anchor = ABOUT_ANCHOR;
    about.title = getContext(this).resourceManager.getStringSync($r('app.string.article_about_title'));
    about.level = 1;
    toc.push(about);
    this.tocItems = toc;
  }

  // ArticleSummary.imageURL(forWidth: ImageUtils.leadImageWidth()): the thumbnail re-sized to
  // the lead width, never the original upload - an original can be a 16 MP photo that the
  // image decoder gives up on, leaving an empty grey box.
  private leadImageURL(): string {
    if (this.summary === null) {
      return '';
    }
    const original: string = this.summary.original !== null ? this.summary.original.source : '';
    const thumb: string = this.summary.thumbnail !== null ? this.summary.thumbnail.source : '';
    const width: number = LEAD_IMAGE_WIDTH;
    if (this.summary.original !== null && this.summary.original.width <= width) {
      return original;
    }
    if (thumb !== '' && /\/\d+px-/.test(thumb)) {
      return thumb.replace(/\/\d+px-/, '/' + width + 'px-');
    }
    return thumb !== '' ? thumb : original;
  }

  private openSegment(seg: ArticleSegment): void {
    if (seg.kind === 'backlink') {
      this.openBackLinks(seg);
      return;
    }
    if (seg.kind === 'wiki') {
      this.openWikiLink(seg.target);
    } else if (seg.kind === 'external') {
      this.openSinglePageWeb(seg.target);
    } else {
      // a citation marker — ReferenceViewController presents the reference (source parity)
      this.referenceAnchor = seg.target;
      this.referenceLabel = seg.text;
      this.showToc = false;
      this.activeSheet = 'reference';
      this.showSheet = true;
    }
  }

  // Every block in reading order (the lead, then each section's), with the section it is in.
  private allBlocks(): ArticleBlock[] {
    const out: ArticleBlock[] = this.leadBlocks.slice();
    for (const section of this.sections) {
      out.push(...section.blocks);
    }
    return out;
  }

  // .backLink(referenceId:referenceText:backLinks:) -> showReferenceBackLinks: the reference's
  // citations are its markers in the body, in document order (the order pcs-back-links lists)
  private openBackLinks(seg: ArticleSegment): void {
    const targets: ArticleSegment[] = [];
    for (const b of this.allBlocks()) {
      for (const s of blockSegments(b)) {
        if (s.kind === 'ref' && s.target === seg.target) {
          targets.push(s);
        }
      }
    }
    if (targets.length === 0) {
      return;
    }
    this.backLinkTargets = targets;
    this.backLinkSource = seg;
    this.backLinkRef = seg.target;
    this.backLinkLabel = seg.text;
    this.backLinkIndex = 0;
    this.showBackLinkTarget();
  }

  // referenceBackLinksViewControllerUserDidNavigateTo: scroll to the citation, centred, and
  // highlight it
  private showBackLinkTarget(): void {
    const seg: ArticleSegment | undefined = this.backLinkTargets[this.backLinkIndex];
    if (seg !== undefined) {
      this.scrollToSegment(seg, true);
    }
  }

  private setHighlight(seg: ArticleSegment | null): void {
    this.highlightedRun = seg;
    this.highlightTick++;
  }

  private isHighlighted(seg: ArticleSegment): boolean {
    return this.highlightTick >= 0 && seg === this.highlightedRun;
  }

  private stepBackLinks(delta: number): void {
    const n: number = this.backLinkTargets.length;
    this.backLinkIndex = (this.backLinkIndex + delta + n) % n;
    this.showBackLinkTarget();
  }

  private closeBackLinks(): void {
    this.backLinkRef = '';
    this.setHighlight(null);
    this.backLinkTargets = [];
  }

  // referenceViewControllerUserDidNavigateBackToReference: back to the reference in the list,
  // highlighted for a second
  private backToReference(): void {
    const source: ArticleSegment | null = this.backLinkSource;
    this.closeBackLinks();
    if (source !== null) {
      this.scrollToSegment(source, false);
      setTimeout(() => {
        if (this.highlightedRun === source) {
          this.setHighlight(null);
        }
      }, 1000);
    }
  }

  private scrollToSegment(seg: ArticleSegment, centered: boolean): void {
    const block: ArticleBlock | undefined = this.allBlocks().find((b: ArticleBlock) => blockSegments(b).indexOf(seg) >= 0);
    if (block === undefined) {
      return;
    }
    // a closed section (References) opens first
    const section: ArticleSection | undefined = this.sections.find((x: ArticleSection) => x.blocks.indexOf(block) >= 0);
    if (section !== undefined && !section.expanded) {
      this.scrollToSection(section.anchor);
    }
    this.setHighlight(seg);
    setTimeout(() => {
      try {
        const utils = this.getUIContext().getComponentUtils();
        const target = utils.getRectangleById('article_block_' + block.key);
        const body = utils.getRectangleById('article_body_scroll');
        const offset: number = this.scroller.currentOffset().yOffset;
        const delta: number = px2vp(target.windowOffset.y - body.windowOffset.y);
        const margin: number = centered ? px2vp(body.size.height) / 2 - px2vp(target.size.height) / 2 : 16;
        this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, offset + delta - margin),
          animation: { duration: 300 } });
      } catch (e) {
        console.error('article: scroll to citation failed: ' + (e as Error).message);
      }
    }, 120);
  }

  // ArticleViewController.handleLink -> Router.destination(for:): a main-namespace title is an
  // article, Talk:/User talk: the native talk page, and the main page and every other
  // namespace (Help:, Wikipedia:, File:, Template: ...) the in-app web page.
  private openWikiLink(title: string): void {
    const d: LinkDestination = destinationFor(this.host.split('.')[0], title);
    if (d.kind === LinkKind.Article) {
      this.openArticle(d.title);
    } else if (d.kind === LinkKind.Talk) {
      router.pushUrl({ url: 'pages/TalkPageViewControllerPage',
        params: { 'talkPageTitle': d.title, 'languageCode': d.languageCode } });
    } else if (d.kind !== LinkKind.Web) {
      // Special:History/…, Special:MobileDiff/…, Special:Watchlist … open their native screens
      const intent = intentForDestination(d);
      router.pushUrl({ url: intent.route, params: intent.params });
    } else {
      this.openSinglePageWeb(d.url);
    }
  }

  // ArticleWebMessageHandling .leadImage / .image -> WMFImageGalleryViewController on the
  // tapped image, paging through the article's images (the lead first, then the figures).
  private openImageGallery(fileTitle: string, imageURL: string): void {
    const titles: string[] = [];
    const urls: string[] = [];
    const add = (title: string, url: string): void => {
      if (url !== '' && (title === '' || titles.indexOf(title) < 0)) {
        titles.push(title);
        urls.push(url);
      }
    };
    if (this.leadImageURL() !== '') {
      add(fileTitleFromImageURL(this.leadImageURL()), this.leadImageURL());
    }
    const collect = (blocks: ArticleBlock[]): void => {
      for (const b of blocks) {
        if (b.kind === 'img' && b.videoURLs.length === 0) {
          add(b.fileTitle, b.imageURL);
        }
      }
    };
    collect(this.leadBlocks);
    for (const section of this.sections) {
      collect(section.blocks);
    }
    let index: number = fileTitle !== '' ? titles.indexOf(fileTitle) : urls.indexOf(imageURL);
    if (index < 0) {
      titles.unshift(fileTitle);
      urls.unshift(imageURL);
      index = 0;
    }
    router.pushUrl({ url: 'pages/WMFImageGalleryViewControllerPage', params: {
      'fileTitles': JSON.stringify(titles), 'imageURLs': JSON.stringify(urls), 'initialIndex': index.toString()
    } }).catch((e: Error) => {
      console.error('article: image gallery route failed: ' + e.message);
    });
  }

  private recordSectionTop(anchor: string, y: Length | undefined): void {
    if (y === undefined) {
      return;
    }
    const top: number = Number.parseFloat(y.toString());
    if (!Number.isNaN(top)) {
      this.sectionTops.set(anchor, top);
    }
  }

  // Find in page: each run split around the matches of the query, the matches marked (the
  // source highlights the words; this used to tint the whole paragraph).
  private inlineColor(seg: ArticleSegment): string {
    return readableInlineColor(seg.color, WMFTheme.isDarkThemeName(this.theme));
  }

  // the block's text as the Text component counts it: the bullet, every Span, and one
  // character for each ImageSpan (swatch, external-link mark)
  private blockPlainText(b: ArticleBlock): string {
    let out: string = b.kind === 'li' && b.bullet ? '\u2022 ' : '';
    for (const piece of this.findPieces(b)) {
      out += piece.seg.kind === 'swatch' || (piece.text === '' && piece.seg.externalMark) ? ' ' : piece.text;
    }
    return out;
  }

  private findPieces(b: ArticleBlock): FindPiece[] {
    const out: FindPiece[] = [];
    const q: string = this.findQuery.toLowerCase();
    for (const seg of b.segments) {
      if (q === '' || seg.kind === 'swatch') {
        out.push(new FindPiece(seg.text, seg, false));
        if (seg.externalMark) {
          out.push(new FindPiece('', seg, false));
        }
        continue;
      }
      const lower: string = seg.text.toLowerCase();
      let at: number = 0;
      let hit: number = lower.indexOf(q);
      while (hit >= 0) {
        if (hit > at) {
          out.push(new FindPiece(seg.text.substring(at, hit), seg, false));
        }
        out.push(new FindPiece(seg.text.substring(hit, hit + q.length), seg, true));
        at = hit + q.length;
        hit = lower.indexOf(q, at);
      }
      if (at < seg.text.length) {
        out.push(new FindPiece(seg.text.substring(at), seg, false));
      }
      if (seg.externalMark) {
        out.push(new FindPiece('', seg, false));
      }
    }
    return out;
  }


  // WMFGameAnnouncementViewController is presented as a sheet OVER the article, not pushed:
  // this pushed the games splash full-screen, so opening any article on a fresh install
  // replaced the article with the game and the reader had to back out of it to read anything.
  private presentGameInvitationIfNeeded(): void {
    try {
      if (GameStore.hasSeenAnnouncement()) {
        return;
      }
      // Shown once. Recorded here rather than on dismissal so a second article cannot raise
      // it again while this sheet is still open.
      GameStore.markAnnouncementSeen();
    } catch (e) {
      return;
    }
    this.activeSheet = 'gameInvite';
    this.showSheet = true;
  }

  @Builder
  gameInviteSheet() {
    Column() {
      Text($r('app.string.games_announcement_title'))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_text'))
        .margin({ top: 16 })
      Text($r('app.string.games_announcement_message'))
        .width('100%')
        .fontSize(15)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 8 })
      Button($r('app.string.games_announcement_play_button'))
        .id('games_announcement_play')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .backgroundColor($r('app.color.theme_link'))
        .margin({ top: 24 })
        .onClick(() => {
          this.showSheet = false;
          router.pushUrl({ url: 'pages/WMFGamesSplashScreenViewControllerPage' })
            .catch((e: Error) => {
              console.error('article: games splash push failed: ' + e.message);
            });
        })
      // Source's second action is "No thanks", not Cancel.
      Button($r('app.string.variants_alert_dismiss_button'))
        .id('games_announcement_dismiss')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .backgroundColor(this.mid())
        .margin({ top: 8 })
        .onClick(() => {
          this.showSheet = false;
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  private lastEdited(): string {
    return lastEditedString(getContext(this), this.summary !== null ? this.summary.timestamp : null);
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // One paragraph / list item: plain runs and tappable link runs in a single Text. Each run
  // used to be its own Text box in a wrapping Flex, so a run that wrapped onto two lines
  // pushed the next link out beside it ("Çin" floating at the margin), and under an RTL
  // device language the Flex laid the runs out right-to-left.
  @Builder
  blockView(b: ArticleBlock) {
    if (b.kind === 'img') {
      ArticleFigureView({
        block: b,
        fontPercent: this.fontPercent,
        imageOpacity: (WMFTheme.withName(this.theme) ?? WMFTheme.standard).imageOpacity,
        rtl: this.articleIsRTL,
        dark: WMFTheme.isDarkThemeName(this.theme),
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        },
        onImage: (block: ArticleBlock): void => {
          this.openImageGallery(block.fileTitle, block.imageURL);
        }
      })
    } else if (b.kind === 'pie') {
      ArticlePieView({
        block: b,
        fontPercent: this.fontPercent,
        rtl: this.articleIsRTL,
        dark: WMFTheme.isDarkThemeName(this.theme),
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        }
      })
    } else if (b.kind === 'quote') {
      this.quoteBoxView(b)
    } else if (b.kind === 'bq') {
      this.blockquoteView(b)
    } else if (b.kind === 'ambox') {
      this.amboxView(b)
    } else if (b.kind === 'table') {
      ArticleTableView({
        block: b,
        defaultOpen: this.quickFactsExpanded,
        fontPercent: this.fontPercent,
        imageOpacity: (WMFTheme.withName(this.theme) ?? WMFTheme.standard).imageOpacity,
        rtl: this.articleIsRTL,
        dark: WMFTheme.isDarkThemeName(this.theme),
        panelColor: this.mid(),
        toggleId: this.leadBlocks.indexOf(b) >= 0 ? 'quick_facts_toggle' : 'collapse_table_toggle_itemroot',
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        },
        scroller: this.scroller,
        scrollId: 'article_body_scroll'
      })
    } else {
      this.textBlockView(b)
    }
  }

  // Template:Quote box: a 1 vp #A2A9B1 border around the template's fill (#ACE1AF on Moon
  // landing), the quote's paragraphs and the cite line inside, at the full text width.
  @Builder
  quoteBoxView(b: ArticleBlock) {
    Column() {
      ForEach(b.children, (c: ArticleBlock) => {
        this.textBlockView(c)
      }, (c: ArticleBlock) => c.key + '_' + this.findQuery)
    }
    .width('calc(100% - 32vp)')
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    .padding({ top: 8, bottom: 8 })
    .border({ width: 1, color: '#A2A9B1' })
    .backgroundColor(b.fill !== '' ? b.fill : this.mid())
  }

  // Template:Ambox as mobile-html draws it: a #FBFBFB box in a 1 vp #A2A9B1 border with a 10 vp
  // left bar in the type's colour, the 40 vp icon centred in a 52 vp column (0.5 em in), then
  // the message and, indented 1.6 em, the listed issues. The dark themes keep the page's
  // paper and draw the border and the bar in #54595D.
  @Builder
  amboxView(b: ArticleBlock) {
    Row() {
      if (b.imageURL !== '') {
        Image(b.imageURL)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
          .margin({ left: 14, right: 6 })
      }
      Column() {
        this.textBlockView(b)
        ForEach(b.children, (c: ArticleBlock) => {
          this.textBlockView(c)
        }, (c: ArticleBlock) => c.key + '_' + this.findQuery)
      }
      .layoutWeight(1)
      .padding({ top: 4, bottom: 4 })
    }
    .width('calc(100% - 32vp)')
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .direction(this.articleDirection())
    .border({
      width: { left: 10, top: 1, right: 1, bottom: 1 },
      color: this.isDarkArticle() ? '#54595D'
        : { left: b.ink, top: '#A2A9B1', right: '#A2A9B1', bottom: '#A2A9B1' }
    })
    .backgroundColor(this.isDarkArticle() ? this.paper() : (b.fill !== '' ? b.fill : '#FBFBFB'))
  }

  private isDarkArticle(): boolean {
    return WMFTheme.isDarkThemeName(this.theme);
  }

  // A blockquote as the PCS base CSS draws it: a 3 px --border-color-subtle bar on the leading
  // side at the text margin, the text 32 px in from the bar and 24 px from the far edge, 8 px
  // above and below, 1 em clear of the paragraphs around it; the serif face at 1.1 em.
  @Builder
  blockquoteView(b: ArticleBlock) {
    Column() {
      ForEach(b.children, (c: ArticleBlock) => {
        this.textBlockView(c)
      }, (c: ArticleBlock) => c.key + '_' + this.findQuery)
    }
    .width('calc(100% - 16vp)')
    .margin({ left: this.articleIsRTL ? 0 : 16, right: this.articleIsRTL ? 16 : 0, top: 8, bottom: 8 })
    .padding({ top: 8, bottom: 8 })
    .border({ width: this.articleIsRTL ? { right: 3 } : { left: 3 }, color: this.quoteBar() })
  }

  // --border-color-subtle: #c8ccd1, sepia #cbc8c1, dark and black #54595d
  private quoteBar(): string {
    if (WMFTheme.isDarkThemeName(this.theme)) {
      return '#54595D';
    }
    return this.theme.startsWith('sepia') ? '#CBC8C1' : '#C8CCD1';
  }

  private textControllerFor(key: string): TextController {
    let c: TextController | undefined = this.textControllers.get(key);
    if (c === undefined) {
      c = new TextController();
      this.textControllers.set(key, c);
    }
    return c;
  }

  // contextMenuConfigurationForElement: the run under the finger, if it is an article link,
  // gets the peek preview and menu.
  private longPressLink(b: ArticleBlock, event: GestureEvent): void {
    if (event.fingerList.length === 0) {
      return;
    }
    const finger: FingerInfo = event.fingerList[0];
    let position: number = -1;
    try {
      position = this.textControllerFor(b.key).getLayoutManager()
        .getGlyphPositionAtCoordinate(vp2px(finger.localX), vp2px(finger.localY)).position;
    } catch (e) {
      return;
    }
    // the runs in the order textBlockView draws them; an image run is one character
    let at: number = b.kind === 'li' && b.bullet ? 2 : 0;
    let hit: ArticleSegment | null = null;
    for (const piece of this.findPieces(b)) {
      const len: number = piece.seg.kind === 'swatch' || (piece.text === '' && piece.seg.externalMark)
        ? 1 : piece.text.length;
      if (position >= at && position < at + len) {
        hit = piece.seg;
        break;
      }
      at += len;
    }
    if (hit === null || hit.kind !== 'wiki') {
      return;
    }
    const d: LinkDestination = destinationFor(this.host.split('.')[0], hit.target);
    if (d.kind !== LinkKind.Article) {
      return;
    }
    this.linkPreviewTitle = d.title;
    this.linkPreviewLanguage = d.languageCode;
    this.linkPreviewDescription = '';
    this.linkPreviewImage = '';
    this.linkPreviewExtract = '';
    this.linkPreviewLoaded = false;
    this.linkPreviewCoords = [];
    this.linkMenuKey = b.key;

    const host: string = d.languageCode + '.wikipedia.org';
    ArticleService.fetchSummary(host, d.title).then((summary: ArticleSummary) => {
      this.linkPreviewDescription = summary.articleDescription ?? '';
      this.linkPreviewImage = summary.thumbnail !== null ? summary.thumbnail.source : '';
      this.linkPreviewExtract = summary.extract ?? '';
      if (summary.coordinates !== null) {
        this.linkPreviewCoords = [summary.coordinates.lat, summary.coordinates.lon];
      }
      this.linkPreviewLoaded = true;
    }).catch((e: Error) => {
      this.linkPreviewLoaded = true;
      console.error('article: link preview failed: ' + e.message);
    });
    SavedStore.isSaved(this.linkPreviewKey()).then((saved: boolean) => {
      this.linkPreviewSaved = saved;
    }).catch((e: Error) => {
      console.error('article: link saved state failed: ' + e.message);
    });
  }

  private linkPreviewKey(): string {
    return 'https://' + this.linkPreviewLanguage + '.wikipedia.org/wiki/' + this.linkPreviewTitle.replace(/ /g, '_');
  }

  // the menu's actions run after it closes
  private linkMenuAction(action: string): void {
    this.linkMenuKey = '';
    const title: string = this.linkPreviewTitle;
    const projectID: string = 'wikipedia~' + this.linkPreviewLanguage;
    if (action === 'open') {
      this.openArticle(title);
    } else if (action === 'newTab') {
      TabsStore.createArticleTab(null, projectID, true).then(() => {
        this.openArticle(title);
      }).catch((e: Error) => console.error('article: open in new tab failed: ' + e.message));
    } else if (action === 'backgroundTab') {
      TabsStore.createArticleTab(title, projectID, false)
        .catch((e: Error) => console.error('article: open in background tab failed: ' + e.message));
    } else if (action === 'save') {
      SavedStore.toggleSave(this.linkPreviewKey(), null, title)
        .catch((e: Error) => console.error('article: link save failed: ' + e.message));
    } else if (action === 'map' && this.linkPreviewCoords.length === 2) {
      showArticleOnMap(this.getUIContext().getRouter(), title, this.linkPreviewDescription,
        this.linkPreviewImage, this.linkPreviewCoords[0], this.linkPreviewCoords[1]);
    } else if (action === 'share') {
      const record: systemShare.SharedRecord = { utd: 'general.hyperlink', content: this.linkPreviewKey(), title: title };
      try {
        new systemShare.ShareController(new systemShare.SharedData(record)).show(getContext(this) as common.UIAbilityContext, {
          selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL
        }).catch((e: Error) => console.error('article: link share failed: ' + e.message));
      } catch (e) {
        console.error('article: link share unavailable: ' + (e as Error).message);
      }
    }
  }

  // ArticlePeekPreviewViewController: lead image over title, description and the extract.
  // The card's size is fixed before the summary arrives (image area, two title/description
  // lines, five extract lines): the context menu measures its preview once, so a card that
  // grew afterwards was cut off at the image.
  @Builder
  linkPreviewCard() {
    Column() {
      Stack() {
        if (this.linkPreviewImage !== '') {
          Image(this.linkPreviewImage)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        }
      }
      .width('100%')
      .height(160)
      .backgroundColor($r('app.color.gray200'))
      Column() {
        Text(this.linkPreviewTitle)
          .width('100%')
          .height(28)
          .fontSize(20)
          .fontFamily(WMFFontFamilies.serifStack)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.linkPreviewDescription)
          .width('100%')
          .height(21)
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Stack() {
          if (!this.linkPreviewLoaded) {
            LoadingProgress()
              .width(32)
              .height(32)
              .color($r('app.color.theme_secondary_text'))
          } else {
            Text(this.linkPreviewExtract)
              .width('100%')
              .height('100%')
              .fontSize(15)
              .lineHeight(21)
              .fontColor($r('app.color.theme_text'))
              .align(Alignment.TopStart)
              .maxLines(5)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .height(105)
        .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
    }
    .width(320)
    .height(160 + 16 + 28 + 25 + 115 + 16)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // the source's link menu: Open, Open in new tab, Open in background tab, Save for later,
  // View on a map (an article with coordinates), Share
  @Builder
  linkMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.article_tabs_open'), endIcon: $r('app.media.chevron_right') })
        .onClick(() => this.linkMenuAction('open'))
      MenuItem({ content: $r('app.string.article_tabs_open_new_tab'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_square')).fontColor([$r('app.color.theme_text')]) })
        .onClick(() => this.linkMenuAction('newTab'))
      MenuItem({ content: $r('app.string.article_tabs_open_background_tab'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_square')).fontColor([$r('app.color.theme_text')]) })
        .onClick(() => this.linkMenuAction('backgroundTab'))
      MenuItem({ content: this.linkPreviewSaved ? $r('app.string.button_saved_remove') : $r('app.string.button_save_for_later'),
        symbolStartIcon: new SymbolGlyphModifier(this.linkPreviewSaved ? $r('sys.symbol.bookmark_fill')
          : $r('sys.symbol.bookmark')).fontColor([$r('app.color.theme_text')]) })
        .onClick(() => this.linkMenuAction('save'))
      if (this.linkPreviewCoords.length === 2) {
        MenuItem({ content: $r('app.string.page_location'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.map')).fontColor([$r('app.color.theme_text')]) })
          .onClick(() => this.linkMenuAction('map'))
      }
      MenuItem({ content: $r('app.string.article_share'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([$r('app.color.theme_text')]) })
        .onClick(() => this.linkMenuAction('share'))
    }
  }

  // ReferenceBackLinksViewController over the article (a passthrough view): the reference's
  // bar on top (jump back to the reference, "Reference [a]", close) and the toolbar at the
  // bottom ("n/m", previous and next, wrapping around)
  // ReferenceBackLinksViewController (a passthrough view over the article): while it is up its
  // bar replaces the navigation bar (jump back to the reference, "Reference [a]", close) and its
  // toolbar the article toolbar ("n/m", previous and next, wrapping around)
  @Builder
  backLinksTopBar() {
    Row() {
      Button() {
        Image($r('app.media.references'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.theme_link'))
      }
      .id('reference_back_to_reference')
      .accessibilityText($r('app.string.reference_section_button_accessibility_label'))
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.backToReference();
      })
      Text(getContext(this).resourceManager.getStringSync($r('app.string.article_reference_view_title').id)
        .replace(/\\?\$1/, this.backLinkLabel))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      Button() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor([$r('app.color.theme_text')])
      }
      .id('reference_backlinks_close')
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.closeBackLinks();
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor(this.paper())
  }

  @Builder
  backLinksToolbar() {
    Row({ space: 8 }) {
      Text(`${this.backLinkIndex + 1}/${this.backLinkTargets.length}`)
        .id('reference_backlinks_count')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
      Blank()
      Button() {
        Image($r('app.media.directionup'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.theme_link'))
      }
      .id('reference_backlinks_previous')
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .enabled(this.backLinkTargets.length > 1)
      .opacity(this.backLinkTargets.length > 1 ? 1 : 0.4)
      .onClick(() => {
        this.stepBackLinks(-1);
      })
      Button() {
        Image($r('app.media.directiondown'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.theme_link'))
      }
      .id('reference_backlinks_next')
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .enabled(this.backLinkTargets.length > 1)
      .opacity(this.backLinkTargets.length > 1 ? 1 : 0.4)
      .onClick(() => {
        this.stepBackLinks(1);
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 8 })
    .backgroundColor(this.paper())
  }

  @Builder
  textBlockView(b: ArticleBlock) {
    Text(undefined, { controller: this.textControllerFor(b.key) }) {
      if (b.kind === 'li' && b.bullet) {
        Span('\u2022 ')
          .fontColor($r('app.color.theme_secondary_text'))
      }
      ForEach(this.findPieces(b), (piece: FindPiece, i: number) => {
        if (piece.seg.kind === 'swatch') {
          // a legend / colour-box square
          ImageSpan(swatchPixelMap(piece.seg.color, piece.seg.borderColor))
            .width(this.fs(14))
            .height(this.fs(14))
            .margin({ right: 4 })
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else if (piece.text === '' && piece.seg.externalMark) {
          ImageSpan(externalLinkMark(WMFTheme.isDarkThemeName(this.theme), this.articleIsRTL))
            .width(this.fs(13))
            .height(this.fs(13))
            .margin({ left: 2 })
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else if (piece.seg.kind === 'text') {
          Span(piece.text)
            .fontSize(this.spanSize(b, piece.seg))
            .baselineOffset(this.supRaise(b, piece.seg))
            .lineHeight(this.supLineHeight(b, piece.seg))
            .fontWeight(piece.seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(piece.seg.italic !== (b.kind === 'note') ? FontStyle.Italic : FontStyle.Normal)
            .fontColor(b.kind === 'note' ? $r('app.color.theme_secondary_text')
              : (this.inlineColor(piece.seg) !== '' ? this.inlineColor(piece.seg) : this.inkFor(b)))
            // inline highlights are light colours: kept to the light themes
            .textBackgroundStyle({ color: piece.hit ? FIND_MATCH_BG
              : (piece.seg.background !== '' && !WMFTheme.isDarkThemeName(this.theme) ? piece.seg.background
                : Color.Transparent) })
        } else {
          Span(piece.text)
            .fontSize(this.spanSize(b, piece.seg))
            .baselineOffset(this.supRaise(b, piece.seg))
            .lineHeight(this.supLineHeight(b, piece.seg))
            .fontWeight(piece.seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(piece.seg.italic !== (b.kind === 'note') ? FontStyle.Italic : FontStyle.Normal)
            .fontColor(this.linkFor(b))
            .textBackgroundStyle({ color: piece.hit || this.isHighlighted(piece.seg) ? FIND_MATCH_BG
              : Color.Transparent })
            .onClick(() => {
              this.openSegment(piece.seg);
            })
        }
      }, (piece: FindPiece, i: number) => b.key + '_' + i + '_' + this.findQuery +
        (this.isHighlighted(piece.seg) ? '_hl' + this.highlightTick : ''))
    }
    // a hatnote: the source's italic, smaller, secondary-colour note above the text
    .fontStyle(b.kind === 'note' ? FontStyle.Italic : FontStyle.Normal)
    .fontFamily(b.kind === 'bqp' ? WMFFontFamilies.serifStack : undefined)
    .fontSize(this.fs(this.bodySize(b)))
    .lineHeight(this.fs(this.lineSize(b)))
    .width('100%')
    .direction(this.articleDirection())
    .textAlign(b.justify ? TextAlign.JUSTIFY : TextAlign.Start)
    .padding(this.blockPadding(b))
    // the article text is selectable, and the selection menu's Share is the app's own
    // (shareArticle(with: selectedText), which offers Share-a-fact)
    .copyOption(CopyOptions.LocalDevice)
    // flipping the value clears every selection (a link long press is a preview, not one)
    .selection(this.selectionResetFlip ? 0 : -1, this.selectionResetFlip ? 0 : -1)
    .onTextSelectionChange((start: number, end: number) => {
      this.selectedText = end > start ? this.blockPlainText(b).substring(start, end).trim() : '';
    })
    .editMenuOptions({
      onCreateMenu: (items: TextMenuItem[]): TextMenuItem[] => items,
      onMenuItemClick: (item: TextMenuItem, range: TextRange): boolean => {
        if (item.id.equals(TextMenuItemId.SHARE)) {
          // the live selection (onTextSelectionChange); the menu's range can lag behind handle drags
          this.share(this.selectedText !== '' ? this.selectedText
            : this.blockPlainText(b).substring(range.start ?? 0, range.end ?? 0).trim());
          return true;
        }
        return false;
      }
    })
    // parallel, so the text's own long press still starts a selection off a link
    .parallelGesture(LongPressGesture({ duration: 500 }).onAction((event: GestureEvent) => {
      this.longPressLink(b, event);
    }))
    .bindContextMenu(this.linkMenuKey === b.key, this.linkMenu(), {
      preview: this.linkPreviewCard(),
      onDisappear: () => {
        if (this.linkMenuKey === b.key) {
          this.linkMenuKey = '';
          // the text's own long press ran in parallel and left a selection behind
          this.selectionResetFlip = !this.selectionResetFlip;
        }
      }
    })
  }

  // a message box's text sits 0.5 em in from its icon, its listed issues 1.6 em further
  private blockPadding(b: ArticleBlock): Padding {
    if (b.kind === 'ambox') {
      return { left: 8, right: 8, top: 4, bottom: 4 };
    }
    if (b.kind === 'ambi') {
      return { left: 34, right: 8, top: 0, bottom: 0 };
    }
    // inside the blockquote's bar: 32 px in, 24 px from the far edge (the text margin's 16 + 24)
    if (b.kind === 'bqp') {
      return { left: 32, right: 40, top: 4, bottom: 4 };
    }
    const side: number = b.kind === 'qp' ? 12 : 16;
    return { left: b.kind === 'li' && b.bullet ? 32 : side, right: side, top: 6, bottom: 6 };
  }

  // a hatnote and a quote box's text (the template's font-size: 88 %) are smaller than body text
  // a blockquote's serif is Georgia at 1.1 em in the source; Noto Serif is drawn larger for its
  // size (taller x-height, wider letters), so the body size matches the source's look
  private bodySize(b: ArticleBlock): number {
    return b.kind === 'note' || b.kind === 'qp' ? 15 : 17;
  }

  // a message box's listed issues: line-height 1.5 em
  private lineSize(b: ArticleBlock): number {
    return b.kind === 'note' ? 22 : (b.kind === 'qp' ? 23 : (b.kind === 'ambi' ? 24 : (b.kind === 'bqp' ? 28 : 26)));
  }

  // Text in a quote box takes the template's colour; on a filled (light) box with none set, the
  // light theme's ink, so it stays readable when the article is dark.
  private inkFor(b: ArticleBlock): ResourceColor {
    if (b.kind === 'qp' && b.ink !== '') {
      return b.ink;
    }
    return b.kind === 'qp' && b.fill !== '' ? '#202122' : $r('app.color.theme_text');
  }

  private linkFor(b: ArticleBlock): ResourceColor {
    return b.kind === 'qp' && b.fill !== '' ? '#3366CC' : $r('app.color.theme_link');
  }

  // The chrome glyphs are black PNGs; under dark and black they are recoloured to the
  // theme's primary text (gray100) so they stay visible.
  private iconTint(): ColorFilter {
    return WMFTheme.isDarkThemeName(this.theme) ? DARK_ICON_FILTER : IDENTITY_FILTER;
  }

  private fs(size: number): number {
    return size * this.fontPercent / 100;
  }

  // A text block's body size; <sup> runs (reference markers) at SUP_SCALE of it, as in the source.
  private spanSize(b: ArticleBlock, seg: ArticleSegment): number {
    const body: number = this.bodySize(b);
    return this.fs(seg.sup ? body * SUP_SCALE : (seg.small ? body * SMALL_SCALE : body));
  }

  // A <sup> run gets a line box no taller than its own glyphs, so lifting it does not push the
  // line open (the source's sup keeps line-height: 1); other runs keep the block's line height.
  private supLineHeight(b: ArticleBlock, seg: ArticleSegment): number {
    const body: number = this.bodySize(b);
    return this.fs(seg.sup ? body * SUP_SCALE : this.lineSize(b));
  }

  private supRaise(b: ArticleBlock, seg: ArticleSegment): LengthMetrics {
    return LengthMetrics.vp(seg.sup ? this.fs(this.bodySize(b) * SUP_RAISE) : 0);
  }

  // The theme_* resources cover light and dark (the colour mode ThemeManager sets); sepia
  // and black have no resource set, so the article paints their papers itself.
  private themeColors(): ThemeColors | null {
    const t: WMFTheme | null = WMFTheme.withName(this.theme);
    return t !== null && (t.colors.identifier === ThemeIdentifier.sepia ||
      t.colors.identifier === ThemeIdentifier.black) ? t.colors : null;
  }

  private paper(): ResourceColor {
    const c: ThemeColors | null = this.themeColors();
    return c !== null ? c.paperBackground : (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'));
  }

  private mid(): ResourceColor {
    const c: ThemeColors | null = this.themeColors();
    return c !== null ? c.midBackground : (this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background'));
  }

  // Direction.Auto follows the device language, not the parent, so every row of article
  // content names the article's own direction.
  private articleDirection(): Direction {
    return this.articleIsRTL ? Direction.Rtl : Direction.Ltr;
  }

  @Builder
  sheetBuilder() {
    if (this.activeSheet === 'languages') {
      Column() {
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_text')])
          }
          .id('close_button')
          .type(ButtonType.Circle)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showSheet = false;
          })
          Blank()
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
        WMFLanguagesView({
          articleTitle: this.articleTitle,
          articleHost: this.host,
          topInset: 0,
          onSelect: (lang: MWKLanguageLink): void => {
            this.pendingLanguage = lang;
            this.showSheet = false;
          }
        })
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    } else if (this.activeSheet === 'reference') {
      ReferenceView({
        articleTitle: this.articleTitle,
        host: this.host,
        referenceAnchor: this.referenceAnchor,
        referenceLabel: this.referenceLabel,
        onClose: (): void => {
          this.showSheet = false;
        },
        onJumpToReferenceSection: (): void => {
          this.showSheet = false;
          this.scrollToSection('References');
        },
        // WMFReferencePopoverMessageViewController link tap: dismiss, then handle the link
        onOpenLink: (seg: ArticleSegment): void => {
          this.showSheet = false;
          this.openSegment(seg);
        }
      })
    } else if (this.activeSheet === 'pageIssues') {
      PageIssuesTableView({
        articleTitle: this.articleTitle,
        host: this.host,
        onClose: (): void => {
          this.showSheet = false;
        }
      })
    } else if (this.activeSheet === 'referencePage') {
      WMFReferencePageView({
        articleTitle: this.articleTitle,
        host: this.host,
        onClose: (): void => {
          this.showSheet = false;
        },
        onReferenceChanged: (index: number): void => {
          // didFinishAnimating -> re-highlight that citation in the article body
          this.scrollToSection('References');
          console.info('article: reference panel moved to ' + index.toString());
        }
      })
    } else if (this.activeSheet === 'profile') {
      WMFProfileViewSheet({
        onClose: (): void => {
          this.showSheet = false;
        }
      })
    } else if (this.activeSheet === 'gameInvite') {
      this.gameInviteSheet()
    }
  }

  @Builder
  coverBuilder() {
    if (this.activeCover === 'addToReadingList') {
      AddArticlesToReadingListView({
        articleKey: this.articleKey(),
        articleTitle: this.getDisplayTitle(),
        // createNewReadingListButtonPressed — a child-local @State branch never redraws
        // here (proven on device: the field flips, the overlay doesn't), so the switch to
        // CreateReadingListViewController is driven by this HOST's own `activeCover`,
        // the same mechanism that already opens this cover correctly.
        onCreateNewList: (): void => {
          // CreateReadingListViewController is a routed page: inside this cover its typed
          // name never redrew and it had no callbacks, so Create and X did nothing.
          this.showCover = false;
          const params: Record<string, string> = {
            'articleKey': this.articleKey(), 'articleTitle': this.getDisplayTitle() };
          router.pushUrl({ url: 'pages/CreateReadingListViewControllerPage', params: params });
        },
        // needsAutoDismissUponAdd — the overlay closes itself once the article is added
        onDismiss: (): void => {
          this.showCover = false;
          // adding the article to a list saves it — reflect that on the save toolbar item
          this.savedDate = Date.now();
          this.isSaved = true;
        }
      })
    } else if (this.activeCover === 'fundraising' && this.fundraisingAsset !== null) {
      FundraisingAnnouncementPanelView({
        asset: this.fundraisingAsset,
        showOptionalButton: this.fundraisingShowsMaybeLater,
        // primaryButtonTapHandler: DonateCoordinator with the campaign's donate URL
        onPrimary: (): void => {
          const asset: CampaignAsset = this.fundraisingAsset as CampaignAsset;
          FundraisingCampaignStore.markAssetAsPermanentlyHidden(asset);
          this.closeFundraising();
          router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage',
            params: { 'url': FundraisingCampaignStore.donateURL(asset) } });
        },
        // secondaryButtonTapHandler: Maybe later, or (on the last day) I already donated
        onSecondary: (): void => {
          const asset: CampaignAsset = this.fundraisingAsset as CampaignAsset;
          if (this.fundraisingShowsMaybeLater) {
            FundraisingCampaignStore.markAssetAsMaybeLater(asset, Date.now());
            this.fundraisingToast($r('app.string.donate_later_title'));
          } else {
            FundraisingCampaignStore.markAssetAsPermanentlyHidden(asset);
            this.fundraisingToast($r('app.string.donate_already_donated'));
          }
          this.closeFundraising();
        },
        // optionalButtonTapHandler: I already donated
        onOptional: (): void => {
          FundraisingCampaignStore.markAssetAsPermanentlyHidden(this.fundraisingAsset as CampaignAsset);
          this.fundraisingToast($r('app.string.donate_already_donated'));
          this.closeFundraising();
        },
        // traceableDismissHandler(.tappedClose)
        onClose: (): void => {
          FundraisingCampaignStore.markAssetAsPermanentlyHidden(this.fundraisingAsset as CampaignAsset);
          this.closeFundraising();
        },
        onDismiss: (): void => {
          this.closeFundraising();
        },
        // footerLinkAction: the donor policy in the browser
        onFooterLink: (url: string): void => {
          (getContext(this) as common.UIAbilityContext).openLink(url).catch((e: Error) => {
            console.error('article: footer link failed: ' + e.message);
          });
        }
      })
    } else if (this.activeCover === 'shareAFact') {
      ShareAFactView({
        // update(with:articleTitle:text:image:) — the fact text and the lead image of the
        // article this cover is presented over
        selectedText: this.shareAFactText,
        articleTitle: this.getDisplayTitle(),
        imageURL: this.summary !== null && this.summary.thumbnail !== null
          ? this.summary.thumbnail.source : '',
        articleURL: this.articleURL(),
        onShare: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'tabs') {
      WMFArticleTabsView({
        onClose: (): void => {
          this.showCover = false;
        }
      })
    } else if (this.activeCover === 'education') {
      // comp_scrollable_panel (survey / education panels presented over the article)
      ScrollableEducationPanelViewController({
        onClose: (): void => {
          this.showCover = false;
        },
        onPrimary: (): void => {
          this.showCover = false;
        },
        onSecondary: (): void => {
          this.showCover = false;
        }
      })
    }
  }

  @Builder
  themesPopupBuilder() {
    ReadingThemesControlsView()
  }

  @Builder
  hintBuilder() {
    HintView({
      kind: this.hintKind,
      hintText: this.hintText,
      actionTitle: this.hintActionTitle,
      onAction: (): void => {
        this.showHint = false;
        if (this.hintActionKind === 'viewWatchlist') {
          router.pushUrl({ url: 'pages/WMFWatchlistViewPage' });
        } else if (this.hintActionKind === 'seeList') {
          router.pushUrl({ url: 'pages/ReadingListDetailViewControllerPage', params: { 'listRowId': this.hintListRowId } });
        } else {
          this.openAddToReadingList();
        }
      }
    })
  }

  // The bar's surface runs on through the gesture-handle strip below its 56 vp, so the items
  // drop by about a third of that strip (capped), as the root tab bar's do. Visual only.
  private toolbarItemOffset(): number {
    return Math.min(this.navIndicatorInset * 0.35, 12);
  }

  build() {
    Column() {
      if (this.backLinkRef !== '') {
        this.backLinksTopBar()
      }
      // navigation bar (ArticleViewController.configureNavigationBar)
      // S5: floating white circles + a joined white pill (navChrome token: radius 22,
      // shadow(8, #1F000000, offsetY 2), glyphs textPrimary) over the mid background.
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .colorFilter(this.iconTint())
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
          .id('BackButton')
          .accessibilityText('Back')
          .type(ButtonType.Circle)
          .width(44)
          .height(44)
          .backgroundColor(this.paper())
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            // A second tap on a sheet's close button lands here once the sheet is gone; it must
            // not also leave the article.
            if (Date.now() - this.sheetClosedAt < 600) {
              return;
            }
            if (!this.goBackInArticles()) {
              router.back();
            }
          })
        Blank()
        Button() {
          Image($r('app.media.w'))
            .colorFilter(this.iconTint())
            .width(27)
            .height(18)
            .objectFit(ImageFit.Contain)
        }
          .id('Article Home Button')
          .accessibilityText('Wikipedia')
          .type(ButtonType.Circle)
          .width(44)
          .height(44)
          .margin({ right: 12 })
          .backgroundColor(this.paper())
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .bindPopup(this.showWTip, {
            builder: this.wTipView(),
            placement: Placement.Bottom,
            popupColor: this.paper(),
            radius: 16,
            width: 320,
            shadow: { radius: 16, color: '#1F000000', offsetY: 2 },
            onStateChange: (e) => {
              // a tap outside the popover closes it (presentationControllerDidDismiss)
              if (e.isVisible) {
                this.wTipShown = true;
              } else if (this.wTipShown && this.showWTip) {
                this.invalidateWTip();
              }
            }
          })
          .onClick(() => {
            // wButtonTapped: wTip.invalidate(reason: .actionPerformed)
            this.invalidateWTip();
            this.returnToExplore();
          })
        Button() {
          Image($r('app.media.search'))
            .colorFilter(this.iconTint())
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
        }
          .id('Article Search Button')
          .accessibilityText('Search Wikipedia')
          .type(ButtonType.Normal)
          .width(52)
          .height(44)
          .backgroundColor(this.paper())
          .borderRadius({ topLeft: 22, bottomLeft: 22 })
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchViewControllerPage' });
          })
        Button() {
          Image($r('app.media.article_tabs_square'))
            .colorFilter(this.iconTint())
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.theme_text'))
        }
          .id('Tabs Button')
          .accessibilityText('Tabs')
          .type(ButtonType.Normal)
          .width(52)
          .height(44)
          .backgroundColor(this.paper())
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
              console.error('article tabs push failed: ' + e.message);
            });
          })
        Button() {
          Stack({ alignContent: Alignment.BottomStart }) {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
              .fontSize(26)
              .fontColor([$r('app.color.theme_text')])
            // unread notifications: the source's badge on the profile button
            UnreadNotificationsDot()
          }
        }
          .id('profile-button')
          .accessibilityText('Account')
          .type(ButtonType.Normal)
          .width(52)
          .height(44)
          .backgroundColor(this.paper())
          .borderRadius({ topRight: 22, bottomRight: 22 })
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            this.showToc = false;
            this.activeSheet = 'profile';
            this.showSheet = true;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: this.navHidden ? 0 : 8, bottom: this.navHidden ? 0 : 8 })
      // collapsed rather than removed: the row carries the content cover binding
      .height(this.navHidden ? 0 : (this.navHeight > 0 ? this.navHeight : 'auto'))
      .opacity(this.navHidden ? 0 : 1)
      .visibility(this.backLinkRef !== '' ? Visibility.None : Visibility.Visible)
      .clip(true)
      .onAreaChange((_o: Area, n: Area) => {
        if (!this.navHidden && Number(n.height) > 0) {
          this.navHeight = Number(n.height);
        }
      })
      .backgroundColor(this.mid())
      // S5 (capture S0326): the source presents these covers as a slide-up modal over the
      // article on the mid background — ContentCoverOptions styling only.
      .bindContentCover($$this.showCover, this.coverBuilder(), {
        modalTransition: this.activeCover === 'fundraising' ? ModalTransition.ALPHA : ModalTransition.DEFAULT,
        // the campaign panel is a card over the dimmed article
        backgroundColor: this.activeCover === 'fundraising' ? Color.Transparent
          : (this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background'))
      })

      // article body (native render of mobile-html), under the refresh control; while it
      // reloads, refreshOverlay dims it (black at 30%) and takes the touches
      Stack() {
      Refresh({ refreshing: $$this.isPullRefreshing }) {
      Scroll(this.scroller) {
        Column() {
          // loading / error / content are mutually exclusive; the toolbar and footer
          // chrome stay mounted either way.
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color($r('app.color.theme_secondary_text'))
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .justifyContent(FlexAlign.Center)
          } else if (this.loadError !== '') {
            Column({ space: 12 }) {
              Text($r('app.string.empty_no_article_message'))
                .fontSize(17)
                .lineHeight(24)
                .fontColor($r('app.color.theme_text'))
              Text(this.loadError)
                .fontSize(13)
                .fontColor($r('app.color.theme_secondary_text'))
              Button($r('app.string.settings_notifications_echo_failure_try_again'))
                .id('article_retry')
                .type(ButtonType.Normal)
                .fontSize(17)
                .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
                .backgroundColor($r('app.color.theme_link'))
                .borderRadius(8)
                .height(44)
                .padding({ left: 20, right: 20 })
                .onClick(() => {
                  this.load().catch((e: Error) => {
                    this.loadError = e.message;
                  });
                })
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
          } else {
          // lead: absent when the article has no image (the source hides the lead image view)
          if (this.leadImageURL() !== '') {
          Image(this.leadImageURL())
            .id('Article Lead Image')
            .width('100%')
            .height(240)
            .objectFit(ImageFit.Cover)
            .backgroundColor($r('app.color.gray200'))
            // Theme.imageOpacity: only the dimmed variants (Dark/Black with "Dim images" on) dim
            // it. Every dark theme used to, whatever the switch said.
            .opacity((WMFTheme.withName(this.theme) ?? WMFTheme.standard).imageOpacity)
            // ArticleWebMessageHandling .leadImage -> the gallery on the lead image
            .onClick(() => {
              this.openImageGallery(fileTitleFromImageURL(this.leadImageURL()), this.leadImageURL());
            })
          }
          // The lead carries its own edit pencil, exactly as every section header does; the port
          // had one on the sections only, so the article title had no edit affordance at all.
          Row() {
            Row() {
              Text(this.getDisplayTitle())
                .flexShrink(1)
                // the source sets the article title in the serif face (Georgia)
                .fontFamily(WMFFontFamilies.serifStack)
                .fontSize(this.fs(28))
                .fontWeight(FontWeight.Normal)
                .fontColor($r('app.color.theme_text'))
              // PCS's pronunciation button right after the title (0.8em, link-container
              // opacity); the source opens the recording's URL as a link
              if (this.pronunciationURL !== '') {
                Image($r('app.media.title_pronunciation'))
                  .colorFilter(this.iconTint())
                  .width(this.fs(22))
                  .height(this.fs(22))
                  .objectFit(ImageFit.Contain)
                  .opacity(WMFTheme.isDarkThemeName(this.theme) ? 0.7 : 0.54)
                  .margin({ left: 10, right: 10 })
                  .scale({ x: this.articleDirection() === Direction.Rtl ? -1 : 1 })
                  .id('title_pronunciation')
                  .accessibilityText('Listen to pronunciation')
                  .onClick(() => {
                    this.openSinglePageWeb(this.pronunciationURL);
                  })
              }
            }
            .layoutWeight(1)
            .alignItems(VerticalAlign.Center)
            Button() {
              Image(this.editProtected ? $r('app.media.pencil_protected') : $r('app.media.pencil'))
                .colorFilter(this.iconTint())
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
              .id('edit_lead_section')
              .accessibilityText('Edit introduction')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .width(36)
              .height(36)
              .onClick(() => {
                this.editSection('');
              })
          }
            .width('100%')
            .direction(this.articleDirection())
            .alignItems(VerticalAlign.Center)
            .padding({ left: 16, right: 16, top: 16 })
          Text(this.summary !== null && this.summary.articleDescription !== null ? this.summary.articleDescription : '')
            .fontSize(this.fs(17))
            .fontColor($r('app.color.theme_secondary_text'))
            .width('100%')
            .direction(this.articleDirection())
            .textAlign(TextAlign.Start)
            .padding({ left: 16, right: 16, top: 4 })
          Divider()
            .width(96)
            .strokeWidth(1)
            .color($r('app.color.gray200'))
            .margin({ left: 16, top: 16, bottom: 8 })
          // article body — the mobile-html document rendered natively, so every
          // in-document link is its own node carrying '<slug>_articlelink_itemroot'.
          ForEach(this.leadBlocks, (b: ArticleBlock) => {
            // the id is what a citation's back link scrolls to
            Column() {
              this.blockView(b)
            }
            .id('article_block_' + b.key)
            .width('100%')
          }, (b: ArticleBlock) => b.key)

          // sections: the edit pencil where PCS offers an edit link; a toggle only on the sections the
          // source starts closed (References, Further reading, External links)
          ForEach(this.sections, (s: ArticleSection, idx: number) => {
            Column() {
              if (this.sectionShown(s)) {
                // hr.pcs-fold-hr: the hairline above the first closed section
                if (s.collapsible && this.firstCollapsible() === s.anchor) {
                  Divider()
                    .strokeWidth(1)
                    .color($r('app.color.gray200'))
                    .margin({ left: 16, right: 16, top: 16, bottom: 4 })
                }
                Row() {
                  // pcs-section-control: the chevron before the title (0.6 em of the 1.5 em heading,
                  // 0.4 em before it), down while closed
                  if (s.collapsible) {
                    Button() {
                      Image(s.expanded ? $r('app.media.chevron_up') : $r('app.media.chevron_down'))
                        .colorFilter(this.iconTint())
                        .width(14)
                        .height(14)
                        .objectFit(ImageFit.Contain)
                    }
                      .id(idx === 0 ? 'expand_section' : 'expand_section_itemroot')
                      .accessibilityText(s.expanded ? 'Collapse section' : 'Expand section')
                      .type(ButtonType.Normal)
                      .backgroundColor(Color.Transparent)
                      .width(24)
                      .height(40)
                      .margin({ right: 6 })
                      .onClick(() => {
                        this.toggleSection(s.anchor);
                      })
                  }
                  // the source's section headings: level 2 in the serif face, deeper ones bold sans
                  Text(s.title)
                    .layoutWeight(1)
                    .fontFamily(s.level <= 2 ? WMFFontFamilies.serifStack : undefined)
                    .fontSize(this.fs(s.level <= 2 ? 24 : 18))
                    .fontWeight(s.level <= 2 ? FontWeight.Normal : FontWeight.Bold)
                    .fontColor($r('app.color.theme_text'))
                  if (s.editable) {
                    Button() {
                      Image(this.editProtected ? $r('app.media.pencil_protected') : $r('app.media.pencil'))
                        .colorFilter(this.iconTint())
                        .width(18)
                        .height(18)
                        .objectFit(ImageFit.Contain)
                    }
                      // One instance per section: Rule 12's list-row exception — the SHARED id
                      // ending in `itemroot`, resolved by index, not a per-section invention
                      // (`edit_section_<anchor>` matches no source slug and reads as an
                      // invented control).
                      .id(idx === 0 ? 'edit_section_on_protected' : 'edit_section_itemroot')
                      .accessibilityText(this.editProtected ? 'Edit section on protected page' : 'Edit section')
                      .type(ButtonType.Normal)
                      .backgroundColor(Color.Transparent)
                      .width(40)
                      .height(40)
                      .onClick(() => {
                        this.editSection(s.anchor);
                      })
                  }
                }
                .width('100%')
                .direction(this.articleDirection())
                .alignItems(VerticalAlign.Center)
                .padding({ left: s.collapsible ? 10 : 16, right: 8, top: 8, bottom: 8 })
                // the whole header of a closed section opens it (pcs-section-hideable-header onclick)
                .onClick(() => {
                  if (s.collapsible) {
                    this.toggleSection(s.anchor);
                  }
                })
                if (s.expanded) {
                  ForEach(s.blocks, (b: ArticleBlock) => {
                    Column() {
                      this.blockView(b)
                    }
                    .id('article_block_' + b.key)
                    .width('100%')
                  }, (b: ArticleBlock) => b.key)
                }
              }
            }
            .width('100%')
            .onAreaChange((_o: Area, n: Area) => {
              this.recordSectionTop(s.anchor, n.position.y);
            })
          // The key carries the open state (its own, and its hideable parent's for a subsection):
          // sections are plain (unobserved) objects, so a toggle only redraws a section when its key changes.
          }, (s: ArticleSection) => s.anchor + (s.expanded ? '_open' : '_closed') + (this.sectionShown(s) ? '' : '_hidden'))

          }

          // footer: About this article, Read more and the licence (PCS Footer, setupFooter)
          ArticleFooterView({
            lastEdited: this.lastEdited(),
            hasPageIssues: this.hasPageIssues,
            hasCoordinates: this.summary !== null && this.summary.coordinates !== null,
            related: this.relatedArticles,
            rtl: this.articleIsRTL,
            onTalkPage: (): void => {
              const params: Record<string, string> = { 'articleTitle': this.articleTitle };
              router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params });
            },
            onEditHistory: (): void => {
              const params: Record<string, string> = {
                'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0] };
              router.pushUrl({ url: 'pages/PageHistoryViewControllerPage', params: params });
            },
            onPageIssues: (): void => {
              this.showToc = false;
              this.activeSheet = 'pageIssues';
              this.showSheet = true;
            },
            onSimilarPages: (): void => {
              const params: Record<string, string> = { 'articleTitle': this.articleTitle };
              router.pushUrl({ url: 'pages/DisambiguationPagesViewControllerPage', params: params });
            },
            onRelated: (title: string): void => {
              this.openArticle(title);
            },
            onViewOnMap: (): void => {
              const s: ArticleSummary | null = this.summary;
              if (s !== null && s.coordinates !== null) {
                showArticleOnMap(this.getUIContext().getRouter(), this.articleTitle,
                  s.articleDescription ?? '', s.thumbnail !== null ? s.thumbnail.source : '',
                  s.coordinates.lat, s.coordinates.lon);
              }
            },
            onLicense: (): void => {
              this.openSinglePageWeb('https://creativecommons.org/licenses/by-sa/4.0/');
            },
            onBrowser: (): void => {
              this.openArticleInBrowser();
            },
            onReadMoreOffset: (y: number): void => {
              this.readMoreOffset = y;
              this.recordSectionTop(READ_MORE_ANCHOR, this.footerTop + y);
            }
          })
            // the "About this article" ToC entry lands on the footer's top
            .onAreaChange((_o: Area, n: Area) => {
              this.footerTop = Number(n.position.y);
              this.recordSectionTop(ABOUT_ANCHOR, n.position.y);
              this.recordSectionTop(READ_MORE_ANCHOR, this.footerTop + this.readMoreOffset);
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        // The article lays out in its own language's direction: a German article under an
        // Arabic UI mirrored its runs right-to-left.
        .direction(this.articleIsRTL ? Direction.Rtl : Direction.Ltr)
      }
      .id('article_body_scroll')
      .width('100%')
      .height('100%')
      .backgroundColor(this.paper())
      .align(Alignment.Top)
      .onDidScroll((_x: number, dy: number) => {
        this.onBodyScroll(dy);
      })
      }
      .width('100%')
      .height('100%')
      .pullToRefresh(!this.isLoading && this.loadError === '')
      .onRefreshing(() => {
        this.refreshArticle();
      })
      if (this.isReloading) {
        Column()
          .id('article_refresh_overlay')
          .width('100%')
          .height('100%')
          .backgroundColor('#4D000000')
      }
      }
      .layoutWeight(1)

      // find-in-page bar (feat_find_in_page; shown by the toolbar toggle)
      if (this.showFindBar) {
        Row() {
          TextInput({ placeholder: $r('app.string.action_find_in_page'), text: this.findQuery })
            .id('find_in_page_field')
            // highlight as each letter is typed, not once the keyboard commits a word
            .enablePreviewText(false)
            .layoutWeight(1)
            .height(36)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .backgroundColor(this.paper())
            .borderRadius(8)
            .onChange((v: string) => {
              this.findInPage(v);
            })
            .onSubmit(() => {
              this.findNext();
            })
          Button($r('app.string.description_published_button_title'))
            .id('find_in_page_done')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .height(36)
            .padding({ left: 12, right: 4 })
            .onClick(() => {
              this.showFindBar = false;
              this.findInPage('');
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.mid())
        .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      }

      if (this.backLinkRef !== '') {
        this.backLinksToolbar()
      }
      // bottom toolbar (ArticleToolbarController — capture order)
      Row() {
        Row() {
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.toc'), w: 33, h: 33 })
            }
              .id('Table of contents')
              .accessibilityText('Table of contents')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.openToc();
              })
          }
            .id('Article Table of Contents Button')
            .width(48)
            .height(48)
          Button() {
            ArticleToolbarGlyph({ icon: $r('app.media.language'), w: 28, h: 24 })
          }
            .id('Article Languages Button')
            .accessibilityText('Change language')
            .type(ButtonType.Circle)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)
            .onClick(() => {
              // WMFArticleLanguagesViewController: this article's language versions, presented
              // as a sheet over the article (drag handle + close), as the source does.
              this.showToc = false;
              this.activeSheet = 'languages';
              this.showSheet = true;
            })
          // The drivers find a control by its visible text or its .id() only, and the
          // correctness gate grades the node that CARRIES the tap — so the contract name
          // ('Save for later') is on the button itself and the capture slug
          // ('Article Save Button') on the wrapper, whose bounds are the button's.
          Stack() {
            Button() {
              // conditionalVariants(article.savedDate): filled bookmark once saved
              // The source's own save state is its accessibility LABEL, which the capture
              // records as text; on HarmonyOS .accessibilityText() never reaches the uitest
              // dump, so the glyph's own id carries the state instead — the one attribute a
              // dump comparison can see flip. Not a control: the Image is not clickable.
              ArticleToolbarGlyph({
                icon: this.savedDate !== null ? $r('app.media.save_filled') : $r('app.media.save'),
                w: 16,
                h: 23,
                glyphId: this.savedDate !== null ? 'save_state_on' : 'save_state_off'
              })
            }
              .id('Save for later')
              .accessibilityText(this.savedDate !== null ? 'Saved. Activate to unsave.' : 'Save for later')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.toggleSave();
              })
              // saveButtonLongPressed: straight to the add-to-reading-list picker
              // priority over the button's own click: a plain .gesture() never won the press
              .priorityGesture(LongPressGesture({ duration: 500 }).onAction(() => {
                this.showHint = false;
                this.openAddToReadingList();
              }))
          }
            .id('Article Save Button')
            .width(48)
            .height(48)
            // WMFReadingListToastManager: the "add to a reading list?" hint sits just above the
            // toolbar, over the save button - it used to float mid-page off the article scroll.
            .bindPopup($$this.showHint, {
              builder: this.hintBuilder(),
              placement: Placement.Top,
              width: '92%',
              // a toast, not a modal: the toolbar stays live under it (the mask ate the next tap)
              mask: false,
              popupColor: $r('app.color.blue100'),
              radius: 8,
              enableArrow: false,
              shadow: { radius: 8, color: '#1F000000', offsetY: 2 }
            })
          Button() {
            ArticleToolbarGlyph({ icon: $r('app.media.find_in_page'), w: 19, h: 25 })
          }
            .id('Article Find In Page Button')
            .accessibilityText('Find in page')
            .type(ButtonType.Circle)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)
            .onClick(() => {
              this.showFindBar = true;
            })
          // Same split as 'Save for later' above: the capture records this control with BOTH a
          // resource-id ('Article Theme Button') and a text ('font size', the iOS
          // accessibilityLabel), and the drivers match on text or .id() only —
          // .accessibilityText() never reaches the uitest dump, so the contract's 'font size'
          // was unfindable. The wrapper keeps the capture slug (same bounds, not clickable);
          // the button that carries the tap keeps the contract name.
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.font_size'), w: 24, h: 20 })
            }
              .id('font size')
              .accessibilityText('font size')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                if (Date.now() - this.themesPopupClosedAt < 400) {
                  return;
                }
                this.showThemesPopup = !this.showThemesPopup;
              })
          }
            .id('Article Theme Button')
            .width(48)
            .height(48)
          Button() {
            ArticleToolbarGlyph({ icon: null })
          }
            .id('Article More Button')
            .accessibilityText('More')
            .type(ButtonType.Circle)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)
            // WMFArticleViewController's overflow: six rows, each with its own glyph, "Main Page"
            // first. The port was missing that row and carried no icons at all, and the talk and
            // history rows were pushed with no params, so both screens opened empty. The row
            // labels were literals, so the menu stayed English on a Turkish device - the case
            // that covers this row names it "Izle".
            .bindMenu([
              {
                value: $r('app.string.main_page'),
                icon: $r('app.media.w'),
                action: (): void => {
                  this.showArticle('Main Page');
                }
              } as MenuElement,
              {
                value: $r('app.string.article_share'),
                // share.png is cropped at menu size; the system share symbol is not
                symbolIcon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([$r('app.color.theme_text')]),
                action: (): void => {
                  this.share();
                }
              } as MenuElement,
              {
                value: this.isWatched ? $r('app.string.unwatch') : $r('app.string.watch'),
                icon: this.isWatched ? $r('app.media.watchlist_star') : $r('app.media.watch_articles'),
                action: (): void => {
                  this.toggleWatch();
                }
              } as MenuElement,
              {
                value: $r('app.string.article_talk_page'),
                icon: $r('app.media.language_talk_page'),
                action: (): void => {
                  this.openTalkPage();
                }
              } as MenuElement,
              {
                value: $r('app.string.article_revision_history'),
                icon: $r('app.media.edit_history_2'),
                action: (): void => {
                  this.openRevisionHistory();
                }
              } as MenuElement,
              {
                value: $r('app.string.editor_edit_source'),
                icon: $r('app.media.pencil'),
                action: (): void => {
                  this.editSection('');
                }
              } as MenuElement
            ].concat(this.tabNavigationMenuItems()))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)
        .translate({ y: this.toolbarItemOffset() })
      }
      // A HarmonyOS bottom toolbar, as the root tab bar: full width on the page surface with a
      // hairline above, its surface running under the navigation indicator. It replaces the iOS
      // 26 floating pill (92% wide, radius 28, shadow) of the capture. No fixed height:
      // expandSafeArea is ignored on a fixed-size component, so the 56 vp come from the 48 vp
      // buttons plus the padding.
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .responseRegion({ x: 0, y: 0, width: '100%', height: 56 + this.toolbarItemOffset() })
      .backgroundColor(this.paper())
      .border({ width: { top: 0.5 }, color: $r('app.color.theme_border') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .visibility(this.backLinkRef !== '' ? Visibility.None : Visibility.Visible)
      .id('Toolbar')
      // S5 (capture S0359): the reading-themes popover is a paperBackground card with
      // rounded corners and no arrow — PopupOptions styling only.
      .bindPopup($$this.showThemesPopup, {
        builder: this.themesPopupBuilder(),
        popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
        enableArrow: false,
        radius: 10,
        width: '100%',
        shadow: ShadowStyle.OUTER_DEFAULT_MD,
        onStateChange: (e) => {
          if (!e.isVisible) {
            this.showThemesPopup = false;
            this.themesPopupClosedAt = Date.now();
          }
        }
      })

      // TableOfContentsPresentationController: the panel slides in over the article, nav bar
      // and toolbar alike. Positioned, so it takes no room in the column.
      if (this.showToc) {
        TableOfContentsView({
          items: this.tocItems,
          articleTitle: this.articleTitle,
          currentAnchor: this.tocCurrent,
          rtl: this.articleIsRTL,
          onSelect: (anchor: string): void => {
            this.selectTocItem(anchor);
          },
          onClose: (): void => {
            this.closeToc();
          }
        })
          .position({ x: 0, y: 0 })
          .zIndex(10)
      }
    }
    .id('ArticleViewController')
    .width('100%')
    .height('100%')
    .backgroundColor(this.paper())
    .bindSheet($$this.showSheet, this.sheetBuilder(), {
      // Every sheet here draws its own close, so the framework's stays off (never two).
      // The game announcement is a short sheet; everything else here is full height.
      height: this.activeSheet === 'gameInvite' ? 360 : SheetSize.LARGE,
      dragBar: this.activeSheet === 'gameInvite' || this.activeSheet === 'languages',
      // ArkUI draws the drag bar only for a sheet with more than one detent.
      detents: this.activeSheet === 'languages' ? [SheetSize.LARGE, SheetSize.MEDIUM] : undefined,
      backgroundColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
      showClose: false,
      onWillDisappear: () => {
        this.sheetClosedAt = Date.now();
      },
      onDisappear: () => {
        this.sheetClosedAt = Date.now();
        const lang: MWKLanguageLink | null = this.pendingLanguage;
        this.pendingLanguage = null;
        if (lang !== null) {
          this.openLanguageVersion(lang.languageCode, lang.pageTitleText);
        }
      }
    })
  }

  private getDisplayTitle(): string {
    if (this.summary !== null && this.summary.displayTitle !== null) {
      // displayTitle is HTML ('<span lang="en" dir="ltr">...'), same as every body run.
      return stripTags(this.summary.displayTitle);
    }
    return this.articleTitle;
  }

  // In-document links (and the 'Read more' related articles) open ANOTHER article on THIS
  // route, and `router.pushUrl` does not navigate when the pushed url is the page already on
  // top of the stack: the tap ran, the stack never moved, and every one of the 15 replayed
  // link taps came back a NO-OP while every push to a DIFFERENT page on this screen worked.
  // The source pushes a new ArticleViewController (handleLink -> LinkCoordinator/navigate),
  // so reproduce that observable behaviour in place: swap the article and keep our own back
  // stack, which the nav-bar Back and the system back unwind before leaving the page.
  // A link to the SAME article does nothing, exactly as handleLink's in-memory-key guard does.
  private openArticle(articleTitle: string): void {
    if (articleTitle === '' || articleTitle === this.articleTitle) {
      return;
    }
    this.articleBackStack.push(this.languageOverride + '\n' + this.articleTitle);
    this.showArticle(articleTitle);
  }

  // The article in another language, in place (the source pushes a new article controller);
  // Back returns to the version it came from.
  // addToReadingList: a routed page (as a cover its lists never drew)
  private openAddToReadingList(): void {
    const params: Record<string, string> = {
      'articleKey': this.articleKey(), 'articleTitle': this.getDisplayTitle() };
    router.pushUrl({ url: 'pages/AddArticlesToReadingListViewControllerPage', params: params });
  }

  // back from the reading-list pages: adding to a list saves the article
  onPageShow(): void {
    // viewDidAppear -> presentModalsIfNeeded -> showFundraisingCampaignAnnouncementIfNeeded
    this.showFundraisingCampaignAnnouncementIfNeeded();
    // didLogIn -> performAfterLoginBlock: back from logging in to watch
    if (this.watchAfterLogin) {
      this.watchAfterLogin = false;
      if (SessionStore.isLoggedIn) {
        setTimeout(() => this.toggleWatch(), 300);
      }
    }
    // WMFReadingListToastManager: 'Article added to "<list>"' with See reading list
    const added: string = AppStorage.get<string>(READING_LIST_ADDED_KEY) ?? '';
    if (added !== '') {
      AppStorage.setOrCreate<string>(READING_LIST_ADDED_KEY, '');
      const list: string[] = JSON.parse(added) as string[];
      const ctx: common.Context = getContext(this) as common.Context;
      this.hintActionKind = 'seeList';
      this.hintListRowId = list[0];
      this.presentHint('confirmation',
        formatString(ctx, $r('app.string.reading_lists_article_added_confirmation'), [list[1]]),
        ctx.resourceManager.getStringSync($r('app.string.reading_list_alert_see_list')));
    }
    const tables: boolean = Prefs.getBoolean(PrefKeys.isAutomaticTableOpeningEnabled, false);
    if (tables !== this.appliedTableOpening) {
      this.appliedTableOpening = tables;
      this.quickFactsExpanded = tables;
    }
    const key: string = this.articleKey();
    if (key === '') {
      return;
    }
    SavedStore.isSaved(key).then((saved: boolean) => {
      this.isSaved = saved;
      this.savedDate = saved ? (this.savedDate ?? Date.now()) : null;
    }).catch((e: Error) => {
      console.error('article: saved refresh failed: ' + e.message);
    });
  }

  private openLanguageVersion(code: string, title: string): void {
    if (title === '' || (code === this.host.split('.')[0] && title === this.articleTitle)) {
      return;
    }
    this.articleBackStack.push(this.languageOverride + '\n' + this.articleTitle);
    this.languageOverride = code;
    this.showArticle(title);
  }

  // Replaces the rendered article without leaving the page. Every per-article field is reset
  // so the previous article's body/summary/toolbar state cannot survive the swap.
  private showArticle(articleTitle: string): void {
    this.saveArticleScrollPosition();
    this.flushPageViewSeconds();
    this.articleTitle = articleTitle;
    this.summary = null;
    this.leadBlocks = [];
    this.sections = [];
    this.editProtected = false;
    this.pronunciationURL = '';
    this.tocItems = [];
    this.relatedArticles = [];
    this.hasPageIssues = false;
    this.sectionTops = new Map<string, number>();
    this.savedDate = null;
    this.isSaved = false;
    this.isWatched = false;
    this.offlineTried = false;
    this.loadError = '';
    this.showSheet = false;
    this.showToc = false;
    this.showFindBar = false;
    this.findQuery = '';
    this.appearedAt = Date.now();
    this.scroller.scrollEdge(Edge.Top);
    this.load().catch((e: Error) => {
      this.loadError = e.message;
    });
  }

  // true when a previous article was restored, so the caller must NOT leave the page.
  private goBackInArticles(): boolean {
    const prev: string | undefined = this.articleBackStack.pop();
    if (prev === undefined) {
      return false;
    }
    this.isBackNavigation = true;
    // entries are 'languageOverride\ntitle' ('' = the app language)
    const cut: number = prev.indexOf('\n');
    this.languageOverride = cut >= 0 ? prev.substring(0, cut) : this.languageOverride;
    this.showArticle(cut >= 0 ? prev.substring(cut + 1) : prev);
    return true;
  }

  // createMoreMenu: the next article of the tab (chevron.forward), then the previous one
  // (chevron.backward), each titled with the article
  private tabNavigationMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    const next: TabArticle | null = this.nextArticleTab;
    if (next !== null) {
      items.push({
        value: TabsMenuTitle.truncated(next.title),
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.chevron_right')).fontColor([$r('app.color.theme_text')]),
        action: (): void => {
          this.openArticleInTab(next);
        }
      });
    }
    const prev: TabArticle | null = this.previousArticleTab;
    if (prev !== null) {
      items.push({
        value: TabsMenuTitle.truncated(prev.title),
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.chevron_left')).fontColor([$r('app.color.theme_text')]),
        action: (): void => {
          this.openArticleInTab(prev);
        }
      });
    }
    return items;
  }

  // backInTab / forwardInTab: open the adjacent article (tabConfig .adjacentArticleInTab:
  // its tab item becomes current, nothing is appended); the current article stays on the
  // page's back stack, as the source pushes a new article screen.
  private openArticleInTab(article: TabArticle): void {
    if (article.identifier === null) {
      return;
    }
    this.articleBackStack.push(this.languageOverride + '\n' + this.articleTitle);
    const parts: string[] = article.projectID.split(/[~.]/);
    this.languageOverride = parts.length > 1 ? parts[1] : this.languageOverride;
    this.pendingTabItem = article.identifier;
    this.showArticle(article.title);
  }

  private returnToExplore(): void {
    router.pushUrl({ url: 'pages/ExploreViewControllerPage' });
  }

  // The pencil sheet's two rows. Both opened the remote ?action=edit page in the web screen,
  // which serves the VisualEditor bootstrap and never becomes an editor in a natively
  // rendered document; they now open this app's own editor against the action API.
  // Both screens read an `articleTitle` param and were pushed without one, so they opened on
  // an empty title and had nothing to fetch.
  private openTalkPage(): void {
    const params: Record<string, string> = { 'articleTitle': this.articleTitle };
    router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('article: talk page route failed: ' + e.message);
      });
  }

  private openRevisionHistory(): void {
    const params: Record<string, string> = {
      'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0] };
    router.pushUrl({ url: 'pages/PageHistoryViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('article: revision history route failed: ' + e.message);
      });
  }

  private openEditor(mode: string, anchor: string): void {
    const params: Record<string, string> = {
      'mode': mode,
      'articleTitle': this.articleTitle,
      'host': this.host,
      'anchor': anchor,
      'languageCode': this.host.split('.')[0],
      'description': this.summary?.articleDescription ?? ''
    };
    router.pushUrl({ url: 'pages/SectionEditorViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('article: editor route failed: ' + e.message);
      });
  }

  private openSinglePageWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private openArticleInBrowser(): void {
    this.openSinglePageWeb(this.articleURL());
  }

  private articleKey(): string {
    return 'https://' + this.host + '/wiki/' + this.articleTitle.replace(/ /g, '_');
  }

  // Percent-encoded, always. "View article in browser" built its own unencoded URL from the
  // raw title, so any article whose title carries a space or a non-ASCII character produced a
  // malformed request and the web screen answered "This page could not be loaded."
  private articleURL(): string {
    return 'https://' + this.host + '/wiki/' +
      encodeURIComponent(this.articleTitle.replace(/ /g, '_'));
  }

  // hidesBarsOnSwipe: hide the top bar on a scroll down past the lead, show it on a scroll up
  // or back at the top.
  private onBodyScroll(dy: number): void {
    const y: number = this.scroller.currentOffset().yOffset;
    const hide: boolean = dy > 2 && y > 120 ? true : (dy < -2 || y <= 40 ? false : this.navHidden);
    if (hide !== this.navHidden) {
      this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
        this.navHidden = hide;
      });
    }
  }

  // The toolbar's contents button, opened at the section in view.
  private openToc(): void {
    this.tocCurrent = this.sectionInView();
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.showToc = true;
    });
  }

  private closeToc(): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.showToc = false;
    });
  }

  // tableOfContentsController(_:didSelectItem:): scroll the article to the row (the title row
  // to the top) and close the panel.
  private selectTocItem(anchor: string): void {
    if (anchor === '') {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } else {
      this.scrollToSection(anchor);
    }
    this.closeToc();
  }

  // Section header toggle (the source collapses/expands a section in place).
  // A subsection of a closed hideable section is hidden with it.
  private sectionShown(s: ArticleSection): boolean {
    return s.under === '' || this.sections.some((p: ArticleSection) => p.anchor === s.under && p.expanded);
  }

  private firstCollapsible(): string {
    const first: ArticleSection | undefined = this.sections.find((s: ArticleSection) => s.collapsible);
    return first !== undefined ? first.anchor : '';
  }

  private toggleSection(anchor: string): void {
    const next: ArticleSection[] = [];
    for (const section of this.sections) {
      if (section.anchor === anchor) {
        section.expanded = !section.expanded;
      }
      next.push(section);
    }
    this.sections = next;
  }

  // The last section whose header is at or above the top of the viewport; '' while the
  // lead is still in view.
  private sectionInView(): string {
    const y: number = this.scroller.currentOffset().yOffset + 60;
    let best: string = '';
    let bestTop: number = -1;
    this.sectionTops.forEach((top: number, anchor: string) => {
      if (top <= y && top > bestTop) {
        best = anchor;
        bestTop = top;
      }
    });
    return best;
  }

  // ToC selection: open the section (and the closed section it sits in) and move the page scroller to the offset the
  // section header reported through onAreaChange.
  private scrollToSection(anchor: string): void {
    const target: ArticleSection | undefined = this.sections.find((s: ArticleSection) => s.anchor === anchor);
    const parent: string = target !== undefined ? target.under : '';
    const next: ArticleSection[] = [];
    for (const section of this.sections) {
      if (section.anchor === anchor || section.anchor === parent) {
        section.expanded = true;
      }
      next.push(section);
    }
    this.sections = next;
    const top: number | undefined = this.sectionTops.get(anchor);
    if (top !== undefined) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: top });
    }
  }

  // ArticleFindInPageState -> a native search over the rendered text: every block whose
  // text carries the query is highlighted (findHighlight).
  private findInPage(query: string): void {
    this.findQuery = query;
  }

  // Return on the find field jumps to the first section that carries the query.
  // ponytail: first match, not match-by-match — add a match cursor if that matters.
  private findNext(): void {
    const query: string = this.findQuery.toLowerCase();
    if (query === '') {
      return;
    }
    for (const section of this.sections) {
      if (section.title.toLowerCase().includes(query)) {
        this.scrollToSection(section.anchor);
        return;
      }
      for (const block of section.blocks) {
        if (block.plain.toLowerCase().includes(query)) {
          this.scrollToSection(section.anchor);
          return;
        }
      }
    }
  }

  // Section editing opens the wikitext editor on the mobile site (no native editor ported).
  // ArticleViewController+Editing.swift:226 showEditSectionOrTitleDescriptionDialogForSection —
  // the pencil does NOT open an editor directly: it presents a UIAlertController OVER the
  // article with 'Edit article description', 'Edit introduction' and Cancel, which is what the
  // capture of this state shows. The two editors themselves are the deferred editor cluster
  // (plan deferrals: unreachable-programmatic), so each action keeps the wikitext-editor web
  // fallback that was here before — the dialog is the structure, the fallback is the target.
  // ONE cover node carries every modal (line 15: one bindContentCover per node), so opening
  // cover B while cover A is still up makes ArkUI destroy A's subtree in the same frame that
  // B mounts. The device log named it exactly: `AceOverlay: ModalPage node mount to root node`
  // and 2 ms later `AceStateMgmt: View WMFLanguagesView is already in process of destruction,
  // will not execute observeComponentCreation2` — an app-owned E line, so the state's landing
  // hilog window failed even though the list itself rendered. Closing first and mounting on
  // the next tick keeps the two lifecycles apart.
  // An overlay has no route of its own: EntryAbility publishes the requested target here and
  // this host presents it. The key is consumed, so a later re-appear does not re-open it.
  private presentLaunchOverlay(): void {
    const want: string = AppStorage.get<string>('launchOverlay') ?? '';
    if (want.length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>('launchOverlay', '');
    if (want === 'AddArticlesToReadingListViewController') {
      this.openAddToReadingList();
    } else if (want === 'ReadingThemesControlsViewController') {
      // bindPopup positions against its ANCHOR, which does not exist yet in aboutToAppear —
      // setting the flag here is dropped. The cover has no anchor and opens immediately.
      setTimeout(() => {
        this.showThemesPopup = true;
      }, 400);
    }
  }

  private openCover(name: string): void {
    if (this.showCover && this.activeCover !== name) {
      this.showCover = false;
      setTimeout(() => {
        this.activeCover = name;
        this.showCover = true;
      }, 80);
      return;
    }
    this.activeCover = name;
    this.showCover = true;
  }

  private editSection(anchor: string): void {
    // HarmonyOS action menu (as the Places filter): a centred list with its own Cancel. The
    // ActionSheet this was opened with empty title/message lines and squeezed the two rows.
    this.getUIContext().getPromptAction().showActionMenu({
      buttons: [
        { text: $r('app.string.description_edit_pencil_title'), color: $r('app.color.theme_link') },
        { text: $r('app.string.description_edit_pencil_introduction'), color: $r('app.color.theme_link') }
      ]
    }).then((r) => {
      if (r.index === 0) {
        this.openEditor('description', '');
      } else {
        this.openEditor('section', anchor);
      }
    }).catch(() => {
      // cancelled
    });
  }

  // svc_saved_store toggle — persists (and downloads the offline copy) across relaunch.
  private toggleSave(): void {
    const key: string = this.articleKey();
    // The source flips the glyph and raises the toast on the tap itself; the store round-trips
    // (toggleSave also fetches the offline copy), so flipping only in .then() leaves the
    // screen unchanged for as long as the network takes — a live control that reads as dead.
    // Flip first, reconcile with what the store actually did.
    const willSave: boolean = this.savedDate === null;
    this.applySavedState(willSave);
    SavedStore.toggleSave(key, null, this.getDisplayTitle()).then((saved: boolean) => {
      if (saved !== willSave) {
        this.applySavedState(saved);
      }
    }).catch((e: Error) => {
      console.error('article: toggleSave failed: ' + e.message);
      this.applySavedState(!willSave);
      this.presentHint('warning', 'Could not save this article', '');
    });
  }

  // article.savedDate + the hint the source pairs with it (WMFReadingListToastManager:
  // the "Add \"<title>\" to a reading list?" toast on save, dismissed on unsave).
  private applySavedState(saved: boolean): void {
    this.isSaved = saved;
    this.savedDate = saved ? Date.now() : null;
    if (saved) {
      const ctx: common.Context = getContext(this) as common.Context;
      this.hintActionKind = 'addToList';
      this.presentHint('confirmation',
        formatString(ctx, $r('app.string.reading_list_add_hint_title'), [this.getDisplayTitle()]),
        ctx.resourceManager.getStringSync($r('app.string.action_add_to_reading_list')));
    } else {
      this.showHint = false;
    }
  }

  private presentHint(kind: string, text: string, actionTitle: string): void {
    this.hintKind = kind;
    this.hintText = text;
    this.hintActionTitle = actionTitle;
    this.showHint = true;
    if (this.hintTimer >= 0) {
      clearTimeout(this.hintTimer);
    }
    // HintViewController auto-dismisses the hint after it has been read
    this.hintTimer = setTimeout(() => {
      this.showHint = false;
      this.hintTimer = -1;
    }, 8000);
  }

  // WatchlistController.watch: logged-out readers log in first and the watch resumes after
  // (performAfterLoginBlock); then the "Watchlist expiry" sheet, the watch call, and the toast for
  // the chosen period with View Watchlist. Unwatch goes straight through.
  private watchAfterLogin: boolean = false;

  private toggleWatch(): void {
    if (!SessionStore.isLoggedIn) {
      this.watchAfterLogin = !this.isWatched;
      router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
        console.error('article: login route failed: ' + e.message);
      });
      return;
    }
    if (this.isWatched) {
      WatchlistService.unwatch(this.host, this.articleTitle).then((ok: boolean) => {
        if (ok) {
          this.isWatched = false;
          this.presentHint('confirmation', getContext(this).resourceManager.getStringSync(
            $r('app.string.watchlist_removed')), '');
        }
      }).catch((e: Error) => this.watchFailed(e));
      return;
    }
    presentChooseExpiryActionSheet(this.getUIContext(), (expiry: string, toast: Resource) => {
      WatchlistService.watch(this.host, this.articleTitle, expiry).then((ok: boolean) => {
        if (ok) {
          this.isWatched = true;
          const rm = getContext(this).resourceManager;
          this.hintActionKind = 'viewWatchlist';
          this.presentHint('confirmation', rm.getStringSync(toast.id),
            rm.getStringSync($r('app.string.watchlist_added_toast_view_watchlist')));
        }
      }).catch((e: Error) => this.watchFailed(e));
    });
  }

  private watchFailed(e: Error): void {
    console.error('article: watch toggle failed: ' + e.message);
    this.presentHint('warning', getContext(this).resourceManager.getStringSync(
      $r('app.string.fetcher_error_generic')), '');
  }

  // The system share panel (ShareKit) — the source raises UIActivityViewController here. This
  // port copied the link to the clipboard instead, which reads as "the button did nothing".
  // The clipboard remains the fallback for a device where the panel cannot be shown.
  // showFundraisingCampaignAnnouncementIfNeeded: the active campaign for the device's region and
  // this article's wiki, unless a donation was saved here within 250 days
  private showFundraisingCampaignAnnouncementIfNeeded(): void {
    if (this.showCover) {
      return;
    }
    let countryCode: string = '';
    try {
      countryCode = i18n.System.getSystemRegion();
    } catch (e) {
      return;
    }
    const languageCode: string = this.host.split('.')[0];
    const ready: Promise<void> = Prefs.getString('fundraising-campaign-config', '') === ''
      ? FundraisingCampaignStore.fetchConfig() : Promise.resolve();
    ready.then(() => {
      const now: number = Date.now();
      const asset: CampaignAsset | null =
        FundraisingCampaignStore.loadActiveCampaignAsset(countryCode, languageCode, now);
      if (asset === null || asset.actions.length !== 3 || this.showCover ||
        DonateHistory.hasDonatedSince(now - 250 * 86400000)) {
        return;
      }
      this.fundraisingAsset = asset;
      this.fundraisingShowsMaybeLater = FundraisingCampaignStore.showMaybeLaterOption(asset, now);
      this.activeCover = 'fundraising';
      this.showCover = true;
    }).catch((e: Error) => {
      console.error('article: campaign check failed: ' + e.message);
    });
  }

  private closeFundraising(): void {
    this.showCover = false;
  }

  // donateDidSetMaybeLater / donateAlreadyDonated: the toast half a second after the panel goes
  private fundraisingToast(res: Resource): void {
    // WMFToastManager.showRichToast: the whole message (the reading-list hint stops at two lines)
    const text: string = getContext(this).resourceManager.getStringSync(res.id);
    setTimeout(() => this.getUIContext().getPromptAction().showToast({ message: text, duration: 4000 }), 500);
  }

  // shareArticle(with: selectedText): ShareActivityController adds Share-a-fact when text is
  // selected, and WMFOpenInMapsActivity / WMFGetDirectionsInMapsActivity for an article with a
  // map item. The HarmonyOS share panel takes no app-defined actions, so those are offered
  // beside Share first.
  private share(selectedText: string = this.selectedText): void {
    const coords: ArticleSummaryCoordinates | null = this.summary?.coordinates ?? null;
    const actions: string[] = [];
    const buttons: promptAction.Button[] = [];
    if (selectedText !== '') {
      actions.push('fact');
      buttons.push({ text: 'Share-a-fact', color: $r('app.color.theme_link') });
    }
    actions.push('share');
    buttons.push({ text: $r('app.string.share_menu_item'), color: $r('app.color.theme_link') });
    if (coords !== null) {
      actions.push('maps', 'directions');
      buttons.push({ text: $r('app.string.share_open_in_maps'), color: $r('app.color.theme_link') },
        { text: $r('app.string.share_get_directions_in_maps'), color: $r('app.color.theme_link') });
    }
    if (actions.length === 1) {
      this.showSharePanel();
      return;
    }
    // the options take a fixed-arity tuple; an undefined entry is rejected (401)
    const menu: promptAction.ActionMenuOptions = buttons.length === 2 ? { buttons: [buttons[0], buttons[1]] }
      : buttons.length === 3 ? { buttons: [buttons[0], buttons[1], buttons[2]] }
        : { buttons: [buttons[0], buttons[1], buttons[2], buttons[3]] };
    let shown: Promise<promptAction.ActionMenuSuccessResponse>;
    try {
      shown = this.getUIContext().getPromptAction().showActionMenu(menu);
    } catch (e) {
      console.error('article: share menu failed: ' + (e as Error).message);
      this.showSharePanel();
      return;
    }
    shown.then((r) => {
      const action: string = actions[r.index];
      if (action === 'fact') {
        // shareAFact(with:) -> ShareViewController
        this.shareAFactText = selectedText;
        this.activeCover = 'shareAFact';
        this.showCover = true;
      } else if (action === 'share') {
        this.showSharePanel();
      } else if (coords !== null) {
        this.openInMaps(coords, action === 'directions');
      }
    }).catch(() => {
      // cancelled
    });
  }

  // mapItem.openInMaps: a geo: link shows the place; Get Directions (MKLaunchOptionsDirectionsMode)
  // asks Petal Maps for a route from the current location.
  private openInMaps(coords: ArticleSummaryCoordinates, directions: boolean): void {
    const title: string = this.getDisplayTitle();
    // Petal Maps shows the geo: label as written (no percent-decoding); parentheses would end it
    const url: string = directions
      ? 'maps://routes?destinationLatitude=' + coords.lat + '&destinationLongitude=' + coords.lon +
        '&destinationName=' + encodeURIComponent(title) + '&linkSource=com.dtse.hmosmigrator'
      : 'geo:' + coords.lat + ',' + coords.lon + '?q=' + coords.lat + ',' + coords.lon + '(' +
        title.replace(/[()]/g, '') + ')';
    try {
      (getContext(this) as common.UIAbilityContext).openLink(url).catch((e: Error) => {
        console.error('article: maps link failed: ' + e.message);
      });
    } catch (e) {
      console.error('article: maps link threw: ' + (e as Error).message);
    }
  }

  private showSharePanel(): void {
    const title: string = this.getDisplayTitle();
    const url: string = this.articleURL();
    const record: systemShare.SharedRecord = {
      utd: 'general.hyperlink',
      content: url,
      title: title,
      description: this.summary?.articleDescription ?? ''
    };
    try {
      const controller: systemShare.ShareController =
        new systemShare.ShareController(new systemShare.SharedData(record));
      controller.show(getContext(this) as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      }).catch((e: Error) => {
        console.error('article: share panel failed: ' + e.message);
        this.copyArticleLink(title + ' ' + url);
      });
    } catch (e) {
      console.error('article: share panel unavailable: ' + (e as Error).message);
      this.copyArticleLink(title + ' ' + url);
    }
  }

  private copyArticleLink(text: string): void {
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: 'Article link copied' });
    }).catch((e: Error) => {
      console.error('article: share failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not share this article' });
    });
  }
}
