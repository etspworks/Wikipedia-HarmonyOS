// screen_splash_screen — presentation: page. No controls (plan controlInventory empty).
// S3 structure from Wikipedia/Code/SplashScreenViewController.swift:
//   full-screen splashView (UIImageView, "splashscreen-background", centered content) with
//   the "splashscreen-wordmark" image centered on it (offset 12 handled in S5),
//   plus LoadingAnimationViewController cross-faded in below the splash view when setup
//   runs longer than maximumNonInteractiveTimeInterval (4 s).
//
// S4 wiring, from SplashScreenViewController + WMFAppViewController:
//   triggerMigratingAnimation() -> perform(showLoadingAnimation, afterDelay: 4) — the timer
//   is cancelled in viewWillDisappear/deinit, so it is cleared in aboutToDisappear too.
//   WMFAppViewController shows the splash over the blocking setup (data store + migrations)
//   and calls hideSplashView() the moment that finishes, handing off to the main UI
//   (WMFAppViewController / Explore). Here the blocking setup is Prefs + the RDB store
//   (Database.init runs the CREATE TABLE migrations), then replaceUrl to pages/Index so the
//   splash leaves the back stack — the source removes the splash VC, it is not pushed over.
//   The onboarding branch (didShowOnboarding -> WMFWelcomeInitial) is the routed page
//   pages/WMFWelcomeInitialViewControllerPage, so the handoff picks between it and Index.
// S5 styling: splashView.backgroundColor = systemBackground (theme paperBackground #FFFFFF),
// unscaled centered artwork, wordmark offset -12, 0.3s cross-fade to the loading animation
// tinted theme.colors.link. Tokens from state.json generation.styleBaseline (screen_explore).
import { router } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';
import { Database } from '../common/Database';
import { TabsStore } from '../common/TabsStore';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';

const MAXIMUM_NON_INTERACTIVE_TIME_INTERVAL: number = 4000;

@Entry
@Component
struct SplashScreenViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // showLoadingAnimation() — set by the 4 s non-interactive timer.
  @State showLoadingAnimation: boolean = false;
  private migratingTimer: number = -1;

  aboutToAppear(): void {
    this.migratingTimer = setTimeout((): void => {
      this.showLoadingAnimation = true;
    }, MAXIMUM_NON_INTERACTIVE_TIME_INTERVAL);
    this.runSetup();
  }

  aboutToDisappear(): void {
    this.cancelMigratingAnimation();
  }

  private cancelMigratingAnimation(): void {
    if (this.migratingTimer !== -1) {
      clearTimeout(this.migratingTimer);
      this.migratingTimer = -1;
    }
  }

  // The blocking setup the splash covers; hideSplashView() equivalent runs when it ends —
  // including on failure, since the source never leaves the user stranded on the splash.
  private async runSetup(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      Prefs.init(ctx);
      await Database.init(ctx);
      // The splash already covers the blocking setup, which is where the source seeds the
      // reader's current article tab.
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      await TabsStore.ensureDefaultTab('wikipedia.' + lang.languageCode);
    } catch (e) {
      console.error('splash: setup failed: ' + (e as Error).message);
    } finally {
      this.cancelMigratingAnimation();
      // WMFAppViewController.hideSplashView() hands off to onboarding on a fresh install
      // and to the app's main UI afterwards. replaceUrl either way, so the splash leaves
      // the back stack exactly as the source removes the splash view controller.
      const seenWelcome: boolean = Prefs.getBoolean(WMFDataPrefKeys.didShowWelcomeOnboarding, false);
      router.replaceUrl({
        url: seenWelcome ? 'pages/Index' : 'pages/WMFWelcomeInitialViewControllerPage'
      });
    }
  }

  build() {
    Stack() {
      if (this.showLoadingAnimation) {
        // LoadingAnimationViewController layer (below the splash view in source z-order,
        // revealed by fading the splash out).
        LoadingProgress()
          .width(60)
          .height(60)
          .color($r('app.color.theme_link'))
      }
      // splashView: contentMode .center — the artwork is NOT scaled, it sits centered on
      // systemBackground. crossFadeAnimationDuration 0.3 fades it out for the loader.
      Image($r('app.media.splashscreen_background'))
        .objectFit(ImageFit.None)
        .width('100%')
        .height('100%')
        .opacity(this.showLoadingAnimation ? 0 : 1)
        .animation({ duration: 300, curve: Curve.EaseInOut })
      // wordmarkView: centered, 12pt above the splash view's centerY.
      Image($r('app.media.splashscreen_wordmark'))
        .objectFit(ImageFit.None)
        .offset({ y: -12 })
        .opacity(this.showLoadingAnimation ? 0 : 1)
        .animation({ duration: 300, curve: Curve.EaseInOut })
    }
    .id('SplashScreenViewController')
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
