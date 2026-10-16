// Image recommendations ("Add an image"): WMFGrowthTasksDataController (the recommendations,
// cached in memory per wiki), WMFImageRecommendationsDataController (feedback and the onboarding
// flags). The lead-section insertion is insertImageWikitextAfterTemplates in InsertMedia.ts.
import { HttpClient } from './HttpClient';
import { AuthService, TokenType, mediaWikiApiURL } from './AuthService';
import { Prefs } from './Prefs';
import { ArticleSummary } from '../model/ArticleSummary';

interface MetadataJson {
  descriptionUrl?: string;
  thumbUrl?: string;
  fullUrl?: string;
  description?: string;
  reason?: string;
}

interface ImageJson {
  image?: string;
  displayFilename?: string;
  source?: string;
  metadata?: MetadataJson;
}

interface SuggestionJson {
  titleText?: string;
  images?: ImageJson[];
}

interface MainSlotJson {
  content?: string;
}

interface SlotsJson {
  main?: MainSlotJson;
}

interface RevisionJson {
  slots?: SlotsJson;
}

interface PageJson {
  pageid?: number;
  title?: string;
  pageimage?: string;
  revisions?: RevisionJson[];
  growthimagesuggestiondata?: SuggestionJson[];
}

interface QueryJson {
  pages?: PageJson[];
}

interface ResponseJson {
  query?: QueryJson;
}

// WMFImageRecommendationsViewModel.ImageRecommendation
export class ImageRecommendation {
  pageId: number = 0;
  pageTitle: string = '';
  filename: string = '';
  displayFilename: string = '';
  thumbUrl: string = '';
  fullUrl: string = '';
  // HTML
  description: string = '';
  descriptionUrl: string = '';
  reason: string = '';
  // the lead section (rvsection=0)
  wikitext: string = '';
  summary: ArticleSummary | null = null;
}

// WMFImageRecommendationsDataController.OnboardingStatus
interface OnboardingStatus {
  hasPresentedOnboardingModal: boolean;
  hasPresentedOnboardingTooltips: boolean;
}

const ONBOARDING_KEY: string = 'image-recommendations-onboarding';
// WMFDeveloperSettingsDataController.doNotPostImageRecommendationsEdit
const DO_NOT_POST_KEY: string = 'dev-settings-do-not-post-image-rec-edit';
// port-only developer setting: skip the edit-count requirement (QA accounts are new)
const IGNORE_EDIT_COUNT_KEY: string = 'dev-settings-suggested-edits-ignore-edit-count';

// WMFSuggestedEditsContentSource needs more than 50 edits; the feed settings row 50 or more
export function meetsSuggestedEditsEditCount(editCount: number, forSettingsRow: boolean): boolean {
  if (Prefs.getBoolean(IGNORE_EDIT_COUNT_KEY, false)) {
    return true;
  }
  return forSettingsRow ? editCount >= 50 : editCount > 50;
}

function protocolRelative(url: string): string {
  return url.startsWith('//') ? 'https:' + url : url;
}

export class GrowthTasksService {
  // the shared in-memory queue per wiki host
  private static cache: Map<string, ImageRecommendation[]> = new Map<string, ImageRecommendation[]>();

  // fetchImageRecommendationsForAppLanguage: the cache when it has any, otherwise a random batch
  static async fetch(host: string): Promise<ImageRecommendation[]> {
    const cached: ImageRecommendation[] = GrowthTasksService.cache.get(host) ?? [];
    if (cached.length > 0) {
      return cached.slice();
    }
    const url: string = HttpClient.buildURL(mediaWikiApiURL(host), {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': 'hasrecommendation:image',
      'gsrnamespace': '0',
      'gsrsort': 'random',
      'gsrlimit': '10',
      'prop': 'growthimagesuggestiondata|revisions|pageimages',
      'pilicense': 'any',
      'rvprop': 'ids|timestamp|flags|comment|user|content',
      'rvslots': 'main',
      'rvsection': '0',
      'formatversion': '2',
      'format': 'json'
    });
    const resp: ResponseJson = await HttpClient.getJson<ResponseJson>(url);
    const out: ImageRecommendation[] = [];
    for (const page of resp.query?.pages ?? []) {
      // pages that already have a lead image are skipped
      const suggestion: SuggestionJson | undefined = (page.growthimagesuggestiondata ?? [])[0];
      const image: ImageJson | undefined = (suggestion?.images ?? [])[0];
      if (page.pageimage !== undefined || suggestion === undefined || image === undefined) {
        continue;
      }
      const rec: ImageRecommendation = new ImageRecommendation();
      rec.pageId = page.pageid ?? 0;
      rec.pageTitle = suggestion.titleText ?? page.title ?? '';
      rec.filename = image.image ?? '';
      rec.displayFilename = image.displayFilename ?? rec.filename;
      rec.thumbUrl = protocolRelative(image.metadata?.thumbUrl ?? '');
      rec.fullUrl = protocolRelative(image.metadata?.fullUrl ?? '');
      rec.description = image.metadata?.description ?? '';
      rec.descriptionUrl = protocolRelative(image.metadata?.descriptionUrl ?? '');
      rec.reason = image.metadata?.reason ?? '';
      rec.wikitext = (page.revisions ?? [])[0]?.slots?.main?.content ?? '';
      out.push(rec);
    }
    GrowthTasksService.cache.set(host, cached.concat(out));
    return out.slice();
  }

  // hasImageRecommendations: the Explore card needs at least one
  static async hasRecommendations(host: string): Promise<boolean> {
    try {
      return (await GrowthTasksService.fetch(host)).length > 0;
    } catch (e) {
      return false;
    }
  }

  static remove(host: string, pageId: number): void {
    GrowthTasksService.cache.set(host,
      (GrowthTasksService.cache.get(host) ?? []).filter((r: ImageRecommendation) => r.pageId !== pageId));
  }

  static reset(host: string): void {
    GrowthTasksService.cache.set(host, []);
  }

  // sendFeedback: PUT growthexperiments/v0/suggestions/addimage/feedback/<title>; skipped (as a
  // success) while the developer setting "Do not post image recommendations edit." is on
  static async sendFeedback(host: string, rec: ImageRecommendation, accepted: boolean, reasons: string[],
    caption: string | null, editRevId: number | null): Promise<void> {
    if (Prefs.getBoolean(DO_NOT_POST_KEY, false)) {
      console.info('imageRecs: feedback not posted (developer setting)');
      return;
    }
    const token: string = await AuthService.fetchToken(host, TokenType.csrf);
    const body: Record<string, Object | null> = {
      'filename': rec.filename,
      'accepted': accepted,
      'reasons': reasons,
      'caption': caption ?? rec.filename,
      'sectionTitle': null,
      'sectionNumber': null,
      'token': token
    };
    if (editRevId !== null) {
      body['editRevId'] = editRevId;
    }
    const url: string = 'https://' + host + '/w/rest.php/growthexperiments/v0/suggestions/addimage/feedback/' +
      encodeURIComponent(rec.pageTitle.replace(/ /g, '_'));
    await HttpClient.putJsonForText(url, body, {});
  }

  private static onboarding(): OnboardingStatus {
    try {
      return JSON.parse(Prefs.getString(ONBOARDING_KEY, '')) as OnboardingStatus;
    } catch (e) {
      return { hasPresentedOnboardingModal: false, hasPresentedOnboardingTooltips: false };
    }
  }

  static hasPresentedOnboardingModal(): boolean {
    return GrowthTasksService.onboarding().hasPresentedOnboardingModal === true;
  }

  static hasPresentedOnboardingTooltips(): boolean {
    return GrowthTasksService.onboarding().hasPresentedOnboardingTooltips === true;
  }

  static setOnboarding(modal: boolean | null, tooltips: boolean | null): void {
    const status: OnboardingStatus = GrowthTasksService.onboarding();
    const next: OnboardingStatus = {
      hasPresentedOnboardingModal: modal ?? status.hasPresentedOnboardingModal === true,
      hasPresentedOnboardingTooltips: tooltips ?? status.hasPresentedOnboardingTooltips === true
    };
    Prefs.putString(ONBOARDING_KEY, JSON.stringify(next));
  }
}

// set by Save changes after a successful publish (editorDidPublish)
export const IMAGE_REC_PUBLISHED_KEY: string = 'wmfImageRecPublished';

// the recommendation the Yes flow (details, Preview, Save changes) is working on
export class ImageRecSession {
  static host: string = 'en.wikipedia.org';
  static recommendation: ImageRecommendation | null = null;
}
