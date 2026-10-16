// Native HTML -> block model used by the screens that render a remote MediaWiki page
// WITHOUT an ArkWeb `Web`: the on-device drivers (replay_on_harmonyos.py,
// evidence_collect.py, screen_correctness.py) locate a control only by its visible text or
// its .id() and can see NOTHING inside a Web — so with a Web body every in-document link
// tap is unreplayable and a required contract control reads as absent. ArkWeb also fails to
// init on the verify device.
// Pure logic, so .ts (Rule 9); the pages import it.

// One inline run of a block. A link is its OWN run so it can be rendered as its own
// tappable node carrying the slug the capture recorded (graph.json edges).
export class WebSegment {
  text: string = '';
  kind: string = 'text';       // text | link
  target: string = '';         // absolute URL
  slug: string = '';
}

// One paragraph / list item / heading of the document.
export class WebBlock {
  kind: string = 'p';          // h1 | h2 | h3 | h4 | p | li
  key: string = '';
  plain: string = '';
  segments: WebSegment[] = [];
}

export function decodeEntities(text: string): string {
  if (text.indexOf('&') < 0) {
    return text;
  }
  let out: string = text.replace(/&nbsp;/g, ' ')
    .replace(/&ndash;/g, '–')
    .replace(/&mdash;/g, '—')
    .replace(/&hellip;/g, '…')
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

// Parsoid puts HTML inside attribute values (data-mw carries a template's rendered label,
// e.g. "<span>Anhören</span>"). Every scan here matches tags with [^>]*, which stopped at the
// first '>' inside such a value and leaked the rest of the attribute into the text as raw
// JSON. Escaping the brackets inside quoted values once keeps all of those scans correct.
export function escapeAttributeBrackets(html: string): string {
  return html.replace(/<[a-zA-Z](?:"[^"]*"|'[^']*'|[^'">])*>/g, (tag: string): string =>
    tag.replace(/"[^"]*"|'[^']*'/g, (value: string): string =>
      value.replace(/</g, '&lt;').replace(/>/g, '&gt;')));
}

export function stripTags(html: string): string {
  return decodeEntities(html.replace(/<[^>]*>/g, '')).replace(/\s+/g, ' ').trim();
}

// The slug the capture recorded for a control: its label lowercased, split on anything
// non-alphanumeric, first four words joined by '_' (graph.json:
// "Legal & safety contacts" -> legal_safety_contacts,
// "Last edited 1 month ago by Pppery" -> last_edited_1_month).
// Returns '' for a label with no ASCII alphanumerics at all (日本語, العربية, čeština);
// the callers fall back to the raw label, which is the slug the capture recorded for those.
export function slugify(text: string): string {
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

// Rule 12: a control's id is the SOURCE element's slug. For a label slugify() cannot
// transliterate the capture recorded the raw label itself (graph.json S0064.outgoing:
// 日本語, 中文, سنڌي, العربية, עברית, čeština), so that is the id those links must carry —
// dropping them to plain text would make 6 of this screen's states unreplayable.
function slugFor(label: string): string {
  const ascii: string = slugify(label);
  return ascii !== '' ? ascii : label.trim();
}

export function attrOf(attrs: string, name: string): string {
  const m: RegExpMatchArray | null = attrs.match(new RegExp('\\b' + name + '\\s*=\\s*"([^"]*)"'));
  return m !== null ? m[1] : '';
}

// href -> absolute URL against the page currently shown. The mobile skin emits
// '/wiki/Foo', '//en.wikipedia.org/...', absolute 'https://...' and bare '#anchor'.
export function absolutize(href: string, base: string): string {
  if (href.startsWith('http://') || href.startsWith('https://')) {
    return href;
  }
  if (href.startsWith('//')) {
    return 'https:' + href;
  }
  const origin: RegExpMatchArray | null = base.match(/^(https?:\/\/[^\/]+)/);
  const root: string = origin !== null ? origin[1] : 'https://en.m.wikipedia.org';
  if (href.startsWith('/')) {
    return root + href;
  }
  const cut: number = base.lastIndexOf('/');
  return (cut > 8 ? base.substring(0, cut) : base) + '/' + href;
}

// Splits one block's inner HTML into plain runs and link runs. `seen` keeps the ids unique
// within the page — the driver keeps the FIRST match in tree order, which is the one the
// capture recorded.
export function parseInline(html: string, base: string, seen: Map<string, number>): WebSegment[] {
  const segs: WebSegment[] = [];
  const rx: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let last: number = 0;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    const before: string = stripTags(html.substring(last, m.index));
    if (before !== '') {
      const t = new WebSegment();
      t.text = before + ' ';
      segs.push(t);
    }
    const attrs: string = m[1];
    const strippedLabel: string = stripTags(m[2]);
    const label: string = strippedLabel !== '' ? strippedLabel : attrOf(m[2], 'alt');
    const href: string = attrOf(attrs, 'href');
    if (label !== '') {
      const seg = new WebSegment();
      seg.text = label + ' ';
      // A bare '#anchor' navigates nowhere — render it as plain text rather than a
      // control whose tap cannot change the screen.
      const slug: string = slugFor(label);
      if (slug !== '' && href !== '' && !href.startsWith('#') && !href.startsWith('javascript')) {
        seg.kind = 'link';
        seg.target = absolutize(href, base);
        const used: number | undefined = seen.get(slug);
        const n: number = used === undefined ? 0 : used;
        seen.set(slug, n + 1);
        seg.slug = n === 0 ? slug : slug + '_' + n;
      }
      segs.push(seg);
    }
    last = m.index + m[0].length;
    m = rx.exec(html);
  }
  const tail: string = stripTags(html.substring(last));
  if (tail !== '') {
    const t = new WebSegment();
    t.text = tail;
    segs.push(t);
  }
  return segs;
}

// Removes one element (and everything nested inside it) by its `id` attribute, tracking
// open/close depth by TAG NAME rather than a flat regex — the container is a <div> nested
// several levels deep inside other <div>s, so a non-nesting-aware cut would either stop at
// the first inner </div> or eat past the real end.
export function stripElementById(html: string, id: string): string {
  const open: RegExpMatchArray | null =
    html.match(new RegExp('<([a-zA-Z0-9]+)\\b[^>]*\\bid\\s*=\\s*"' + id + '"[^>]*>'));
  if (open === null || open.index === undefined) {
    return html;
  }
  const tag: string = open[1].toLowerCase();
  const start: number = open.index;
  const rx: RegExp = new RegExp('<\\/?' + tag + '\\b[^>]*>', 'gi');
  rx.lastIndex = start + open[0].length;
  let depth: number = 1;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    if (m[0].startsWith('</')) {
      depth--;
      if (depth === 0) {
        return html.substring(0, start) + html.substring(m.index + m[0].length);
      }
    } else {
      depth++;
    }
    m = rx.exec(html);
  }
  return html; // unbalanced — leave untouched rather than risk cutting real content
}

// The WHOLE document is scanned, not just the content body: the footer links
// (Desktop view, Terms of Use, Privacy policy, Statistics, Code of Conduct) live in the
// skin footer's <li><a> entries and the capture tapped them.
// ponytail: no block cap — every block is laid out eagerly at render. Add one if a very
// long page makes the parse itself slow.
export function parsePage(html: string, base: string): WebBlock[] {
  let body: string = escapeAttributeBrackets(
    html.replace(/<(script|style)\b[\s\S]*?<\/(?:script|style)>/gi, ''));
  // Minerva's collapsed off-canvas main menu (Home/Random/Nearby/Settings/Create account/
  // Log in, in <div id="mw-mf-page-left"> / nav#p-navigation) sits behind the hamburger —
  // the capture never shows it, so rendering it flat is invented UI. page-actions and the
  // footer (where "Desktop view" lives) are NOT touched — the capture does show those.
  body = stripElementById(body, 'mw-mf-page-left');
  const blocks: WebBlock[] = [];
  const seen: Map<string, number> = new Map<string, number>();
  const rx: RegExp = /<(h1|h2|h3|h4|p|li)\b[^>]*>([\s\S]*?)<\/(?:h1|h2|h3|h4|p|li)>/gi;
  let count: number = 0;
  let m: RegExpExecArray | null = rx.exec(body);
  while (m !== null) {
    const tag: string = m[1].toLowerCase();
    const inner: string = m[2];
    const plain: string = stripTags(inner);
    if (plain !== '') {
      const block = new WebBlock();
      block.kind = tag;              // h1 | h2 | h3 | h4 | p | li
      block.plain = plain;
      block.key = 'b' + count;
      block.segments = parseInline(inner, base, seen);
      blocks.push(block);
      count++;
    }
    m = rx.exec(body);
  }
  const contentRange: ElementRange | null =
    findElementRange(body, 'mw-content-text') ?? findElementRange(body, 'bodyContent');
  if (contentRange !== null) {
    const leftovers: WebBlock[] =
      parseLeftoverAnchors(body, contentRange.innerStart, contentRange.innerEnd, base, seen, count);
    for (const lb of leftovers) {
      blocks.push(lb);
    }
  }
  return blocks;
}

// Range of one element's inner HTML by id, depth-aware by tag name — same approach as
// stripElementById above, kept separate since this returns a range rather than a cut string.
export class ElementRange {
  innerStart: number = 0;
  innerEnd: number = 0;
}

export function findElementRange(html: string, id: string): ElementRange | null {
  const open: RegExpMatchArray | null =
    html.match(new RegExp('<([a-zA-Z0-9]+)\\b[^>]*\\bid\\s*=\\s*"' + id + '"[^>]*>'));
  if (open === null || open.index === undefined) {
    return null;
  }
  const tag: string = open[1].toLowerCase();
  const innerStart: number = open.index + open[0].length;
  const rx: RegExp = new RegExp('<\\/?' + tag + '\\b[^>]*>', 'gi');
  rx.lastIndex = innerStart;
  let depth: number = 1;
  let m: RegExpExecArray | null = rx.exec(html);
  while (m !== null) {
    if (m[0].startsWith('</')) {
      depth--;
      if (depth === 0) {
        const range = new ElementRange();
        range.innerStart = innerStart;
        range.innerEnd = m.index;
        return range;
      }
    } else {
      depth++;
    }
    m = rx.exec(html);
  }
  return null;
}

export class Span {
  start: number = 0;
  end: number = 0;
}

// ponytail: leftover-anchor pass. The block scan above visits only <h1|h2|h3|h4|p|li> —
// MediaWiki markup routinely puts real link anchors elsewhere (infobox <td>, image
// <figcaption>, <dd>, plain <div>), which that scan never sees. Enumerating every possible
// container tag into the block regex would just re-emit the same anchors several times as
// containers nest. Instead: recompute the block scan's own spans, then walk every <a> in the
// content root that falls outside all of them, in document order, and give each its own
// single-segment block carrying the same .id()/target/tap contract as any other link.
// Ceiling: link-only recovery for these — no surrounding prose, since they were never inside
// a scanned block to begin with. Restricted to the content root (#mw-content-text /
// #bodyContent), same as the block scan — the chrome menus outside it stay excluded.
export function parseLeftoverAnchors(
  body: string, start: number, end: number, base: string,
  seen: Map<string, number>, startCount: number): WebBlock[] {
  const covered: Span[] = [];
  const blockRx: RegExp = /<(h1|h2|h3|h4|p|li)\b[^>]*>([\s\S]*?)<\/(?:h1|h2|h3|h4|p|li)>/gi;
  let bm: RegExpExecArray | null = blockRx.exec(body);
  while (bm !== null) {
    const span = new Span();
    span.start = bm.index;
    span.end = bm.index + bm[0].length;
    covered.push(span);
    bm = blockRx.exec(body);
  }
  const out: WebBlock[] = [];
  const region: string = body.substring(start, end);
  const rx: RegExp = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;
  let count: number = startCount;
  let m: RegExpExecArray | null = rx.exec(region);
  while (m !== null) {
    const absIndex: number = start + m.index;
    let inBlock: boolean = false;
    for (const span of covered) {
      if (absIndex >= span.start && absIndex < span.end) {
        inBlock = true;
        break;
      }
    }
    if (!inBlock) {
      const attrs: string = m[1];
      const strippedLabel: string = stripTags(m[2]);
      const label: string = strippedLabel !== '' ? strippedLabel : attrOf(m[2], 'alt');
      const href: string = attrOf(attrs, 'href');
      // Same Rule-12 bound as parseInline, including the raw-label fallback.
      const slug: string = slugFor(label);
      if (label !== '' && slug !== '' && href !== '' && !href.startsWith('#') && !href.startsWith('javascript')) {
        const seg = new WebSegment();
        seg.text = label;
        seg.kind = 'link';
        seg.target = absolutize(href, base);
        const used: number | undefined = seen.get(slug);
        const n: number = used === undefined ? 0 : used;
        seen.set(slug, n + 1);
        seg.slug = n === 0 ? slug : slug + '_' + n;
        const block = new WebBlock();
        block.kind = 'p';
        block.plain = label;
        block.key = 'lo' + count;
        block.segments = [seg];
        out.push(block);
        count++;
      }
    }
    m = rx.exec(region);
  }
  return out;
}
