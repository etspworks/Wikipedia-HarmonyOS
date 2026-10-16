// Deferred-task target for the daily background feed refresh — the HarmonyOS analogue of
// iOS BGTaskScheduler's "org.wikimedia.wikipedia.appRefresh" handler, which calls
// WMFExploreFeedContentController.updateFeedSources in the background.
// A WorkInfo's bundleName/abilityName must resolve to a DECLARED WorkSchedulerExtensionAbility
// (module.json5 extensionAbilities, type "workScheduler"); without one the OS rejects
// startWork in CheckExtensionInfos ("extension info is error", errCode 970000501).
// Base class + lifecycle per <sdk>/ets/api/@ohos.WorkSchedulerExtensionAbility.d.ts.
import WorkSchedulerExtensionAbility from '@ohos.WorkSchedulerExtensionAbility';
import workScheduler from '@ohos.resourceschedule.workScheduler';
import { WMFContentGroup } from '../model/WMFContentGroup';
import { WMFFeedDayResponse, WMFFeedImage, WMFFeedTopReadResponse } from '../model/WMFFeedDayResponse';
import { WMFFeedArticlePreview } from '../model/WMFFeedArticlePreview';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { FeedStore, ContentGroupKind, midnightUTCFromLocal } from '../common/FeedStore';
import { FeedService } from '../common/FeedService';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';

// ponytail: refreshes the feed/featured day sources only (tfa, mostread, image, news) —
// the same four the Explore page persists from one request. On-this-day / random / nearby
// stay foreground-only; add them here if the background card set is ever judged short.
export default class FeedRefreshExtension extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    console.info('feed-refresh: work ' + work.workId + ' started');
    this.refreshFeed().then(() => {
      console.info('feed-refresh: feed updated');
    }).catch((e: Error) => {
      console.error('feed-refresh: update failed: ' + e.message);
    });
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    console.info('feed-refresh: work ' + work.workId + ' stopped');
  }

  private async refreshFeed(): Promise<void> {
    Prefs.init(this.context);
    await Database.init(this.context);
    const lang: MWKLanguageLink = await LanguageStore.appLanguage();
    const host: string = lang.languageCode + '.wikipedia.org';
    const site: string = 'https://' + host;
    const feed: WMFFeedDayResponse = await FeedService.fetchTodayFeed(host);

    const featured: WMFFeedArticlePreview | null = feed.featuredArticle;
    if (featured !== null) {
      const json: string = JSON.stringify([featured]);
      await this.persistGroup(this.makeGroup(ContentGroupKind.FeaturedArticle, site, 1),
        json, json, 1);
    }
    const topRead: WMFFeedTopReadResponse | null = feed.topRead;
    if (topRead !== null && topRead.articlePreviews.length > 0) {
      await this.persistGroup(this.makeGroup(ContentGroupKind.TopRead, site, 2),
        JSON.stringify(topRead.articlePreviews.slice(0, 5)),
        JSON.stringify(topRead.articlePreviews), topRead.articlePreviews.length);
    }
    const potd: WMFFeedImage | null = feed.pictureOfTheDay;
    if (potd !== null) {
      const json: string = JSON.stringify(potd);
      await this.persistGroup(this.makeGroup(ContentGroupKind.PictureOfTheDay, site, 3),
        json, json, 1);
    }
    if (feed.newsStories.length > 0) {
      await this.persistGroup(this.makeGroup(ContentGroupKind.News, site, 4),
        JSON.stringify(feed.newsStories.slice(0, 3)),
        JSON.stringify(feed.newsStories), feed.newsStories.length);
    }
    Prefs.putNumber(PrefKeys.feedRefreshDate, Date.now());
  }

  private makeGroup(kind: number, site: string, sortPriority: number): WMFContentGroup {
    const g: WMFContentGroup = new WMFContentGroup();
    g.contentGroupKindInteger = kind;
    g.siteURLString = site;
    g.date = Date.now();
    g.isVisible = true;
    g.dailySortPriority = sortPriority;
    return g;
  }

  // fetchOrCreateGroup, but a group the user dismissed today stays dismissed.
  private async persistGroup(group: WMFContentGroup, previewJSON: string,
    fullJSON: string | null, count: number | null): Promise<void> {
    if (group.key === null && group.siteURLString !== null && group.date !== null) {
      group.midnightUTCDate = midnightUTCFromLocal(group.date);
      group.key = FeedStore.keyForKind(group.contentGroupKindInteger as ContentGroupKind,
        group.siteURLString, group.midnightUTCDate, group.articleURLString);
    }
    if (group.key !== null) {
      const existing: WMFContentGroup | null = await FeedStore.groupForKey(group.key);
      if (existing !== null && existing.wasDismissed) {
        return;
      }
    }
    group.contentPreviewJSON = previewJSON;
    await FeedStore.fetchOrCreateGroup(group, fullJSON, count);
  }
}
