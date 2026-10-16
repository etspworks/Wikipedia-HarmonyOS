// Ported from Wikipedia/Code/MWKLanguageLink.h/.m.

export interface MWKLanguageLinkJson {
  languageCode?: string;
  pageTitleText?: string;
  localizedName?: string;
  name?: string;
  languageVariantCode?: string;
  altISOCode?: string;
}

export class MWKLanguageLink {
  languageCode: string = '';
  pageTitleText: string = '';
  localizedName: string = '';
  name: string = '';
  languageVariantCode: string | null = null;
  altISOCode: string | null = null;

  // Source: contentLanguageCode = languageVariantCode ?? languageCode.
  get contentLanguageCode(): string {
    if (this.languageVariantCode !== null && this.languageVariantCode !== '') {
      return this.languageVariantCode;
    }
    return this.languageCode;
  }

  get siteURL(): string {
    return 'https://' + this.languageCode + '.wikipedia.org';
  }

  get articleURL(): string {
    return this.siteURL + '/wiki/' + encodeURIComponent(this.pageTitleText.replace(/ /g, '_'));
  }

  static fromJson(j: MWKLanguageLinkJson): MWKLanguageLink {
    const out = new MWKLanguageLink();
    out.languageCode = j.languageCode ?? '';
    out.pageTitleText = j.pageTitleText ?? '';
    out.localizedName = j.localizedName ?? '';
    out.name = j.name ?? '';
    out.languageVariantCode = j.languageVariantCode ?? null;
    out.altISOCode = j.altISOCode ?? null;
    return out;
  }
}
