// svc_lang_store — preferred/app language persistence.
// Ported from Wikipedia/Code/MWKLanguageLinkController.m: preferred language codes are an
// ordered array persisted under WMFPreviousSelectedLanguagesKey (moc key-value store ->
// WMFKeyValue table); appLanguage = first; falls back to the OS languages when empty.

import { i18n } from '@kit.LocalizationKit';
import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { LanguageService } from './LanguageService';
import { Subject } from './Reactive';
import { MWKLanguageLink } from '../model/MWKLanguageLink';

// MWKLanguageLinkController.m:14
const PREVIOUS_LANGUAGES_KEY: string = 'WMFPreviousSelectedLanguagesKey';

// WMFPreferredLanguagesChangeType (MWKLanguageLinkController.h).
export enum LanguageChangeType {
  Add = 1,
  Remove = 2,
  Reorder = 3
}

export class LanguageChange {
  changeType: LanguageChangeType = LanguageChangeType.Add;
  changedLanguageCode: string = '';
}

function linkForCode(code: string): MWKLanguageLink {
  const all: MWKLanguageLink[] = LanguageService.cachedLanguages();
  for (const link of all) {
    if (link.contentLanguageCode === code) {
      return link;
    }
  }
  // No sitematrix cache yet — synthesize a minimal link so the app language still works.
  // The display name comes from ICU rather than the raw code, so a language row reads
  // "English", not "en", on the screens that render a link before the matrix is fetched
  // (screen_feed_card_settings on a fresh install, for one).
  const out = new MWKLanguageLink();
  out.languageCode = code;
  let display: string = code;
  try {
    display = i18n.System.getDisplayLanguage(code, code, true);
  } catch (e) {
    display = code;
  }
  // `name` is what every language row renders. Leaving it as the raw code put "en" on the
  // preferred-languages screen where the reader expects "English".
  out.name = display;
  out.localizedName = display;
  return out;
}

export class LanguageStore {
  // WMFPreferredLanguagesDidChangeNotification.
  static readonly languagesDidChange: Subject<LanguageChange> = new Subject<LanguageChange>();

  private static cachedCodes: string[] | null = null;

  // readSavedPreferredLanguageCodes — the persisted ordered array.
  static async readSavedCodes(): Promise<string[]> {
    const rows: string[] = await Database.query<string>(
      'SELECT valueJSON FROM WMFKeyValue WHERE key = ? AND grp = ?',
      [PREVIOUS_LANGUAGES_KEY, ''],
      (rs: relationalStore.ResultSet): string => rs.getString(rs.getColumnIndex('valueJSON')));
    if (rows.length === 0 || rows[0] === '') {
      return [];
    }
    return JSON.parse(rows[0]) as string[];
  }

  // readPreferredLanguageCodes — saved codes, else the OS preferred languages.
  static async readPreferredCodes(): Promise<string[]> {
    if (LanguageStore.cachedCodes !== null) {
      return LanguageStore.cachedCodes;
    }
    let codes: string[] = await LanguageStore.readSavedCodes();
    if (codes.length === 0) {
      // NSLocale.wmf_preferredWikipediaLanguageCodes equivalent: every device language, in
      // the device's order (the system language first), not only the first one.
      codes = [];
      let device: string[] = [];
      try {
        device = i18n.System.getPreferredLanguageList();
      } catch (e) {
        console.error('languages: device language list unavailable: ' + (e as Error).message);
      }
      device.unshift(i18n.System.getSystemLanguage());
      for (const tag of device) {
        const langCode: string = tag.split('-')[0].toLowerCase();
        if (langCode !== '' && codes.indexOf(langCode) < 0) {
          codes.push(langCode);
        }
      }
      if (codes.length === 0) {
        codes = ['en'];
      }
    }
    LanguageStore.cachedCodes = codes;
    return codes;
  }

  // savePreferredLanguageCodes:changeType:changedLanguage: — persists, drops the cache,
  // and notifies observers.
  private static async saveCodes(codes: string[], changeType: LanguageChangeType,
    changedCode: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      'key': PREVIOUS_LANGUAGES_KEY,
      'grp': '',
      'date': Date.now(),
      'valueJSON': JSON.stringify(codes)
    };
    await Database.insert('WMFKeyValue', values);
    LanguageStore.cachedCodes = null;
    const change = new LanguageChange();
    change.changeType = changeType;
    change.changedLanguageCode = changedCode;
    LanguageStore.languagesDidChange.next(change);
  }

  // preferredLanguages — codes resolved through the sitematrix cache.
  static async preferredLanguages(): Promise<MWKLanguageLink[]> {
    const codes: string[] = await LanguageStore.readPreferredCodes();
    const out: MWKLanguageLink[] = [];
    for (const code of codes) {
      out.push(linkForCode(code));
    }
    return out;
  }

  // appLanguage — the first preferred language.
  static async appLanguage(): Promise<MWKLanguageLink> {
    const preferred: MWKLanguageLink[] = await LanguageStore.preferredLanguages();
    return preferred.length > 0 ? preferred[0] : linkForCode('en');
  }

  // otherLanguages — allLanguages minus preferred.
  static async otherLanguages(): Promise<MWKLanguageLink[]> {
    const preferredCodes: string[] = await LanguageStore.readPreferredCodes();
    const all: MWKLanguageLink[] = LanguageService.cachedLanguages();
    const out: MWKLanguageLink[] = [];
    for (const link of all) {
      if (preferredCodes.indexOf(link.contentLanguageCode) < 0) {
        out.push(link);
      }
    }
    return out;
  }

  // appendPreferredLanguage — de-dupe, append at the end.
  static async appendPreferredLanguage(contentLanguageCode: string): Promise<void> {
    const codes: string[] = (await LanguageStore.readPreferredCodes()).slice(0);
    const existing: number = codes.indexOf(contentLanguageCode);
    if (existing >= 0) {
      codes.splice(existing, 1);
    }
    codes.push(contentLanguageCode);
    await LanguageStore.saveCodes(codes, LanguageChangeType.Add, contentLanguageCode);
  }

  // reorderPreferredLanguage:toIndex: — no-op when the index is out of range or the
  // language is not preferred (source asserts and returns).
  static async reorderPreferredLanguage(contentLanguageCode: string,
    newIndex: number): Promise<void> {
    const codes: string[] = (await LanguageStore.readPreferredCodes()).slice(0);
    if (newIndex >= codes.length) {
      return;
    }
    const oldIndex: number = codes.indexOf(contentLanguageCode);
    if (oldIndex < 0) {
      return;
    }
    codes.splice(oldIndex, 1);
    codes.splice(newIndex, 0, contentLanguageCode);
    await LanguageStore.saveCodes(codes, LanguageChangeType.Reorder, contentLanguageCode);
  }

  // The Wikipedia-languages editor commits reorders and removals together on Done.
  static async setPreferredCodes(codes: string[]): Promise<void> {
    const before: string[] = await LanguageStore.readPreferredCodes();
    await LanguageStore.saveCodes(codes.slice(0), LanguageChangeType.Reorder, codes.length > 0 ? codes[0] : '');
    for (const code of before) {
      if (!codes.includes(code)) {
        const change = new LanguageChange();
        change.changeType = LanguageChangeType.Remove;
        change.changedLanguageCode = code;
        LanguageStore.languagesDidChange.next(change);
      }
    }
  }

  // removePreferredLanguage.
  static async removePreferredLanguage(contentLanguageCode: string): Promise<void> {
    const codes: string[] = (await LanguageStore.readPreferredCodes()).slice(0);
    const index: number = codes.indexOf(contentLanguageCode);
    if (index >= 0) {
      codes.splice(index, 1);
    }
    await LanguageStore.saveCodes(codes, LanguageChangeType.Remove, contentLanguageCode);
  }
}
