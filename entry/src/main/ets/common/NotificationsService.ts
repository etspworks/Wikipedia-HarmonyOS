// svc_notifications — ported from
// WMF Framework/Remote Notifications/RemoteNotificationsAPIController.swift:409
// (meta=notifications, notformat=model), :438 (echomarkread) and
// Wikipedia/Code/EchoSubscriptionFetcher.swift:16 (echopushsubscriptions).
// Fetched notifications are persisted into the RemoteNotification table (Database.ts),
// which the notifications screen reads — the same read/write split the CoreData store had.
// Echo puts the message model under the "*" key and the title namespace key under
// "namespace-key" — neither is a legal ArkTS property name, so those keys are renamed in the
// response text before parsing ("*" -> "starMessage", "namespace-key" -> "namespaceKey").

import { relationalStore } from '@kit.ArkData';
import { notificationManager } from '@kit.NotificationKit';
import { HttpClient } from './HttpClient';
import { AuthService, TokenType, mediaWikiApiURL } from './AuthService';
import { Database } from './Database';
import { RemoteNotification, RemoteNotificationRow } from '../model/RemoteNotification';
import { SessionStore } from './SessionStore';
import { LanguageStore } from './LanguageStore';

// AppStorage: the account's unread notifications across all projects. The profile buttons draw
// their red dot from it and the profile sheet its count.
export const UNREAD_NOTIFICATIONS_KEY: string = 'wmfUnreadNotifications';

interface EchoCountJson {
  rawcount?: number;
}

interface EchoCountQueryJson {
  notifications?: EchoCountJson;
}

interface EchoCountResponseJson {
  query?: EchoCountQueryJson;
}

interface EchoTimestampJson {
  utcunix?: string;
  utciso8601?: string;
}

interface EchoTitleJson {
  full?: string;
  text?: string;
  namespace?: string;
  namespaceKey?: number;                           // JSON: "namespace-key" (renamed pre-parse)
}

interface EchoAgentJson {
  id?: number;
  name?: string;
}

interface EchoMessageJson {
  header?: string;
  body?: string;
  links?: object;
}

interface EchoItemJson {
  wiki?: string;
  id?: number;
  type?: string;
  category?: string;
  section?: string;
  timestamp?: EchoTimestampJson;
  title?: EchoTitleJson;
  agent?: EchoAgentJson;
  revid?: number;
  read?: string;                                   // present (a timestamp) when read
  starMessage?: EchoMessageJson;                   // JSON: "*" (renamed pre-parse)
}

interface EchoNotificationsJson {
  list?: EchoItemJson[];
  notcontinue?: string;
}

interface EchoQueryJson {
  notifications?: EchoNotificationsJson;
}

interface EchoResponseJson {
  query?: EchoQueryJson;
}

export class NotificationsPage {
  notifications: RemoteNotification[] = [];
  continueId: string | null = null;
}

export class NotificationsService {
  // RemoteNotificationsController.numberOfUnreadNotifications, which the source keeps current
  // from its background sync: the Echo unread count on every project (notprop=count). When Echo
  // gives no count (offline, or an expired session answering login-required) it is the unread
  // rows of the local store, which is what the source counts. Logged out the count is 0.
  static async refreshUnreadCount(): Promise<number> {
    let count: number | undefined = 0;
    if (SessionStore.currentUser.value !== null) {
      try {
        const host: string = (await LanguageStore.appLanguage()).languageCode + '.wikipedia.org';
        const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
          'action': 'query', 'meta': 'notifications', 'notprop': 'count', 'notfilter': '!read',
          'notwikis': '*', 'format': 'json', 'formatversion': '2'
        });
        const resp: EchoCountResponseJson = await HttpClient.getJson<EchoCountResponseJson>(url);
        count = resp.query?.notifications?.rawcount;
      } catch (e) {
        console.warn('notifications: unread count unavailable: ' + JSON.stringify(e));
        count = undefined;
      }
      if (count === undefined) {
        try {
          count = await Database.queryCount('SELECT COUNT(*) FROM RemoteNotification WHERE isRead = 0', []);
        } catch (e) {
          count = AppStorage.get<number>(UNREAD_NOTIFICATIONS_KEY) ?? 0;
        }
      }
    }
    const unread: number = count ?? 0;
    AppStorage.setOrCreate<number>(UNREAD_NOTIFICATIONS_KEY, unread);
    // WMFAppViewController: setBadgeCount(numberOfUnreadNotifications) — the app icon badge
    notificationManager.setBadgeNumber(unread).catch((e: Error) => {
      console.warn('notifications: setting the app badge failed: ' + JSON.stringify(e));
    });
    return unread;
  }

  // Source: RemoteNotificationsAPIController.swift:409 — action=query, meta=notifications,
  // notformat=model, notfilter=read|!read, notwikis=* (all projects).
  static async fetchNotifications(host: string,
    continueId: string | null): Promise<NotificationsPage> {
    const params: Record<string, string> = {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'notformat': 'model',
      'meta': 'notifications',
      'notlimit': '50',
      'notfilter': 'read|!read',
      'notwikis': '*'
    };
    if (continueId !== null) {
      params['notcontinue'] = continueId;
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    let text: string = await HttpClient.getText(url, null);
    // "*" and "namespace-key" are not legal ArkTS property names — rename before parsing.
    text = text.split('"*":').join('"starMessage":');
    text = text.split('"namespace-key":').join('"namespaceKey":');
    const resp: EchoResponseJson = HttpClient.parseJson<EchoResponseJson>(text);

    const out = new NotificationsPage();
    const listJson: EchoItemJson[] = resp.query?.notifications?.list ?? [];
    for (const item of listJson) {
      out.notifications.push(NotificationsService.notificationFromEchoItem(item));
    }
    out.continueId = resp.query?.notifications?.notcontinue ?? null;
    return out;
  }

  // Maps one Echo item (notformat=model) onto RemoteNotification, filling every field the
  // source Notification CodingKeys map fills (message lives under "*", renamed starMessage).
  private static notificationFromEchoItem(item: EchoItemJson): RemoteNotification {
    const wiki: string = item.wiki ?? '';
    const idString: string = item.id === undefined ? '' : String(item.id);
    const utcUnix: string = item.timestamp?.utcunix ?? '';
    const message: EchoMessageJson | undefined = item.starMessage;

    const row: RemoteNotificationRow = {
      agentId: item.agent?.id === undefined ? '' : String(item.agent.id),
      agentName: item.agent?.name ?? '',
      categoryString: item.category ?? '',
      date: utcUnix === '' ? 0 : Number(utcUnix) * 1000,
      id: idString,
      isRead: item.read !== undefined && item.read !== '' ? 1 : 0,
      key: wiki + '-' + idString,                  // source: key = "{wiki}-{id}"
      messageBody: message?.body ?? '',
      messageHeader: message?.header ?? '',
      messageLinksJSON: message?.links === undefined ? '' : JSON.stringify(message.links),
      section: item.section ?? '',
      titleFull: item.title?.full ?? '',
      titleNamespace: item.title?.namespace ?? '',
      titleNamespaceKey: item.title?.namespaceKey ?? 0,
      titleText: item.title?.text ?? '',
      typeString: item.type ?? '',
      utcUnixString: utcUnix,
      wiki: wiki,
      revisionID: item.revid === undefined ? '' : String(item.revid)
    };
    return RemoteNotification.fromRow(row);
  }

  // Write path: persist a fetched page into the RemoteNotification table.
  static async saveNotifications(notifications: RemoteNotification[]): Promise<void> {
    for (const notification of notifications) {
      const values: relationalStore.ValuesBucket = {
        'id': notification.id,
        'wiki': notification.wiki,
        'key': notification.key,
        'agentId': notification.agentId,
        'agentName': notification.agentName,
        'categoryString': notification.categoryString,
        'date': notification.date,
        'isRead': notification.isRead ? 1 : 0,
        'messageBody': notification.messageBody,
        'messageHeader': notification.messageHeader,
        'messageLinksJSON': notification.messageLinks === null ?
          '' : JSON.stringify(notification.messageLinks),
        'section': notification.section,
        'titleFull': notification.titleFull,
        'titleNamespace': notification.titleNamespace,
        'titleNamespaceKey': notification.titleNamespaceKey,
        'titleText': notification.titleText,
        'typeString': notification.typeString,
        'utcUnixString': notification.utcUnixString,
        'revisionID': notification.revisionID
      };
      await Database.insert('RemoteNotification', values);
    }
  }

  static async cachedNotifications(): Promise<RemoteNotification[]> {
    return await Database.query<RemoteNotification>(
      'SELECT * FROM RemoteNotification ORDER BY date DESC', [],
      (rs: relationalStore.ResultSet): RemoteNotification => {
        const row: RemoteNotificationRow = {
          agentId: Database.colString(rs, 'agentId') ?? '',
          agentName: Database.colString(rs, 'agentName') ?? '',
          categoryString: Database.colString(rs, 'categoryString') ?? '',
          date: Database.colLong(rs, 'date') ?? 0,
          id: Database.colString(rs, 'id') ?? '',
          isRead: Database.colBool(rs, 'isRead') ? 1 : 0,
          key: Database.colString(rs, 'key') ?? '',
          messageBody: Database.colString(rs, 'messageBody') ?? '',
          messageHeader: Database.colString(rs, 'messageHeader') ?? '',
          messageLinksJSON: Database.colString(rs, 'messageLinksJSON') ?? '',
          section: Database.colString(rs, 'section') ?? '',
          titleFull: Database.colString(rs, 'titleFull') ?? '',
          titleNamespace: Database.colString(rs, 'titleNamespace') ?? '',
          titleNamespaceKey: Database.colLong(rs, 'titleNamespaceKey') ?? 0,
          titleText: Database.colString(rs, 'titleText') ?? '',
          typeString: Database.colString(rs, 'typeString') ?? '',
          utcUnixString: Database.colString(rs, 'utcUnixString') ?? '',
          wiki: Database.colString(rs, 'wiki') ?? '',
          revisionID: Database.colString(rs, 'revisionID') ?? ''
        };
        return RemoteNotification.fromRow(row);
      });
  }

  // Source: RemoteNotificationsAPIController.swift:438 — action=echomarkread with a csrf
  // token; list (mark read) or unreadlist (mark unread) of "{id}|{id}" identifiers.
  static async markReadOrUnread(host: string, ids: string[],
    markRead: boolean): Promise<boolean> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'echomarkread',
      'format': 'json',
      'token': token
    };
    if (markRead) {
      form['list'] = ids.join('|');
    } else {
      form['unreadlist'] = ids.join('|');
    }
    await HttpClient.postForm(mediaWikiApiURL(host), form);
    // Mirror into the local store so the list renders the new state offline.
    for (const id of ids) {
      await Database.execute('UPDATE RemoteNotification SET isRead = ? WHERE id = ?',
        [markRead ? 1 : 0, id]);
    }
    return true;
  }

  // Source: RemoteNotificationsAPIController.swift:458 — action=echomarkseen, type=all.
  static async markAllSeen(host: string): Promise<void> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'echomarkseen',
      'format': 'json',
      'type': 'all',
      'token': token
    };
    await HttpClient.postForm(mediaWikiApiURL(host), form);
  }

  // Source: EchoSubscriptionFetcher.swift:16 — action=echopushsubscriptions command=create.
  // HarmonyOS self-signed builds have no push provider, so the subscription is recorded
  // server-side only when the caller supplies a provider token; it never blocks the app.
  static async subscribePush(host: string, providerToken: string,
    topic: string): Promise<boolean> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'echopushsubscriptions',
      'format': 'json',
      'command': 'create',
      'provider': 'apns',
      'providertoken': providerToken,
      'topic': topic,
      'token': token
    };
    try {
      await HttpClient.postForm(mediaWikiApiURL(host), form);
      return true;
    } catch (e) {
      return false;
    }
  }
}
