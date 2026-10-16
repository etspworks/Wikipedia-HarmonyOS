// Ported from Wikipedia/Code/WMFFeedNewsStory.h/.m.

import { WMFFeedArticlePreview, WMFFeedArticlePreviewJson } from './WMFFeedArticlePreview';

export interface WMFFeedNewsStoryJson {
  story?: string;
  links?: WMFFeedArticlePreviewJson[];
}

export class WMFFeedNewsStory {
  storyHTML: string | null = null;                 // JSON: story
  featuredArticlePreview: WMFFeedArticlePreview | null = null;
  articlePreviews: WMFFeedArticlePreview[] = [];   // JSON: links
  midnightUTCMonthAndDay: string | null = null;    // parsed from `story` date prefix (month-day)

  static fromJson(j: WMFFeedNewsStoryJson): WMFFeedNewsStory {
    const out = new WMFFeedNewsStory();
    out.storyHTML = j.story ?? null;
    const links = j.links;
    if (links !== undefined) {
      const previews: WMFFeedArticlePreview[] = [];
      for (const link of links) {
        previews.push(WMFFeedArticlePreview.fromJson(link));
      }
      out.articlePreviews = previews;
      // Source: featuredArticlePreview defaults to the first linked article.
      if (previews.length > 0) {
        out.featuredArticlePreview = previews[0];
      }
    }
    // Source: midnightUTCMonthAndDay is regex-extracted from the story HTML date prefix.
    const story: string = j.story ?? '';
    const dateMatch = story.match(/^([A-Z][a-z]+ +\d{1,2})/);
    if (dateMatch !== null && dateMatch.length > 1) {
      out.midnightUTCMonthAndDay = dateMatch[1];
    }
    return out;
  }
}
