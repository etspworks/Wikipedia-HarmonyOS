// svc_plural — the MediaWiki {{PLURAL:$1|one|other}} markup the Wikipedia string catalogue
// ships inside its values. ArkUI resources substitute $1 but know nothing about the markup,
// so a screen that passed such a string straight to $r() rendered the braces on screen.
// Languages with a single numeral form (Turkish among them) translate the whole thing to one
// form, so the parser falls back to the last form it is given.
import { common } from '@kit.AbilityKit';

const PLURAL_RE: RegExp = /\{\{PLURAL:\$1\|([^}]*)\}\}/;
// The catalogue escapes its placeholders as \$1 (ArkUI gives $ its own meaning in a resource
// value), and what comes back out of the resource manager is "\1". Put both spellings back
// to $1 before anything else reads the string.
const ESCAPED_PLACEHOLDER_RE: RegExp = /\\\$?(\d)/g;

function normalize(raw: string): string {
  return raw.replace(ESCAPED_PLACEHOLDER_RE, '$$$1');
}

// The catalogue numbers its placeholders $1, $2 ... while ArkUI's own resource formatting
// expects %d/%s, so a value passed straight to $r() rendered "$1" on screen.
export function formatString(context: common.Context, res: Resource, values: string[]): string {
  let raw: string = '';
  try {
    raw = context.resourceManager.getStringSync(res);
  } catch (e) {
    console.error('plural: string unavailable: ' + (e as Error).message);
    return '';
  }
  raw = normalize(raw);
  const m: RegExpMatchArray | null = raw.match(PLURAL_RE);
  if (m !== null && values.length > 0) {
    const forms: string[] = m[1].split('|');
    const n: number = Number.parseInt(values[0], 10);
    raw = raw.replace(m[0], n === 1 ? forms[0] : forms[forms.length - 1]);
  }
  for (let i: number = 0; i < values.length; i++) {
    raw = raw.replace(new RegExp('\\$' + (i + 1).toString(), 'g'), values[i]);
  }
  return raw;
}

export function pluralString(context: common.Context, res: Resource, count: number): string {
  let raw: string = '';
  try {
    raw = context.resourceManager.getStringSync(res);
  } catch (e) {
    console.error('plural: string unavailable: ' + (e as Error).message);
    return count.toString();
  }
  raw = normalize(raw);
  const m: RegExpMatchArray | null = raw.match(PLURAL_RE);
  if (m !== null) {
    const forms: string[] = m[1].split('|');
    const form: string = count === 1 ? forms[0] : forms[forms.length - 1];
    raw = raw.replace(m[0], form);
  }
  return raw.replace(/\$1/g, count.toString());
}

// PCS page-last-edited ({{PLURAL:$1|Updated yesterday|Updated $1 days ago|0=Updated today}}),
// split into three resources because the parser above has no explicit-number forms. Empty
// when the edit time is unknown (an article that never loaded has none).
export function lastEditedString(context: common.Context, timestamp: string | null): string {
  const then: number = timestamp === null ? NaN : Date.parse(timestamp);
  if (Number.isNaN(then)) {
    return '';
  }
  const days: number = Math.max(0, Math.floor((Date.now() - then) / 86400000));
  const name: string = days === 0 ? 'page_last_edited_today' :
    days === 1 ? 'page_last_edited_yesterday' : 'page_last_edited_days';
  try {
    return normalize(context.resourceManager.getStringByNameSync(name)).replace(/\$1/g, days.toString());
  } catch (e) {
    console.error('plural: string unavailable: ' + (e as Error).message);
    return '';
  }
}

// A catalogue sentence with links inside it ("Don't have an account? $1") split at its
// placeholders, so each piece can be its own Span. ponytail: assumes the translation keeps
// $1 before $2; a language that reorders them would need the markers returned as well.
export function formatParts(context: common.Context, res: Resource): string[] {
  return formatString(context, res, ['\u0000', '\u0000', '\u0000']).split('\u0000');
}
