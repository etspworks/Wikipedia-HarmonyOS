// svc_cache_store — saved-article downloader/offline cache. Ported from
// WMF Framework/CacheController.swift + ArticleCacheController (Cache.xcdatamodeld:
// CacheGroup / CacheItem, response bodies stored as files keyed by item key).
// The mobile-html body is written under filesDir/articlecache/, and CacheGroup /
// CacheItem / CacheGroupItem rows (Database.ts) record what is downloaded.

import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { ArticleService } from './ArticleService';
import { CacheItem, CacheItemRow } from '../model/CacheGroupCacheItem';

const CACHE_DIR_NAME: string = 'articlecache';

// Stable file name for an item key (the source names files by a sha of the item key).
function fileNameForKey(key: string): string {
  let hash: number = 0;
  for (let i = 0; i < key.length; i++) {
    hash = ((hash << 5) - hash + key.charCodeAt(i)) | 0;
  }
  return 'item_' + (hash >>> 0).toString(16) + '.html';
}

export class ArticleCacheStore {
  private static cacheDir: string = '';

  static init(context: common.Context): void {
    ArticleCacheStore.cacheDir = context.filesDir + '/' + CACHE_DIR_NAME;
    if (!fileIo.accessSync(ArticleCacheStore.cacheDir)) {
      fileIo.mkdirSync(ArticleCacheStore.cacheDir);
    }
  }

  private static pathForKey(key: string): string {
    return ArticleCacheStore.cacheDir + '/' + fileNameForKey(key);
  }

  // Source: ArticleCacheController.add — download mobile-html, persist body + DB rows.
  // groupKey/itemKey are the article key (https://{host}/wiki/{title}), like the source.
  static async saveArticle(host: string, title: string): Promise<void> {
    const key: string = 'https://' + host + '/wiki/' + title.replace(/ /g, '_');
    const html: string = await ArticleService.fetchMobileHtml(host, title);
    const path: string = ArticleCacheStore.pathForKey(key);
    const file: fileIo.File = fileIo.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, html);
    } finally {
      fileIo.closeSync(file);
    }
    const itemValues: relationalStore.ValuesBucket = {
      'key': key,
      'date': Date.now(),
      'isDownloaded': 1,
      'url': ArticleService.mobileHtmlURL(host, title),
      'variant': null
    };
    await Database.insert('CacheItem', itemValues);
    const groupValues: relationalStore.ValuesBucket = { 'key': key };
    await Database.insert('CacheGroup', groupValues);
    const joinValues: relationalStore.ValuesBucket = {
      'groupKey': key,
      'itemKey': key,
      'mustHave': 1
    };
    await Database.insert('CacheGroupItem', joinValues);
  }

  static async isCached(articleKey: string): Promise<boolean> {
    const count: number = await Database.queryCount(
      'SELECT COUNT(*) FROM CacheItem WHERE key = ? AND isDownloaded = 1', [articleKey]);
    return count > 0;
  }

  // Returns the cached mobile-html body, or null when the article is not cached.
  static async cachedHtml(articleKey: string): Promise<string | null> {
    const cached: boolean = await ArticleCacheStore.isCached(articleKey);
    if (!cached) {
      return null;
    }
    const path: string = ArticleCacheStore.pathForKey(articleKey);
    if (!fileIo.accessSync(path)) {
      return null;
    }
    return fileIo.readTextSync(path);
  }

  static async cachedItems(): Promise<CacheItem[]> {
    return await Database.query<CacheItem>(
      'SELECT * FROM CacheItem WHERE isDownloaded = 1 ORDER BY date DESC', [],
      (rs: relationalStore.ResultSet): CacheItem => {
        const row: CacheItemRow = {
          key: Database.colString(rs, 'key') ?? '',
          date: Database.colLong(rs, 'date') ?? 0,
          isDownloaded: Database.colBool(rs, 'isDownloaded') ? 1 : 0,
          url: Database.colString(rs, 'url') ?? '',
          variant: Database.colString(rs, 'variant') ?? ''
        };
        return CacheItem.fromRow(row);
      });
  }

  // Source: ArticleCacheController.remove — delete the file and every row for the group.
  static async removeArticle(articleKey: string): Promise<void> {
    const path: string = ArticleCacheStore.pathForKey(articleKey);
    if (fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
    }
    await Database.execute('DELETE FROM CacheGroupItem WHERE groupKey = ?', [articleKey]);
    await Database.execute('DELETE FROM CacheGroup WHERE key = ?', [articleKey]);
    await Database.execute('DELETE FROM CacheItem WHERE key = ?', [articleKey]);
  }
}
