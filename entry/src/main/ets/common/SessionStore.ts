// svc_session — login session + current user state.
// Ported from WMF Framework/UserSession.swift + Wikipedia/Code/Session.swift semantics:
// iOS keeps the CentralAuth session in URLSession's cookie store and the current user in
// memory; here the cookie jar and user snapshot persist through Prefs and publish through
// a BehaviorSubject so pages can react to login/logout.

import { WMFCurrentUser, WMFCurrentUserAuthState, WMFCurrentUserJson } from '../model/WMFCurrentUser';
import { HttpClient } from './HttpClient';
import { Prefs } from './Prefs';
import { BehaviorSubject } from './Reactive';
import { webview } from '@kit.ArkWeb';
import { notificationManager } from '@kit.NotificationKit';

const KEY_SESSION_COOKIES: string = 'wmf-session-cookies';
const KEY_CURRENT_USER_JSON: string = 'wmf-current-user-json';

export class SessionStore {
  // the preference keys that carry the login (kept out of Export User Data, as the source drops
  // its container's Library)
  static readonly privateKeys: string[] = [KEY_SESSION_COOKIES, KEY_CURRENT_USER_JSON];

  static readonly currentUser: BehaviorSubject<WMFCurrentUser | null> =
    new BehaviorSubject<WMFCurrentUser | null>(null);

  static get isLoggedIn(): boolean {
    const user = SessionStore.currentUser.value;
    return user !== null && user.isPermanent;
  }

  // Call after Prefs.init: restores cookies + the last known user.
  static restore(): void {
    const cookies: string = Prefs.getString(KEY_SESSION_COOKIES, '');
    HttpClient.cookieJar.restore(cookies);
    const userJson: string = Prefs.getString(KEY_CURRENT_USER_JSON, '');
    if (userJson !== '') {
      const j: WMFCurrentUserJson = JSON.parse(userJson) as WMFCurrentUserJson;
      SessionStore.currentUser.next(WMFCurrentUser.fromJson(j));
    }
  }

  // Persist the cookie jar (call after any auth-changing request).
  static persistCookies(): void {
    Prefs.putString(KEY_SESSION_COOKIES, HttpClient.cookieJar.serialize());
  }

  static setCurrentUser(user: WMFCurrentUser): void {
    const j: WMFCurrentUserJson = {
      id: user.userID,
      globalUserID: user.globalUserID,
      name: user.name,
      groups: user.groups,
      editcount: user.editCount,
      isBlocked: user.isBlocked,
      anon: user.authState === WMFCurrentUserAuthState.ip,
      temp: user.authState === WMFCurrentUserAuthState.temporary,
      registrationdate: user.registrationDateString ?? undefined
    };
    Prefs.putString(KEY_CURRENT_USER_JSON, JSON.stringify(j));
    SessionStore.currentUser.next(user);
    SessionStore.persistCookies();
  }

  // Source: logout clears the CentralAuth session and the user snapshot.
  static clear(): void {
    HttpClient.cookieJar.clear();
    // the web views got a copy of the session (SinglePageWebViewController): drop it too, or
    // a wiki page opened after logout would still show the user logged in
    try {
      webview.WebCookieManager.clearAllCookiesSync();
    } catch (e) {
      console.error('session: clearing web cookies failed: ' + (e as Error).message);
    }
    Prefs.remove(KEY_SESSION_COOKIES);
    Prefs.remove(KEY_CURRENT_USER_JSON);
    SessionStore.currentUser.next(null);
    // WMFAppViewController logout: setBadgeCount(0)
    notificationManager.setBadgeNumber(0).catch((e: Error) => {
      console.warn('session: clearing the app badge failed: ' + JSON.stringify(e));
    });
  }
}
