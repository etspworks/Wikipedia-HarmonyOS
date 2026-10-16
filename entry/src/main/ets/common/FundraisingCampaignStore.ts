// WMFFundraisingCampaignDataController: the apps campaign config at
// donate.wikimedia.org/w/index.php?title=MediaWiki:AppsCampaignConfig.json&action=raw, cached;
// the active asset for the reader's country, the article's wiki language and today
// (version 3, iOS platform, inside its dates), one A/B asset picked per install by the
// config's weights; and the prompt state (Maybe later until tomorrow, or hidden for good).
import { HttpClient, appVersion } from './HttpClient';
import { Prefs, WMFDataPrefKeys } from './Prefs';
import { util } from '@kit.ArkTS';

const CONFIG_URL: string =
  'https://donate.wikimedia.org/w/index.php?title=MediaWiki:AppsCampaignConfig.json&action=raw';
const CONFIG_CACHE_KEY: string = 'fundraising-campaign-config';
const PROMPT_STATE_KEY: string = 'fundraising-campaign-prompt-state';
// WMFFundraisingCampaignConfigResponse.currentVersion
const CURRENT_VERSION: number = 3;

interface ActionJson {
  title?: string;
  url?: string;
}

interface AssetJson {
  id?: string;
  weight?: number;
  text?: string;
  footer?: string;
  actions?: ActionJson[];
  currency_code?: string;
}

interface ConfigJson {
  id?: string;
  start_time?: string;
  end_time?: string;
  version?: number;
  countries?: string[];
  platforms?: Record<string, Object>;
  assets?: Record<string, AssetJson[]>;
}

interface PromptState {
  campaignID: string;
  isHidden: boolean;
  maybeLaterDate: number | null;
}

export class CampaignAction {
  title: string = '';
  url: string = '';
}

// WMFFundraisingCampaignConfig.WMFAsset
export class CampaignAsset {
  id: string = '';
  assetID: string = '';
  textHtml: string = '';
  footerHtml: string = '';
  actions: CampaignAction[] = [];
  countryCode: string = '';
  languageCode: string = '';
  endDate: number = 0;

  get metricsID(): string {
    return this.assetID !== '' ? `${this.languageCode}${this.countryCode}_${this.id}_${this.assetID}_iOS`
      : `${this.languageCode}${this.countryCode}_${this.id}_iOS`;
  }
}

// stableHash01: FNV-1a 64-bit over the seed, mapped to [0, 1)
function stableHash01(seed: string): number {
  let hash: bigint = BigInt('1469598103934665603');
  const prime: bigint = BigInt('1099511628211');
  const mask: bigint = (BigInt(1) << BigInt(64)) - BigInt(1);
  for (const byte of Array.from(new util.TextEncoder().encodeInto(seed))) {
    hash = hash ^ BigInt(byte);
    hash = (hash * prime) & mask;
  }
  return Number(hash) / Number(mask);
}

// randomAssetFrom(assets:seed:): weighted, deterministic per install; the first asset when the
// weights are missing or do not add up to 1
function pickAsset(assets: AssetJson[], seed: string): AssetJson {
  const weights: number[] = assets.map((a: AssetJson) => a.weight ?? -1);
  if (weights.some((w: number) => w < 0)) {
    return assets[0];
  }
  const sum: number = weights.reduce((a: number, b: number) => a + b, 0);
  if (Math.abs(sum - 1) >= 1e-6) {
    return assets[0];
  }
  const roll: number = stableHash01(seed);
  let running: number = 0;
  for (let i = 0; i < weights.length; i++) {
    running += weights[i];
    if (roll <= running || i === weights.length - 1) {
      return assets[i];
    }
  }
  return assets[0];
}

export class FundraisingCampaignStore {
  // fetchConfig(countryCode:currentDate:) — the response is cached for loadActiveCampaignAsset
  static async fetchConfig(): Promise<void> {
    const text: string = await HttpClient.getText(CONFIG_URL, null);
    JSON.parse(text);
    Prefs.putString(CONFIG_CACHE_KEY, text);
  }

  // loadActiveCampaignAsset(countryCode:wmfProject:currentDate:)
  static loadActiveCampaignAsset(countryCode: string, languageCode: string, now: number): CampaignAsset | null {
    const raw: string = Prefs.getString(CONFIG_CACHE_KEY, '');
    if (raw === '') {
      return null;
    }
    let configs: ConfigJson[] = [];
    try {
      configs = JSON.parse(raw) as ConfigJson[];
    } catch (e) {
      return null;
    }
    const installID: string = Prefs.getString(WMFDataPrefKeys.appInstallID, '');
    for (const config of configs) {
      if (config.version !== CURRENT_VERSION || config.platforms?.['iOS'] === undefined ||
        (config.countries ?? []).indexOf(countryCode) < 0) {
        continue;
      }
      const start: number = Date.parse(config.start_time ?? '');
      const end: number = Date.parse(config.end_time ?? '');
      if (Number.isNaN(start) || Number.isNaN(end) || now < start || now > end) {
        continue;
      }
      const assets: AssetJson[] | undefined = config.assets?.[languageCode];
      if (assets === undefined || assets.length === 0) {
        continue;
      }
      const picked: AssetJson = pickAsset(assets, `${config.id}|${languageCode}|${installID}`);
      const asset: CampaignAsset = new CampaignAsset();
      asset.id = config.id ?? '';
      asset.assetID = picked.id ?? '';
      asset.textHtml = picked.text ?? '';
      asset.footerHtml = picked.footer ?? '';
      asset.actions = (picked.actions ?? []).map((a: ActionJson): CampaignAction => {
        const action: CampaignAction = new CampaignAction();
        action.title = a.title ?? '';
        action.url = a.url ?? '';
        return action;
      });
      asset.countryCode = countryCode;
      asset.languageCode = languageCode;
      asset.endDate = end;
      return FundraisingCampaignStore.isSuppressed(asset, now) ? null : asset;
    }
    return null;
  }

  // queuedActiveLanguageSpecificAsset: a hidden campaign, or one put off until a later date
  private static isSuppressed(asset: CampaignAsset, now: number): boolean {
    const raw: string = Prefs.getString(PROMPT_STATE_KEY, '');
    if (raw === '') {
      return false;
    }
    const state: PromptState = JSON.parse(raw) as PromptState;
    if (state.campaignID !== asset.id) {
      return false;
    }
    if (state.isHidden) {
      return true;
    }
    return state.maybeLaterDate !== null && state.maybeLaterDate > now;
  }

  // markAssetAsMaybeLater: until the next day's midnight
  static markAssetAsMaybeLater(asset: CampaignAsset, now: number): void {
    const d: Date = new Date(now);
    const nextMidnight: number = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime();
    const state: PromptState = { campaignID: asset.id, isHidden: false, maybeLaterDate: nextMidnight };
    Prefs.putString(PROMPT_STATE_KEY, JSON.stringify(state));
  }

  static markAssetAsPermanentlyHidden(asset: CampaignAsset): void {
    const state: PromptState = { campaignID: asset.id, isHidden: true, maybeLaterDate: null };
    Prefs.putString(PROMPT_STATE_KEY, JSON.stringify(state));
  }

  // showShowMaybeLaterOption: not on the campaign's last day
  static showMaybeLaterOption(asset: CampaignAsset, now: number): boolean {
    const end: Date = new Date(asset.endDate);
    const today: Date = new Date(now);
    return !(end.getFullYear() === today.getFullYear() && end.getMonth() === today.getMonth() &&
      end.getDate() === today.getDate());
  }

  // URL.replacingDonateParameters(language:metricsId:)
  static donateURL(asset: CampaignAsset): string {
    const template: string = asset.actions.length > 0 ? asset.actions[0].url : '';
    return template
      .replace(/\$formattedId;/g, asset.metricsID)
      .replace(/\$country;/g, asset.countryCode)
      .replace(/\$language;/g, asset.languageCode)
      .replace(/\$appVersion;/g, appVersion())
      .replace(/\$appInstallId;/g, Prefs.getString(WMFDataPrefKeys.appInstallID, ''))
      .replace(/\$platform;/g, 'iOS');
  }
}
