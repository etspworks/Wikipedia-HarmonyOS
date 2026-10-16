// svc_http — shared HTTP client over @ohos.net.http.
// Ported from Wikipedia/Code/Session.swift (default headers) and
// Wikipedia/Code/WikipediaAppUtils.m (versionedUserAgent). Keeps a cookie jar so the
// CentralAuth login session survives across requests (URLSession did this implicitly on iOS).

import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';

let appVersionCache: string = '';

// NSBundle+WMFInfoUtils wmf_appVersion: "<CFBundleVersion>-<env>-<CFBundleShortVersionString with
// dots as dashes>". The port carries the iOS release it was made from in its own bundle:
// versionCode = the iOS build number (betas/6144), versionName = the date-based iOS version
// (2026.08.11), so this reads "6144-r-2026-08-11" - what the App Store app of that release shows
// on About and sends in its User-Agent. Always "r": the source's dev/alpha labels mark iOS build
// channels this port does not have.
export function appVersion(): string {
  if (appVersionCache === '') {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      appVersionCache = String(info.versionCode) + '-r-' + info.versionName.split('.').join('-');
    } catch (e) {
      hilog.error(0x0000, 'http', 'bundle info failed: %{public}s', (e as Error).message);
      return '0-r-0-0-0';
    }
  }
  return appVersionCache;
}

// Source: "WikipediaApp/<version> (iOS <ver>; <form factor>)" — platform adjusted.
export function versionedUserAgent(): string {
  return 'WikipediaApp/' + appVersion() + ' (HarmonyOS; Phone)';
}

export class HttpError extends Error {
  responseCode: number;

  constructor(message: string, responseCode: number) {
    super(message);
    this.responseCode = responseCode;
  }
}

export class HttpTextResponse {
  responseCode: number = 0;
  body: string = '';
  cookies: string = '';
}

// In-memory cookie jar keyed by cookie name (Wikipedia auth cookies are host-family wide).
// SessionStore persists/restores it across launches.
export class CookieJar {
  private cookies: Map<string, string> = new Map<string, string>();

  headerValue(): string {
    const parts: string[] = [];
    this.cookies.forEach((value: string, name: string) => {
      parts.push(name + '=' + value);
    });
    return parts.join('; ');
  }

  // Accepts the raw Set-Cookie payload(s) of one response.
  ingestSetCookie(setCookie: string): void {
    const lines: string[] = setCookie.split('\n');
    for (const line of lines) {
      const first: string = line.split(';')[0];
      const eq: number = first.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name: string = first.substring(0, eq).trim();
      const value: string = first.substring(eq + 1).trim();
      if (value === 'deleted' || value === '') {
        this.cookies.delete(name);
      } else {
        this.cookies.set(name, value);
      }
    }
  }

  serialize(): string {
    const parts: string[] = [];
    this.cookies.forEach((value: string, name: string) => {
      parts.push(name + '=' + value);
    });
    return parts.join('\n');
  }

  restore(serialized: string): void {
    this.cookies.clear();
    if (serialized === '') {
      return;
    }
    const lines: string[] = serialized.split('\n');
    for (const line of lines) {
      const eq: number = line.indexOf('=');
      if (eq > 0) {
        this.cookies.set(line.substring(0, eq), line.substring(eq + 1));
      }
    }
  }

  clear(): void {
    this.cookies.clear();
  }
}

export class HttpClient {
  static readonly cookieJar: CookieJar = new CookieJar();
  static acceptLanguage: string = 'en';

  // Source Session.swift default headers.
  private static defaultHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': 'application/json; charset=utf-8',
      'Accept-Language': HttpClient.acceptLanguage,
      'User-Agent': versionedUserAgent()
    };
    const cookie: string = HttpClient.cookieJar.headerValue();
    if (cookie !== '') {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  private static async requestText(url: string, method: http.RequestMethod,
    extraHeaders: Record<string, string> | null, body: string | null): Promise<HttpTextResponse> {
    const req = http.createHttp();
    try {
      const headers: Record<string, string> = HttpClient.defaultHeaders();
      if (extraHeaders !== null) {
        for (const key of Object.keys(extraHeaders)) {
          headers[key] = extraHeaders[key];
        }
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      };
      if (body !== null) {
        options.extraData = body;
      }
      // Logged BEFORE the await as well as after: a request that throws (no network, TLS,
      // timeout) never reaches the response line, and 'the app never tried' has to stay
      // distinguishable from 'the app tried and failed' in the evidence.
      hilog.info(0x0000, 'HttpClient', 'request %{public}s', url);
      const resp: http.HttpResponse = await req.request(url, options);
      const out = new HttpTextResponse();
      out.responseCode = resp.responseCode;
      out.body = resp.result as string;
      // One line per request — the app's only network trace. The device-side feature
      // asserts (golden_path.py, evidence_collect.py) read the hilog window to tell a
      // real fetch from a screen that merely rendered, and nothing else emits a URL.
      hilog.info(0x0000, 'HttpClient', '%{public}d %{public}s', out.responseCode, url);
      // Repeated Set-Cookie headers come back as a string[] in resp.header (single one as
      // a string) — normalize before ingesting, or .split() throws on the array.
      const respHeaders = resp.header as Record<string, string | string[]>;
      const rawSetCookie: string | string[] | undefined =
        respHeaders['set-cookie'] ?? respHeaders['Set-Cookie'];
      if (rawSetCookie !== undefined) {
        const setCookie: string = Array.isArray(rawSetCookie) ?
          (rawSetCookie as string[]).join('\n') : rawSetCookie as string;
        HttpClient.cookieJar.ingestSetCookie(setCookie);
        out.cookies = setCookie;
      }
      if (out.responseCode >= 400) {
        throw new HttpError('HTTP ' + out.responseCode + ' for ' + url, out.responseCode);
      }
      return out;
    } finally {
      req.destroy();
    }
  }

  static async getText(url: string, extraHeaders: Record<string, string> | null): Promise<string> {
    const resp = await HttpClient.requestText(url, http.RequestMethod.GET, extraHeaders, null);
    return resp.body;
  }

  static async getJson<T>(url: string): Promise<T> {
    const text: string = await HttpClient.getText(url, null);
    return HttpClient.parseJson<T>(text);
  }

  // application/x-www-form-urlencoded POST (the MediaWiki action API shape).
  static async postForm(url: string, form: Record<string, string>): Promise<string> {
    const parts: string[] = [];
    for (const key of Object.keys(form)) {
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(form[key]));
    }
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded'
    };
    const resp = await HttpClient.requestText(url, http.RequestMethod.POST, headers, parts.join('&'));
    return resp.body;
  }

  // A JSON body POST that answers with text (the PCS transform endpoints).
  static async postJsonForText(url: string, body: Object, extraHeaders: Record<string, string>): Promise<string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    for (const key of Object.keys(extraHeaders)) {
      headers[key] = extraHeaders[key];
    }
    const resp = await HttpClient.requestText(url, http.RequestMethod.POST, headers, JSON.stringify(body));
    return resp.body;
  }

  // A JSON body PUT (the GrowthExperiments REST feedback endpoint).
  static async putJsonForText(url: string, body: Object, extraHeaders: Record<string, string>): Promise<string> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    for (const key of Object.keys(extraHeaders)) {
      headers[key] = extraHeaders[key];
    }
    const resp = await HttpClient.requestText(url, http.RequestMethod.PUT, headers, JSON.stringify(body));
    return resp.body;
  }

  static async postFormJson<T>(url: string, form: Record<string, string>): Promise<T> {
    const text: string = await HttpClient.postForm(url, form);
    return HttpClient.parseJson<T>(text);
  }

  static parseJson<T>(text: string): T {
    return JSON.parse(text) as T;
  }

  // Builds "<base>?a=b&c=d" with encoded values.
  static buildURL(base: string, query: Record<string, string>): string {
    const parts: string[] = [];
    for (const key of Object.keys(query)) {
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(query[key]));
    }
    if (parts.length === 0) {
      return base;
    }
    return base + '?' + parts.join('&');
  }
}
