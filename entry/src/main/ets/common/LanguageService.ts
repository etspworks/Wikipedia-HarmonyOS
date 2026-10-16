// svc_languages — ported from
// Command Line Tools/Update Languages/WikipediaLanguageCommandLineUtilityAPI.swift:23
// (sitematrix; on iOS its output ships as bundled wikipedia-languages.json, read by
// MWKLanguageLinkController) and :91 (per-language siteinfo). The ported app fetches the
// sitematrix at runtime and caches it in Prefs.

import { HttpClient } from './HttpClient';
import { MWKLanguageLink, MWKLanguageLinkJson } from '../model/MWKLanguageLink';
import { Prefs } from './Prefs';
import { i18n } from '@kit.LocalizationKit';

// Source: WikipediaLanguageCommandLineUtilityAPI.swift:23.
const SITEMATRIX_URL: string =
  'https://meta.wikimedia.org/w/api.php?action=sitematrix&smsiteprop=url%7Cdbname%7Ccode%7Csitename%7Clang&format=json&formatversion=2&origin=*';

// Source: WikipediaLanguageCommandLineUtilityAPI.swift:91 — per-language siteinfo.
const SITEINFO_PATH: string =
  '.wikipedia.org/w/api.php?action=query&format=json&prop=&list=&meta=siteinfo&siprop=namespaces%7Cgeneral%7Cnamespacealiases%7Cmagicwords&formatversion=2&origin=*';

const CACHE_PREF_KEY: string = 'WMFCachedSiteMatrixJSON';

// MWKLanguageLink.localizedName is the language's name in the reader's own locale (iOS asks
// NSLocale.current), so a Turkish reader sees "İngilizce", not the sitematrix's English
// "localname". ICU answers with the bare code for languages it does not know; those keep the
// sitematrix name.
export function capitalizeFirst(s: string): string {
  const chars: string[] = Array.from(s);
  return chars.length === 0 ? s : chars[0].toLocaleUpperCase() + chars.slice(1).join('');
}

export function localizedLanguageName(code: string, fallback: string): string {
  try {
    const name: string = i18n.System.getDisplayLanguage(code, i18n.System.getSystemLocale(), true);
    // ICU answers an unknown code with the code itself, capitalised ('azb' -> 'Azb').
    return name !== '' && name.toLowerCase() !== code.toLowerCase() ? name : fallback;
  } catch (e) {
    return fallback;
  }
}

interface LangLinkJson {
  lang?: string;
  title?: string;
  autonym?: string;
  langname?: string;
}

interface LangLinksPageJson {
  langlinks?: LangLinkJson[];
}

interface LangLinksQueryJson {
  pages?: LangLinksPageJson[];
}

interface LangLinksResponseJson {
  query?: LangLinksQueryJson;
}

interface SiteMatrixSiteJson {
  url?: string;
  dbname?: string;
  code?: string;
  sitename?: string;
}

interface SiteMatrixEntryJson {
  code?: string;
  name?: string;
  localname?: string;
  site?: SiteMatrixSiteJson[];
}

interface SiteInfoGeneralJson {
  mainpage?: string;
  sitename?: string;
  lang?: string;
  rtl?: string;
}

interface SiteInfoNamespaceJson {
  id?: number;
  name?: string;
  canonical?: string;
}

interface SiteInfoQueryJson {
  general?: SiteInfoGeneralJson;
  namespaces?: Record<string, SiteInfoNamespaceJson>;
}

interface SiteInfoResponseJson {
  query?: SiteInfoQueryJson;
}

// MWKLanguageLink / MWLanguageInfo's right-to-left wikis. An article reads in its own
// language's direction whatever the device language is.
const RTL_LANGUAGES: string[] = ['arc', 'arz', 'ar', 'azb', 'bcc', 'bqi', 'ckb', 'dv', 'fa', 'glk', 'he',
  'khw', 'ks', 'lrc', 'mzn', 'nqo', 'pnb', 'ps', 'sd', 'skr', 'ug', 'ur', 'yi'];

export function isRTLLanguage(code: string): boolean {
  return RTL_LANGUAGES.indexOf(code) >= 0;
}

export class SiteInfo {
  languageCode: string = '';
  siteName: string = '';
  mainPage: string = '';
  isRTL: boolean = false;
  namespaces: Map<number, string> = new Map<number, string>();
}

export class LanguageService {
  // Source: sitematrix entries are keyed "0".."N" beside "count" and "specials";
  // each has code / name / localname / site[] (url, dbname, code, sitename).
  // WMFArticleLanguagesViewController: the languages THIS article exists in (langlinks), each
  // carrying the article's title on that wiki in pageTitleText.
  static async fetchArticleLanguages(host: string, title: string): Promise<MWKLanguageLink[]> {
    const url: string = 'https://' + host + '/w/api.php?action=query&format=json&formatversion=2' +
      '&prop=langlinks&lllimit=500&llprop=autonym%7Clangname&titles=' + encodeURIComponent(title);
    const j: LangLinksResponseJson = await HttpClient.getJson<LangLinksResponseJson>(url);
    const out: MWKLanguageLink[] = [];
    for (const page of j.query?.pages ?? []) {
      for (const link of page.langlinks ?? []) {
        const code: string = link.lang ?? '';
        const linkJson: MWKLanguageLinkJson = {
          languageCode: code,
          pageTitleText: link.title ?? '',
          localizedName: localizedLanguageName(code, link.langname ?? code),
          // the source capitalises the autonym (capitalizingFirstLetter): 'български' -> 'Български'
          name: capitalizeFirst(link.autonym ?? code)
        };
        out.push(MWKLanguageLink.fromJson(linkJson));
      }
    }
    return out;
  }

  static async fetchAllLanguages(): Promise<MWKLanguageLink[]> {
    const text: string = await HttpClient.getText(SITEMATRIX_URL, null);
    Prefs.putString(CACHE_PREF_KEY, text);
    return LanguageService.parseSiteMatrix(text);
  }

  // Cached copy for offline startup; empty when the matrix was never fetched.
  static cachedLanguages(): MWKLanguageLink[] {
    const text: string = Prefs.getString(CACHE_PREF_KEY, '');
    if (text === '') {
      return [];
    }
    return LanguageService.parseSiteMatrix(text);
  }

  static parseSiteMatrix(text: string): MWKLanguageLink[] {
    const root: Record<string, object> = HttpClient.parseJson<Record<string, object>>(text);
    const matrix = root['sitematrix'] as Record<string, object> | undefined;
    if (matrix === undefined) {
      return [];
    }
    const out: MWKLanguageLink[] = [];
    const keys: string[] = Object.keys(matrix);
    for (const key of keys) {
      if (key === 'count' || key === 'specials') {
        continue;
      }
      const entry = matrix[key] as SiteMatrixEntryJson;
      const code: string = entry.code ?? '';
      if (code === '') {
        continue;
      }
      // Only languages with a wikipedia site are shown in the language picker.
      let hasWikipedia: boolean = false;
      const sites: SiteMatrixSiteJson[] = entry.site ?? [];
      for (const site of sites) {
        if (site.code === 'wiki' && (site.url ?? '').indexOf('wikipedia.org') >= 0) {
          hasWikipedia = true;
        }
      }
      if (!hasWikipedia) {
        continue;
      }
      const linkJson: MWKLanguageLinkJson = {
        languageCode: code,
        pageTitleText: '',
        localizedName: localizedLanguageName(code, entry.localname ?? entry.name ?? code),
        name: entry.name ?? code,
        languageVariantCode: undefined,
        altISOCode: undefined
      };
      out.push(MWKLanguageLink.fromJson(linkJson));
    }
    out.sort((a: MWKLanguageLink, b: MWKLanguageLink): number =>
      a.languageCode < b.languageCode ? -1 : (a.languageCode > b.languageCode ? 1 : 0));
    return out;
  }

  // Source: WikipediaLanguageCommandLineUtilityAPI.swift:91 — siteinfo for one language wiki.
  static async fetchSiteInfo(languageCode: string): Promise<SiteInfo> {
    const url: string = 'https://' + languageCode + SITEINFO_PATH;
    const resp: SiteInfoResponseJson = await HttpClient.getJson<SiteInfoResponseJson>(url);
    const out = new SiteInfo();
    out.languageCode = languageCode;
    const general: SiteInfoGeneralJson | undefined = resp.query?.general;
    out.siteName = general?.sitename ?? '';
    out.mainPage = general?.mainpage ?? '';
    out.isRTL = general?.rtl !== undefined;
    const namespaces: Record<string, SiteInfoNamespaceJson> | undefined = resp.query?.namespaces;
    if (namespaces !== undefined) {
      const keys: string[] = Object.keys(namespaces);
      for (const key of keys) {
        const ns: SiteInfoNamespaceJson = namespaces[key];
        out.namespaces.set(ns.id ?? 0, ns.name ?? '');
      }
    }
    return out;
  }
}
