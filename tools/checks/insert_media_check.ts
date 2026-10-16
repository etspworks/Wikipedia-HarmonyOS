// Self-check for entry/src/main/ets/common/InsertMedia.ts against the wikitext table of
// InsertMediaSettingsViewController.prepareWikitext. Run from the repo root:
//   export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH
//   npx --yes -p typescript@5.4.5 tsc --target es2020 --module commonjs --strict --outDir /tmp/imc tools/checks/insert_media_check.ts
//   node /tmp/imc/tools/checks/insert_media_check.js
import * as M from '../../entry/src/main/ets/common/InsertMedia';

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
function settings(f: (s: M.InsertMediaSettings) => void): M.InsertMediaSettings {
  const s = new M.InsertMediaSettings();
  f(s);
  return s;
}
const F = 'File:Foo.jpg';
eq('defaults', M.mediaWikitext(F, settings(() => {})), '[[File:Foo.jpg | thumb | right]]');
eq('wrapOff', M.mediaWikitext(F, settings((s) => { s.wrapTextAroundImage = false; })), '[[File:Foo.jpg | thumb | none]]');
eq('framelessLeft', M.mediaWikitext(F, settings((s) => { s.type = 'frameless'; s.position = 'left'; })),
  '[[File:Foo.jpg | frameless | left]]');
eq('frameCenter', M.mediaWikitext(F, settings((s) => { s.type = 'frame'; s.position = 'center'; })),
  '[[File:Foo.jpg | frame | center]]');
eq('basicRight', M.mediaWikitext(F, settings((s) => { s.type = 'basic'; })), '[[File:Foo.jpg | right]]');
eq('custom', M.mediaWikitext(F, settings((s) => { s.customSize = true; s.width = '300'; s.height = '200'; })),
  '[[File:Foo.jpg | thumb | 300x200px | right]]');
eq('customDefault', M.mediaWikitext(F, settings((s) => { s.customSize = true; })), '[[File:Foo.jpg | thumb | right]]');
eq('customBad', M.mediaWikitext(F, settings((s) => { s.customSize = true; s.width = 'x'; })),
  '[[File:Foo.jpg | thumb | right]]');
eq('captionAlt', M.mediaWikitext(F, settings((s) => { s.caption = 'CAP'; s.alternativeText = 'ALT'; })),
  '[[File:Foo.jpg | thumb | right | alt=ALT | CAP]]');
eq('captionOnly', M.mediaWikitext(F, settings((s) => { s.caption = 'CAP'; })), '[[File:Foo.jpg | thumb | right | CAP]]');
eq('altOnly', M.mediaWikitext(F, settings((s) => { s.alternativeText = 'ALT'; })),
  '[[File:Foo.jpg | thumb | right |  alt=ALT]]');
eq('blankCaption', M.mediaWikitext(F, settings((s) => { s.caption = '  '; })), '[[File:Foo.jpg | thumb | right]]');
eq('basicCenterSizeCaption', M.mediaWikitext(F, settings((s) => {
  s.type = 'basic'; s.position = 'center'; s.customSize = true; s.width = '300'; s.height = '200'; s.caption = 'CAP';
})), '[[File:Foo.jpg | 300x200px | center | CAP]]');
eq('displayTitle', M.fileDisplayTitle('File:Foo bar.jpg'), 'Foo bar');
eq('displayTitleJpeg', M.fileDisplayTitle('File:Foo.jpeg'), 'Foo.');
eq('thumb', M.thumbnailURL('https://u/thumb/a/ab/Foo.jpg/120px-Foo.jpg', 400), 'https://u/thumb/a/ab/Foo.jpg/500px-Foo.jpg');
eq('license', M.licenseIconNames('cc-by-sa-4.0'), ['license_cc', 'license_by', 'license_sa']);

// WMFWikitextUtilsTests: the source's own fixtures (tools/checks/wikitext_insert_image_fixtures.json)
declare function require(name: string): { readFileSync(path: string, enc: string): string };
interface Fixture { name: string; imageWikitext: string; initialArticleWikitext: string;
  expectedInsertedArticleWikitext: string }
const fixtures: Fixture[] = JSON.parse(require('fs').readFileSync('tools/checks/wikitext_insert_image_fixtures.json',
  'utf8')) as Fixture[];
for (const f of fixtures) {
  eq(f.name, M.insertImageWikitextAfterTemplates(f.imageWikitext, f.initialArticleWikitext),
    f.expectedInsertedArticleWikitext);
}
let threw = false;
try {
  M.insertImageWikitextAfterTemplates('[[File:A.jpg]]', 'Text }} more');
} catch (e) {
  threw = true;
}
eq('unbalancedThrows', threw, true);

console.log(`${pass} passed, ${fails.length} failed`);
for (const f of fails) {
  console.log('FAIL ' + f);
}
if (fails.length > 0) {
  process.exit(1);
}
