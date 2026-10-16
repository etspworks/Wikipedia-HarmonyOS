// WMFSourceEditorViewController: the wikitext text view with its input accessory toolbars and the
// Text Formatting input view, ported onto a TextArea.
//   - WMFEditorToolbarExpandingView (no selection): Text formatting, Reference, Link, Template,
//     Image, Find, and the expand button that slides to Unordered / Ordered list, Decrease /
//     Increase indent and the four cursor arrows.
//   - WMFEditorToolbarHighlightView (a selection): Bold, Italics, Reference, Link, Template and
//     the plus button that opens Text Formatting.
//   - WMFEditorInputView (Text Formatting, in place of the keyboard via customKeyboard): the
//     heading picker (Paragraph, Heading, Subheading 1-4) and the paired buttons Bold|Italics,
//     Underline|Strikethrough, Reference|Link, Unordered|Ordered list, Decrease|Increase indent,
//     Superscript|Subscript, Template|Comment.
// The formatting itself is WikitextFormatter (the WMFSourceEditorFormatter* port). Undo / redo
// is the text view's undo manager: typing is grouped by pauses, each formatting action is one
// step.
import {
  EditorState, toggleBold, toggleItalics, toggleStrikethrough, toggleSubscript, toggleSuperscript,
  toggleUnderline, toggleReference, toggleTemplate, toggleComment, setHeading, toggleUnorderedList,
  toggleOrderedList, increaseIndent, decreaseIndent, isBold, isItalics, isStrikethrough, isSubscript,
  isSuperscript, isUnderline, isReference, isTemplate, isComment, headingLevel, isUnorderedList,
  isOrderedList, canIncreaseIndent, canDecreaseIndent, moveCursor, findMatches, replaceMatch, replaceAll,
  syntaxRuns, SyntaxRun, SyntaxColor
} from '../common/WikitextFormatter';
import { LengthMetrics } from '@kit.ArkUI';
import { Prefs, PrefKeys, SYNTAX_HIGHLIGHTING_KEY } from '../common/Prefs';

// typing within this long of the last keystroke joins the same undo step
const UNDO_GROUPING_MS: number = 1000;
// WMFTheme editorMatchBackground (yellow600 at 30%) / editorSelectedMatchBackground (yellow600)
// recolouring waits for typing to pause, so the field is not re-set under every keystroke
const RESTYLE_PAUSE_MS: number = 600;

// WMFTheme.editorOrange/Purple/Green/Blue/Gray: light, sepia (taupe gray), dark and black
function syntaxColor(color: SyntaxColor, themeName: string): string {
  const dark: boolean = themeName.startsWith('dark') || themeName.startsWith('black');
  if (color === 'orange') {
    return dark ? '#FFCC33' : '#FF9500';
  } else if (color === 'purple') {
    return dark ? '#FEE7E6' : '#6B4BA1';
  } else if (color === 'green') {
    return '#00AF89';
  } else if (color === 'blue') {
    return dark ? '#6699FF' : '#3366CC';
  }
  return dark ? '#C8CCD1' : themeName.startsWith('sepia') ? '#646059' : '#72777D';
}

const MATCH_BACKGROUND: string = '#4DFFCC33';
const SELECTED_MATCH_BACKGROUND: string = '#FFCC33';

class HeadingChoice {
  title: Resource;
  level: number;

  constructor(title: Resource, level: number) {
    this.title = title;
    this.level = level;
  }
}

const HEADINGS: HeadingChoice[] = [
  new HeadingChoice($r('app.string.editor_keyboard_paragraph_button'), 0),
  new HeadingChoice($r('app.string.editor_keyboard_heading_button'), 2),
  new HeadingChoice($r('app.string.editor_keyboard_subheading1_button'), 3),
  new HeadingChoice($r('app.string.editor_keyboard_subheading2_button'), 4),
  new HeadingChoice($r('app.string.editor_keyboard_subheading3_button'), 5),
  new HeadingChoice($r('app.string.editor_keyboard_subheading4_button'), 6)
];

// one button of a WMFEditorMultiButton pair
class ToolButton {
  symbol: Resource | null = null;
  glyph: string = '';
  label: Resource;
  id: string;
  selected: () => boolean = () => false;
  enabled: () => boolean = () => true;
  action: () => void;

  constructor(label: Resource, id: string, action: () => void) {
    this.label = label;
    this.id = id;
    this.action = action;
  }
}

function sym(symbol: Resource, label: Resource, id: string, selected: () => boolean, enabled: () => boolean,
  action: () => void): ToolButton {
  const b: ToolButton = new ToolButton(label, id, action);
  b.symbol = symbol;
  b.selected = selected;
  b.enabled = enabled;
  return b;
}

function glyph(text: string, label: Resource, id: string, selected: () => boolean, action: () => void): ToolButton {
  const b: ToolButton = new ToolButton(label, id, action);
  b.glyph = text;
  b.selected = selected;
  return b;
}

// the host's handle on the editor (undo / redo from the navigation bar, link and image results)
export class WikitextEditorController {
  undo: () => void = () => {};
  redo: () => void = () => {};
  // replaces the whole state (insert link / image results), as one undo step
  apply: (next: EditorState) => void = () => {};
  state: () => EditorState = () => new EditorState('', 0, 0);
  closeFind: () => void = () => {};
}

@Component
export struct WikitextEditorView {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  // the Syntax Highlighting switch, the theme and the text size: each restyles the text
  @StorageProp(SYNTAX_HIGHLIGHTING_KEY) @Watch('restyle') syntaxHighlighting: boolean = false;
  @StorageProp('WMFAppThemeName') @Watch('restyle') themeName: string = '';
  @StorageProp('WMFArticleFontSizeMultiplier') @Watch('restyle') fontSizePercent: number = 100;
  private isReady: boolean = false;
  private restyleTimer: number = -1;
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @Link text: string;
  controller: WikitextEditorController = new WikitextEditorController();
  onUndoStateChange: (canUndo: boolean, canRedo: boolean) => void = () => {};
  // the toolbar buttons that open other screens
  onLink: (state: EditorState) => void = () => {};
  onImage: () => void = () => {};
  // the Find and replace header replaces the navigation bar while the find bar is up
  onFindModeChange: (active: boolean) => void = () => {};

  @State selStart: number = 0;
  @State selEnd: number = 0;
  @State showFormatMenu: boolean = false;
  @State expanded: boolean = false;
  private richController: RichEditorStyledStringController = new RichEditorStyledStringController();
  // WMFSourceEditorFormatterFindAndReplace: the find bar, its matches and the selected one
  @State findMode: boolean = false;
  @State findQuery: string = '';
  @State replaceText: string = '';
  @State replaceAllType: boolean = false;
  @State matches: number[] = [];
  @State matchIndex: number = -1;
  private undoStack: EditorState[] = [];
  private redoStack: EditorState[] = [];
  private lastText: string = '';
  private lastTypedAt: number = 0;
  private applying: boolean = false;
  private pendingSelection: EditorState | null = null;

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>(SYNTAX_HIGHLIGHTING_KEY,
      Prefs.getBoolean(PrefKeys.isSyntaxHighlightingEnabled, false));
    this.lastText = this.text;
    this.controller.undo = (): void => this.undo();
    this.controller.redo = (): void => this.redo();
    // a link or image result: the field takes focus back, so it scrolls to the change
    this.controller.apply = (next: EditorState): void => {
      this.setState(next, true);
      setTimeout(() => {
        this.getUIContext().getFocusController().requestFocus('wikitext_field');
        this.richController.setSelection(next.start, next.end);
      }, 80);
    };
    this.controller.state = (): EditorState => this.current();
    this.controller.closeFind = (): void => this.closeFind();
  }

  private str(res: ResourceStr): string {
    if (typeof res === 'string') {
      return res;
    }
    try {
      return getContext(this).resourceManager.getStringSync((res as Resource).id);
    } catch (e) {
      return '';
    }
  }

  private current(): EditorState {
    return new EditorState(this.text, Math.min(this.selStart, this.text.length),
      Math.min(this.selEnd, this.text.length));
  }

  private notifyUndo(): void {
    this.onUndoStateChange(this.undoStack.length > 0, this.redoStack.length > 0);
  }

  // the text with the editor font, and the find highlights while the find bar is up
  restyle(): void {
    if (this.isReady) {
      this.render(this.current());
    }
  }

  // WMFSourceEditorColors: the syntax colours while highlighting is on, the text colour otherwise
  private styled(text: string): MutableStyledString {
    const fontSize: number = 15 * (this.fontSizePercent > 0 ? this.fontSizePercent : 100) / 100;
    const runs: SyntaxRun[] = this.syntaxHighlighting ? syntaxRuns(text) : [new SyntaxRun(0, text.length, '')];
    const styles: StyleOptions[] = runs.map((run: SyntaxRun): StyleOptions => ({
      start: run.start,
      length: run.length,
      styledKey: StyledStringKey.FONT,
      styledValue: new TextStyle({ fontSize: LengthMetrics.vp(fontSize), fontFamily: 'monospace',
        fontColor: run.color === '' ? $r('app.color.theme_text') : syntaxColor(run.color, this.themeName) })
    }));
    if (this.findMode && this.findQuery !== '') {
      for (let i = 0; i < this.matches.length; i++) {
        if (this.matches[i] + this.findQuery.length > text.length) {
          continue;
        }
        styles.push({
          start: this.matches[i],
          length: this.findQuery.length,
          styledKey: StyledStringKey.BACKGROUND_COLOR,
          styledValue: new BackgroundColorStyle({ color: i === this.matchIndex ? SELECTED_MATCH_BACKGROUND
            : MATCH_BACKGROUND })
        });
      }
    }
    return new MutableStyledString(text, styles);
  }

  // puts text and selection into the field
  private render(next: EditorState): void {
    this.applying = true;
    this.richController.setStyledString(this.styled(next.text));
    this.selStart = next.start;
    this.selEnd = next.end;
    setTimeout(() => {
      this.richController.setSelection(next.start, next.end);
      this.applying = false;
    }, 0);
  }

  // one undo step: the state before, then the new text and selection
  private setState(next: EditorState, recordUndo: boolean): void {
    if (recordUndo) {
      this.undoStack.push(this.current());
      this.redoStack = [];
    }
    this.text = next.text;
    this.lastText = next.text;
    this.lastTypedAt = 0;
    if (this.findMode) {
      this.refreshMatches(next.text, false);
    }
    this.render(next);
    this.notifyUndo();
  }

  private format(fn: (s: EditorState) => EditorState): void {
    this.setState(fn(this.current()), true);
  }

  private undo(): void {
    const previous: EditorState | undefined = this.undoStack.pop();
    if (previous === undefined) {
      return;
    }
    this.redoStack.push(this.current());
    this.setState(previous, false);
  }

  private redo(): void {
    const next: EditorState | undefined = this.redoStack.pop();
    if (next === undefined) {
      return;
    }
    this.undoStack.push(this.current());
    this.setState(next, false);
  }

  // typing: a pause starts a new undo step
  private textChanged(): void {
    if (this.applying) {
      return;
    }
    const value: string = this.richController.getStyledString().getString();
    if (value === this.lastText) {
      return;
    }
    const now: number = Date.now();
    if (now - this.lastTypedAt > UNDO_GROUPING_MS) {
      this.undoStack.push(new EditorState(this.lastText, this.selStart, this.selEnd));
      this.redoStack = [];
      this.notifyUndo();
    }
    this.lastTypedAt = now;
    this.lastText = value;
    this.text = value;
    if (this.findMode) {
      this.refreshMatches(value, false);
    }
    if (this.syntaxHighlighting) {
      if (this.restyleTimer !== -1) {
        clearTimeout(this.restyleTimer);
      }
      this.restyleTimer = setTimeout(() => {
        this.restyleTimer = -1;
        this.restyle();
      }, RESTYLE_PAUSE_MS);
    }
  }

  private cursor(direction: string): void {
    const next: EditorState = moveCursor(this.current(), direction as 'up' | 'down' | 'left' | 'right');
    this.selStart = next.start;
    this.selEnd = next.end;
    this.richController.setSelection(next.start, next.end);
  }

  // --- find and replace (WMFSourceEditorViewController find delegate) ---

  private openFind(): void {
    this.findMode = true;
    this.showFormatMenu = false;
    this.onFindModeChange(true);
  }

  // closeFind / resetFind: the highlights go and the expanding toolbar comes back
  private closeFind(): void {
    this.findMode = false;
    this.findQuery = '';
    this.replaceText = '';
    this.matches = [];
    this.matchIndex = -1;
    this.render(this.current());
    this.onFindModeChange(false);
  }

  private refreshMatches(text: string, selectFirst: boolean): void {
    this.matches = this.findQuery === '' ? [] : findMatches(text, this.findQuery);
    if (this.matches.length === 0) {
      this.matchIndex = -1;
    } else if (selectFirst || this.matchIndex < 0 || this.matchIndex >= this.matches.length) {
      this.matchIndex = 0;
    }
  }

  // findAndReplaceView(didChangeFindText:)
  private findTextChanged(query: string): void {
    this.findQuery = query;
    this.refreshMatches(this.text, true);
    if (this.matchIndex >= 0) {
      const start: number = this.matches[this.matchIndex];
      this.render(new EditorState(this.text, start, start + this.findQuery.length));
      this.scrollToMatchSoon(1200);
    } else {
      this.render(this.current());
    }
  }

  // highlight every match, select the current one and scroll it into view (scrollRangeToVisible):
  // the field only follows its selection while it has focus, so it takes focus for a moment
  // and gives it back to the find field
  private showMatch(): void {
    const state: EditorState = this.current();
    if (this.matchIndex < 0) {
      this.render(state);
      return;
    }
    const start: number = this.matches[this.matchIndex];
    this.render(new EditorState(this.text, start, start + this.findQuery.length));
    this.scrollToMatchSoon(30);
  }

  // A keystroke in the find field must not land in the text, so while typing the scroll waits
  // for a pause (each keystroke restarts the wait); Next / Previous scroll at once.
  private scrollTimer: number = -1;

  private scrollToMatchSoon(delay: number): void {
    if (this.scrollTimer !== -1) {
      clearTimeout(this.scrollTimer);
    }
    this.scrollTimer = setTimeout(() => {
      this.scrollTimer = -1;
      if (!this.findMode || this.matchIndex < 0) {
        return;
      }
      const start: number = this.matches[this.matchIndex];
      const focus = this.getUIContext().getFocusController();
      focus.requestFocus('wikitext_field');
      this.richController.setSelection(start, start + this.findQuery.length);
      setTimeout(() => focus.requestFocus('editor_find_field'), 120);
    }, delay);
  }

  // findAndReplaceViewDidTapNext / Previous
  private stepMatch(delta: number): void {
    if (this.matches.length === 0) {
      return;
    }
    this.matchIndex = (this.matchIndex + delta + this.matches.length) % this.matches.length;
    this.showMatch();
  }

  // "n / m", "0 / 0" with no match, nothing before a query is typed
  private matchInfo(): string {
    if (this.findQuery === '') {
      return '';
    }
    return this.matches.length === 0 ? '0 / 0' : `${this.matchIndex + 1} / ${this.matches.length}`;
  }

  // didTapReplaceSingle / didTapReplaceAll
  private replace(): void {
    if (this.matches.length === 0 || this.findQuery === '') {
      return;
    }
    if (this.replaceAllType) {
      const text: string = replaceAll(this.text, this.findQuery, this.replaceText);
      this.matchIndex = -1;
      this.setState(new EditorState(text, this.selStart, this.selStart), true);
      return;
    }
    const index: number = this.matchIndex;
    const text: string = replaceMatch(this.text, this.findQuery, index, this.replaceText);
    this.setState(new EditorState(text, this.selStart, this.selStart), true);
    // the next match is selected (the one now at the same position in the list)
    if (this.matches.length > 0) {
      this.matchIndex = index % this.matches.length;
    }
    this.showMatch();
  }

  @Builder
  iconButton(symbol: Resource, label: ResourceStr, id: string, selected: () => boolean, enabled: () => boolean,
    action: () => void) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor([selected() ? $r('app.color.theme_link') : (enabled() ? $r('app.color.theme_text')
          : $r('app.color.theme_secondary_text'))])
    }
    .id(id)
    .accessibilityText(this.str(label))
    .type(ButtonType.Normal)
    .width(40)
    .height(36)
    .borderRadius(6)
    .enabled(enabled())
    .opacity(enabled() ? 1 : 0.4)
    .backgroundColor(selected() ? $r('app.color.theme_mid_background') : Color.Transparent)
    .onClick(action)
  }

  @Builder
  glyphButton(glyph: string, label: ResourceStr, id: string, selected: () => boolean, action: () => void) {
    Button() {
      Text(glyph)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(selected() ? $r('app.color.theme_link') : $r('app.color.theme_text'))
    }
    .id(id)
    .accessibilityText(this.str(label))
    .type(ButtonType.Normal)
    .width(40)
    .height(36)
    .borderRadius(6)
    .backgroundColor(selected() ? $r('app.color.theme_mid_background') : Color.Transparent)
    .onClick(action)
  }

  // WMFEditorToolbarExpandingView
  @Builder
  expandingToolbar() {
    Row() {
      if (!this.expanded) {
        this.iconButton($r('sys.symbol.textformat'), $r('app.string.editor_toolbar_open_text_format_menu_accessibility'),
          'editor_format_text', () => false, () => true, () => {
            this.showFormatMenu = true;
          })
        this.iconButton($r('sys.symbol.quote'), $r('app.string.editor_toolbar_reference_accessibility'),
          'editor_reference', () => isReference(this.current()), () => true, () => this.format(toggleReference))
        this.iconButton($r('sys.symbol.link'), $r('app.string.editor_toolbar_link_accessibility'),
          'editor_link', () => false, () => true, () => this.onLink(this.current()))
        this.glyphButton('{ }', $r('app.string.editor_toolbar_template_accessibility'), 'editor_template',
          () => isTemplate(this.current()), () => this.format(toggleTemplate))
        this.iconButton($r('sys.symbol.picture'), $r('app.string.editor_toolbar_image_accessibility'),
          'editor_image', () => false, () => true, () => this.onImage())
        this.iconButton($r('sys.symbol.doc_text_magnifyingglass_fill'), $r('app.string.editor_toolbar_find_accessibility'),
          'editor_find', () => false, () => true, () => this.openFind())
      } else {
        this.iconButton($r('sys.symbol.list_bullet'), $r('app.string.editor_toolbar_list_unordered_accessibility'),
          'editor_unordered_list', () => isUnorderedList(this.current()), () => true, () => this.format(toggleUnorderedList))
        this.iconButton($r('sys.symbol.list_number'), $r('app.string.editor_toolbar_list_ordered_accessibility'),
          'editor_ordered_list', () => isOrderedList(this.current()), () => true, () => this.format(toggleOrderedList))
        this.iconButton($r('sys.symbol.indentation_left'), $r('app.string.editor_toolbar_indent_decrease_accessibility'),
          'editor_decrease_indent', () => false, () => canDecreaseIndent(this.current()), () => this.format(decreaseIndent))
        this.iconButton($r('sys.symbol.indent_right'), $r('app.string.editor_toolbar_indent_increase_accessibility'),
          'editor_increase_indent', () => false, () => canIncreaseIndent(this.current()), () => this.format(increaseIndent))
        this.iconButton($r('sys.symbol.chevron_up'), $r('app.string.editor_toolbar_cursor_up_accessibility'),
          'editor_cursor_up', () => false, () => true, () => this.cursor('up'))
        this.iconButton($r('sys.symbol.chevron_down'), $r('app.string.editor_toolbar_cursor_down_accessibility'),
          'editor_cursor_down', () => false, () => true, () => this.cursor('down'))
        this.iconButton($r('sys.symbol.chevron_left'), $r('app.string.editor_toolbar_cursor_previous_accessibility'),
          'editor_cursor_left', () => false, () => true, () => this.cursor('left'))
        this.iconButton($r('sys.symbol.chevron_right'), $r('app.string.editor_toolbar_cursor_next_accessibility'),
          'editor_cursor_right', () => false, () => true, () => this.cursor('right'))
      }
      Blank()
      // expandButton: chevron.right.circle, turned when expanded
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_right_circle'))
          .fontSize(22)
          .fontColor([$r('app.color.theme_link')])
          .rotate({ angle: this.expanded ? 180 : 0 })
      }
      .id('editor_expand')
      .accessibilityText(this.str($r('app.string.editor_toolbar_show_more_accessibility')))
      .type(ButtonType.Normal)
      .width(40)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.expanded = !this.expanded;
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  // WMFEditorToolbarHighlightView
  @Builder
  highlightToolbar() {
    Row() {
      this.iconButton($r('sys.symbol.bold'), $r('app.string.editor_toolbar_bold_accessibility'),
        'editor_bold', () => isBold(this.current()), () => true, () => this.format(toggleBold))
      this.iconButton($r('sys.symbol.italic'), $r('app.string.editor_toolbar_italics_accessibility'),
        'editor_italics', () => isItalics(this.current()), () => true, () => this.format(toggleItalics))
      this.iconButton($r('sys.symbol.quote'), $r('app.string.editor_toolbar_reference_accessibility'),
        'editor_reference', () => isReference(this.current()), () => true, () => this.format(toggleReference))
      this.iconButton($r('sys.symbol.link'), $r('app.string.editor_toolbar_link_accessibility'),
        'editor_link', () => false, () => true, () => this.onLink(this.current()))
      this.glyphButton('{ }', $r('app.string.editor_toolbar_template_accessibility'), 'editor_template',
        () => isTemplate(this.current()), () => this.format(toggleTemplate))
      Blank()
      Button() {
        SymbolGlyph($r('sys.symbol.plus_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.theme_link')])
      }
      .id('editor_show_more')
      .accessibilityText(this.str($r('app.string.editor_toolbar_open_text_format_menu_accessibility')))
      .type(ButtonType.Normal)
      .width(40)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showFormatMenu = true;
      })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
  }

  @Builder
  toolButton(b: ToolButton) {
    if (b.symbol !== null) {
      this.iconButton(b.symbol, b.label, b.id, b.selected, b.enabled, b.action)
    } else {
      this.glyphButton(b.glyph, b.label, b.id, b.selected, b.action)
    }
  }

  // WMFEditorMultiButton: two buttons joined in one rounded group
  @Builder
  pair(left: ToolButton, right: ToolButton) {
    Row() {
      this.toolButton(left)
      Divider()
        .vertical(true)
        .height(24)
        .color($r('app.color.theme_border'))
      this.toolButton(right)
    }
    .borderRadius(8)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // WMFEditorInputView: Text Formatting in place of the keyboard
  @Builder
  formatMenu() {
    Column({ space: 12 }) {
      Row() {
        Text($r('app.string.editor_keyboard_text_formatting_title'))
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Button() {
          SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
            .fontSize(26)
            .fontColor([$r('app.color.theme_secondary_text')])
        }
        .id('editor_format_close')
        .accessibilityText(this.str($r('app.string.editor_keyboard_close_text_format_menu_accessibility')))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showFormatMenu = false;
        })
      }
      .width('100%')
      // WMFEditorHeaderSelectScrollView
      Scroll() {
        Row({ space: 8 }) {
          ForEach(HEADINGS, (h: HeadingChoice) => {
            Text(h.title)
              .id('editor_heading_' + h.level)
              .fontSize(h.level === 0 ? 15 : 16)
              .fontWeight(h.level === 0 ? FontWeight.Normal : FontWeight.Medium)
              .fontColor(headingLevel(this.current()) === h.level ? Color.White : $r('app.color.theme_text'))
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .borderRadius(8)
              .backgroundColor(headingLevel(this.current()) === h.level ? $r('app.color.theme_link')
                : (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
              .onClick(() => {
                this.format((s: EditorState): EditorState => setHeading(s, h.level));
              })
          }, (h: HeadingChoice) => h.level + '_' + (headingLevel(this.current()) === h.level))
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      Row({ space: 10 }) {
        this.pair(sym($r('sys.symbol.bold'), $r('app.string.editor_keyboard_bold_accessibility'), 'editor_menu_bold', () => isBold(this.current()), () => true, () => this.format(toggleBold)),
          sym($r('sys.symbol.italic'), $r('app.string.editor_keyboard_italics_accessibility'), 'editor_menu_italics', () => isItalics(this.current()), () => true, () => this.format(toggleItalics)))
        this.pair(sym($r('sys.symbol.underline'), $r('app.string.editor_keyboard_underline_accessibility'), 'editor_menu_underline', () => isUnderline(this.current()), () => true, () => this.format(toggleUnderline)),
          sym($r('sys.symbol.strikethrough'), $r('app.string.editor_keyboard_strikethrough_accessibility'), 'editor_menu_strikethrough', () => isStrikethrough(this.current()), () => true, () => this.format(toggleStrikethrough)))
        this.pair(sym($r('sys.symbol.quote'), $r('app.string.editor_keyboard_reference_accessibility'), 'editor_menu_reference', () => isReference(this.current()), () => true, () => this.format(toggleReference)),
          sym($r('sys.symbol.link'), $r('app.string.editor_keyboard_link_accessibility'), 'editor_menu_link', () => false, () => true, () => this.onLink(this.current())))
      }
      Row({ space: 10 }) {
        this.pair(sym($r('sys.symbol.list_bullet'), $r('app.string.editor_keyboard_list_unordered_accessibility'), 'editor_menu_unordered', () => isUnorderedList(this.current()), () => true, () => this.format(toggleUnorderedList)),
          sym($r('sys.symbol.list_number'), $r('app.string.editor_keyboard_list_ordered_accessibility'), 'editor_menu_ordered', () => isOrderedList(this.current()), () => true, () => this.format(toggleOrderedList)))
        this.pair(sym($r('sys.symbol.indentation_left'), $r('app.string.editor_keyboard_indent_decrease_accessibility'), 'editor_menu_decrease', () => false, () => canDecreaseIndent(this.current()), () => this.format(decreaseIndent)),
          sym($r('sys.symbol.indent_right'), $r('app.string.editor_keyboard_indent_increase_accessibility'), 'editor_menu_increase', () => false, () => canIncreaseIndent(this.current()), () => this.format(increaseIndent)))
      }
      Row({ space: 10 }) {
        this.pair(glyph('x²', $r('app.string.editor_keyboard_superscript_accessibility'), 'editor_menu_superscript', () => isSuperscript(this.current()), () => this.format(toggleSuperscript)),
          glyph('x₂', $r('app.string.editor_keyboard_subscript_accessibility'), 'editor_menu_subscript', () => isSubscript(this.current()), () => this.format(toggleSubscript)))
        this.pair(glyph('{ }', $r('app.string.editor_keyboard_template_accessibility'), 'editor_menu_template', () => isTemplate(this.current()), () => this.format(toggleTemplate)),
          sym($r('sys.symbol.exclamationmark_circle'), $r('app.string.editor_keyboard_comment_accessibility'), 'editor_menu_comment', () => isComment(this.current()), () => true, () => this.format(toggleComment)))
      }
    }
    .width('100%')
    .height(320)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }

  // WMFFindAndReplaceView
  @Builder
  findBar() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        this.iconButton($r('sys.symbol.xmark'), $r('app.string.editor_find_close_button_accessibility'),
          'editor_find_close', () => false, () => true, () => this.closeFind())
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(16)
            .fontColor([$r('app.color.theme_secondary_text')])
          TextInput({ text: this.findQuery, placeholder: this.str($r('app.string.editor_find_textfield_accessibility')) })
            .id('editor_find_field')
            .layoutWeight(1)
            .height(36)
            .padding({ left: 0, right: 0 })
            .backgroundColor(Color.Transparent)
            .defaultFocus(true)
            .onChange((value: string) => {
              this.findTextChanged(value);
            })
          Text(this.matchInfo())
            .id('editor_find_match_info')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
          if (this.findQuery !== '') {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .id('editor_find_clear')
              .fontSize(16)
              .fontColor([$r('app.color.theme_secondary_text')])
              .onClick(() => {
                this.findTextChanged('');
              })
          }
        }
        .layoutWeight(1)
        .height(36)
        .padding({ left: 8, right: 8 })
        .borderRadius(8)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        this.iconButton($r('sys.symbol.chevron_up'), $r('app.string.editor_find_previous_button_accessibility'),
          'editor_find_previous', () => false, () => this.matches.length > 0, () => this.stepMatch(-1))
        this.iconButton($r('sys.symbol.chevron_down'), $r('app.string.editor_find_next_button_accessibility'),
          'editor_find_next', () => false, () => this.matches.length > 0, () => this.stepMatch(1))
      }
      .width('100%')
      Row({ space: 6 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil'))
            .fontSize(16)
            .fontColor([$r('app.color.theme_secondary_text')])
          TextInput({ text: this.replaceText, placeholder: this.str($r('app.string.editor_replace_textfield_placeholder')) })
            .id('editor_replace_field')
            .layoutWeight(1)
            .height(36)
            .padding({ left: 0, right: 0 })
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.replaceText = value;
            })
          // replaceTypeLabel: which replace the button runs
          Text(this.replaceAllType ? $r('app.string.editor_replace_type_all') : $r('app.string.editor_replace_type_single'))
            .id('editor_replace_type')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .layoutWeight(1)
        .height(36)
        .padding({ left: 8, right: 8 })
        .borderRadius(8)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        // replaceButton
        this.iconButton($r('sys.symbol.arrow_left_arrow_right'), $r('app.string.editor_replace_textfield_accessibility'),
          'editor_replace', () => false, () => this.matches.length > 0, () => this.replace())
        // replaceSwitchButton: the ellipsis menu, Replace / Replace all
        Button() {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('editor_replace_switch')
        .type(ButtonType.Normal)
        .width(40)
        .height(36)
        .backgroundColor(Color.Transparent)
        .bindMenu([
          { value: this.str($r('app.string.editor_replace_type_single')), action: () => {
            this.replaceAllType = false;
          } },
          { value: this.str($r('app.string.editor_replace_type_all')), action: () => {
            this.replaceAllType = true;
          } }
        ])
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
  }

  build() {
    Column() {
      RichEditor({ controller: this.richController })
        .id('wikitext_field')
        .accessibilityText(this.str($r('app.string.editor_wikitext_textview_accessibility')))
        .width('100%')
        .layoutWeight(1)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .customKeyboard(this.showFormatMenu ? this.formatMenu() : undefined)
        .onReady(() => {
          this.isReady = true;
          this.richController.setStyledString(this.styled(this.text));
          this.richController.onContentChanged({
            onDidChange: (): void => {
              this.textChanged();
            }
          });
        })
        .onSelectionChange((range: RichEditorRange) => {
          if (this.applying) {
            return;
          }
          this.selStart = range.start ?? 0;
          this.selEnd = range.end ?? 0;
        })
      Divider()
        .color($r('app.color.theme_border'))
      if (this.findMode) {
        this.findBar()
      } else if (this.selEnd > this.selStart) {
        this.highlightToolbar()
      } else {
        this.expandingToolbar()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }
}
