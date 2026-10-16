// Ported from Wikipedia/Code/MediaList.swift (MediaListItem + nested source/original types).

export enum MediaListItemType {
  image = 'image',
  audio = 'audio',
  video = 'video'
}

export class MediaListItemSource {
  urlString: string = '';                          // JSON: src
  scale: string = '';
}

export class MediaListItemOriginal {
  source: string = '';
}

interface MediaListItemSourceJson {
  src?: string;
  scale?: string;
}

interface MediaListItemOriginalJson {
  source?: string;
}

export interface MediaListItemJson {
  title?: string;
  section_id?: number;
  type?: string;
  showInGallery?: boolean;
  leadImage?: boolean;
  srcset?: MediaListItemSourceJson[];
  original?: MediaListItemOriginalJson;
  audioType?: string;
}

export class MediaListItem {
  title: string | null = null;
  sectionID: number = 0;                           // JSON: section_id
  type: MediaListItemType = MediaListItemType.image;
  showInGallery: boolean = false;
  isLeadImage: boolean = false;                    // JSON: leadImage
  sources: MediaListItemSource[] = [];             // JSON: srcset
  original: MediaListItemOriginal | null = null;
  audioType: string | null = null;

  static fromJson(j: MediaListItemJson): MediaListItem {
    const out = new MediaListItem();
    out.title = j.title ?? null;
    out.sectionID = j.section_id ?? 0;
    const typeString: string = j.type ?? 'image';
    if (typeString === 'audio') {
      out.type = MediaListItemType.audio;
    } else if (typeString === 'video') {
      out.type = MediaListItemType.video;
    } else {
      out.type = MediaListItemType.image;
    }
    out.showInGallery = j.showInGallery ?? false;
    out.isLeadImage = j.leadImage ?? false;
    const srcset = j.srcset;
    if (srcset !== undefined) {
      const sources: MediaListItemSource[] = [];
      for (const s of srcset) {
        const src = new MediaListItemSource();
        src.urlString = s.src ?? '';
        src.scale = s.scale ?? '';
        sources.push(src);
      }
      out.sources = sources;
    }
    const originalJson = j.original;
    if (originalJson !== undefined) {
      const original = new MediaListItemOriginal();
      original.source = originalJson.source ?? '';
      out.original = original;
    }
    out.audioType = j.audioType ?? null;
    return out;
  }
}
