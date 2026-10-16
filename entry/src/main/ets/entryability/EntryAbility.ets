import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { resolveRoute, DEFAULT_ROUTE, SPLASH_ROUTE, intentForUri, LaunchIntent, LAUNCH_INTENT_KEY } from './RouteTable';
import { openRootTab } from '../components/RootTabBar';
import { initWikiLinks } from '../common/WikiLinks';
import { TabsStore } from '../common/TabsStore';
import { CONTINUATION_WANT_PARAM, currentActivityURI } from '../common/Continuation';
import { ThemeManager } from '../common/ThemeManager';
import { Prefs, PrefKeys } from '../common/Prefs';
import { SessionStore } from '../common/SessionStore';
import { TOP_SAFE_INSET_KEY, NAV_INDICATOR_INSET_KEY } from '../common/SafeArea';
import { IS_DARK_KEY } from '../common/ThemeManager';
// loaded here so its change-triggered sync hook is in place before any list change
import '../common/ReadingListSyncService';

const DOMAIN = 0x0000;

function stringParam(want: Want, key: string): string {
  const params: Record<string, Object> | undefined = want.parameters;
  if (params !== undefined) {
    const v: Object | undefined = params[key];
    if (typeof v === 'string') {
      return v;
    }
  }
  return '';
}

function targetPageOf(want: Want): string {
  return stringParam(want, 'targetPage');
}

// processUserActivity / processShortcutItem: a wikipedia:// or https://*.wikipedia.org link
// (want.uri), or a home-screen quick action (shortcuts_config.json passes its link as the
// 'shortcutUri' parameter).
function launchIntentOf(want: Want): LaunchIntent | null {
  // a screen continued from another device carries its wikipedia:// link
  const continued: string = stringParam(want, CONTINUATION_WANT_PARAM);
  if (continued.length > 0) {
    return intentForUri(continued);
  }
  const shortcut: string = stringParam(want, 'shortcutUri');
  return intentForUri(shortcut.length > 0 ? shortcut : (want.uri ?? ''));
}

// A cold launch loads its page through `loadContent`, which carries no router params, so an
// article named in the Want would be lost. Publish it once here; ArticleViewControllerPage
// reads this key when it was opened without router params.
const LAUNCH_ARTICLE_KEY: string = 'launchArticleTitle';
// Same problem for an overlay: it has no route of its own, so the host page reads the
// requested target from here and presents it.
const LAUNCH_OVERLAY_KEY: string = 'launchOverlay';
// Same problem for SinglePageWebViewController: it hosts an arbitrary URL its presenter
// passes, and a cold deep link carries no router params. replay-config.json's launchParams
// name the URL for that route, exactly as `articleTitle` names the article for ArticleViewController.
const LAUNCH_WEB_URL_KEY: string = 'launchWebUrl';
// Same problem for TalkPageViewController: a cold deep link carries no router params, so
// replay-config.json's launchParams name the talk title for that route, exactly as `url`
// names the URL for SinglePageWebViewController.
const LAUNCH_TALK_PAGE_TITLE_KEY: string = 'launchTalkPageTitle';

export default class EntryAbility extends UIAbility {
  private pendingRoute: string = DEFAULT_ROUTE;
  private stage: window.WindowStage | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // Open the preference store before ANY page is loaded. A cold launch that deep-links
    // straight to a page (`--ps targetPage …`) runs that page's aboutToAppear with no tab host
    // ahead of it, so a page reading Prefs threw "Prefs.init(context) must be called before
    // use" and the app died before reaching the foreground. Prefs.init is idempotent, so the
    // per-page guards that already call it stay correct.
    try {
      Prefs.init(this.context);
      ThemeManager.attach(this.context.getApplicationContext());
      // The login cookies and user snapshot live in Prefs; bring them back before any page
      // asks SessionStore.isLoggedIn, or a cold start reads as signed out until a page that
      // restores the session on its own (Settings, Watchlist) happens to open.
      SessionStore.restore();
      initWikiLinks(this.context);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to open preferences. Cause: %{public}s', JSON.stringify(err));
    }
    // A plain home launch (no targetPage) opens the splash, which covers the blocking
    // Prefs + Database setup and then replaceUrls to pages/Index — the source's
    // SplashScreenViewController -> hideSplashView() -> WMFAppViewController handoff.
    // A deep link names its own target and must NOT be delayed behind the splash, and
    // onNewWant (a warm relaunch) never routes here, so the splash shows once per cold start.
    const target: string = targetPageOf(want);
    this.pendingRoute = target.length === 0 ? SPLASH_ROUTE : resolveRoute(target);
    AppStorage.setOrCreate<string>(LAUNCH_ARTICLE_KEY, stringParam(want, 'articleTitle'));
    AppStorage.setOrCreate<string>(LAUNCH_OVERLAY_KEY, targetPageOf(want));
    AppStorage.setOrCreate<string>(LAUNCH_WEB_URL_KEY, stringParam(want, 'url'));
    AppStorage.setOrCreate<string>(LAUNCH_TALK_PAGE_TITLE_KEY, stringParam(want, 'talkPageTitle'));
    // A link or quick action on a cold start: the splash still runs the setup, and Index
    // takes the intent over once it is on screen.
    const intent: LaunchIntent | null = launchIntentOf(want);
    AppStorage.setOrCreate<string>(LAUNCH_INTENT_KEY, intent !== null ? JSON.stringify(intent) : '');
    AppStorage.setOrCreate<boolean>(IS_DARK_KEY,
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // The effective colour mode (the app's theme, or the device's under Default) for chrome
  // that cannot use the colour resources, e.g. the tab bar's tinted PNG icons.
  onConfigurationUpdate(config: Configuration): void {
    AppStorage.setOrCreate<boolean>(IS_DARK_KEY, config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    ThemeManager.deviceColorModeChanged();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const target: string = targetPageOf(want);
    const articleTitle: string = stringParam(want, 'articleTitle');
    AppStorage.setOrCreate<string>(LAUNCH_ARTICLE_KEY, articleTitle);
    AppStorage.setOrCreate<string>(LAUNCH_OVERLAY_KEY, targetPageOf(want));
    AppStorage.setOrCreate<string>(LAUNCH_WEB_URL_KEY, stringParam(want, 'url'));
    AppStorage.setOrCreate<string>(LAUNCH_TALK_PAGE_TITLE_KEY, stringParam(want, 'talkPageTitle'));
    // A link or quick action while the app is running: open its tab or push its page.
    const intent: LaunchIntent | null = launchIntentOf(want);
    if (intent !== null && this.stage !== null) {
      const uiRouter = this.stage.getMainWindowSync().getUIContext().getRouter();
      if (intent.route.length === 0) {
        openRootTab(uiRouter, intent.tab);
      } else {
        uiRouter.pushUrl({ url: intent.route, params: intent.params }).catch((e: Error) => {
          hilog.error(DOMAIN, 'testTag', 'link route failed: %{public}s', e.message);
        });
      }
      return;
    }
    // Tapping the launcher icon on an app that is only backgrounded delivers an empty Want
    // here. Pushing DEFAULT_ROUTE for it stacked a second Explore on top of the live one, so
    // the back gesture popped to an identical screen instead of leaving the app, and the
    // reader lost wherever they actually were. A relaunch with no target just resumes.
    if (target.length === 0) {
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'onNewWant: resume, no targetPage');
      return;
    }
    const route: string = resolveRoute(target);
    const routeParams: Record<string, string> = { 'articleTitle': articleTitle };
    const stage: window.WindowStage | null = this.stage;
    if (stage !== null) {
      stage.getMainWindowSync().getUIContext().getRouter().pushUrl({ url: route, params: routeParams })
        .catch((e: Error) => {
          hilog.error(DOMAIN, 'testTag', 'onNewWant route failed: %{public}s', e.message);
        });
    } else {
      this.pendingRoute = route;
    }
  }

  // Handoff: hand the advertised screen's link to the device continuing it
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const uri: string = currentActivityURI();
    if (uri.length === 0) {
      return AbilityConstant.OnContinueResult.REJECT;
    }
    wantParam[CONTINUATION_WANT_PARAM] = uri;
    return AbilityConstant.OnContinueResult.AGREE;
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.stage = windowStage;
    windowStage.loadContent(this.pendingRoute, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
    // Published once for the cover screens, which draw under the status bar.
    try {
      const top: number =
        windowStage.getMainWindowSync().getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height;
      AppStorage.setOrCreate<number>(TOP_SAFE_INSET_KEY, px2vp(top));
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to read the status bar inset: %{public}s', JSON.stringify(err));
    }
    // The gesture-handle strip under the bottom tab bar (0 with three-button navigation), so the
    // bar can balance its items above it on every phone; kept current if the navigation mode changes.
    try {
      const main: window.Window = windowStage.getMainWindowSync();
      const indicator: number =
        main.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height;
      AppStorage.setOrCreate<number>(NAV_INDICATOR_INSET_KEY, px2vp(indicator));
      main.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate<number>(NAV_INDICATOR_INSET_KEY, px2vp(data.area.bottomRect.height));
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to read the navigation indicator inset: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    this.stage = null;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    // wmf_appResignActiveDate: Continue reading shows once the app has been away a day
    try {
      Prefs.putNumber(PrefKeys.appResignActiveDate, Date.now());
    } catch (e) {
      hilog.warn(DOMAIN, 'testTag', 'resign date not stored');
    }
    // NavigationStateController.saveNavigationState: leaving the app with an article on screen
    // keeps that article for the next cold start; leaving it anywhere else forgets it.
    let onArticle: boolean = false;
    try {
      const stage: window.WindowStage | null = this.stage;
      if (stage !== null) {
        const state = stage.getMainWindowSync().getUIContext().getRouter().getState();
        onArticle = (state.path + state.name).indexOf('ArticleViewControllerPage') >= 0;
      }
    } catch (e) {
      onArticle = false;
    }
    if (onArticle) {
      TabsStore.saveCurrentStateForLaterRestoration().catch((e: Error) => {
        hilog.warn(DOMAIN, 'testTag', 'restoration state not saved: %{public}s', e.message);
      });
    } else {
      TabsStore.clearCurrentStateForRestoration();
    }
  }
}
