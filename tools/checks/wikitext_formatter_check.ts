// Self-check for entry/src/main/ets/common/WikitextFormatter.ts, mirroring the source's
// WMFSourceEditorFormatterButtonActionTests / TextFrameworkMediatorTests. Run from the repo root:
//   export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH
//   npx --yes -p typescript@5.4.5 tsc --target es2020 --module commonjs --strict --outDir /tmp/wtf tools/checks/wikitext_formatter_check.ts
//   node /tmp/wtf/tools/checks/wikitext_formatter_check.js
// Mirrors WMFSourceEditorFormatterButtonActionTests, WMFSourceEditorTextFrameworkMediatorTests and
// (via the query functions) WMFSourceEditorFormatterTests.
import * as W from '../../entry/src/main/ets/common/WikitextFormatter';

declare const process: { exit(code: number): void };
let pass = 0;
const fails: string[] = [];
function eq(name: string, actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) === JSON.stringify(expected)) {
    pass++;
  } else {
    fails.push(`${name}: got ${JSON.stringify(actual)} expected ${JSON.stringify(expected)}`);
  }
}
const S = (text: string, start: number, len: number): W.EditorState => new W.EditorState(text, start, start + len);

// ---- Button actions (explicit .add/.remove as in the Swift tests) ----
eq('boldInsert', W.toggleBold(S('One Two Three Four', 4, 3), false).text, "One '''Two''' Three Four");
eq('boldRemove', W.toggleBold(S("One '''Two''' Three Four", 7, 3), true).text, 'One Two Three Four');
eq('italicsInsert', W.toggleItalics(S('One Two Three Four', 8, 5), false).text, "One Two ''Three'' Four");
eq('italicsRemove(bold)', W.toggleBold(S("One Two '''Three''' Four", 11, 5), true).text, 'One Two Three Four');
eq('cursorBoldRemove', W.toggleBold(S("One '''Two''' Three Four", 8, 0), true).text, 'One Two Three Four');
eq('cursorItalicsRemove', W.toggleBold(S("One Two '''Three''' Four", 14, 0), true).text, 'One Two Three Four');
eq('boldItalicsInsert', W.toggleItalics(W.toggleBold(S('One Two Three Four', 4, 3), false), false).text,
  "One '''''Two''''' Three Four");
let s = W.toggleBold(S("One '''''Two''''' Three Four", 9, 3), true);
eq('boldItalicsRemove1', s.text, "One ''Two'' Three Four");
eq('boldItalicsRemove2', W.toggleItalics(s, true).text, 'One Two Three Four');
s = W.toggleBold(S('One Two Three Four', 4, 0), false);
eq('cursorBoldInsert', s.text, "One ''' '''Two Three Four");
eq('cursorBoldRemove2', W.toggleBold(s, true).text, 'One Two Three Four');
s = W.toggleItalics(S('One Two Three Four', 4, 0), false);
eq('cursorItalicsInsert', s.text, "One '' ''Two Three Four");
eq('cursorItalicsRemove2', W.toggleItalics(s, true).text, 'One Two Three Four');
s = W.toggleBold(S("One '''Two Three Four''' Five", 11, 5), true);
eq('boldInner1', s.text, "One '''Two '''Three''' Four''' Five");
eq('boldInner2', W.toggleBold(s, true).text, "One '''Two Three Four''' Five");
s = W.toggleItalics(S("One ''Two Three Four'' Five", 10, 5), true);
eq('italicsInner1', s.text, "One ''Two ''Three'' Four'' Five");
eq('italicsInner2', W.toggleItalics(s, true).text, "One ''Two Three Four'' Five");
s = W.toggleBold(S("One '''''Two Three Four''''' Five", 13, 5), true);
eq('biInnerBold1', s.text, "One '''''Two '''Three''' Four''''' Five");
eq('biInnerBold2', W.toggleBold(s, true).text, "One '''''Two Three Four''''' Five");
s = W.toggleItalics(S("One '''''Two Three Four''''' Five", 13, 5), true);
eq('biInnerItalics1', s.text, "One '''''Two ''Three'' Four''''' Five");
eq('biInnerItalics2', W.toggleItalics(s, true).text, "One '''''Two Three Four''''' Five");
eq('templateInsert', W.toggleTemplate(S('One Two Three Four', 4, 3), false).text, 'One {{Two}} Three Four');
eq('templateRemove', W.toggleTemplate(S('One {{Two}} Three Four', 6, 3), true).text, 'One Two Three Four');
s = W.toggleTemplate(S('One Two Three Four', 4, 0), false);
eq('cursorTemplateInsert', s.text, 'One {{ }}Two Three Four');
eq('cursorTemplateRemove', W.toggleTemplate(s, true).text, 'One Two Three Four');
s = W.toggleReference(S('One Two Three Four', 4, 3), false);
eq('refInsert', s.text, 'One <ref>Two</ref> Three Four');
eq('refRemove', W.toggleReference(s, true).text, 'One Two Three Four');
s = W.toggleReference(S('One Two Three Four', 4, 0), false);
eq('refInsertCursor', s.text, 'One <ref> </ref>Two Three Four');
eq('refRemoveCursor', W.toggleReference(s, true).text, 'One Two Three Four');
s = W.toggleReference(S('One <ref name="testing">Two</ref> Three Four', 24, 3), true);
eq('refNamedRemove', s.text, 'One Two Three Four');
eq('refNamedInsert', W.toggleReference(s, false).text, 'One <ref>Two</ref> Three Four');
s = W.toggleReference(S('One <ref name="testing">Two</ref> Three Four', 25, 0), true);
eq('refNamedRemoveCursor', s.text, 'One Two Three Four');
eq('refNamedInsertCursor', W.toggleReference(s, false).text, 'One <ref>Two</ref> Three Four');

s = W.toggleUnorderedList(S('Test', 2, 0), false);
eq('bulletInsert', s.text, '* Test');
eq('bulletRemove', W.toggleUnorderedList(s, true).text, 'Test');
eq('bulletIndent', W.increaseIndent(s).text, '** Test');
s = W.decreaseIndent(S('*** Test', 4, 0));
eq('bulletDecrease1', s.text, '** Test');
s = W.decreaseIndent(s);
eq('bulletDecrease2', s.text, '* Test');
eq('bulletDecreaseRemove', W.toggleUnorderedList(s, true).text, 'Test');
s = W.toggleOrderedList(S('Test', 2, 0), false);
eq('numberInsert', s.text, '# Test');
eq('numberRemove', W.toggleOrderedList(s, true).text, 'Test');
eq('numberIndent', W.increaseIndent(s).text, '## Test');
s = W.decreaseIndent(S('### Test', 4, 0));
eq('numberDecrease1', s.text, '## Test');
s = W.decreaseIndent(s);
eq('numberDecrease2', s.text, '# Test');
eq('numberDecreaseRemove', W.toggleOrderedList(s, true).text, 'Test');

const marks = ['', '', '==', '===', '====', '=====', '======'];
for (let lvl = 2; lvl <= 6; lvl++) {
  const m = marks[lvl];
  eq(`headingAdd${lvl}`, W.setHeading(S('Test', 0, 4), lvl).text, `\n${m}Test${m}\n`);
  eq(`headingRemove${lvl}`, W.setHeading(S(`${m}Test${m}`, lvl, 4), 0).text, 'Test');
}
eq('headingSwitch', W.setHeading(S('==Test==', 2, 4), 5).text, '=====Test=====');

for (const [fn, o, c] of [[W.toggleStrikethrough, '<s>', '</s>'], [W.toggleSubscript, '<sub>', '</sub>'],
  [W.toggleSuperscript, '<sup>', '</sup>'], [W.toggleUnderline, '<u>', '</u>'], [W.toggleComment, '<!--', '-->']] as
  [(st: W.EditorState, r?: boolean) => W.EditorState, string, string][]) {
  s = fn(S('One Two Three Four', 4, 3), false);
  eq(`${o}insert`, s.text, `One ${o}Two${c} Three Four`);
  eq(`${o}remove`, fn(s, true).text, 'One Two Three Four');
}

// Links
let li = W.linkAtSelection(S('Testing [[Cat]] Testing', 10, 3));
eq('linkEditParams', [li?.page, li?.label, li?.start, li?.end], ['Cat', null, 10, 13]);
li = W.linkAtSelection(S('Testing [[Cat|Kitty]] Testing', 10, 3));
eq('linkEditParamsLabel', [li?.page, li?.label], ['Cat', 'Kitty']);
eq('linkNoneOutside', W.linkAtSelection(S('Testing Cat Testing', 8, 3)), null);
eq('linkInsert', W.insertLink(S('One Two Three Four', 4, 3), 'Two').text, 'One [[Two]] Three Four');
eq('linkInsertLabel', W.insertLink(S('One Two Three Four', 4, 3), 'Deux').text, 'One [[Deux|Two]] Three Four');
eq('linkInsertCaret', W.insertLink(S('One Two', 4, 0), 'Cat').text, 'One [[Cat|]]Two');
eq('linkEdit', W.editLink(S('One Two [[Three]] Four', 12, 0), 'Five').text, 'One Two [[Five]] Four');
eq('linkEditLabel', W.editLink(S('One Two [[Three]] Four', 12, 0), 'Five', 'fiver').text, 'One Two [[Five|fiver]] Four');
eq('linkRemove', W.removeLink(S('One Two [[Three]] Four', 10, 5)).text, 'One Two Three Four');
eq('linkRemoveLabel', W.removeLink(S('One Two [[Three|3]] Four', 12, 0)).text, 'One Two Three|3 Four');

// ---- Selection states (mediator tests) ----
const bi = "One\nTwo '''Three ''Four'' Five''' Six ''Seven'' Eight\nNine";
const biCases: [number, number, boolean, boolean][] = [[0, 3, false, false], [4, 3, false, false], [11, 5, true, false],
  [19, 4, true, true], [26, 4, true, false], [34, 3, false, false], [40, 5, false, true], [48, 5, false, false],
  [54, 4, false, false]];
for (const [a, l, b, i] of biCases) {
  eq(`boldState${a}`, W.isBold(S(bi, a, l)), b);
  eq(`italicsState${a}`, W.isItalics(S(bi, a, l)), i);
}
let t = "Testing '''bold with {{template}}''' selection that spans nonbold.";
eq('spanning1', [W.isBold(S(t, 11, 22)), W.isTemplate(S(t, 11, 22))], [true, false]);
t = "Testing {{template | '''bold'''}} selection that spans nonbold.";
eq('spanning2', [W.isBold(S(t, 10, 21)), W.isTemplate(S(t, 10, 21))], [false, true]);
eq('closingBoldCursor', W.isBold(S("One '''Two''' Three", 10, 0)), true);
eq('closingItalicsCursor', W.isItalics(S("One ''Two'' Three", 9, 0)), true);
t = 'Testing simple {{Currentdate}} template example.';
eq('templateCursor', [4, 20, 33].map((a: number): boolean => W.isTemplate(S(t, a, 0))), [false, true, false]);
eq('templateRange', [4, 20, 33].map((a: number): boolean => W.isTemplate(S(t, a, 3))), [false, true, false]);
eq('verticalTemplates', [W.isTemplate(S('{{Infobox officeholder', 4, 0)), W.isTemplate(S('| genus = Felis', 4, 0)),
  W.isTemplate(S('}}', 1, 0))], [false, false, false]);
t = 'Testing inner formatted {{cite web | url=https://en.wikipedia.org | title = The \'\'\'Free\'\'\' Encyclopedia}} template example.';
eq('templateFormattedRange', W.isTemplate(S(t, 26, 77)), true);
eq('refState', [W.isReference(S('Testing <ref>Testing</ref> Testing', 13, 7)),
  W.isReference(S('Testing <ref>Testing</ref> Testing', 16, 0)),
  W.isReference(S('Testing <ref name="testing">Testing</ref> Testing', 28, 7)),
  W.isReference(S('Testing <ref name="testing">Testing</ref> Testing', 31, 0))], [true, true, true, true]);
const listState = (st: W.EditorState): boolean[] =>
  [W.isUnorderedList(st), W.isOrderedList(st), W.canIncreaseIndent(st), W.canDecreaseIndent(st)];
eq('bulletSingle', listState(S('* Test', 2, 4)), [true, false, true, false]);
eq('bulletMultiple', listState(S('** Test', 3, 0)), [true, false, true, true]);
eq('numberSingle', listState(S('# Test', 2, 4)), [false, true, true, false]);
eq('numberMultiple', listState(S('## Test', 3, 0)), [false, true, true, true]);
eq('notList', listState(S('Test', 2, 0)), [false, false, false, false]);
for (let lvl = 2; lvl <= 6; lvl++) {
  const m = marks[lvl];
  t = `${m} Test ${m}`;
  eq(`headingState${lvl}`, [W.headingLevel(S(t, lvl + 1, 4)), W.headingLevel(S(t, lvl + 4, 0))], [lvl, lvl]);
}
eq('inlineHeading', W.headingLevel(S('Test == Test == Test', 8, 0)), 0);
t = 'Testing <s>Strikethrough</s> Testing.';
eq('strikeRange', [W.isStrikethrough(S(t, 0, 7)), W.isStrikethrough(S(t, 11, 13)), W.isStrikethrough(S(t, 29, 7))],
  [false, true, false]);
eq('strikeCursor', [3, 17, 33].map((a: number): boolean => W.isStrikethrough(S(t, a, 0))), [false, true, false]);
t = 'Testing [[Link with space]] Testing.';
eq('linkState', [W.linkAtSelection(S(t, 0, 7)) !== null, W.linkAtSelection(S(t, 10, 15))?.page,
  W.linkAtSelection(S(t, 28, 7)) !== null], [false, 'Link with space', false]);
eq('linkCursor', [3, 12, 30].map((a: number): boolean => W.linkAtSelection(S(t, a, 0)) !== null), [false, true, false]);
t = 'Test [[File:Cat with fish.jpg|thumb|left|Cat with [[fish]]|alt=Photo of cat looking at fish]] Test';
eq('nestedLinkCursor', [0, 13, 54, 73, 96].map((a: number): boolean => W.linkAtSelection(S(t, a, 0)) !== null),
  [false, false, true, false, false]);
t = 'Testing <!--Comment--> Testing.';
eq('commentRange', [W.isComment(S(t, 0, 7)), W.isComment(S(t, 12, 7)), W.isComment(S(t, 23, 7))], [false, true, false]);
eq('commentCursor', [3, 19, 25].map((a: number): boolean => W.isComment(S(t, a, 0))), [false, true, false]);

// ---- WMFSourceEditorFormatterTests content ranges, via queries ----
eq('fmtBoldItalic', [W.isBold(S("The quick '''''brown''''' fox", 15, 5)), W.isItalics(S("The quick '''''brown''''' fox", 15, 5))], [true, true]);
eq('fmtApostrophe', W.isItalics(S("Apostrophes ''shouldn't throw off'' formatting", 14, 19)), true);
t = "one '''two ''three'' four ''five'' six''' seven";
eq('fmtItalicsInBold', [W.isBold(S(t, 13, 5)), W.isItalics(S(t, 13, 5)), W.isItalics(S(t, 21, 4))], [true, true, false]);
t = "one ''two '''three''' four '''five''' six'' seven";
eq('fmtBoldInItalics', [W.isBold(S(t, 13, 5)), W.isItalics(S(t, 13, 5)), W.isBold(S(t, 22, 4))], [true, true, false]);
eq('fmtSub', W.isSubscript(S('Testing. <sub>Subscript.</sub> Testing', 14, 10)), true);
eq('fmtSup', W.isSuperscript(S('Testing. <sup>Superscript.</sup> Testing', 14, 12)), true);
eq('fmtUnderline', W.isUnderline(S('Testing. <u>Underline.</u> Testing', 12, 10)), true);
eq('fmtOpenOnlyRef', W.isReference(S('Testing.<ref> Testing', 15, 0)), false);

// ---- Find / replace ----
t = "Find a '''word''' and highlight that word.";
eq('findWithResults', W.findMatches(t, 'word'), [10, 37]);
eq('findCaseInsensitive', W.findMatches(t, 'WORD').length, 2);
eq('findWithoutResults', W.findMatches(t, 'cat'), []);
t = "Find a '''word''' and replace that word.";
eq('replaceSingle', W.replaceMatch(t, 'word', 0, 'testing'), "Find a '''testing''' and replace that word.");
eq('replaceSingleRemaining', W.findMatches(W.replaceMatch(t, 'word', 0, 'testing'), 'word').length, 1);
eq('replaceAll', W.replaceAll(t, 'word', 'testing'), "Find a '''testing''' and replace that testing.");
eq('replaceLiteral$', W.replaceAll('a b', 'a', '$&$&'), '$&$& b');

// ---- Cursor arrows ----
t = 'abcdef\nxy\nlonger line';
eq('left', W.moveCursor(new W.EditorState(t, 3, 5), 'left'), new W.EditorState(t, 2, 2));
eq('right', W.moveCursor(new W.EditorState(t, 3, 5), 'right'), new W.EditorState(t, 4, 4));
eq('leftAtStart', W.moveCursor(new W.EditorState(t, 0, 0), 'left'), new W.EditorState(t, 0, 0));
eq('downClamped', W.moveCursor(new W.EditorState(t, 5, 5), 'down').start, 9);
eq('downSameColumn', W.moveCursor(new W.EditorState(t, 8, 8), 'down').start, 11);
eq('upClamped', W.moveCursor(new W.EditorState(t, 20, 20), 'up').start, 9);
eq('upFirstLine', W.moveCursor(new W.EditorState(t, 2, 2), 'up').start, 2);

// Immutability + toolbar-derived toggles
const orig = S('One Two', 4, 3);
W.toggleBold(orig);
eq('noMutation', [orig.text, orig.start, orig.end], ['One Two', 4, 7]);
s = W.toggleBold(orig);
eq('derivedAdd', s.text, "One '''Two'''");
eq('derivedRemove', W.toggleBold(s).text, 'One Two');
s = W.toggleUnorderedList(S('Test', 2, 0));
eq('derivedListToggle', [s.text, W.toggleUnorderedList(s).text], ['* Test', 'Test']);

// ---- Syntax highlighting (WMFSourceEditorFormatterTests: which characters get which colour) ----
function colored(text: string): string[] {
  return W.syntaxRuns(text).filter((r: W.SyntaxRun) => r.color !== '')
    .map((r: W.SyntaxRun) => r.color + ':' + text.substr(r.start, r.length));
}
eq('hlBold', colored("One '''Two''' Three"), ["orange:'''", "orange:'''"]);
eq('hlItalics', colored("One ''Two'' Three"), ["orange:''", "orange:''"]);
eq('hlBoldItalics', colored("'''''Two'''''"), ["orange:'''''", "orange:'''''"]);
eq('hlTemplate', colored('One {{Two|three}} Four'), ['purple:{{Two|three}}']);
eq('hlNestedTemplate', colored('{{One|{{Two}}}}'), ['purple:{{One|{{Two}}}}']);
eq('hlVerticalTemplate', colored('{{Infobox\n| a = b\n}}'), ['purple:{{Infobox', 'purple:| a = b', 'purple:}}']);
eq('hlRef', colored('A<ref name="x">B</ref>C'), ['green:<ref name="x">', 'green:</ref>']);
eq('hlRefEmpty', colored('A<ref name="x" />C'), ['green:<ref name="x" />']);
eq('hlList', colored('* One\n## Two'), ['orange:*', 'orange:##']);
eq('hlHeading', colored('== One ==\n=== Two ==='), ['orange:==', 'orange:==', 'orange:===', 'orange:===']);
eq('hlHeadingUneven', colored('== One ==='), []);
eq('hlTags', colored('<s>a</s> <sup>b</sup> <sub>c</sub> <u>d</u>'),
  ['green:<s>', 'green:</s>', 'green:<sup>', 'green:</sup>', 'green:<sub>', 'green:</sub>', 'green:<u>', 'green:</u>']);
eq('hlLink', colored('One [[Two|three]] Four'), ['blue:[[Two|three]]']);
eq('hlNestedLink', colored('[[File:A.jpg|thumb|A [[cat]]]] end'), ['blue:[[File:A.jpg|thumb|A [[cat]]]]']);
eq('hlComment', colored('A <!-- B --> C'), ['gray:<!-- B -->']);
eq('hlLinkInTemplate', colored('{{A|[[B]]}}'), ['purple:{{A|', 'blue:[[B]]', 'purple:}}']);
eq('hlRunsCover', W.syntaxRuns('ab [[c]]').reduce((n: number, r: W.SyntaxRun) => n + r.length, 0), 8);

console.log(`${pass} passed, ${fails.length} failed`);
for (const f of fails) {
  console.log('FAIL ' + f);
}
if (fails.length > 0) {
  process.exit(1);
}
