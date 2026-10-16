// screen_welcome_initial — presentation: modal, hosted by ExploreViewControllerPage
// (.bindContentCover; first launch shows it modally over Explore). NOT a routed page.
// Edge welcome_initial -> explore is the modal dismiss (cover closes onto Explore).
//
// S3 structure from Wikipedia/Code/WMFWelcomeInitialViewController.swift, which embeds
// WMFWelcomePageViewController: FOUR WMFWelcomeContainerViewControllers, one per
// WMFWelcomePageType — intro, exploration, languages, analytics. Each container stacks its
// welcome animation view over a WMFWelcomePanelViewController (comp_welcome_panels), and the
// page view controller adds the shared Skip / Next buttons underneath, fading them out on the
// last page (hideButtons(for:)) — reproduced with .opacity so the nodes stay addressable.
// S4: Next advances the pager and dismisses past the end; Skip dismisses immediately; both
// record that onboarding was completed (svc_prefs, the source's
// didSendNewInstallOnboardingStartEvent / didShowWelcome bookkeeping) before closing the
// host's cover. "Learn more about Wikipedia" opens the source's About Wikipedia alert.
// feat_animations: the welcome animation views fade and rise into place on each page change
// (WMFWelcomeAnimationView.beginAnimations), driven here by animateTo on the page index.
// S5: capture base.ui.json (402x874) — the ftux-puzzle-globe 150x150 at [126,201], the
// 24pt title band starting y388 inset to [65,337], the description and the 15pt
// "Learn more about Wikipedia" link at y580, and Skip x56 / Next x289 at y800.
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Prefs, WMFDataPrefKeys } from '../common/Prefs';
import { LanguageStore } from '../common/LanguageStore';
import { WMFWelcomePanelViewController } from '../components/WMFWelcomePanelViewController';

// ImageModel from WMFWelcomeAnimationBackgroundView: size in vp (unitSize x the 320 container
// width) and unitDestination, the offset from the container center as a fraction of 320x164.
interface WelcomeGlyph {
  res: Resource;
  w: number;
  h: number;
  x: number;
  y: number;
}

// WMFWelcome{Exploration,Languages,Analytics}AnimationBackgroundView.imageModels.
const EXPLORATION_GLYPHS: WelcomeGlyph[] = [
  { res: $r('app.media.ftux_background_globe'), w: 23, h: 23, x: 0.265625, y: -0.32621 },
  { res: $r('app.media.ftux_background_map_dot'), w: 20, h: 23, x: 0.2015625, y: 0.286585 },
  { res: $r('app.media.ftux_background_calendar'), w: 20, h: 23, x: -0.3140625, y: -0.417682 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.2015625, y: -0.49085 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.284375, y: 0.10670 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: -0.303125, y: 0.051829 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: 0.3359375, y: -0.100609 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: -0.275, y: 0.34756 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: -0.3984375, y: -0.155487 }
];
const LANGUAGES_GLYPHS: WelcomeGlyph[] = [
  { res: $r('app.media.ftux_background_langs'), w: 26, h: 23, x: 0.303125, y: -0.121951 },
  { res: $r('app.media.ftux_background_langs'), w: 26, h: 23, x: -0.259375, y: 0.277439 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.2109375, y: -0.36585 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.2875, y: 0.195121 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: -0.309375, y: 0.070121 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: 0.2359375, y: 0.381097 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: -0.29375, y: -0.393292 }
];
const ANALYTICS_GLYPHS: WelcomeGlyph[] = [
  { res: $r('app.media.ftux_background_chart'), w: 16, h: 14, x: 0.26875, y: 0.329268 },
  { res: $r('app.media.ftux_background_shield_star'), w: 16, h: 20, x: -0.3234375, y: -0.41158 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.23125, y: -0.466463 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: 0.2984375, y: 0.076219 },
  { res: $r('app.media.ftux_background_plus'), w: 10, h: 10, x: -0.309375, y: 0.070121 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: 0.3359375, y: -0.161585 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: -0.3984375, y: -0.125 },
  { res: $r('app.media.ftux_background_circle'), w: 13, h: 13, x: -0.2765625, y: 0.31707 }
];

// intro, exploration, languages, analytics
const LANGUAGES_PAGE_INDEX: number = 2;

@Component
export struct WMFWelcomeInitialView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  onDismiss: () => void = () => {
    console.info('welcomeInitial: dismissed');
  };

  @State pageIndex: number = 0;
  // WMFWelcomeAnimationView: each page fades in and rises as it becomes current.
  @State animationOpacity: number = 1;
  private swiperController: SwiperController = new SwiperController();
  private static readonly pageCount: number = 4;

  private isLastPage(): boolean {
    return this.pageIndex >= WMFWelcomeInitialView.pageCount - 1;
  }

  // WMFWelcomeLanguageTableViewController.viewWillDisappear: leaving the languages page
  // shows the search language bar only when the user has more than one language.
  private saveLanguageBarDefault(): void {
    LanguageStore.readPreferredCodes().then((codes: string[]) => {
      Prefs.putBoolean(WMFDataPrefKeys.showSearchLanguageBar, codes.length > 1);
    }).catch((e: Error) => {
      console.error('welcomeInitial: languages unavailable: ' + e.message);
    });
  }

  private finish(): void {
    if (this.pageIndex === LANGUAGES_PAGE_INDEX) {
      this.saveLanguageBarDefault();
    }
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      Prefs.putBoolean(WMFDataPrefKeys.didShowWelcomeOnboarding, true);
    } catch (e) {
      console.error('welcomeInitial: prefs unavailable: ' + (e as Error).message);
    }
    this.onDismiss();
  }

  private next(): void {
    if (this.isLastPage()) {
      this.finish();
      return;
    }
    this.swiperController.showNext();
  }

  // WMFWelcomeAnalyticsViewController: the link offers Privacy policy / Terms of use (plus
  // Cancel) and opens the chosen page.
  private showPrivacyOptions(): void {
    this.getUIContext().getPromptAction().showActionMenu({
      buttons: [
        { text: $r('app.string.main_menu_privacy_policy'), color: $r('app.color.theme_link') },
        { text: $r('app.string.main_menu_terms_of_use'), color: $r('app.color.theme_link') }
      ]
    }).then((r) => {
      const url: string = r.index === 0 ? 'https://foundation.wikimedia.org/wiki/Policy:Privacy_policy'
        : 'https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use';
      const params: Record<string, string> = { 'url': url };
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params }).catch((e: Error) => {
        console.error('welcomeInitial: privacy route failed: ' + e.message);
      });
    }).catch(() => {
      // cancelled
    });
  }

  // showLearnMoreAlert(withSender:)
  private showLearnMoreAlert(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.welcome_intro_free_encyclopedia_more_about'),
      message: $r('app.string.welcome_intro_free_encyclopedia_more_description'),
      confirm: {
        value: $r('app.string.welcome_explore_tell_me_more_done_button'),
        action: (): void => {
          console.info('welcomeInitial: learn more dismissed');
        }
      }
    });
  }

  // WMFWelcomeAnimationView.beginAnimations — fade+rise as the page becomes current.
  private animateIn(): void {
    this.animationOpacity = 0;
    this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.animationOpacity = 1;
    });
  }

  @Builder
  welcomePage(background: Resource, foreground: Resource, hasForeground: boolean,
    pageType: string, glyphs: WelcomeGlyph[]) {
    Column() {
      // WMFWelcome.storyboard: the 320x164 "Top Background Container View" (clipped) holding
      // the scattered background glyphs, with the 150x150 foreground centered over it.
      Stack() {
        // WMFWelcomeAnimationBackgroundView: each glyph starts at the center and moves out to
        // its unitDestination as it fades in — here both ride the page's animation progress.
        ForEach(glyphs, (g: WelcomeGlyph) => {
          Image(g.res)
            .width(g.w)
            .height(g.h)
            .objectFit(ImageFit.Contain)
            .offset({ x: g.x * 320 * this.animationOpacity, y: g.y * 164 * this.animationOpacity })
        })
        // WMFWelcomeAnimationView: the background art with its foreground element over it,
        // on a midBackground circle for every page but the intro (hasCircleBackground).
        Stack() {
          Image(background)
            .width(150)
            .height(150)
            .objectFit(ImageFit.Contain)
          if (hasForeground) {
            Image(foreground)
              .width(150)
              .height(150)
              .objectFit(ImageFit.Contain)
          }
        }
        .width(150)
        .height(150)
        .borderRadius(75)
        .clip(true)
        .backgroundColor(glyphs.length > 0 ? (this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')) : Color.Transparent)
      }
      .width(320)
      .height(164)
      .clip(true)
      .margin({ top: 93 })
      .opacity(this.animationOpacity)

      Column() {
        WMFWelcomePanelViewController({
          pageType: pageType,
          onLearnMore: (): void => {
            this.showLearnMoreAlert();
          },
          onGetStarted: (): void => {
            this.finish();
          },
          onPrivacy: (): void => {
            this.showPrivacyOptions();
          },
          // the source pushes the preferred-languages editor and returns to this page
          onAddLanguage: (): void => {
            router.pushUrl({ url: 'pages/WMFPreferredLanguagesViewControllerPage' }).catch((e: Error) => {
              console.error('welcomeInitial: languages route failed: ' + e.message);
            });
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 65, right: 65, top: 37 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        this.welcomePage($r('app.media.ftux_puzzle_globe'),
          $r('app.media.ftux_background_globe'), false, 'intro', [])
        this.welcomePage($r('app.media.ftux_telescope_base'),
          $r('app.media.ftux_telescope_tube'), true, 'exploration', EXPLORATION_GLYPHS)
        this.welcomePage($r('app.media.ftux_langs_left'),
          $r('app.media.ftux_langs_right'), true, 'languages', LANGUAGES_GLYPHS)
        this.welcomePage($r('app.media.ftux_analytics_phone'),
          $r('app.media.ftux_analytics_chart'), true, 'analytics', ANALYTICS_GLYPHS)
      }
      .layoutWeight(1)
      .width('100%')
      .loop(false)
      .indicator(Indicator.dot()
        .color($r('app.color.gray300'))
        .selectedColor($r('app.color.theme_link')))
      .displayArrow(false)
      .onChange((index: number) => {
        if (this.pageIndex === LANGUAGES_PAGE_INDEX && index !== LANGUAGES_PAGE_INDEX) {
          this.saveLanguageBarDefault();
        }
        this.pageIndex = index;
        this.animateIn();
      })

      Row() {
        Button($r('app.string.button_skip'))
          .id('App Onboarding Skip Button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(40)
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .onClick(() => {
            this.finish();
          })

        Blank()

        Button($r('app.string.button_next'))
          .id('App Onboarding Next Button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(40)
          .fontSize(17)
          .fontColor($r('app.color.theme_link'))
          .enabled(!this.isLastPage())
          .onClick(() => {
            this.next();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 56, right: 56 })
      .opacity(this.isLastPage() ? 0 : 1)
    }
    .id('WMFWelcomeInitialViewController')
    .width('100%')
    .height('100%')
    .padding({ bottom: 34 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}

// The onboarding is its own routed page, not a cover over Explore. As a cover it shared
// Explore's single cover slot and was torn down by the feed's first state write while it
// was still building its panel ("View WMFWelcomePanelViewController is already in process
// of destruction"), which left the pager on screen with no title or body text. Routed, it
// owns its tree, and the source's order holds anyway: onboarding runs BEFORE the feed.
// SplashScreenViewControllerPage picks this route while didShowWelcomeOnboarding is unset.
@Entry
@Component
struct WelcomeOnboardingPage {
  build() {
    // @Entry needs a container root, so the pager sits in a full-bleed Column.
    Column() {
      WMFWelcomeInitialView({
        onDismiss: (): void => {
          router.replaceUrl({ url: 'pages/Index' });
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
