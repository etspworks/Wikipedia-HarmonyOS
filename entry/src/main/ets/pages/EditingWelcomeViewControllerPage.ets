// screen_editing_welcome — presentation: modal, hosted by screen_explore
// (.bindContentCover in ExploreViewControllerPage). NOT a routed page.
//
// S3 structure from Wikipedia/Code/EditingWelcomeViewController.swift: a WelcomeViewController
// over FOUR WelcomeContainerViewControllers, one per data source — BeBold, ImpartialTone,
// CiteReliableSources, SetKnowledgeFree. Each container is a WelcomeAnimationView (a static
// image with its animated overlay images stacked on it) above a WelcomePanelViewController
// (titleLabelText, the WelcomePanelLabelContentViewController text, an optional actionLabel
// and an optional capsule actionButton). Only BeBold carries the promise actionLabel; only
// SetKnowledgeFree carries the "Get started" actionButton — the other two pass nil for both.
// The shared WelcomePageViewController supplies the bottom Skip / Next buttons and fades them
// out on the last page (reproduced with .opacity so the nodes stay addressable for replay).
// S4: Next advances the pager or dismisses past the end; Skip and "Get started" dismiss,
// recording that the editing welcome was seen (svc_prefs) before closing the host's cover.
// S5: capture base.ui.json (402x874) — the animation band spans the full width y87..494,
// title 24..378 at y504 (24pt bold), body y553 (15pt), promise line y777 (13pt secondary),
// Skip x80 / Next x289 at y800.
import { common } from '@kit.AbilityKit';
import { Prefs } from '../common/Prefs';

@Component
export struct EditingWelcomeView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  onDismiss: () => void = () => {
    console.info('editingWelcome: dismissed');
  };

  @State pageIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private static readonly pageCount: number = 4;

  private isLastPage(): boolean {
    return this.pageIndex >= EditingWelcomeView.pageCount - 1;
  }

  private finish(): void {
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      Prefs.putBoolean('did-show-editing-welcome', true);
    } catch (e) {
      console.error('editingWelcome: prefs unavailable: ' + (e as Error).message);
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

  // WelcomePanelViewController(titleLabelText:actionLabelText:actionButtonTitle:content:)
  @Builder
  panel(title: Resource, body: Resource, hasPromise: boolean, hasActionButton: boolean) {
    Column() {
      Text(title)
        .width('100%')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)

      Text(body)
        .width('100%')
        .fontSize(15)
        .lineHeight(20)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })

      if (hasActionButton) {
        Button($r('app.string.welcome_explore_continue_button'))
          .id('get_started')
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

      if (hasPromise) {
        Text($r('app.string.description_welcome_promise_title'))
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .margin({ top: 24 })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 24, right: 24, top: 10 })
    .alignItems(HorizontalAlign.Center)
  }

  // WelcomeAnimationView(staticImageNamed:animatedImageViews:) — the static plate with its
  // animated overlay images drawn on top of it.
  @Builder
  animationBand(staticImage: Resource, overlayA: Resource, overlayB: Resource, hasOverlayB: boolean) {
    Stack() {
      Image(staticImage)
        .width('100%')
        .height(407)
        .objectFit(ImageFit.Contain)
      Image(overlayA)
        .width('100%')
        .height(407)
        .objectFit(ImageFit.Contain)
      if (hasOverlayB) {
        Image(overlayB)
          .width(244)
          .height(136)
          .objectFit(ImageFit.Contain)
      }
    }
    .width('100%')
    .height(407)
  }

  @Builder
  welcomePage(staticImage: Resource, overlayA: Resource, overlayB: Resource, hasOverlayB: boolean,
    title: Resource, body: Resource, hasPromise: boolean, hasActionButton: boolean) {
    Column() {
      this.animationBand(staticImage, overlayA, overlayB, hasOverlayB)
      this.panel(title, body, hasPromise, hasActionButton)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        // BeBoldDataSource: static "be-bold/article" + pluses + the edit overlay
        this.welcomePage($r('app.media.article'), $r('app.media.pluses'), $r('app.media.edit'), true,
          $r('app.string.editing_welcome_be_bold_title'),
          $r('app.string.editing_welcome_be_bold_subtitle'), true, false)
        // ImpartialToneDataSource: static "impartial-tone/stem" + its scale overlays
        this.welcomePage($r('app.media.stem'), $r('app.media.pluses_2'), $r('app.media.saturn'), true,
          $r('app.string.editing_welcome_impartial_tone_title'),
          $r('app.string.editing_welcome_impartial_tone_subtitle'), false, false)
        // CiteReliableSourcesDataSource: static "cite/article" + highlight + pluses
        this.welcomePage($r('app.media.article_3'), $r('app.media.pluses_3'),
          $r('app.media.highlight'), true,
          $r('app.string.editing_welcome_citations_title'),
          $r('app.string.editing_welcome_citations_subtitle'), false, false)
        // SetKnowledgeFreeDataSource: static "set-knowledge-free/main-article" + pluses
        this.welcomePage($r('app.media.main_article'), $r('app.media.pluses_4'),
          $r('app.media.pluses_4'), false,
          $r('app.string.editing_welcome_set_knowledge_free_title'),
          $r('app.string.editing_welcome_set_knowledge_free_subtitle'), false, true)
      }
      .layoutWeight(1)
      .width('100%')
      .loop(false)
      .indicator(Indicator.dot()
        .color($r('app.color.gray300'))
        .selectedColor($r('app.color.theme_link')))
      .displayArrow(false)
      .onChange((index: number) => {
        this.pageIndex = index;
      })

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
      .opacity(this.isLastPage() ? 0 : 1)
    }
    .id('EditingWelcomeViewController')
    .width('100%')
    .height('100%')
    .padding({ bottom: 34 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
