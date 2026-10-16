// svc_metrics — ported from Wikipedia/Code/WMFFeedContentFetcher.m:152 (pageviews/per-article
// on the wikimedia.org metrics REST API, Configuration.swift:263) and
// WMF Framework/Event Platform/EventPlatformClient.swift:191-223 (EventGate intake URIs +
// streamconfigs). Intake POSTs are raw JSON, so they go over @ohos.net.http directly
// (HttpClient only exposes form/GET); the request is destroyed in finally.

import { http } from '@kit.NetworkKit';
import { HttpClient, versionedUserAgent } from './HttpClient';
import { Prefs } from './Prefs';

// Source: EventPlatformClient.swift:191-205.
const ANALYTICS_INTAKE_URL: string = 'https://intake-analytics.wikimedia.org/v1/events';
const ANALYTICS_INTAKE_BETA_URL: string = 'https://intake-analytics-beta.wmflabs.org/v1/events';
const LOGGING_INTAKE_URL: string = 'https://intake-logging.wikimedia.org/v1/events';
const LOGGING_INTAKE_BETA_URL: string = 'https://intake-logging-beta.wmflabs.org/v1/events';

// Source: EventPlatformClient.swift:223.
const STREAM_CONFIGS_URL: string =
  'https://meta.wikimedia.org/w/api.php?action=streamconfigs&format=json';

interface PageviewItemJson {
  timestamp?: string;                              // YYYYMMDDHH
  views?: number;
}

interface PageviewsResponseJson {
  items?: PageviewItemJson[];
}

interface StreamSamplingJson {
  rate?: number;
  identifier?: string;
}

interface StreamConfigurationJson {
  destination_event_service?: string;
  sampling?: StreamSamplingJson;
}

interface StreamConfigsResponseJson {
  streams?: Record<string, StreamConfigurationJson>;
}

export class PageviewDay {
  timestamp: string = '';                          // YYYYMMDDHH from the metrics API
  views: number = 0;
}

export class StreamConfig {
  stream: string = '';
  destinationEventService: string | null = null;
  samplingRate: number | null = null;
  samplingIdentifier: string | null = null;
}

export class PageviewMetricsService {
  // When true the intake POSTs go to the beta hosts
  // (source: WMFDeveloperSettingsDataController.shared.sendAnalyticsToWMFLabs).
  static get useBetaIntake(): boolean {
    return Prefs.getBoolean('dev-settings-send-analytics-to-wmflabs', false);
  }

  static analyticsIntakeURL(): string {
    return PageviewMetricsService.useBetaIntake ? ANALYTICS_INTAKE_BETA_URL : ANALYTICS_INTAKE_URL;
  }

  static loggingIntakeURL(): string {
    return PageviewMetricsService.useBetaIntake ? LOGGING_INTAKE_BETA_URL : LOGGING_INTAKE_URL;
  }

  // Source: WMFFeedContentFetcher.m:159 — path ["pageviews","per-article",
  // "{lang}.{domain}", "all-access", "user", title, "daily", start, end] on
  // https://wikimedia.org/api/rest_v1/metrics/ (Configuration.swift:263).
  // Dates are YYYYMMDDHH ("2026010100") the way the source formatter emits them.
  static async fetchPageviews(languageCode: string, domain: string, title: string,
    startDate: string, endDate: string): Promise<PageviewDay[]> {
    const encodedTitle: string = encodeURIComponent(title.replace(/ /g, '_'));
    const url: string = 'https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/' +
      languageCode + '.' + domain + '/all-access/user/' + encodedTitle + '/daily/' +
      startDate + '/' + endDate;
    const resp: PageviewsResponseJson = await HttpClient.getJson<PageviewsResponseJson>(url);
    const out: PageviewDay[] = [];
    const items: PageviewItemJson[] = resp.items ?? [];
    for (const item of items) {
      const day = new PageviewDay();
      day.timestamp = item.timestamp ?? '';
      day.views = item.views ?? 0;
      out.push(day);
    }
    return out;
  }

  // Source: EventPlatformClient.swift:223 — stream configurations from Meta wiki.
  static async fetchStreamConfigs(): Promise<StreamConfig[]> {
    const resp: StreamConfigsResponseJson =
      await HttpClient.getJson<StreamConfigsResponseJson>(STREAM_CONFIGS_URL);
    const out: StreamConfig[] = [];
    const streams: Record<string, StreamConfigurationJson> | undefined = resp.streams;
    if (streams === undefined) {
      return out;
    }
    const keys: string[] = Object.keys(streams);
    for (const key of keys) {
      const raw: StreamConfigurationJson = streams[key];
      const config = new StreamConfig();
      config.stream = key;
      config.destinationEventService = raw.destination_event_service ?? null;
      config.samplingRate = raw.sampling?.rate ?? null;
      config.samplingIdentifier = raw.sampling?.identifier ?? null;
      out.push(config);
    }
    return out;
  }

  // Source: EventPlatformClient.postEvents — the intake accepts a JSON array of events.
  // eventsJson is the serialized array; toLoggingIntake picks the logging EventGate.
  static async submitEvents(eventsJson: string, toLoggingIntake: boolean): Promise<boolean> {
    const url: string = toLoggingIntake ?
      PageviewMetricsService.loggingIntakeURL() : PageviewMetricsService.analyticsIntakeURL();
    const req = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'User-Agent': versionedUserAgent()
      };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: eventsJson,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      };
      const resp: http.HttpResponse = await req.request(url, options);
      return resp.responseCode >= 200 && resp.responseCode < 300;
    } catch (e) {
      // Source: event submission failures are swallowed (analytics must never break the app).
      return false;
    } finally {
      req.destroy();
    }
  }
}
