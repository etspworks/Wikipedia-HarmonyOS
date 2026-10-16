// Ported from Wikipedia/Code/WMFFeedDayResponse.h, WMFFeedTopReadResponse.h, WMFFeedImage.h
// (/feed/featured/yyyy/mm/dd response).

import { WMFFeedArticlePreview, WMFFeedArticlePreviewJson } from './WMFFeedArticlePreview';
import { WMFFeedNewsStory, WMFFeedNewsStoryJson } from './WMFFeedNewsStory';

interface FeedImageDescriptionJson {
  text?: string;
  lang?: string;
}

interface FeedImageThumbnailJson {
  source?: string;
  width?: number;
  height?: number;
}

export interface WMFFeedImageJson {
  title?: string;
  description?: FeedImageDescriptionJson;
  thumbnail?: FeedImageThumbnailJson;
  image?: FeedImageThumbnailJson;
}

export class WMFFeedImage {
  canonicalPageTitle: string = '';                 // JSON: title
  imageDescription: string | null = null;          // JSON: description.text
  imageDescriptionIsRTL: boolean = false;
  imageThumbURL: string = '';                      // JSON: thumbnail.source
  imageURL: string = '';                           // JSON: image.source
  imageWidth: number | null = null;
  imageHeight: number | null = null;

  static fromJson(j: WMFFeedImageJson): WMFFeedImage {
    const out = new WMFFeedImage();
    out.canonicalPageTitle = j.title ?? '';
    out.imageDescription = j.description?.text ?? null;
    out.imageThumbURL = j.thumbnail?.source ?? '';
    out.imageURL = j.image?.source ?? '';
    out.imageWidth = j.image?.width ?? null;
    out.imageHeight = j.image?.height ?? null;
    return out;
  }
}

interface WMFFeedTopReadJson {
  date?: string;
  articles?: WMFFeedArticlePreviewJson[];
}

export class WMFFeedTopReadResponse {
  date: string | null = null;
  articlePreviews: WMFFeedArticlePreview[] = [];   // JSON: articles

  static fromJson(j: WMFFeedTopReadJson): WMFFeedTopReadResponse {
    const out = new WMFFeedTopReadResponse();
    out.date = j.date ?? null;
    const articles = j.articles;
    if (articles !== undefined) {
      const previews: WMFFeedArticlePreview[] = [];
      for (const article of articles) {
        previews.push(WMFFeedArticlePreview.fromJson(article));
      }
      out.articlePreviews = previews;
    }
    return out;
  }
}

export interface WMFFeedDayResponseJson {
  tfa?: WMFFeedArticlePreviewJson;
  mostread?: WMFFeedTopReadJson;
  image?: WMFFeedImageJson;
  news?: WMFFeedNewsStoryJson[];
}

export class WMFFeedDayResponse {
  maxAge: number = 0;                              // from the response Cache-Control header
  featuredArticle: WMFFeedArticlePreview | null = null;  // JSON: tfa
  topRead: WMFFeedTopReadResponse | null = null;   // JSON: mostread
  pictureOfTheDay: WMFFeedImage | null = null;     // JSON: image
  newsStories: WMFFeedNewsStory[] = [];            // JSON: news

  static fromJson(j: WMFFeedDayResponseJson): WMFFeedDayResponse {
    const out = new WMFFeedDayResponse();
    const tfa = j.tfa;
    if (tfa !== undefined) {
      out.featuredArticle = WMFFeedArticlePreview.fromJson(tfa);
    }
    const mostread = j.mostread;
    if (mostread !== undefined) {
      out.topRead = WMFFeedTopReadResponse.fromJson(mostread);
    }
    const image = j.image;
    if (image !== undefined) {
      out.pictureOfTheDay = WMFFeedImage.fromJson(image);
    }
    const news = j.news;
    if (news !== undefined) {
      const stories: WMFFeedNewsStory[] = [];
      for (const storyJson of news) {
        stories.push(WMFFeedNewsStory.fromJson(storyJson));
      }
      out.newsStories = stories;
    }
    return out;
  }
}
