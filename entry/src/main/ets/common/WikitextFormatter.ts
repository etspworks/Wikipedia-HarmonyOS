// Wikitext source-editor formatting, ported from the iOS WMFComponents Source Editor
// (WMFSourceEditorFormatter*+ButtonActions, the WMFSourceEditorFormatter* highlighters that
// decide the toolbar's selected states, and WMFSourceEditorViewController.moveCursor).
// Pure functions over an EditorState; offsets are UTF-16 like NSRange.

export class EditorState {
  text: string;
  start: number;
  end: number;

  constructor(text: string, start: number, end: number) {
    this.text = text;
    this.start = start;
    this.end = end;
  }
}

export class LinkInfo {
  page: string = '';
  label: string | null = null;
  // Range of the text between [[ and ]] (the source's preselectedTextRange).
  start: number = 0;
  end: number = 0;
}

function copy(s: EditorState): EditorState {
  return new EditorState(s.text, s.start, s.end);
}

function precededBy(text: string, p: number, s: string): boolean {
  return p - s.length >= 0 && p <= text.length && text.substring(p - s.length, p) === s;
}

function followedBy(text: string, p: number, s: string): boolean {
  return p >= 0 && p + s.length <= text.length && text.substring(p, p + s.length) === s;
}

function surrounded(s: EditorState, open: string, close: string): boolean {
  return precededBy(s.text, s.start, open) && followedBy(s.text, s.end, close);
}

function lineStart(text: string, p: number): number {
  return p > 0 ? text.lastIndexOf('\n', p - 1) + 1 : 0;
}

// ---------------------------------------------------------------------------
// Shared button-action machinery (WKSourceEditorFormatter+ButtonActions.swift)
// ---------------------------------------------------------------------------

// Port of expandSelectedRangeUpToNearestFormattingStrings.
function expand(s: EditorState, open: string, close: string): EditorState {
  const t = s.text;
  const breakOnOpposite = open !== close;
  let finalStart = -1;
  for (let p = s.start; p >= 0; p--) {
    if (precededBy(t, p, open)) {
      finalStart = p;
      break;
    }
    if (precededBy(t, p, '\n') || (breakOnOpposite && precededBy(t, p, close))) {
      break;
    }
  }
  let finalEnd = -1;
  for (let p = s.end; p <= t.length; p++) {
    if (followedBy(t, p, close)) {
      finalEnd = p;
      break;
    }
    if (followedBy(t, p, '\n') || (breakOnOpposite && followedBy(t, p, open))) {
      break;
    }
  }
  if (finalStart < 0 || finalEnd < 0) {
    return copy(s);
  }
  return new EditorState(t, finalStart, finalEnd);
}

// Port of addStringFormattingCharacters.
function addFormatting(s: EditorState, open: string, close: string): EditorState {
  const t = s.text;
  if (s.start === s.end) {
    const text = t.substring(0, s.start) + open + ' ' + close + t.substring(s.start);
    const caret = s.start + open.length;
    return new EditorState(text, caret, caret + 1); // the placeholder space is selected
  }
  const text = t.substring(0, s.start) + open + t.substring(s.start, s.end) + close + t.substring(s.end);
  return new EditorState(text, s.start + open.length, s.end + open.length);
}

// Port of removeSurroundingFormattingStringsFromSelectedRange.
function removeFormatting(s: EditorState, open: string, close: string): EditorState {
  const t = s.text;
  if (s.start - open.length < 0 || s.end + close.length > t.length) {
    return copy(s);
  }
  const newStart = s.start - open.length;
  if (t.substring(s.start, s.end) === ' ') {
    // Just a placeholder space in the middle: remove the whole thing.
    return new EditorState(t.substring(0, newStart) + t.substring(s.end + close.length), newStart, newStart);
  }
  const text = t.substring(0, newStart) + t.substring(s.start, s.end) + t.substring(s.end + close.length);
  return new EditorState(text, newStart, s.end - open.length);
}

// Port of getModifiedStartingFormattingStringForSingleWildcard ("<ref*>" -> '<ref name="x">').
function resolveWildcard(s: EditorState, wildcard: string): string {
  const parts = wildcard.split('*').filter((x: string): boolean => x.length > 0);
  if (parts.length !== 2) {
    return wildcard;
  }
  const t = s.text;
  let closing = -1;
  let opening = -1;
  let p = s.start;
  while (p >= 0) {
    if (closing < 0 && precededBy(t, p, parts[1])) {
      closing = p;
      continue;
    }
    if (closing >= 0 && precededBy(t, p, parts[0])) {
      opening = p - parts[0].length;
      break;
    }
    if (precededBy(t, p, '\n')) {
      break;
    }
    p--;
  }
  if (opening < 0 || closing < 0) {
    return wildcard;
  }
  return t.substring(opening, closing);
}

// Port of toggleFormatting(startingFormattingString:wildcardStartingFormattingString:endingFormattingString:action:in:).
function toggleFormatting(state: EditorState, open: string, close: string, remove: boolean,
  wildcard: string | null): EditorState {
  const resolved = wildcard !== null ? resolveWildcard(state, wildcard) : open;
  if (state.start === state.end) {
    if (remove) {
      const expanded = expand(state, resolved, close);
      return surrounded(expanded, resolved, close) ? removeFormatting(expanded, resolved, close) : expanded;
    }
    return surrounded(state, resolved, close) ? removeFormatting(state, resolved, close) :
      addFormatting(state, open, close);
  }
  if (remove) {
    // Not directly wrapped: split the markup around the selection (flipped strings).
    return surrounded(state, resolved, close) ? removeFormatting(state, resolved, close) :
      addFormatting(state, close, open);
  }
  // Italics inside bold-italics: always add (source's "italics misfire" workaround).
  if (open === "''" && close === "''" && surrounded(state, "''", "''") && surrounded(state, "'''", "'''")) {
    return addFormatting(state, open, close);
  }
  // Re-join markup previously split around the selection (flipped strings).
  return surrounded(state, close, open) ? removeFormatting(state, close, open) : addFormatting(state, open, close);
}

// ---------------------------------------------------------------------------
// Selection state (the WMFSourceEditorFormatter* highlighters + selectionState(selectedDocumentRange:))
// ---------------------------------------------------------------------------

enum Key {
  Orange, Green, Bold, Italics, BoldItalics, BoldAny, ItalicsAny, Strike, Sub, Sup, Underline, Ref,
  Template, Comment, CommentMarkup, Link, BulletSingle, BulletMultiple, NumberSingle, NumberMultiple,
  H2, H3, H4, H5, H6, Count
}

class Match {
  start: number = 0;
  end: number = 0;
  // Group boundaries: [start, end of group 1, end of group 2, ...]; groups are contiguous.
  bounds: number[] = [];
}

function matchAll(re: RegExp, s: string): Match[] {
  re.lastIndex = 0;
  const out: Match[] = [];
  let r: RegExpExecArray | null = re.exec(s);
  while (r !== null) {
    const m = new Match();
    m.start = r.index;
    m.end = r.index + r[0].length;
    let pos = r.index;
    m.bounds.push(pos);
    for (let i = 1; i < r.length; i++) {
      const g: string | undefined = r[i];
      pos += g === undefined ? 0 : g.length;
      m.bounds.push(pos);
    }
    out.push(m);
    if (r[0].length === 0) {
      re.lastIndex++;
    }
    r = re.exec(s);
  }
  return out;
}

function mark(a: boolean[], from: number, to: number, v: boolean): void {
  for (let i = from; i < to; i++) {
    a[i] = v;
  }
}

function overlap(aStart: number, aEnd: number, bStart: number, bEnd: number): number {
  return Math.max(0, Math.min(aEnd, bEnd) - Math.max(aStart, bStart));
}

// Opening/content/closing pattern: markers get `marker`, content gets `content`.
function markTriples(m: boolean[][], re: RegExp, p: string, marker: Key, content: Key): Match[] {
  const found = matchAll(re, p);
  for (const x of found) {
    mark(m[marker], x.bounds[0], x.bounds[1], true);
    mark(m[content], x.bounds[1], x.bounds[2], true);
    mark(m[marker], x.bounds[2], x.bounds[3], true);
  }
  return found;
}

// Italics regex "((?<!')'{2}(?!'))(.*?)((?<!')'{2}(?!'))" without lookbehind: pairs consecutive
// runs of exactly two apostrophes on the same line.
function italicsMatches(p: string): Match[] {
  const runs: number[] = [];
  let i = 0;
  while (i < p.length) {
    if (p.charAt(i) !== "'") {
      i++;
      continue;
    }
    let j = i;
    while (j < p.length && p.charAt(j) === "'") {
      j++;
    }
    if (j - i === 2) {
      runs.push(i);
    }
    i = j;
  }
  const out: Match[] = [];
  let k = 0;
  while (k + 1 < runs.length) {
    const o = runs[k];
    const c = runs[k + 1];
    if (p.substring(o + 2, c).indexOf('\n') >= 0) {
      k++;
      continue;
    }
    const m = new Match();
    m.start = o;
    m.end = c + 2;
    m.bounds = [o, o + 2, c, c + 2];
    out.push(m);
    k += 2;
  }
  return out;
}

const BOLD_ITALICS_RE: RegExp = /('{5})(.*?)('{5})/g;
const BOLD_RE: RegExp = /('{3})(.*?)('{3})/g;
const TEMPLATE_RE: RegExp = /\{{2}[^\{\}\n]*(?:\{{2}[^\{\}\n]*\}{2})*[^\{\}\n]*\}{2}/g;
const STRIKE_RE: RegExp = /(<s>)(\s*.*?)(<\/s>)/g;
const SUB_RE: RegExp = /(<sub>)(.*?)(<\/sub>)/g;
const SUP_RE: RegExp = /(<sup>)(.*?)(<\/sup>)/g;
const UNDERLINE_RE: RegExp = /(<u>)(.*?)(<\/u>)/g;
const REF_RE: RegExp = /(<ref(?:[^\/\>]+?)?>)(.*?)(<\/ref>)/g;
const REF_MARKUP_RES: RegExp[] = [/<ref[^>]+?\/>/g, /<ref(?:[^\/\>]+?)?>/g, /<\/ref>/g];
const COMMENT_RE: RegExp = /(<!--)(.*?)(-->)/g;
const LINK_RE: RegExp = /(\[{2})([^\[\]\n]*)(\]{2})/g;
const HEADING_RES: RegExp[] = [2, 3, 4, 5, 6].map((n: number): RegExp =>
  new RegExp('^(={' + n + '})([^=]*)(={' + n + '})(?!=)$', 'gm'));
const HEADING_KEYS: Key[] = [Key.H2, Key.H3, Key.H4, Key.H5, Key.H6];

function markLists(m: boolean[][], p: string, ch: string, single: Key, multiple: Key): void {
  const multi = markTriplesPrefix(m, new RegExp('^(' + ch + '{2,})(.*)$', 'gm'), p, multiple);
  for (const x of matchAll(new RegExp('^(' + ch + '{1})(.*)$', 'gm'), p)) {
    if (multi.some((y: Match): boolean => overlap(x.start, x.end, y.start, y.end) > 0)) {
      continue;
    }
    mark(m[Key.Orange], x.bounds[0], x.bounds[1], true);
    mark(m[single], x.bounds[1], x.bounds[2], true);
  }
}

function markTriplesPrefix(m: boolean[][], re: RegExp, p: string, content: Key): Match[] {
  const found = matchAll(re, p);
  for (const x of found) {
    mark(m[Key.Orange], x.bounds[0], x.bounds[1], true);
    mark(m[content], x.bounds[1], x.bounds[2], true);
  }
  return found;
}

// Attribute masks for one paragraph, as the formatters' addSyntaxHighlighting would set them.
function buildMasks(p: string): boolean[][] {
  const m: boolean[][] = [];
  for (let k = 0; k < Key.Count; k++) {
    const a: boolean[] = [];
    for (let i = 0; i < p.length; i++) {
      a.push(false);
    }
    m.push(a);
  }
  // WMFSourceEditorFormatterBoldItalics.addSyntaxHighlighting
  const bi = markTriples(m, BOLD_ITALICS_RE, p, Key.Orange, Key.BoldItalics);
  const hitsBI = (x: Match): boolean => bi.some((y: Match): boolean => overlap(x.start, x.end, y.start, y.end) > 0);
  const boldOnly: Match[] = [];
  for (const x of matchAll(BOLD_RE, p)) {
    if (hitsBI(x)) {
      continue;
    }
    boldOnly.push(x);
    mark(m[Key.Orange], x.bounds[0], x.bounds[1], true);
    mark(m[Key.Bold], x.bounds[1], x.bounds[2], true);
    mark(m[Key.Orange], x.bounds[2], x.bounds[3], true);
  }
  for (const x of italicsMatches(p)) {
    if (hitsBI(x)) {
      continue;
    }
    mark(m[Key.Orange], x.bounds[0], x.bounds[1], true);
    mark(m[Key.Italics], x.bounds[1], x.bounds[2], true);
    for (const b of boldOnly) {
      const inter = overlap(b.start, b.end, x.start, x.end);
      const bLen = b.end - b.start;
      const xLen = x.end - x.start;
      const iStart = Math.max(b.start, x.start);
      if (inter > 0 && b.start < x.start && bLen > xLen) {
        mark(m[Key.Italics], x.bounds[1], x.bounds[2], false);
        mark(m[Key.Bold], iStart, iStart + inter, false);
        mark(m[Key.BoldItalics], x.bounds[1], x.bounds[2], true);
      } else if (inter > 0 && x.start < b.start && xLen > bLen) {
        mark(m[Key.Italics], iStart, iStart + inter, false);
        mark(m[Key.Bold], iStart, iStart + inter, false);
        mark(m[Key.BoldItalics], iStart, iStart + inter, true);
      }
    }
    mark(m[Key.Orange], x.bounds[2], x.bounds[3], true);
  }
  for (let i = 0; i < p.length; i++) {
    m[Key.BoldAny][i] = m[Key.Bold][i] || m[Key.BoldItalics][i];
    m[Key.ItalicsAny][i] = m[Key.Italics][i] || m[Key.BoldItalics][i];
  }
  for (const x of matchAll(TEMPLATE_RE, p)) {
    mark(m[Key.Template], x.start, x.end, true);
  }
  markTriples(m, STRIKE_RE, p, Key.Green, Key.Strike);
  markTriples(m, SUB_RE, p, Key.Green, Key.Sub);
  markTriples(m, SUP_RE, p, Key.Green, Key.Sup);
  markTriples(m, UNDERLINE_RE, p, Key.Green, Key.Underline);
  markTriples(m, REF_RE, p, Key.Green, Key.Ref);
  for (const re of REF_MARKUP_RES) {
    for (const x of matchAll(re, p)) {
      mark(m[Key.Green], x.start, x.end, true);
    }
  }
  markTriples(m, COMMENT_RE, p, Key.CommentMarkup, Key.Comment);
  for (const x of matchAll(LINK_RE, p)) {
    mark(m[Key.Link], x.start, x.end, true);
  }
  for (let h = 0; h < HEADING_RES.length; h++) {
    markTriples(m, HEADING_RES[h], p, Key.Orange, HEADING_KEYS[h]);
  }
  markLists(m, p, '\\*', Key.BulletSingle, Key.BulletMultiple);
  markLists(m, p, '#', Key.NumberSingle, Key.NumberMultiple);
  return m;
}

const NO_EDGE: number = -1;
const ANY_EDGE: number = -2;

// Port of the per-formatter `attributedString(_:isXIn:)` checks, evaluated on the paragraph that
// holds the selection start (textkit2SelectionData). `edge` is the marker key that lets a caret
// sitting on a closing marker count the previous character; `wholeRun` is the list formatter's
// stricter range check.
function query(state: EditorState, key: Key, edge: number, wholeRun: boolean): boolean {
  const t = state.text;
  const pStart = lineStart(t, state.start);
  const nl = t.indexOf('\n', state.start);
  const p = t.substring(pStart, nl < 0 ? t.length : nl + 1);
  const rs = state.start - pStart;
  const re = state.end - pStart;
  if (p.length === 0 || rs < 0 || rs >= p.length || re > p.length || re < rs) {
    return false;
  }
  const m = buildMasks(p);
  const k = m[key];
  if (rs === re) {
    if (k[rs]) {
      return true;
    }
    if (rs > 0 && (edge === ANY_EDGE || (edge >= 0 && m[edge][rs]))) {
      return k[rs - 1];
    }
    return false;
  }
  if (wholeRun) {
    // ponytail: source needs one uniform attribute run; approximated as "every char is list content".
    for (let i = rs; i < re; i++) {
      if (!k[i]) {
        return false;
      }
    }
    return true;
  }
  // NSUnionRange of the matching runs equals the selection <=> first and last chars match.
  return k[rs] && k[re - 1];
}

// WMFSourceEditorFormatterBoldItalics.attributedString(_:isBoldIn:)
export function isBold(state: EditorState): boolean {
  return query(state, Key.BoldAny, Key.Orange, false);
}

// WMFSourceEditorFormatterBoldItalics.attributedString(_:isItalicsIn:)
export function isItalics(state: EditorState): boolean {
  return query(state, Key.ItalicsAny, Key.Orange, false);
}

// WMFSourceEditorFormatterStrikethrough.attributedString(_:isStrikethroughIn:)
export function isStrikethrough(state: EditorState): boolean {
  return query(state, Key.Strike, Key.Green, false);
}

// WMFSourceEditorFormatterSubscript.attributedString(_:isSubscriptIn:)
export function isSubscript(state: EditorState): boolean {
  return query(state, Key.Sub, Key.Green, false);
}

// WMFSourceEditorFormatterSuperscript.attributedString(_:isSuperscriptIn:)
export function isSuperscript(state: EditorState): boolean {
  return query(state, Key.Sup, Key.Green, false);
}

// WMFSourceEditorFormatterUnderline.attributedString(_:isUnderlineIn:)
export function isUnderline(state: EditorState): boolean {
  return query(state, Key.Underline, Key.Green, false);
}

// WMFSourceEditorFormatterReference.attributedString(_:isHorizontalReferenceIn:)
export function isReference(state: EditorState): boolean {
  return query(state, Key.Ref, Key.Green, false);
}

// WMFSourceEditorFormatterTemplate.attributedString(_:isHorizontalTemplateIn:)
export function isTemplate(state: EditorState): boolean {
  return query(state, Key.Template, NO_EDGE, false);
}

// WMFSourceEditorFormatterComment.attributedString(_:isCommentIn:)
export function isComment(state: EditorState): boolean {
  return query(state, Key.Comment, Key.CommentMarkup, false);
}

// WMFSourceEditorFormatterHeading isHeadingIn / isSubheading1In...4In: 0 = paragraph, 2..6 = number of '='.
export function headingLevel(state: EditorState): number {
  for (let h = 0; h < HEADING_KEYS.length; h++) {
    if (query(state, HEADING_KEYS[h], Key.Orange, false)) {
      return h + 2;
    }
  }
  return 0;
}

// WMFSourceEditorFormatterList isBulletSingleIn || isBulletMultipleIn
export function isUnorderedList(state: EditorState): boolean {
  return query(state, Key.BulletSingle, ANY_EDGE, true) || query(state, Key.BulletMultiple, ANY_EDGE, true);
}

// WMFSourceEditorFormatterList isNumberSingleIn || isNumberMultipleIn
export function isOrderedList(state: EditorState): boolean {
  return query(state, Key.NumberSingle, ANY_EDGE, true) || query(state, Key.NumberMultiple, ANY_EDGE, true);
}

// WMFEditorToolbarExpandingView.updateButtonSelectionState: increase enabled on any list line.
export function canIncreaseIndent(state: EditorState): boolean {
  return isUnorderedList(state) || isOrderedList(state);
}

// WMFEditorToolbarExpandingView.updateButtonSelectionState: decrease enabled on multi-level lists only.
export function canDecreaseIndent(state: EditorState): boolean {
  return query(state, Key.BulletMultiple, ANY_EDGE, true) || query(state, Key.NumberMultiple, ANY_EDGE, true);
}

// WMFSourceEditorFormatterLink.attributedString(_:isSimpleLinkIn:)
function isSimpleLink(state: EditorState): boolean {
  return query(state, Key.Link, NO_EDGE, false);
}

// ---------------------------------------------------------------------------
// Toggle buttons. `remove` mirrors the source's .add/.remove action; when omitted it is derived
// from the toolbar state the way WMFSourceEditorViewController does (isSelected ? .remove : .add).
// ---------------------------------------------------------------------------

// WMFSourceEditorFormatterBoldItalics.toggleBoldFormatting
export function toggleBold(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, "'''", "'''", remove === undefined ? isBold(state) : remove, null);
}

// WMFSourceEditorFormatterBoldItalics.toggleItalicsFormatting
export function toggleItalics(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, "''", "''", remove === undefined ? isItalics(state) : remove, null);
}

// WMFSourceEditorFormatterStrikethrough.toggleStrikethroughFormatting
export function toggleStrikethrough(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<s>', '</s>', remove === undefined ? isStrikethrough(state) : remove, null);
}

// WMFSourceEditorFormatterSubscript.toggleSubscriptFormatting
export function toggleSubscript(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<sub>', '</sub>', remove === undefined ? isSubscript(state) : remove, null);
}

// WMFSourceEditorFormatterSuperscript.toggleSuperscriptFormatting
export function toggleSuperscript(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<sup>', '</sup>', remove === undefined ? isSuperscript(state) : remove, null);
}

// WMFSourceEditorFormatterUnderline.toggleUnderlineFormatting
export function toggleUnderline(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<u>', '</u>', remove === undefined ? isUnderline(state) : remove, null);
}

// WMFSourceEditorFormatterReference.toggleReferenceFormatting (named refs matched via "<ref*>")
export function toggleReference(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<ref>', '</ref>', remove === undefined ? isReference(state) : remove, '<ref*>');
}

// WMFSourceEditorFormatterTemplate.toggleTemplateFormatting
export function toggleTemplate(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '{{', '}}', remove === undefined ? isTemplate(state) : remove, null);
}

// WMFSourceEditorFormatterComment.toggleCommentFormatting
export function toggleComment(state: EditorState, remove?: boolean): EditorState {
  return toggleFormatting(state, '<!--', '-->', remove === undefined ? isComment(state) : remove, null);
}

// WMFSourceEditorFormatterHeading.toggleHeadingFormatting. level: 0 = paragraph, 2..6 = Heading,
// Subheading 1..4. Like the source it wraps the selection (a caret gets a " " placeholder), and
// adds surrounding line breaks only when coming from a paragraph not already on its own line.
export function setHeading(state: EditorState, level: number): EditorState {
  const current = headingLevel(state);
  let s = copy(state);
  if (current > 0) {
    const marker = '='.repeat(current);
    s = removeFormatting(expand(s, marker, marker), marker, marker);
  }
  if (level < 2 || level > 6) {
    return s;
  }
  const onOwnLine = surrounded(s, '\n', '\n') || (s.start === 0 && followedBy(s.text, s.end, '\n'));
  const lb = current === 0 && !onOwnLine ? '\n' : '';
  const marker = '='.repeat(level);
  return addFormatting(s, lb + marker, marker + lb);
}

// ---------------------------------------------------------------------------
// Lists (WKSourceEditorFormatterList+ButtonActions.swift)
// ---------------------------------------------------------------------------

// NSString.lineRange(for: selectedRange)
function lineRangeEnd(text: string, start: number, end: number): number {
  const idx = text.indexOf('\n', end > start ? end - 1 : start);
  return idx < 0 ? text.length : idx + 1;
}

function shift(s: EditorState, text: string, delta: number, floor: number): EditorState {
  return new EditorState(text, Math.max(floor, s.start + delta), Math.max(floor, s.end + delta));
}

// Port of toggleListItem(action:formattingCharacter:in:).
function toggleListItem(state: EditorState, ch: string, remove: boolean): EditorState {
  const t = state.text;
  const ls = lineStart(t, state.start);
  const line = t.substring(ls, lineRangeEnd(t, state.start, state.end));
  if (!remove) {
    const insert = line.indexOf(ch) < 0 ? ch + ' ' : ch;
    return shift(state, t.substring(0, ls) + insert + t.substring(ls), insert.length, 0);
  }
  let n = 0;
  while (n < line.length && line.charAt(n) === ch) {
    n++;
  }
  const len = n + (n < line.length && line.charAt(n) === ' ' ? 1 : 0);
  return shift(state, t.substring(0, ls) + t.substring(ls + len), -len, ls);
}

// WMFSourceEditorFormatterList.toggleListBullet
export function toggleUnorderedList(state: EditorState, remove?: boolean): EditorState {
  return toggleListItem(state, '*', remove === undefined ? isUnorderedList(state) : remove);
}

// WMFSourceEditorFormatterList.toggleListNumber
export function toggleOrderedList(state: EditorState, remove?: boolean): EditorState {
  return toggleListItem(state, '#', remove === undefined ? isOrderedList(state) : remove);
}

// WMFSourceEditorFormatterList.tappedIncreaseIndent
export function increaseIndent(state: EditorState): EditorState {
  const bullet = isUnorderedList(state);
  if (!bullet && !isOrderedList(state)) {
    return copy(state);
  }
  const t = state.text;
  const ls = lineStart(t, state.start);
  return shift(state, t.substring(0, ls) + (bullet ? '*' : '#') + t.substring(ls), 1, 0);
}

// WMFSourceEditorFormatterList.tappedDecreaseIndent
export function decreaseIndent(state: EditorState): EditorState {
  const t = state.text;
  const ls = lineStart(t, state.start);
  if ((!isUnorderedList(state) && !isOrderedList(state)) || t.length <= ls) {
    return copy(state);
  }
  return shift(state, t.substring(0, ls) + t.substring(ls + 1), -1, 0);
}

// ---------------------------------------------------------------------------
// Links (WKSourceEditorFormatterLink+ButtonActions.swift)
// ---------------------------------------------------------------------------

// WMFSourceEditorFormatterLink.linkWizardParameters(action: .edit) — only when the link button
// would be selected (isSimpleLink). Swift's split drops empty pieces, so "[[A|]]" has no label.
export function linkAtSelection(state: EditorState): LinkInfo | null {
  if (!isSimpleLink(state)) {
    return null;
  }
  const s = expand(state, '[[', ']]');
  const parts = s.text.substring(s.start, s.end).split('|').filter((x: string): boolean => x.length > 0);
  if (parts.length < 1 || parts.length > 2) {
    return null;
  }
  const info = new LinkInfo();
  info.page = parts[0];
  info.label = parts.length === 2 ? parts[1] : null;
  info.start = s.start;
  info.end = s.end;
  return info;
}

// WMFSourceEditorFormatterLink.insertLink. The selected text becomes the label (or `label` if
// given); a caret inserts "[[Page|]]" exactly like the source. Selects the inside of the brackets.
export function insertLink(state: EditorState, page: string, label?: string | null): EditorState {
  const t = state.text;
  const shown = label !== undefined && label !== null ? label : t.substring(state.start, state.end);
  const content = page === shown ? '[[' + page + ']]' : '[[' + page + '|' + shown + ']]';
  return new EditorState(t.substring(0, state.start) + content + t.substring(state.end),
    state.start + 2, state.start + content.length - 2);
}

// WMFSourceEditorFormatterLink.editLink — replaces the inside of the link at the selection.
export function editLink(state: EditorState, page: string, label?: string | null): EditorState {
  const info = linkAtSelection(state);
  if (info === null) {
    return copy(state);
  }
  const body = label !== undefined && label !== null && label.length > 0 ? page + '|' + label : page;
  const caret = info.start + body.length;
  return new EditorState(state.text.substring(0, info.start) + body + state.text.substring(info.end), caret, caret);
}

// WMFSourceEditorFormatterLink.removeLink — drops [[ ]] and keeps everything inside them
// (so "[[A|b]]" becomes "A|b", as in the source tests).
export function removeLink(state: EditorState): EditorState {
  const info = linkAtSelection(state);
  if (info === null) {
    return copy(state);
  }
  const t = state.text;
  const text = t.substring(0, info.start - 2) + t.substring(info.start, info.end) + t.substring(info.end + 2);
  return new EditorState(text, info.start - 2, info.end - 2);
}

// ---------------------------------------------------------------------------
// Find and replace (WMFSourceEditorFormatterFindAndReplace.swift)
// ---------------------------------------------------------------------------

// startMatchSession/calculateMatches: the query is a case-insensitive regular expression, as in
// the source (an invalid pattern yields no matches).
function findRanges(text: string, query: string): Match[] {
  if (query.length === 0) {
    return [];
  }
  try {
    return matchAll(new RegExp(query, 'gi'), text);
  } catch (e) {
    return [];
  }
}

// WMFSourceEditorFormatterFindAndReplace.calculateMatches — match start offsets.
export function findMatches(text: string, query: string): number[] {
  return findRanges(text, query).map((m: Match): number => m.start);
}

// WMFSourceEditorFormatterFindAndReplace.replaceSingleMatch — replacement is literal text.
export function replaceMatch(text: string, query: string, matchIndex: number, replacement: string): string {
  const ms = findRanges(text, query);
  if (matchIndex < 0 || matchIndex >= ms.length) {
    return text;
  }
  const m = ms[matchIndex];
  return text.substring(0, m.start) + replacement + text.substring(m.end);
}

// WMFSourceEditorFormatterFindAndReplace.replaceAllMatches — replacement is literal text.
export function replaceAll(text: string, query: string, replacement: string): string {
  const ms = findRanges(text, query);
  let out = text;
  for (let i = ms.length - 1; i >= 0; i--) {
    out = out.substring(0, ms[i].start) + replacement + out.substring(ms[i].end);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Cursor arrows (WMFSourceEditorViewController.moveCursor(direction:))
// ---------------------------------------------------------------------------

// Moves from the selection start and collapses to a caret; a move past either end is ignored.
// Up/down keep the column on the previous/next logical line, clamped to its length.
// ponytail: source hit-tests the caret rect, so soft-wrapped lines aren't modelled here.
export function moveCursor(state: EditorState, direction: 'up' | 'down' | 'left' | 'right'): EditorState {
  const t = state.text;
  let p = -1;
  if (direction === 'left' || direction === 'right') {
    p = state.start + (direction === 'left' ? -1 : 1);
    if (p < 0 || p > t.length) {
      return copy(state);
    }
    return new EditorState(t, p, p);
  }
  const ls = lineStart(t, state.start);
  const col = state.start - ls;
  if (direction === 'up') {
    if (ls === 0) {
      return copy(state);
    }
    const prev = lineStart(t, ls - 1);
    p = prev + Math.min(col, ls - 1 - prev);
  } else {
    const nl = t.indexOf('\n', state.start);
    if (nl < 0) {
      return copy(state);
    }
    const nextEnd = t.indexOf('\n', nl + 1);
    p = nl + 1 + Math.min(col, (nextEnd < 0 ? t.length : nextEnd) - nl - 1);
  }
  return new EditorState(t, p, p);
}

// ---- Syntax highlighting (WMFSourceEditorTextFrameworkMediator.formatters) ----

// WMFSourceEditorColors: the five syntax colours; '' is the base text colour
export type SyntaxColor = '' | 'orange' | 'purple' | 'green' | 'blue' | 'gray';

export class SyntaxRun {
  start: number;
  length: number;
  color: SyntaxColor;

  constructor(start: number, length: number, color: SyntaxColor) {
    this.start = start;
    this.length = length;
    this.color = color;
  }
}

// colours the groups of every match (group 0 = the whole match)
function paint(colors: SyntaxColor[], text: string, re: RegExp, groups: number[], color: SyntaxColor): void {
  re.lastIndex = 0;
  let m: RegExpExecArray | null = re.exec(text);
  while (m !== null) {
    let offset: number = m.index;
    for (let g = 0; g <= Math.max(...groups); g++) {
      const part: string | undefined = m[g];
      if (g > 0 && part !== undefined) {
        // groups are consecutive in these patterns: each starts where the last ended
        if (groups.indexOf(g) >= 0) {
          colors.fill(color, offset, offset + part.length);
        }
        offset += part.length;
      } else if (g === 0 && groups.indexOf(0) >= 0) {
        colors.fill(color, m.index, m.index + m[0].length);
      }
    }
    if (m[0].length === 0) {
      re.lastIndex++;
    }
    m = re.exec(text);
  }
}

// a group that does not start the match: its start is found from the groups before it
function paintGroup(colors: SyntaxColor[], text: string, re: RegExp, group: number, color: SyntaxColor): void {
  re.lastIndex = 0;
  let m: RegExpExecArray | null = re.exec(text);
  while (m !== null) {
    const part: string | undefined = m[group];
    if (part !== undefined) {
      const at: number = m.index + m[0].indexOf(part);
      colors.fill(color, at, at + part.length);
    }
    if (m[0].length === 0) {
      re.lastIndex++;
    }
    m = re.exec(text);
  }
}

// WMFSourceEditorFormatterLink.linkWithNestedLinkRanges: from an opening [[, the link runs to
// the ]] that balances it
function nestedLinkEnd(text: string, start: number): number {
  let depth: number = 0;
  for (let i = start; i < text.length - 1; i++) {
    if (text[i] === '[' && text[i + 1] === '[') {
      depth++;
      i++;
    } else if (text[i] === ']' && text[i + 1] === ']') {
      depth--;
      i++;
      if (depth === 0) {
        return i + 1;
      }
    }
  }
  return -1;
}

// The colours each formatter adds, in the mediator's order (a later one wins where they
// overlap): templates purple; bold/italic markup orange; ref tags green; list and heading markup
// orange; <s>/<sup>/<sub>/<u> tags green; links blue; comments gray. Returns runs covering the
// whole text.
export function syntaxRuns(text: string): SyntaxRun[] {
  const colors: SyntaxColor[] = new Array<SyntaxColor>(text.length).fill('');
  // WMFSourceEditorFormatterTemplate
  paint(colors, text, /\{{2}[^{}\n]*(?:\{{2}[^{}\n]*\}{2})*[^{}\n]*\}{2}/g, [0], 'purple');
  paintGroup(colors, text, /^(?:.*)(\{{2}[^{}\n]*)$/gm, 1, 'purple');
  paint(colors, text, /^\s*\|.*$/gm, [0], 'purple');
  paint(colors, text, /^([^{}\n]*\}{2})(?:.)*$/gm, [1], 'purple');
  // WMFSourceEditorFormatterBoldItalics: the quote marks
  paint(colors, text, /('{5})(.*?)('{5})/g, [1, 3], 'orange');
  paint(colors, text, /('{3})(.*?)('{3})/g, [1, 3], 'orange');
  paint(colors, text, /((?<!')'{2}(?!'))(.*?)((?<!')'{2}(?!'))/g, [1, 3], 'orange');
  // WMFSourceEditorFormatterReference: the tags
  paint(colors, text, /(<ref(?:[^\/>]+?)?>)(.*?)(<\/ref>)/g, [1, 3], 'green');
  paint(colors, text, /<ref[^>]+?\/>/g, [0], 'green');
  paint(colors, text, /<ref(?:[^\/>]+?)?>/g, [0], 'green');
  paint(colors, text, /<\/ref>/g, [0], 'green');
  // WMFSourceEditorFormatterList: the * and # marks
  paint(colors, text, /^(\*+)(.*)$/gm, [1], 'orange');
  paint(colors, text, /^(#+)(.*)$/gm, [1], 'orange');
  // WMFSourceEditorFormatterHeading: the = marks
  for (let n = 2; n <= 6; n++) {
    paint(colors, text, new RegExp(`^(={${n}})([^=]*)(={${n}})(?!=)$`, 'gm'), [1, 3], 'orange');
  }
  // strikethrough, superscript, subscript, underline: the tags
  for (const tag of ['s', 'sup', 'sub', 'u']) {
    paint(colors, text, new RegExp(`(<${tag}>)(${tag === 's' ? '\\s*' : ''}.*?)(<\\/${tag}>)`, 'g'), [1, 3], 'green');
  }
  // WMFSourceEditorFormatterLink: the whole link, nested ones to their balancing ]]
  paint(colors, text, /(\[{2})([^\[\]\n]*)(\]{2})/g, [1, 2, 3], 'blue');
  const nested: RegExp = /\[{2}[^\[\]\n]*\[{2}/g;
  let m: RegExpExecArray | null = nested.exec(text);
  while (m !== null) {
    const end: number = nestedLinkEnd(text, m.index);
    if (end > 0) {
      colors.fill('blue', m.index, end);
    }
    m = nested.exec(text);
  }
  // WMFSourceEditorFormatterComment: all of it
  paint(colors, text, /(<!--)(.*?)(-->)/g, [1, 2, 3], 'gray');

  const runs: SyntaxRun[] = [];
  for (let i = 0; i < colors.length; i++) {
    const last: SyntaxRun | undefined = runs[runs.length - 1];
    if (last !== undefined && last.color === colors[i]) {
      last.length++;
    } else {
      runs.push(new SyntaxRun(i, 1, colors[i]));
    }
  }
  return runs;
}
