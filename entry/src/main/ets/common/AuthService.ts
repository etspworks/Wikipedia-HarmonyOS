// svc_auth — ported from WMF Framework/Fetcher.swift (requestMediaWikiAPIAuthToken, TokenType),
// Wikipedia/Code/WMFAccountLoginLogoutFetcher.swift (clientlogin),
// Wikipedia/Code/WMFAccountCreator.swift (createaccount),
// Wikipedia/Code/WMFAuthAccountCreationInfoFetcher.swift (authmanagerinfo) and
// Wikipedia/Code/WMFPasswordResetter.swift (resetpassword).
// MediaWiki action API lives at https://{host}/w/api.php; auth cookies ride HttpClient's jar.

import { HttpClient } from './HttpClient';
import { WMFCurrentUser, WMFCurrentUserAuthState, WMFCurrentUserJson } from '../model/WMFCurrentUser';
import { SessionStore } from './SessionStore';
import { Prefs, WMFDataPrefKeys } from './Prefs';

// UserDefaults.Key.isUserUnawareOfLogout
const IS_USER_UNAWARE_OF_LOGOUT_KEY: string = 'WMFIsUserUnawareOfLogout';

export function mediaWikiApiURL(host: string): string {
  return 'https://' + host + '/w/api.php';
}

// Source: Fetcher.swift:491 TokenType — the API `type` value and body parameter name per token.
export class TokenType {
  static readonly csrf: string = 'csrf';
  static readonly login: string = 'login';
  static readonly createAccount: string = 'createaccount';
  static readonly watch: string = 'watch';
  static readonly rollback: string = 'rollback';

  // Source: TokenType.parameterName.
  static parameterName(type: string): string {
    if (type === TokenType.login) {
      return 'logintoken';
    }
    if (type === TokenType.createAccount) {
      return 'createtoken';
    }
    return 'token';
  }
}

interface TokensJson {
  csrftoken?: string;
  logintoken?: string;
  createaccounttoken?: string;
  watchtoken?: string;
  rollbacktoken?: string;
}

interface TokenQueryJson {
  tokens?: TokensJson;
}

interface TokenResponseJson {
  query?: TokenQueryJson;
}

// One AuthenticationRequest of a status "UI" reply: which input the server still needs.
interface ClientLoginRequestJson {
  id?: string;
  fields?: Record<string, Object>;
  metadata?: Record<string, Object>;
}

interface ClientLoginJson {
  status?: string;
  message?: string;
  messagecode?: string;
  username?: string;
  requests?: ClientLoginRequestJson[];
}

interface ClientLoginResponseJson {
  clientlogin?: ClientLoginJson;
}

interface CreateAccountJson {
  status?: string;
  message?: string;
  messagecode?: string;
  username?: string;
}

interface CreateAccountResponseJson {
  createaccount?: CreateAccountJson;
}

interface AuthFieldValueJson {
  value?: string;
}

interface AuthRequestFieldsJson {
  captchaId?: AuthFieldValueJson;
  captchaInfo?: AuthFieldValueJson;
}

interface AuthRequestJson {
  id?: string;
  fields?: AuthRequestFieldsJson;
}

interface AuthManagerInfoJson {
  canauthenticatenow?: boolean;
  cancreateaccounts?: boolean;
  requests?: AuthRequestJson[];
}

interface AuthManagerQueryJson {
  authmanagerinfo?: AuthManagerInfoJson;
}

interface AuthManagerResponseJson {
  query?: AuthManagerQueryJson;
}

interface ResetPasswordJson {
  status?: string;
}

interface ResetPasswordResponseJson {
  resetpassword?: ResetPasswordJson;
}

interface UserInfoQueryJson {
  userinfo?: WMFCurrentUserJson;
}

interface UserInfoResponseJson {
  query?: UserInfoQueryJson;
}

export class LoginResult {
  status: string = '';                             // PASS / FAIL / UI / RESTART ...
  message: string | null = null;
  messageCode: string | null = null;
  username: string | null = null;
  // status "UI": what the server asks for next (WMFAccountLoginError) —
  // 'retype' temporaryPasswordNeedsChange, 'oath' needsOathTokenFor2FA,
  // 'email' needsEmailAuthToken, '' anything else (statusNotPass).
  needs: string = '';

  get succeeded(): boolean {
    return this.status === 'PASS';
  }
}

export class AccountCreationInfo {
  canCreateAccounts: boolean = false;
  captchaID: string | null = null;
  captchaInfo: string | null = null;               // e.g. the captcha image path
}

export class AuthService {
  // Source: Fetcher.requestMediaWikiAPIAuthToken (Fetcher.swift:31) —
  // action=query, meta=tokens, type={type}.
  static async fetchToken(host: string, type: string): Promise<string> {
    const form: Record<string, string> = {
      'action': 'query',
      'meta': 'tokens',
      'type': type,
      'format': 'json'
    };
    const resp: TokenResponseJson =
      await HttpClient.postFormJson<TokenResponseJson>(mediaWikiApiURL(host), form);
    const tokens: TokensJson | undefined = resp.query?.tokens;
    let value: string | undefined = undefined;
    if (type === TokenType.login) {
      value = tokens?.logintoken;
    } else if (type === TokenType.createAccount) {
      value = tokens?.createaccounttoken;
    } else if (type === TokenType.watch) {
      value = tokens?.watchtoken;
    } else if (type === TokenType.rollback) {
      value = tokens?.rollbacktoken;
    } else {
      value = tokens?.csrftoken;
    }
    if (value === undefined || value === '') {
      throw new Error('No ' + type + ' token in response');
    }
    return value;
  }

  // Source: WMFAccountLoginLogoutFetcher.swift:94 — action=clientlogin.
  static async login(host: string, username: string, password: string,
    retypePassword: string | null, oathToken: string | null,
    captchaID: string | null, captchaWord: string | null): Promise<LoginResult> {
    return AuthService.clientLogin(host, username, password, retypePassword, oathToken,
      captchaID, captchaWord, null);
  }

  // WMFAccountLoginLogoutFetcher.login(..., attempt:, newModule:)
  private static async clientLogin(host: string, username: string, password: string,
    retypePassword: string | null, oathToken: string | null,
    captchaID: string | null, captchaWord: string | null, newModule: string | null): Promise<LoginResult> {
    const token: string = await AuthService.fetchToken(host, TokenType.login);
    // WMFDeveloperSettingsDataController.forceEmailAuth -> Session.injectEmailAuthCookie: the
    // server then asks for the emailed code on every login (testing the email step).
    // An empty value drops the cookie, so switching the setting off takes effect at once.
    HttpClient.cookieJar.ingestSetCookie(
      Prefs.getBoolean(WMFDataPrefKeys.forceEmailAuth, false) ? 'forceEmailAuth=1' : 'forceEmailAuth=');
    const form: Record<string, string> = {
      'action': 'clientlogin',
      'username': username,
      'password': password,
      'loginreturnurl': 'https://www.wikipedia.org',
      'rememberMe': '1',
      'logintoken': token,
      'format': 'json'
    };
    if (retypePassword !== null) {
      form['retype'] = retypePassword;
      form['logincontinue'] = '1';
    }
    // The source's verification screen sends its code as both: OATHToken for an
    // authenticator code, token for an emailed one (EmailAuth).
    if (oathToken !== null) {
      form['OATHToken'] = oathToken;
      form['token'] = oathToken;
      form['logincontinue'] = '1';
    }
    if (newModule !== null) {
      form['newModule'] = newModule;
      form['logincontinue'] = '1';
    }
    if (captchaID !== null) {
      form['captchaId'] = captchaID;
    }
    if (captchaWord !== null) {
      form['captchaWord'] = captchaWord;
    }
    const resp: ClientLoginResponseJson =
      await HttpClient.postFormJson<ClientLoginResponseJson>(mediaWikiApiURL(host), form);
    const clientlogin: ClientLoginJson | undefined = resp.clientlogin;
    const out = new LoginResult();
    out.status = clientlogin?.status ?? '';
    out.message = clientlogin?.message ?? null;
    out.messageCode = clientlogin?.messagecode ?? null;
    out.username = clientlogin?.username ?? null;
    if (out.status === 'UI') {
      const requests: ClientLoginRequestJson[] = clientlogin?.requests ?? [];
      out.needs = AuthService.loginNeeds(requests);
      // a choice of second factors: pick the authenticator once
      // (https://phabricator.wikimedia.org/T399654#11133473)
      if (out.needs !== 'retype' && out.needs !== 'oath' && newModule === null &&
        AuthService.allowsTotpModule(requests)) {
        return AuthService.clientLogin(host, username, password, retypePassword, oathToken,
          captchaID, captchaWord, 'totp');
      }
    }
    if (out.succeeded) {
      SessionStore.persistCookies();
      // Source: login success is followed by a userinfo fetch to populate the session.
      const user: WMFCurrentUser | null = await AuthService.fetchCurrentUser(host);
      if (user !== null) {
        SessionStore.setCurrentUser(user);
      }
    }
    return out;
  }

  // The status "UI" branches of WMFAccountLoginLogoutFetcher.login, in the source's order.
  private static loginNeeds(requests: ClientLoginRequestJson[]): string {
    const has = (suffix: string, field: string): boolean => requests.some(
      (r: ClientLoginRequestJson): boolean => (r.id ?? '').endsWith(suffix) &&
        r.fields !== undefined && r.fields[field] !== undefined);
    if (has('PasswordAuthenticationRequest', 'retype')) {
      return 'retype';
    }
    if (has('TOTPAuthenticationRequest', 'OATHToken')) {
      return 'oath';
    }
    if (has('EmailAuthAuthenticationRequest', 'token')) {
      return 'email';
    }
    return '';
  }

  private static allowsTotpModule(requests: ClientLoginRequestJson[]): boolean {
    return requests.some((r: ClientLoginRequestJson): boolean => {
      if (!(r.id ?? '').endsWith('TwoFactorModuleSelectAuthenticationRequest') || r.metadata === undefined) {
        return false;
      }
      const modules: Object | undefined = r.metadata['allowedModules'];
      return Array.isArray(modules) && (modules as string[]).indexOf('totp') >= 0;
    });
  }

  // Source: WMFAccountCreator.swift:162 — action=createaccount.
  static async createAccount(host: string, username: string, password: string,
    retypePassword: string, email: string | null,
    captchaID: string | null, captchaWord: string | null): Promise<LoginResult> {
    const token: string = await AuthService.fetchToken(host, TokenType.createAccount);
    const form: Record<string, string> = {
      'action': 'createaccount',
      'username': username,
      'password': password,
      'retype': retypePassword,
      'createreturnurl': 'https://www.wikipedia.org',
      'createmessageformat': 'html',
      'createtoken': token,
      'format': 'json'
    };
    if (email !== null) {
      form['email'] = email;
    }
    if (captchaID !== null) {
      form['captchaId'] = captchaID;
    }
    if (captchaWord !== null) {
      form['captchaWord'] = captchaWord;
    }
    const resp: CreateAccountResponseJson =
      await HttpClient.postFormJson<CreateAccountResponseJson>(mediaWikiApiURL(host), form);
    const createaccount: CreateAccountJson | undefined = resp.createaccount;
    const out = new LoginResult();
    out.status = createaccount?.status ?? '';
    out.message = createaccount?.message ?? null;
    out.messageCode = createaccount?.messagecode ?? null;
    out.username = createaccount?.username ?? null;
    return out;
  }

  // Source: WMFAuthAccountCreationInfoFetcher.swift:23 —
  // action=query, meta=authmanagerinfo, amirequestsfor=create.
  static async fetchAccountCreationInfo(host: string): Promise<AccountCreationInfo> {
    const params: Record<string, string> = {
      'action': 'query',
      'meta': 'authmanagerinfo',
      'amirequestsfor': 'create',
      'format': 'json'
    };
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), params);
    const resp: AuthManagerResponseJson = await HttpClient.getJson<AuthManagerResponseJson>(url);
    const info: AuthManagerInfoJson | undefined = resp.query?.authmanagerinfo;
    const out = new AccountCreationInfo();
    out.canCreateAccounts = info?.cancreateaccounts ?? true;
    const requests: AuthRequestJson[] = info?.requests ?? [];
    for (const request of requests) {
      const id: string = request.id ?? '';
      if (id.indexOf('CaptchaAuthenticationRequest') >= 0) {
        out.captchaID = request.fields?.captchaId?.value ?? null;
        out.captchaInfo = request.fields?.captchaInfo?.value ?? null;
      }
    }
    return out;
  }

  // Source: WMFPasswordResetter.swift:26 — action=resetpassword (csrf-tokenized POST).
  static async resetPassword(host: string, userName: string | null,
    email: string | null): Promise<string> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'resetpassword',
      'format': 'json',
      'token': token
    };
    if (userName !== null && userName !== '') {
      form['user'] = userName;
    } else if (email !== null && email !== '') {
      form['email'] = email;
    }
    const resp: ResetPasswordResponseJson =
      await HttpClient.postFormJson<ResetPasswordResponseJson>(mediaWikiApiURL(host), form);
    return resp.resetpassword?.status ?? '';
  }

  // Source: WMFCurrentUserFetcher.swift:48 — action=query, meta=userinfo|globaluserinfo.
  static async fetchCurrentUser(host: string): Promise<WMFCurrentUser | null> {
    const form: Record<string, string> = {
      'action': 'query',
      'meta': 'userinfo|globaluserinfo',
      'uiprop': 'groups|blockinfo|editcount|registrationdate',
      'format': 'json'
    };
    const resp: UserInfoResponseJson =
      await HttpClient.postFormJson<UserInfoResponseJson>(mediaWikiApiURL(host), form);
    const userinfo: WMFCurrentUserJson | undefined = resp.query?.userinfo;
    if (userinfo === undefined) {
      return null;
    }
    // Source: WMFCurrentUser.init — userID/globalUserID/name/groups/editCount/isBlocked
    // plus authState derived from anon/temp, and registrationDateString, all from userinfo.
    const out = new WMFCurrentUser();
    out.userID = userinfo.id ?? 0;
    out.globalUserID = userinfo.globalUserID ?? 0;
    out.name = userinfo.name ?? '';
    out.groups = userinfo.groups ?? [];
    out.editCount = userinfo.editcount ?? 0;
    out.isBlocked = userinfo.isBlocked ?? false;
    const isIP: boolean = userinfo.anon ?? false;
    const isTemp: boolean = userinfo.temp ?? false;
    if (isIP) {
      out.authState = WMFCurrentUserAuthState.ip;
    } else if (isTemp) {
      out.authState = WMFCurrentUserAuthState.temporary;
    } else {
      out.authState = WMFCurrentUserAuthState.permanent;
    }
    out.registrationDateString = userinfo.registrationdate ?? null;
    return out;
  }

  // WMFAuthenticationManager.attemptLogin on resume: the stored session is checked against the
  // wiki; a session the server no longer accepts is a logout the reader did not ask for
  // (logout(initiatedBy: .server) -> isUserUnawareOfLogout). The port keeps no password to log
  // back in with, so the session is cleared and the flag set for the "You have been logged
  // out" alert. A connection failure assumes the session still holds, as the source does.
  static async checkStoredSession(host: string): Promise<void> {
    if (!SessionStore.isLoggedIn) {
      return;
    }
    let user: WMFCurrentUser | null = null;
    try {
      user = await AuthService.fetchCurrentUser(host);
    } catch (e) {
      return;
    }
    if (user !== null && !user.isPermanent) {
      SessionStore.clear();
      Prefs.putBoolean(IS_USER_UNAWARE_OF_LOGOUT_KEY, true);
    }
  }

  static get isUserUnawareOfLogout(): boolean {
    return Prefs.getBoolean(IS_USER_UNAWARE_OF_LOGOUT_KEY, false);
  }

  static userDidAcknowledgeUnintentionalLogout(): void {
    Prefs.putBoolean(IS_USER_UNAWARE_OF_LOGOUT_KEY, false);
  }

  // Source: WMFAccountLoginLogoutFetcher logout — action=logout with csrf token.
  static async logout(host: string): Promise<void> {
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const form: Record<string, string> = {
      'action': 'logout',
      'token': token,
      'format': 'json'
    };
    await HttpClient.postForm(mediaWikiApiURL(host), form);
    SessionStore.clear();
  }
}
