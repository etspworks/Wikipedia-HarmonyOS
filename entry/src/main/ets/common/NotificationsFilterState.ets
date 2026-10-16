// RemoteNotificationsFilterState + RemoteNotificationsController.filterState: the
// notifications inbox filters (read status, the types and the projects turned off), kept across
// launches. The source saves it to the library store on every change (setFilterSettingsToLibrary)
// and reads it back on start (populateFilterStateFromPersistence).
import { Prefs } from './Prefs';

const FILTER_STATE_KEY: string = 'WMFNotificationsFilterState';

interface FilterStateJson {
  readStatus?: string;
  offTypes?: string[];
  offProjects?: string[];
}

// RemoteNotificationFilterType: one toggle of the filters sheet, the echo (category, type)
// pairs it stands for, its glyph and the glyph's background (imageBackgroundColorWithTheme).
export class NotificationFilterType {
  id: string;
  title: Resource;
  categories: string[];
  types: string[];
  icon: Resource;
  color: Resource;
  subtitle: Resource | null;

  constructor(id: string, title: Resource, categories: string[], types: string[], icon: Resource,
    color: Resource, subtitle: Resource | null = null) {
    this.id = id;
    this.title = title;
    this.categories = categories;
    this.types = types;
    this.icon = icon;
    this.color = color;
    this.subtitle = subtitle;
  }

  matches(category: string, type: string): boolean {
    return this.categories.indexOf(category) >= 0 && this.types.indexOf(type) >= 0;
  }
}

// RemoteNotificationFilterType.orderingForFilters
export const NOTIFICATION_FILTER_TYPES: NotificationFilterType[] = [
  new NotificationFilterType('userTalkPageMessage', $r('app.string.notifications_center_type_title_user_talk_page_messsage'),
    ['edit-user-talk'], ['edit-user-talk'], $r('app.media.notifications_type_user_talk_message'), $r('app.color.theme_link')),
  new NotificationFilterType('pageReviewed', $r('app.string.notifications_center_type_title_page_review'),
    ['page-review'], ['pagetriage-mark-as-reviewed'], $r('app.media.notifications_type_page_reviewed'), $r('app.color.theme_link')),
  new NotificationFilterType('pageLinked', $r('app.string.notifications_center_type_title_page_link'),
    ['article-linked'], ['page-linked'], $r('app.media.notifications_type_link'), $r('app.color.theme_link')),
  new NotificationFilterType('connectionWithWikidata', $r('app.string.notifications_center_type_title_connection_with_wikidata'),
    ['wikibase-action'], ['page-connection'], $r('app.media.notifications_type_link'), $r('app.color.theme_link')),
  new NotificationFilterType('emailFromOtherUser', $r('app.string.notifications_center_type_title_email_from_other_user'),
    ['emailuser'], ['emailuser'], $r('app.media.notifications_type_email'), $r('app.color.theme_link')),
  new NotificationFilterType('mentionInTalkPage', $r('app.string.notifications_center_type_title_talk_page_mention'),
    ['mention'], ['mention'], $r('app.media.notifications_type_mention'), $r('app.color.theme_link')),
  new NotificationFilterType('mentionInEditSummary', $r('app.string.notifications_center_type_title_edit_summary_mention'),
    ['mention'], ['mention-summary'], $r('app.media.notifications_type_mention'), $r('app.color.theme_link')),
  new NotificationFilterType('successfulMention', $r('app.string.notifications_center_type_title_sent_mention_success'),
    ['mention-success'], ['mention-success'], $r('app.media.notifications_type_mention'), $r('app.color.theme_link')),
  new NotificationFilterType('failedMention', $r('app.string.notifications_center_type_title_sent_mention_failure'),
    ['mention-failure'], ['mention-failure', 'mention-failure-too-many'], $r('app.media.notifications_type_mention'),
    $r('app.color.theme_warning')),
  new NotificationFilterType('userRightsChange', $r('app.string.notifications_center_type_title_user_rights_change'),
    ['user-rights'], ['user-rights'], $r('app.media.notifications_type_user_rights'), $r('app.color.theme_warning')),
  new NotificationFilterType('editReverted', $r('app.string.notifications_center_type_title_edit_reverted'),
    ['reverted'], ['reverted'], $r('app.media.notifications_type_edit_revert'), $r('app.color.theme_warning')),
  new NotificationFilterType('loginAttempts', $r('app.string.notifications_center_type_title_login_attempts'),
    ['login-fail'], ['login-fail-new', 'login-fail-known'], $r('app.media.notifications_type_login_notify'),
    $r('app.color.theme_destructive'), $r('app.string.notifications_center_type_title_login_attempts_subtitle')),
  new NotificationFilterType('loginSuccess', $r('app.string.notifications_center_type_title_login_success'),
    ['login-success'], ['login-success'], $r('app.media.notifications_type_login_notify'),
    $r('app.color.theme_destructive'), $r('app.string.notifications_center_subheader_login_success_unknown_device')),
  new NotificationFilterType('editMilestone', $r('app.string.notifications_center_type_title_edit_milestone'),
    ['thank-you-edit'], ['thank-you-edit'], $r('app.media.notifications_type_milestone'), $r('app.color.theme_accent')),
  new NotificationFilterType('translationMilestone', $r('app.string.notifications_center_type_title_translation_milestone'),
    ['cx'], ['cx-first-translation', 'cx-tenth-translation', 'cx-hundredth-translation'],
    $r('app.media.notifications_type_milestone'), $r('app.color.theme_accent')),
  new NotificationFilterType('thanks', $r('app.string.notifications_center_type_title_thanks'),
    ['edit-thank'], ['edit-thank'], $r('app.media.notifications_type_thanks'), $r('app.color.theme_accent')),
  new NotificationFilterType('welcome', $r('app.string.notifications_center_type_title_welcome'),
    ['system-noemail'], ['welcome'], $r('app.media.notifications_type_milestone'), $r('app.color.theme_accent')),
  new NotificationFilterType('other', $r('app.string.notifications_center_type_title_other'),
    [], [], $r('app.media.notifications_type_default'), $r('app.color.theme_link'))
];

// RemoteNotificationsController.predicateForFilterSavedState, the type part: with Other off
// only the turned-on types pass; otherwise everything passes except the turned-off types.
export function passesTypeFilter(offTypes: string[], category: string, type: string): boolean {
  if (offTypes.length === 0) {
    return true;
  }
  const on: NotificationFilterType[] = NOTIFICATION_FILTER_TYPES.filter((t: NotificationFilterType) =>
    offTypes.indexOf(t.id) < 0);
  if (on.length === 0) {
    return false;
  }
  if (offTypes.indexOf('other') >= 0) {
    return on.some((t: NotificationFilterType) => t.matches(category, type));
  }
  return !NOTIFICATION_FILTER_TYPES.some((t: NotificationFilterType) =>
    offTypes.indexOf(t.id) >= 0 && t.matches(category, type));
}

export class NotificationsFilterState {
  // 'all' | 'read' | 'unread'
  readStatus: string = 'all';
  // NotificationFilterType ids turned off
  offTypes: string[] = [];
  // the Echo wiki ids filtered out (enwiki, commonswiki, ...)
  offProjects: string[] = [];

  static load(): NotificationsFilterState {
    const state = new NotificationsFilterState();
    try {
      const j: FilterStateJson = JSON.parse(Prefs.getString(FILTER_STATE_KEY, '{}')) as FilterStateJson;
      state.readStatus = j.readStatus ?? 'all';
      state.offTypes = j.offTypes ?? [];
      state.offProjects = j.offProjects ?? [];
    } catch (e) {
      console.error('notifications: filter state unreadable: ' + (e as Error).message);
    }
    return state;
  }

  static save(readStatus: string, offTypes: string[], offProjects: string[]): void {
    const j: FilterStateJson = { readStatus: readStatus, offTypes: offTypes, offProjects: offProjects };
    Prefs.putString(FILTER_STATE_KEY, JSON.stringify(j));
  }
}
