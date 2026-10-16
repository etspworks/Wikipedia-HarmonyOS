// svc_feed — ported from Wikipedia/Code/WMFFeedContentFetcher.m:53 (feed/featured/{y}/{m}/{d}),
// WMF Framework/WMFOnThisDayEventsFetcher.m:31 (feed/onthisday/events/{MM}/{DD}) and
// WMF Framework/WMFAnnouncementsFetcher.m:16 (feed/announcements, "announce" array).
// All live on the wiki host's RESTBase: https://{host}/api/rest_v1/.

import { HttpClient } from './HttpClient';
import { WMFFeedDayResponse, WMFFeedDayResponseJson } from '../model/WMFFeedDayResponse';
import { WMFFeedOnThisDayEvent, WMFFeedOnThisDayEventJson } from '../model/WMFFeedOnThisDayEvent';
import { WMFAnnouncement, WMFAnnouncementJson } from '../model/WMFAnnouncement';

function restBase(host: string): string {
  return 'https://' + host + '/api/rest_v1';
}

function pad2(value: number): string {
  if (value < 10) {
    return '0' + String(value);
  }
  return String(value);
}

interface OnThisDayResponseJson {
  events?: WMFFeedOnThisDayEventJson[];
}

interface AnnouncementsResponseJson {
  announce?: WMFAnnouncementJson[];
}

export class FeedService {
  // Source: WMFFeedContentFetcher.m:53 — path ["feed","featured",year,month,day].
  static async fetchFeedDay(host: string, year: number, month: number,
    day: number): Promise<WMFFeedDayResponse> {
    const url: string = restBase(host) + '/feed/featured/' + String(year) + '/' +
      pad2(month) + '/' + pad2(day);
    const j: WMFFeedDayResponseJson = await HttpClient.getJson<WMFFeedDayResponseJson>(url);
    return WMFFeedDayResponse.fromJson(j);
  }

  static async fetchTodayFeed(host: string): Promise<WMFFeedDayResponse> {
    const now = new Date();
    const feed: WMFFeedDayResponse = await FeedService.fetchFeedDay(host, now.getUTCFullYear(),
      now.getUTCMonth() + 1, now.getUTCDate());
    // `mostread` is computed from the PREVIOUS day's pageviews and is not attached to today's
    // feed until that dump has been processed, so for the first hours of each UTC day the
    // endpoint answers today's feed with no mostread at all and the Top read card silently
    // disappeared. The card's own content is yesterday's reading anyway, so fall back to
    // yesterday's feed for it, exactly as its subtitle promises.
    if (feed.topRead === null || feed.topRead.articlePreviews.length === 0) {
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      try {
        const previous: WMFFeedDayResponse = await FeedService.fetchFeedDay(host,
          yesterday.getUTCFullYear(), yesterday.getUTCMonth() + 1, yesterday.getUTCDate());
        if (previous.topRead !== null && previous.topRead.articlePreviews.length > 0) {
          feed.topRead = previous.topRead;
        }
      } catch (e) {
        // No top-read card today; every other section of the feed still stands.
        console.error('feed: top-read fallback failed: ' + (e as Error).message);
      }
    }
    return feed;
  }

  // Source: WMFOnThisDayEventsFetcher.m:31 — path ["feed","onthisday","events",MM,DD];
  // events parsed from the "events" key (line 45). siteURL/language are propagated onto
  // each event the way the serializer's languageVariantCode propagation does.
  static async fetchOnThisDayEvents(host: string, languageCode: string, month: number,
    day: number): Promise<WMFFeedOnThisDayEvent[]> {
    const url: string = restBase(host) + '/feed/onthisday/events/' + pad2(month) + '/' + pad2(day);
    const j: OnThisDayResponseJson = await HttpClient.getJson<OnThisDayResponseJson>(url);
    const out: WMFFeedOnThisDayEvent[] = [];
    const events: WMFFeedOnThisDayEventJson[] = j.events ?? [];
    let index: number = 0;
    for (const eventJson of events) {
      const event: WMFFeedOnThisDayEvent = WMFFeedOnThisDayEvent.fromJson(eventJson);
      event.siteURL = 'https://' + host;
      event.languageCode = languageCode;
      event.contentLanguageCode = languageCode;
      event.index = index;
      event.score = null;
      index++;
      out.push(event);
    }
    return out;
  }

  // Source: WMFAnnouncementsFetcher.m:16 — path ["feed","announcements"], "announce" array,
  // filtered to the current platform the way filterAnnouncementsForiOSPlatform does.
  static async fetchAnnouncements(host: string): Promise<WMFAnnouncement[]> {
    const url: string = restBase(host) + '/feed/announcements';
    const j: AnnouncementsResponseJson = await HttpClient.getJson<AnnouncementsResponseJson>(url);
    const out: WMFAnnouncement[] = [];
    const announcements: WMFAnnouncementJson[] = j.announce ?? [];
    for (const announcementJson of announcements) {
      const announcement: WMFAnnouncement = WMFAnnouncement.fromJson(announcementJson);
      // Source filters on platforms containing "iOSV4"; the ported app keeps the iOS
      // platform channel since the payloads are platform-keyed server-side.
      if (announcement.platforms.length === 0 ||
        announcement.platforms.indexOf('iOSV4') >= 0) {
        out.push(announcement);
      }
    }
    return out;
  }
}
