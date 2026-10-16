// screen_description_welcome_initial — presentation: modal, hosted by
// ExploreViewControllerPage (.bindContentCover). NOT a routed page.
//
// S3 structure from Wikipedia/Code/DescriptionWelcomeInitialViewController.swift, which
// embeds DescriptionWelcomePageViewController: a 2-page UIPageViewController
// (DescriptionWelcomePageType .intro then .exploration), each page a
// DescriptionWelcomeContainerViewController = DescriptionWelcomeImageViewController on top
// ("description-cat" / "description-planet") over DescriptionWelcomePanelViewController
// (titleLabel, the embedded DescriptionWelcomeContentsViewController descriptionLabel,
// bottomLabel = welcomePromiseTitle, and the capsule "Start editing" nextButton whose
// container is hidden on every page except .exploration).
// Below the pager the page VC adds its own nextButton / skipButton (buttonHeight 40,
// centerX +/- 88), and hideButtons(for:) fades BOTH plus the page control to alpha 0 on the
// last page and disables Next there — reproduced with .opacity/.enabled so the control
// nodes stay addressable for replay.
// S4: Next -> showNextWelcomePage (advance, or dismiss on the last page); Skip and
// "Start editing" -> dismiss(completion: completionBlock), which records that the
// description-editing welcome was seen (svc_prefs) and closes the host's cover.
// S5: capture base.ui.json (402x874) — image 218x218 at y269, title 65..337 y504 (24pt),
// subtitle y553 (15pt secondary), Skip x80 / Next x289 at y800, both 40 tall.
import { common } from '@kit.AbilityKit';
import { Prefs } from '../common/Prefs';

@Component
export struct DescriptionWelcomeInitialView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // dismiss(animated:completion:) on the presenting Explore VC
  onDismiss: () => void = () => {
    console.info('descriptionWelcome: dismissed');
  };

  // presentationIndex(for:) of the embedded UIPageViewController
  @State pageIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();

  private isLastPage(): boolean {
    return this.pageIndex >= 1;
  }

  // completionBlock: the welcome is only shown once, so mark it seen before dismissing.
  private finish(): void {
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      Prefs.putBoolean('did-show-description-editing-welcome', true);
    } catch (e) {
      console.error('descriptionWelcome: prefs unavailable: ' + (e as Error).message);
    }
    this.onDismiss();
  }

  // nextButtonTapped -> showNextWelcomePage(currentVC): advance, or dismiss past the end.
  private next(): void {
    if (this.isLastPage()) {
      this.finish();
      return;
    }
    this.swiperController.showNext();
  }

  // DescriptionWelcomeContainerViewController: image on top, panel below.
  @Builder
  welcomePage(image: Resource, title: Resource, subtitle: Resource, isExploration: boolean) {
    Column() {
      Image(image)
        .width(218)
        .height(218)
        .objectFit(ImageFit.Contain)
        .margin({ top: 60 })

      Column() {
        // DescriptionWelcomePanelViewController.titleLabel
        Text(title)
          .width('100%')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .margin({ top: 17 })

        // DescriptionWelcomeContentsViewController.descriptionLabel
        Text(subtitle)
          .width('100%')
          .fontSize(15)
          .lineHeight(20)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })

        if (isExploration) {
          // nextButtonContainerView is only unhidden for .exploration
          Button($r('app.string.description_welcome_start_editing_button'))
            .id('start_editing')
            .type(ButtonType.Capsule)
            .height(46)
            .constraintSize({ minWidth: 220 })
            .fontSize(17)
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .backgroundColor($r('app.color.theme_link'))
            .margin({ top: 24 })
            .onClick(() => {
              this.finish();
            })
        }

        // DescriptionWelcomePanelViewController.bottomLabel = welcomePromiseTitle
        Text($r('app.string.description_welcome_promise_title'))
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .margin({ top: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 65, right: 65 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        this.welcomePage($r('app.media.description_cat'),
          $r('app.string.description_welcome_descriptions_title'),
          $r('app.string.description_welcome_descriptions_sub_title'), false)
        this.welcomePage($r('app.media.description_planet'),
          $r('app.string.description_welcome_concise_title'),
          $r('app.string.description_welcome_concise_sub_title'), true)
      }
      .layoutWeight(1)
      .width('100%')
      .loop(false)
      // UIPageControl: fades out with the buttons on the last page.
      .indicator(Indicator.dot()
        .color($r('app.color.gray300'))
        .selectedColor($r('app.color.theme_link')))
      .displayArrow(false)
      .onChange((index: number) => {
        this.pageIndex = index;
      })

      // The page VC's own skip / next buttons, bottom-aligned, +/-88 from centerX.
      Row() {
        Button($r('app.string.button_skip'))
          .id('skip')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .height(40)
          .fontSize(17)
          .fontColor($r('app.color.gray400'))
          .onClick(() => {
            this.finish();
          })

        Blank()

        Button($r('app.string.button_next'))
          .id('next')
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
      .padding({ left: 70, right: 70 })
      // hideButtons(for:): alpha 0 on the last page (the capsule button takes over)
      .opacity(this.isLastPage() ? 0 : 1)
    }
    .id('DescriptionWelcomeInitialViewController')
    .width('100%')
    .height('100%')
    .padding({ bottom: 34 })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
