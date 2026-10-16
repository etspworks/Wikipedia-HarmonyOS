// Ported from Wikipedia/Code/MediaList.swift.

import { MediaListItem, MediaListItemJson, MediaListItemSource, MediaListItemType } from './MediaListItem';

export interface MediaListJson {
  items?: MediaListItemJson[];
}

export class MediaList {
  items: MediaListItem[] = [];

  static fromJson(j: MediaListJson): MediaList {
    const out = new MediaList();
    const itemsJson = j.items;
    if (itemsJson !== undefined) {
      const items: MediaListItem[] = [];
      for (const itemJson of itemsJson) {
        items.push(MediaListItem.fromJson(itemJson));
      }
      out.items = items;
    }
    return out;
  }

  // Source: init?(from url:) — single-image MediaList for a gallery opened on one image URL.
  static fromSingleImageURL(imageURL: string, imageName: string): MediaList {
    const out = new MediaList();
    const item = new MediaListItem();
    item.title = 'File:' + imageName;
    item.sectionID = 0;
    item.type = MediaListItemType.image;
    item.showInGallery = true;
    item.isLeadImage = true;
    const scales: string[] = ['1x', '2x', '1.5x'];
    const sources: MediaListItemSource[] = [];
    for (const scale of scales) {
      const src = new MediaListItemSource();
      src.urlString = imageURL;
      src.scale = scale;
      sources.push(src);
    }
    item.sources = sources;
    out.items = [item];
    return out;
  }
}
