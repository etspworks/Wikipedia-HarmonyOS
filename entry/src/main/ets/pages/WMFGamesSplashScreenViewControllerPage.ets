// screen_games_splash_screen — presentation: modal, hosted by screen_explore
// (coverBuilder branch in ExploreViewControllerPage). NOT a routed page.
// S3 structure from WMFComponents .../Games/Splash Screen/WMFGamesSplashScreenView.swift:
// icon image, title, subtitle, WMFLargeButton play (primary), WMFLargeButton About
// (secondary; in source, absent from plan controlInventory — source wins, reported).
// Daily game date + streak bound to svc_game_store CDGameSession (S4).
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { navIconTint } from '../components/NavButton';
import { CDGameSession } from '../model/CDGameSession';
import { GameSessionStatus, GameStore, WHICH_CAME_FIRST_GAME_TYPE } from '../common/GameStore';
import { LanguageStore } from '../common/LanguageStore';

// WMFGamesSplashScreenViewController / WMFWhichCameFirstViewController navigation bar: the large
// close button, the game's date as the title (wmfMonthDayYear: "October 13, 2026") and the ⋯ menu
// with Learn more and Problem with feature, white on the game blue.
export function gameDateTitle(isoDay: string): string {
  const day: string = isoDay !== '' ? isoDay.substring(0, 10) : new Date().toISOString().substring(0, 10);
  return new Date(day + 'T12:00:00Z').toLocaleDateString(i18n.System.getSystemLocale(),
    { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
}

// showAbout(): the game's explanation page
export const WHICH_CAME_FIRST_ABOUT_URL: string =
  'https://www.mediawiki.org/wiki/Wikimedia_Apps/Team/iOS/%22Which_came_first%3F%22_Game';

@Component
export struct GamesNavBar {
  @Prop title: string = '';
  // the splash forces white; the game bar uses theme.baseBackground (titleTextAttributes)
  @Prop titleColor: ResourceColor = Color.White;
  onClose?: () => void;
  onLeave?: () => void;

  // showReportProblem(): a mail to ios-support with the games report subject and body
  private reportProblem(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const s = (r: Resource): string => {
      try {
        return ctx.resourceManager.getStringSync(r);
      } catch (e) {
        return '';
      }
    };
    const body: string = [s($r('app.string.games_email_report_body_encountered')),
      s($r('app.string.activity_tab_email_second_line')), s($r('app.string.activity_tab_email_third_line')),
      s($r('app.string.activity_tab_email_fourth_line'))].join('\n\n');
    const mailto: string = 'mailto:ios-support@wikimedia.org?subject=' +
      encodeURIComponent(s($r('app.string.games_email_report_subject'))) + '&body=' + encodeURIComponent(body);
    ctx.openLink(mailto).catch((e: Error) => {
      console.error('games: no mail composer: ' + e.message);
      promptAction.showToast({ message: 'ios-support@wikimedia.org' });
    });
  }

  private openAbout(): void {
    if (this.onLeave !== undefined) {
      this.onLeave();
    }
    const params: Record<string, string> = { 'url': WHICH_CAME_FIRST_ABOUT_URL };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  @Builder
  roundButton(icon: Resource, id: string) {
    Image(icon)
      .width(20)
      .height(20)
      .objectFit(ImageFit.Contain)
      .colorFilter(navIconTint(false))
      .id(id)
  }

  build() {
    Stack() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.titleColor)
      Row() {
        Button() {
          this.roundButton($r('app.media.close'), 'games_close_icon')
        }
        .id('games_close')
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .backgroundColor('#99FFFFFF')
        .onClick(() => {
          if (this.onClose !== undefined) {
            this.onClose();
          }
        })
        Blank()
        Button() {
          this.roundButton($r('app.media.more'), 'games_more_icon')
        }
        .id('games_more')
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .backgroundColor('#99FFFFFF')
        .bindMenu([
          { value: $r('app.string.learn_more_title'), action: () => { this.openAbout(); } },
          { value: $r('app.string.problem_with_feature_title'), action: () => { this.reportProblem(); } }
        ])
      }
      .width('100%')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }
}

@Component
export struct WMFGamesSplashScreenView {
  // the host resolves today's session and can swap it while the splash is up
  @Prop session: CDGameSession | null = null;
  // the card's language; empty means the app language
  @Prop languageCode: string = '';
  onClose?: () => void;

  // WMFGamesSplashScreenView: the primary button names what today's session allows.
  private playTitle(): Resource {
    if (this.session === null) {
      return $r('app.string.games_wcf_button_play_title');
    }
    return this.session.status === GameSessionStatus.Completed
      ? $r('app.string.which_came_first_splash_review_button')
      : $r('app.string.which_came_first_splash_continue_button');
  }

  build() {
    // WMFGamesSplashScreenView: WMFColor.blue600 behind everything, including the status bar
    // and the navigation indicator (a separate layer, so only the colour enters the safe area)
    Stack() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.blue600'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    Column() {
      GamesNavBar({
        title: gameDateTitle(this.session !== null && this.session.dailyGameDate !== null
          ? this.session.dailyGameDate : ''),
        onClose: (): void => {
          if (this.onClose !== undefined) {
            this.onClose();
          }
        },
        onLeave: (): void => {
          GameStore.markAnnouncementSeen();
          if (this.onClose !== undefined) {
            this.onClose();
          }
        }
      })
      Column() {
        Blank()
        SymbolGlyph($r('sys.symbol.calendar'))
          .id('games_icon')
          .fontSize(44)
          .fontColor([$r('app.color.wmf_white')])
          .margin({ bottom: 24 })
        Text($r('app.string.which_came_first_splash_title'))
          .fontSize(28)                           // WMFFont.georgiaTitle1
          .fontFamily('serif')
          .fontColor($r('app.color.wmf_white'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 8 })
        Text($r('app.string.which_came_first_splash_subtitle'))
          .fontSize(17)                           // WMFFont.body
          .lineHeight(22)
          .fontColor($r('app.color.wmf_white'))
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 48 })
        // WMFLargeButton(.neutral) forced white / blue600: a capsule with a semibold label
        Button(this.playTitle())
          .id('games_play')
          .type(ButtonType.Capsule)
          .width('calc(100% - 64vp)')
          .height(46)
          .fontSize(17)
          .fontWeight(600)
          .fontColor($r('app.color.blue600'))
          .backgroundColor($r('app.color.wmf_white'))
          .onClick(() => {
            this.play();
          })
        Blank()
        // WMFLargeButton(.quiet) forced white
        Button($r('app.string.which_came_first_splash_about_button'))
          .id('games_about')
          .type(ButtonType.Capsule)
          .width('calc(100% - 64vp)')
          .height(46)
          .backgroundColor(Color.Transparent)
          .fontSize(17)
          .fontWeight(600)
          .fontColor($r('app.color.wmf_white'))
          .margin({ bottom: 24 })
          .onClick(() => {
            this.openAbout();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    }
    .id('WMFGamesSplashScreenViewController')
    .width('100%')
    .height('100%')
  }

  // didTapPlay: the announcement is marked seen, the splash closes and the game opens.
  // A rapid double tap must launch ONE game, not stack two: the push is async, so without
  // this latch both taps get through before the first navigation lands.
  private launching: boolean = false;

  private play(): void {
    if (this.launching) {
      return;
    }
    this.launching = true;
    GameStore.markAnnouncementSeen();
    if (this.onClose !== undefined) {
      this.onClose();
    }
    const params: Record<string, string> = {
      'dailyGameDate': this.session !== null && this.session.dailyGameDate !== null
        ? this.session.dailyGameDate
        : '',
      'languageCode': this.languageCode
    };
    router.pushUrl({ url: 'pages/WMFWhichCameFirstViewPage', params: params });
  }

  private openAbout(): void {
    // source didTapAbout: presents the game explanation web page
    GameStore.markAnnouncementSeen();
    if (this.onClose !== undefined) {
      this.onClose();
    }
    const params: Record<string, string> = { 'url': WHICH_CAME_FIRST_ABOUT_URL };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }
}

// The routed host. The article view auto-presents the day's game invitation by pushing this,
// rather than by binding yet another cover on a screen that already multiplexes several.
@Entry
@Component
struct GamesSplashPage {
  @State session: CDGameSession | null = null;
  // the Explore card's language (WhichCameFirstCoordinator siteURL); empty means the app language
  @State languageCode: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string> | undefined;
    if (p !== undefined && p !== null) {
      this.languageCode = p['languageCode'] ?? '';
    }
    this.loadSession();
  }

  private async loadSession(): Promise<void> {
    try {
      const code: string = this.languageCode !== '' ? this.languageCode
        : (await LanguageStore.appLanguage()).languageCode;
      const today: string = new Date().toISOString().substring(0, 10);
      this.session = await GameStore.fetchSession(WHICH_CAME_FIRST_GAME_TYPE,
        'wikipedia.' + code, today);
    } catch (e) {
      // The splash still shows its invitation without today's streak.
      console.error('gamesSplash: session unavailable: ' + (e as Error).message);
    }
  }

  build() {
    Column() {
      WMFGamesSplashScreenView({
        session: this.session,
        languageCode: this.languageCode,
        onClose: (): void => {
          router.back();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
