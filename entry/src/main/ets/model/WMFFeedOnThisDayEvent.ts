// Ported from Wikipedia/Code/WMFFeedOnThisDayEvent.h (/feed/onthisday response).

import { WMFFeedArticlePreview, WMFFeedArticlePreviewJson } from './WMFFeedArticlePreview';

export interface WMFFeedOnThisDayEventJson {
  text?: string;
  year?: number;
  pages?: WMFFeedArticlePreviewJson[];
}

export class WMFFeedOnThisDayEvent {
  text: string | null = null;
  year: number | null = null;
  articlePreviews: WMFFeedArticlePreview[] = [];   // JSON: pages
  siteURL: string | null = null;                   // propagated from the requesting site
  languageCode: string | null = null;
  contentLanguageCode: string | null = null;
  score: number | null = null;
  index: number | null = null;

  static fromJson(j: WMFFeedOnThisDayEventJson): WMFFeedOnThisDayEvent {
    const out = new WMFFeedOnThisDayEvent();
    out.text = j.text ?? null;
    out.year = j.year ?? null;
    const pages = j.pages;
    if (pages !== undefined) {
      const previews: WMFFeedArticlePreview[] = [];
      for (const page of pages) {
        previews.push(WMFFeedArticlePreview.fromJson(page));
      }
      out.articlePreviews = previews;
    }
    return out;
  }
}
