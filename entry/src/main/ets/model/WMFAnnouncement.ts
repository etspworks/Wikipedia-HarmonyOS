// Ported from WMF Framework/WMFAnnouncement.h/.m (MTLJSONSerializing key paths, version 4).

interface AnnouncementActionJson {
  title?: string;
  url?: string;
}

export interface WMFAnnouncementJson {
  id?: string;
  type?: string;
  start_time?: string;
  end_time?: string;
  platforms?: string[];
  countries?: string[];
  placement?: string;
  image_url?: string;
  image?: string;
  image_height?: number;
  text?: string;
  action?: AnnouncementActionJson;
  caption_HTML?: string;
  negative_text?: string;
  reading_list_sync_enabled?: boolean;
  logged_in?: boolean;
  beta?: boolean;
  domain?: string;
  articleTitles?: string[];
  percent_receiving_experiment?: number;
  displayDelay?: number;
}

export class WMFAnnouncement {
  identifier: string | null = null;                // JSON: id
  type: string | null = null;
  startTime: string | null = null;                 // JSON: start_time (ISO 8601)
  endTime: string | null = null;                   // JSON: end_time
  platforms: string[] = [];
  countries: string[] = [];
  placement: string | null = null;
  imageURL: string | null = null;                  // JSON: image ?? image_url
  imageHeight: number | null = null;               // JSON: image_height
  text: string | null = null;
  actionTitle: string | null = null;               // JSON: action.title
  actionURLString: string | null = null;           // JSON: action.url
  captionHTML: string | null = null;               // JSON: caption_HTML
  negativeText: string | null = null;              // JSON: negative_text
  readingListSyncEnabled: boolean | null = null;   // JSON: reading_list_sync_enabled
  loggedIn: boolean | null = null;                 // JSON: logged_in
  beta: boolean | null = null;
  domain: string | null = null;
  articleTitles: string[] = [];
  percentReceivingExperiment: number | null = null;
  displayDelay: number | null = null;

  get actionURL(): string | null {
    return this.actionURLString;
  }

  static fromJson(j: WMFAnnouncementJson): WMFAnnouncement {
    const out = new WMFAnnouncement();
    out.identifier = j.id ?? null;
    out.type = j.type ?? null;
    out.startTime = j.start_time ?? null;
    out.endTime = j.end_time ?? null;
    out.platforms = j.platforms ?? [];
    out.countries = j.countries ?? [];
    out.placement = j.placement ?? null;
    out.imageURL = j.image ?? j.image_url ?? null;
    out.imageHeight = j.image_height ?? null;
    out.text = j.text ?? null;
    out.actionTitle = j.action?.title ?? null;
    out.actionURLString = j.action?.url ?? null;
    out.captionHTML = j.caption_HTML ?? null;
    out.negativeText = j.negative_text ?? null;
    out.readingListSyncEnabled = j.reading_list_sync_enabled ?? null;
    out.loggedIn = j.logged_in ?? null;
    out.beta = j.beta ?? null;
    out.domain = j.domain ?? null;
    out.articleTitles = j.articleTitles ?? [];
    out.percentReceivingExperiment = j.percent_receiving_experiment ?? null;
    out.displayDelay = j.displayDelay ?? null;
    return out;
  }
}
