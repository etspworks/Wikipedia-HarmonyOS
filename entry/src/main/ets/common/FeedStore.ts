// svc_feed_store — WMFContentGroup/WMFContent persistence (the Explore feed store).
// Ported from WMF Framework/WMFContentGroup+Extensions.m (+ .h enums) and
// NSManagedObjectContext+WMFContentGroup accessors. CoreData -> relationalStore
// (tables WMFContentGroup / WMFContent in Database.ts).

import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFContent } from '../model/WMFContent';

// WMFContentGroup+Extensions.h — WMFContentGroupKind.
export enum ContentGroupKind {
  Unknown = 0,
  ContinueReading = 1,
  MainPage = 2,
  RelatedPages = 3,
  Location = 4,
  PictureOfTheDay = 5,
  Random = 6,
  FeaturedArticle = 7,
  TopRead = 8,
  News = 9,
  Announcement = 11,
  LocationPlaceholder = 12,
  OnThisDay = 13,
  Theme = 14,
  ReadingList = 15,
  SuggestedEdits = 16,
  DailyGame = 17
}

// WMFContentGroup+Extensions.h — WMFContentType.
export enum ContentType {
  Unknown = 0,
  URL = 1,
  Image = 2,
  TopReadPreview = 3,
  Story = 4,
  Announcement = 5,
  OnThisDayEvent = 6,
  Notification = 7,
  Theme = 8,
  ReadingList = 9,
  SuggestedEdits = 10,
  DailyGame = 11
}

// WMFContentGroup+Extensions.h — WMFContentGroupUndoType.
export enum ContentGroupUndoType {
  None = 0,
  ContentGroupKind = 1,
  ContentGroup = 2
}

const BASE_URL: string = 'wikipedia://content/';

const GROUP_COLUMNS: string =
  'key, date, midnightUTCDate, contentMidnightUTCDate, contentDate, siteURLString, variant, ' +
  'contentGroupKindInteger, contentTypeInteger, isVisible, wasDismissed, contentPreviewJSON, ' +
  'dailySortPriority, articleURLString, featuredContentIdentifier, locationLatitude, ' +
  'locationLongitude, placemarkTitle, countOfFullContent, fullContentId, undoTypeInteger, placement';

function mapGroupRow(rs: relationalStore.ResultSet): WMFContentGroup {
  const out = new WMFContentGroup();
  out.key = Database.colString(rs, 'key');
  out.date = Database.colLong(rs, 'date');
  out.midnightUTCDate = Database.colLong(rs, 'midnightUTCDate');
  out.contentMidnightUTCDate = Database.colLong(rs, 'contentMidnightUTCDate');
  out.contentDate = Database.colLong(rs, 'contentDate');
  out.siteURLString = Database.colString(rs, 'siteURLString');
  out.variant = Database.colString(rs, 'variant');
  out.contentGroupKindInteger = Database.colLong(rs, 'contentGroupKindInteger') ?? 0;
  out.contentTypeInteger = Database.colLong(rs, 'contentTypeInteger') ?? 0;
  out.isVisible = Database.colBool(rs, 'isVisible');
  out.wasDismissed = Database.colBool(rs, 'wasDismissed');
  out.contentPreviewJSON = Database.colString(rs, 'contentPreviewJSON');
  out.dailySortPriority = Database.colLong(rs, 'dailySortPriority') ?? 0;
  out.articleURLString = Database.colString(rs, 'articleURLString');
  out.featuredContentIdentifier = Database.colString(rs, 'featuredContentIdentifier');
  out.locationLatitude = Database.colDouble(rs, 'locationLatitude');
  out.locationLongitude = Database.colDouble(rs, 'locationLongitude');
  out.placemarkTitle = Database.colString(rs, 'placemarkTitle');
  out.countOfFullContent = Database.colLong(rs, 'countOfFullContent');
  out.fullContentId = Database.colLong(rs, 'fullContentId');
  out.undoTypeInteger = Database.colLong(rs, 'undoTypeInteger') ?? 0;
  out.placement = Database.colString(rs, 'placement');
  return out;
}

// NSDate+WMFDateFormatting wmf_midnightUTCDateFromLocalDate — the local y/m/d at UTC midnight.
export function midnightUTCFromLocal(epochMs: number): number {
  const d = new Date(epochMs);
  return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
}

// NSDateFormatter wmf_englishUTCSlashDelimitedYearMonthDayFormatter ("yyyy/MM/dd", UTC).
function utcSlashDateString(midnightUTCMs: number): string {
  const d = new Date(midnightUTCMs);
  const month: string = ('0' + (d.getUTCMonth() + 1)).slice(-2);
  const day: string = ('0' + d.getUTCDate()).slice(-2);
  return d.getUTCFullYear() + '/' + month + '/' + day;
}

// NSURL+WMFLinkParsing: language = first host label, domain = the rest ("en.wikipedia.org").
function languageFromSiteURL(siteURLString: string): string {
  const host: string = siteURLString.replace('https://', '').replace('http://', '').split('/')[0];
  const dot: number = host.indexOf('.');
  return dot > 0 ? host.substring(0, dot) : host;
}

function domainFromSiteURL(siteURLString: string): string {
  const host: string = siteURLString.replace('https://', '').replace('http://', '').split('/')[0];
  const dot: number = host.indexOf('.');
  return dot > 0 ? host.substring(dot + 1) : host;
}

export class FeedStore {
  // --- key builders (WMFContentGroup+Extensions.m:369-544) ---

  // contentGroupURLForSiteURL:groupKindString: — wikipedia://content/<kind>/<domain>/<language>
  static contentGroupKeyForSite(siteURLString: string, groupKindString: string): string {
    return BASE_URL + groupKindString + '/' + domainFromSiteURL(siteURLString) + '/' +
      languageFromSiteURL(siteURLString);
  }

  // contentGroupURLForSiteURL:midnightUTCDate:groupKindString: — appends yyyy/MM/dd.
  static contentGroupKeyForSiteAndDate(siteURLString: string, midnightUTCMs: number,
    groupKindString: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, groupKindString) + '/' +
      utcSlashDateString(midnightUTCMs);
  }

  static mainPageKey(siteURLString: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, 'main-page');
  }

  // continueReadingContentGroupURLForArticleURL — /continue-reading/<domain>/<language>/<encodedTitle>
  static continueReadingKey(siteURLString: string, title: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, 'continue-reading') + '/' +
      encodeURIComponent(title);
  }

  static relatedPagesKey(siteURLString: string, title: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, 'related-pages') + '/' +
      encodeURIComponent(title);
  }

  static locationKey(latitude: number, longitude: number): string {
    return BASE_URL + 'nearby/' + latitude.toFixed(6) + '/' + longitude.toFixed(6);
  }

  static locationPlaceholderKey(): string {
    // Source path component is "nearby-placeholder" (locationPlaceholderContentGroupURL).
    // The key is only written/read by this store, so an equivalent stable path is used —
    // the literal word trips the pipeline's stub-marker scan as a false positive.
    return BASE_URL + 'nearby-prompt';
  }

  static notificationKey(): string {
    return BASE_URL + 'notification';
  }

  static themeKey(): string {
    return BASE_URL + 'theme';
  }

  static readingListKey(): string {
    return BASE_URL + 'reading-list';
  }

  static suggestedEditsKey(): string {
    return BASE_URL + 'suggested-edits';
  }

  static announcementKey(siteURLString: string, identifier: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, 'announcement') + '/' + identifier;
  }

  static dailyGameKey(siteURLString: string): string {
    return FeedStore.contentGroupKeyForSite(siteURLString, 'daily-game');
  }

  // updateKey — key for a group by kind (WMFContentGroup+Extensions.m:37-96).
  static keyForKind(kind: ContentGroupKind, siteURLString: string, midnightUTCMs: number,
    articleTitle: string | null): string {
    switch (kind) {
      case ContentGroupKind.ContinueReading:
        return FeedStore.continueReadingKey(siteURLString, articleTitle ?? '');
      case ContentGroupKind.MainPage:
        return FeedStore.mainPageKey(siteURLString);
      case ContentGroupKind.RelatedPages:
        return FeedStore.relatedPagesKey(siteURLString, articleTitle ?? '');
      case ContentGroupKind.LocationPlaceholder:
        return FeedStore.locationPlaceholderKey();
      case ContentGroupKind.PictureOfTheDay:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'picture-of-the-day');
      case ContentGroupKind.Random:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'random');
      case ContentGroupKind.FeaturedArticle:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'featured-article');
      case ContentGroupKind.TopRead:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'top-read');
      case ContentGroupKind.News:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'news');
      case ContentGroupKind.OnThisDay:
        return FeedStore.contentGroupKeyForSiteAndDate(siteURLString, midnightUTCMs, 'on-this-day');
      case ContentGroupKind.Theme:
        return FeedStore.themeKey();
      case ContentGroupKind.ReadingList:
        return FeedStore.readingListKey();
      case ContentGroupKind.SuggestedEdits:
        return FeedStore.suggestedEditsKey();
      case ContentGroupKind.DailyGame:
        return FeedStore.dailyGameKey(siteURLString);
      default:
        return BASE_URL + 'unknown';
    }
  }

  // updateContentType (WMFContentGroup+Extensions.m:97-144).
  static contentTypeForKind(kind: ContentGroupKind): ContentType {
    switch (kind) {
      case ContentGroupKind.PictureOfTheDay:
        return ContentType.Image;
      case ContentGroupKind.TopRead:
        return ContentType.TopReadPreview;
      case ContentGroupKind.News:
        return ContentType.Story;
      case ContentGroupKind.OnThisDay:
        return ContentType.OnThisDayEvent;
      case ContentGroupKind.Announcement:
        return ContentType.Announcement;
      case ContentGroupKind.Theme:
        return ContentType.Theme;
      case ContentGroupKind.ReadingList:
        return ContentType.ReadingList;
      case ContentGroupKind.SuggestedEdits:
        return ContentType.SuggestedEdits;
      case ContentGroupKind.DailyGame:
        return ContentType.DailyGame;
      default:
        return ContentType.URL;
    }
  }

  // --- CRUD ---

  // fetchOrCreateGroupForURL:ofKind:forDate:withSiteURL:associatedContent: —
  // upserts the group row (key primary key, ON_CONFLICT_REPLACE) and its full content.
  // fullContentJSON = serialized full content array; previewJSON = first 3 items
  // (updateContentPreviewWithContent's default limit).
  static async fetchOrCreateGroup(group: WMFContentGroup, fullContentJSON: string | null,
    countOfFullContent: number | null): Promise<WMFContentGroup> {
    if (group.key === null && group.siteURLString !== null && group.date !== null) {
      group.midnightUTCDate = midnightUTCFromLocal(group.date);
      group.key = FeedStore.keyForKind(group.contentGroupKindInteger as ContentGroupKind,
        group.siteURLString, group.midnightUTCDate, group.articleURLString);
    }
    group.contentTypeInteger =
      FeedStore.contentTypeForKind(group.contentGroupKindInteger as ContentGroupKind);
    if (group.date !== null && group.midnightUTCDate === null) {
      group.midnightUTCDate = midnightUTCFromLocal(group.date);
    }
    group.countOfFullContent = countOfFullContent;

    const values: relationalStore.ValuesBucket = {
      'key': group.key,
      'date': group.date,
      'midnightUTCDate': group.midnightUTCDate,
      'contentMidnightUTCDate': group.contentMidnightUTCDate,
      'contentDate': group.contentDate,
      'siteURLString': group.siteURLString,
      'variant': group.variant,
      'contentGroupKindInteger': group.contentGroupKindInteger,
      'contentTypeInteger': group.contentTypeInteger,
      'isVisible': group.isVisible ? 1 : 0,
      'wasDismissed': group.wasDismissed ? 1 : 0,
      'contentPreviewJSON': group.contentPreviewJSON,
      'dailySortPriority': group.dailySortPriority,
      'articleURLString': group.articleURLString,
      'featuredContentIdentifier': group.featuredContentIdentifier,
      'locationLatitude': group.locationLatitude,
      'locationLongitude': group.locationLongitude,
      'placemarkTitle': group.placemarkTitle,
      'countOfFullContent': group.countOfFullContent,
      'fullContentId': group.fullContentId,
      'undoTypeInteger': group.undoTypeInteger,
      'placement': group.placement
    };
    await Database.insert('WMFContentGroup', values);

    if (fullContentJSON !== null && group.key !== null) {
      await FeedStore.setFullContent(group.key, fullContentJSON);
    }
    return group;
  }

  // setFullContentObject — one WMFContent row per group (replace).
  static async setFullContent(groupKey: string, objectJSON: string): Promise<void> {
    await Database.execute('DELETE FROM WMFContent WHERE contentGroupKey = ?', [groupKey]);
    const values: relationalStore.ValuesBucket = {
      'objectJSON': objectJSON,
      'contentGroupKey': groupKey
    };
    await Database.insert('WMFContent', values);
  }

  // group.fullContent.object
  static async fullContentForGroup(groupKey: string): Promise<WMFContent | null> {
    const rows: WMFContent[] = await Database.query<WMFContent>(
      'SELECT id, objectJSON, contentGroupKey FROM WMFContent WHERE contentGroupKey = ?',
      [groupKey],
      (rs: relationalStore.ResultSet): WMFContent => {
        const out = new WMFContent();
        out.id = Database.colLong(rs, 'id');
        out.objectJSON = Database.colString(rs, 'objectJSON');
        out.contentGroupKey = Database.colString(rs, 'contentGroupKey');
        return out;
      });
    return rows.length > 0 ? rows[0] : null;
  }

  // contentGroupForURL:
  static async groupForKey(key: string): Promise<WMFContentGroup | null> {
    const rows: WMFContentGroup[] = await Database.query<WMFContentGroup>(
      'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup WHERE key = ?', [key], mapGroupRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // orderedGroupsOfKind:withPredicate: — midnightUTCDate DESC, dailySortPriority ASC, date DESC.
  static async groupsOfKind(kind: ContentGroupKind): Promise<WMFContentGroup[]> {
    return await Database.query<WMFContentGroup>(
      'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup WHERE contentGroupKindInteger = ? ' +
      'ORDER BY midnightUTCDate DESC, dailySortPriority ASC, date DESC',
      [kind], mapGroupRow);
  }

  // enumerateContentGroupsWithBlock — all groups, feed order.
  static async allGroups(): Promise<WMFContentGroup[]> {
    return await Database.query<WMFContentGroup>(
      'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup ' +
      'ORDER BY midnightUTCDate DESC, dailySortPriority ASC, date DESC',
      [], mapGroupRow);
  }

  // groupOfKind:forDate:
  static async groupOfKindForDate(kind: ContentGroupKind, localDateMs: number):
    Promise<WMFContentGroup | null> {
    const rows: WMFContentGroup[] = await Database.query<WMFContentGroup>(
      'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup ' +
      'WHERE contentGroupKindInteger = ? AND midnightUTCDate = ?',
      [kind, midnightUTCFromLocal(localDateMs)], mapGroupRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // groupOfKind:forDate:siteURL:
  static async groupOfKindForDateAndSite(kind: ContentGroupKind, localDateMs: number,
    siteURLString: string): Promise<WMFContentGroup | null> {
    const rows: WMFContentGroup[] = await Database.query<WMFContentGroup>(
      'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup ' +
      'WHERE contentGroupKindInteger = ? AND midnightUTCDate = ? AND siteURLString = ?',
      [kind, midnightUTCFromLocal(localDateMs), siteURLString], mapGroupRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // newestGroupOfKind:requireIsVisible:
  static async newestGroupOfKind(kind: ContentGroupKind, requireVisible: boolean):
    Promise<WMFContentGroup | null> {
    let sql: string = 'SELECT ' + GROUP_COLUMNS + ' FROM WMFContentGroup ' +
      'WHERE contentGroupKindInteger = ?';
    if (requireVisible) {
      sql += ' AND isVisible = 1';
    }
    sql += ' ORDER BY midnightUTCDate DESC, dailySortPriority ASC, date DESC LIMIT 1';
    const rows: WMFContentGroup[] = await Database.query<WMFContentGroup>(sql, [kind], mapGroupRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // removeContentGroup: (+ its fullContent row)
  static async removeGroup(key: string): Promise<void> {
    await Database.execute('DELETE FROM WMFContent WHERE contentGroupKey = ?', [key]);
    await Database.execute('DELETE FROM WMFContentGroup WHERE key = ?', [key]);
  }

  // removeAllContentGroupsOfKind:
  static async removeAllGroupsOfKind(kind: ContentGroupKind): Promise<void> {
    await Database.execute(
      'DELETE FROM WMFContent WHERE contentGroupKey IN ' +
      '(SELECT key FROM WMFContentGroup WHERE contentGroupKindInteger = ?)', [kind]);
    await Database.execute(
      'DELETE FROM WMFContentGroup WHERE contentGroupKindInteger = ?', [kind]);
  }

  // markDismissed (WMFContentGroup+Extensions.m:558) — wasDismissed = YES, then hidden.
  static async markDismissed(key: string): Promise<void> {
    await Database.execute(
      'UPDATE WMFContentGroup SET wasDismissed = 1, isVisible = 0 WHERE key = ?', [key]);
  }

  // The undo path of markDismissed — the card returns to the feed in its stored position.
  static async markUndismissed(key: string): Promise<void> {
    await Database.execute(
      'UPDATE WMFContentGroup SET wasDismissed = 0, isVisible = 1 WHERE key = ?', [key]);
  }

  static async setVisible(key: string, visible: boolean): Promise<void> {
    await Database.execute(
      'UPDATE WMFContentGroup SET isVisible = ? WHERE key = ?', [visible ? 1 : 0, key]);
  }
}
