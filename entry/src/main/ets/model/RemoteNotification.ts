// Ported from WMF Framework/Remote Notifications/Model/RemoteNotification+CoreDataProperties.swift
// and RemoteNotificationLinks.swift.

export class RemoteNotificationLink {
  type: string | null = null;
  url: string | null = null;
  label: string | null = null;
}

export class RemoteNotificationLinks {
  primary: RemoteNotificationLink | null = null;
  secondary: RemoteNotificationLink[] = [];
  legacyPrimary: RemoteNotificationLink | null = null;
}

export interface RemoteNotificationRow {
  agentId?: string;
  agentName?: string;
  categoryString?: string;
  date?: number;
  id?: string;
  isRead?: number;
  key?: string;
  messageBody?: string;
  messageHeader?: string;
  messageLinksJSON?: string;
  section?: string;
  titleFull?: string;
  titleNamespace?: string;
  titleNamespaceKey?: number;
  titleText?: string;
  typeString?: string;
  utcUnixString?: string;
  wiki?: string;
  revisionID?: string;
}

interface RemoteNotificationLinkJson {
  type?: string;
  url?: string;
  label?: string;
}

interface RemoteNotificationLinksJson {
  primary?: RemoteNotificationLinkJson;
  secondary?: RemoteNotificationLinkJson[];
  legacyPrimary?: RemoteNotificationLinkJson;
}

function linkFromJson(j: RemoteNotificationLinkJson): RemoteNotificationLink {
  const out = new RemoteNotificationLink();
  out.type = j.type ?? null;
  out.url = j.url ?? null;
  out.label = j.label ?? null;
  return out;
}

export class RemoteNotification {
  agentId: string | null = null;
  agentName: string | null = null;
  categoryString: string | null = null;
  date: number | null = null;                      // epoch ms
  id: string | null = null;
  isRead: boolean = false;
  key: string | null = null;
  messageBody: string | null = null;
  messageHeader: string | null = null;
  messageLinks: RemoteNotificationLinks | null = null;
  section: string | null = null;
  titleFull: string | null = null;
  titleNamespace: string | null = null;
  titleNamespaceKey: number = 0;
  titleText: string | null = null;
  typeString: string | null = null;
  utcUnixString: string | null = null;
  wiki: string | null = null;
  revisionID: string | null = null;

  static fromRow(r: RemoteNotificationRow): RemoteNotification {
    const out = new RemoteNotification();
    out.agentId = r.agentId ?? null;
    out.agentName = r.agentName ?? null;
    out.categoryString = r.categoryString ?? null;
    out.date = r.date ?? null;
    out.id = r.id ?? null;
    out.isRead = (r.isRead ?? 0) !== 0;
    out.key = r.key ?? null;
    out.messageBody = r.messageBody ?? null;
    out.messageHeader = r.messageHeader ?? null;
    out.messageLinks = RemoteNotification.linksFromJsonString(r.messageLinksJSON ?? null);
    out.section = r.section ?? null;
    out.titleFull = r.titleFull ?? null;
    out.titleNamespace = r.titleNamespace ?? null;
    out.titleNamespaceKey = r.titleNamespaceKey ?? 0;
    out.titleText = r.titleText ?? null;
    out.typeString = r.typeString ?? null;
    out.utcUnixString = r.utcUnixString ?? null;
    out.wiki = r.wiki ?? null;
    out.revisionID = r.revisionID ?? null;
    return out;
  }

  static linksFromJsonString(s: string | null): RemoteNotificationLinks | null {
    if (s === null || s === '') {
      return null;
    }
    const j: RemoteNotificationLinksJson = JSON.parse(s) as RemoteNotificationLinksJson;
    const out = new RemoteNotificationLinks();
    // Echo sends null for a missing link (and null entries in secondary): skip them
    if (j.primary !== undefined && j.primary !== null) {
      out.primary = linkFromJson(j.primary);
    }
    if (j.legacyPrimary !== undefined && j.legacyPrimary !== null) {
      out.legacyPrimary = linkFromJson(j.legacyPrimary);
    }
    const secondary = j.secondary;
    if (secondary !== undefined && secondary !== null) {
      const list: RemoteNotificationLink[] = [];
      for (const item of secondary) {
        if (item !== null) {
          list.push(linkFromJson(item));
        }
      }
      out.secondary = list;
    }
    return out;
  }
}
