// screen_year_in_review — presentation: modal, hosted by WMFProfileViewSheet
// (.bindContentCover). NOT a routed page.
// Ported from WMFComponents/.../Year in Review/Views/WMFYearInReviewView.swift:
//   VStack { WMFYearInReviewHeaderView; WMFYearInReviewBodyView } + a bottom toolbar shown
//   only when !isShowingIntro.
// WMFYearInReviewHeaderView  — [donate button when shouldShowTopNavDonateButton, else a
//   spacer] | the W logo | WMFLargeCloseButton(.plainX) -> tappedDone().
// WMFYearInReviewBodyView    — isShowingIntro ? WMFYearInReviewSlideIntroV3View :
//   a paged TabView over viewModel.slides.
// WMFYearInReviewSlideIntroV3View — the scrolling illustration/title/subtitle content, then
//   footer + primaryButton ("Get started", tappedPrimaryButton) + secondaryButton
//   ("Learn more", tappedSecondaryButton).
// WMFYearInReviewToolbarView — the share button (hidden on the last slide) and the
//   next/finish button.
// S5: styled from captured S0186 (intro) and S0188 (slide + toolbar) — the sheet's rounded
// top, the W-logo header with the white plain-X chrome circle, the centred
// illustration/title/subtitle intro, its footnote footer, and the pill primary/secondary
// buttons (46pt, blue fill / gray fill with blue label).
import { router } from '@kit.ArkUI';
import { topSafeInset } from '../common/SafeArea';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { CDYearInReviewSlide } from '../model/CDYearInReviewSlide';
import { YearInReviewStore, YearInReviewReport, SlideId } from '../common/YearInReviewStore';
import { HistoryStore } from '../common/HistoryStore';
import { CDPageView } from '../model/CDPageView';
import { Database } from '../common/Database';
import { Prefs } from '../common/Prefs';
import { NAV_ICON_BUTTON, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';

// WMFUserDefaultsKey.yearInReviewSurveyPresented (hasPresentedYiRSurvey)
const YIR_SURVEY_PRESENTED_KEY: string = 'year-in-review-survey-presented-v3';

// The Year in Review information page behind the intro's "Learn more"
// (tappedLearnMoreAttributedText(url:)).
const YEAR_IN_REVIEW_LEARN_MORE_URL: string = 'https://www.mediawiki.org/wiki/Wikimedia_Apps/Team/Wikipedia_Year_in_Review';

// DonateCoordinator's web donate flow — HarmonyOS has no Apple Pay equivalent, so the
// donate button opens the donation page in the app's web screen (feat_donate substitution).
const DONATE_URL: string = 'https://donate.wikimedia.org/wiki/Ways_to_Give';

// LocalizedStrings.shareText
const SHARE_TEXT: string = 'Here\'s my Wikipedia Year In Review. Created with the Wikipedia app';

// WMFYearInReviewViewModel.LocalizedStrings — the highlights slide titles.
const ARTICLES_READ_TITLE: string = 'Articles read';
const MINUTES_READ_TITLE: string = 'Minutes read';
const FAVORITE_READING_DAY_TITLE: string = 'Favorite day to read';
const MOST_READ_ARTICLES_TITLE: string = 'Articles I read the most';
const WEEKDAY_NAMES: string[] = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday'];

// The serialized slide payload (CDYearInReviewSlide.data) each slide view renders; the
// per-slide counts the bindingContract binds come from here, never from the capture.
interface YearInReviewSlideData {
  title?: string;
  subtitle?: string;
  value?: number;
}

@Component
export struct WMFYearInReviewView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // spec stateVar: items <- svc_yir_store (the report's slides)
  @State items: CDYearInReviewSlide[] = [];
  // WMFYearInReviewViewModel.isShowingIntro / .currentSlideIndex / .isPopulatingReport
  @State isShowingIntro: boolean = true;
  @State currentSlideIndex: number = 0;
  @State isPopulatingReport: boolean = false;
  // shouldShowTopNavDonateButton
  @State shouldShowTopNavDonateButton: boolean = false;
  // the donate flow and the slide share sheet the toolbar raises
  @State showDonate: boolean = false;
  @State isSharing: boolean = false;
  // WMFYearInReviewIntroV3ViewModel title / subtitle / footer
  @State introTitle: string = '';
  @State introSubtitle: string = '';
  @State introFooter: string = '';
  // the sheet's dismiss callback (tappedDone), with whether the reader got past the first slide
  onClose?: (hasSeenTwoSlides: boolean) => void;
  // WMFYearInReviewViewModel.hasSeenTwoSlides: set once the second slide shows
  private hasSeenTwoSlides: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    // CommonStrings.exploreYIRTitlePersonalized / .exploreYIRBodyV3 / .exploreYIRFooterV3
    this.introTitle = 'Explore your Wikipedia Year in Review';
    this.introSubtitle = 'See insights about which articles you read on the Wikipedia app and the edits you made.';
    this.introFooter = 'Your reading history is kept protected. Reading insights are calculated using locally stored data on your device.';
    Database.init(ctx).then(() => {
      // An already-populated report skips the intro's populate step.
      this.loadExistingReport().catch((e: Error) => {
        console.error('yir: report load failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('yir: db init failed: ' + e.message);
    });
  }

  private static currentYear(): number {
    return new Date().getFullYear();
  }

  // fetchYearInReviewReport(forYear:) — the persisted report, if the user already ran it.
  private async loadExistingReport(): Promise<void> {
    const report: YearInReviewReport | null =
      await YearInReviewStore.fetchReport(WMFYearInReviewView.currentYear());
    if (report !== null) {
      this.items = report.slides;
    }
  }

  // populateYearInReviewReportData: the local-history slides, persisted through svc_yir_store.
  private async populateReport(): Promise<void> {
    this.isPopulatingReport = true;
    try {
      const year: number = WMFYearInReviewView.currentYear();
      let report: YearInReviewReport | null = await YearInReviewStore.fetchReport(year);
      if (report === null || report.slides.length === 0) {
        const slides: CDYearInReviewSlide[] = await this.buildSlides(year);
        await YearInReviewStore.createNewReport(year, slides);
        report = await YearInReviewStore.fetchReport(year);
      }
      this.items = report !== null ? report.slides : [];
      this.currentSlideIndex = 0;
    } finally {
      this.isPopulatingReport = false;
    }
  }

  // The readCount / mostReadDate / topArticles slides, all computed from the local
  // CDPageView rows (YearInReview*SlideDataController.populateSlideData).
  private async buildSlides(year: number): Promise<CDYearInReviewSlide[]> {
    const startMs: number = new Date(year, 0, 1).getTime();
    const endMs: number = new Date(year + 1, 0, 1).getTime();
    const counts: Map<string, number> = await HistoryStore.fetchPageViewCounts(startMs, endMs);
    const minutes: number = await HistoryStore.fetchPageViewMinutes(startMs, endMs);
    const views: CDPageView[] = await HistoryStore.fetchAllPageViews();

    // topArticles: fetchPageViewCounts already returns the titles most-viewed first.
    const top: string[] = [];
    counts.forEach((count: number, title: string) => {
      if (top.length < 3) {
        top.push(title);
      }
    });

    // mostReadDate: the weekday carrying the most page views in the year.
    const perWeekday: number[] = [0, 0, 0, 0, 0, 0, 0];
    for (const view of views) {
      const ts: number = view.timestamp;
      if (ts >= startMs && ts < endMs) {
        perWeekday[new Date(ts).getDay()]++;
      }
    }
    let bestDay: number = 0;
    for (let i = 1; i < perWeekday.length; i++) {
      if (perWeekday[i] > perWeekday[bestDay]) {
        bestDay = i;
      }
    }

    const slides: CDYearInReviewSlide[] = [];
    slides.push(WMFYearInReviewView.makeSlide(year, SlideId.readCount, {
      title: ARTICLES_READ_TITLE,
      subtitle: MINUTES_READ_TITLE + ': ' + minutes.toString(),
      value: counts.size
    }));
    slides.push(WMFYearInReviewView.makeSlide(year, SlideId.mostReadDate, {
      title: FAVORITE_READING_DAY_TITLE,
      subtitle: perWeekday[bestDay] > 0 ? WEEKDAY_NAMES[bestDay] : ''
    }));
    slides.push(WMFYearInReviewView.makeSlide(year, SlideId.topArticles, {
      title: MOST_READ_ARTICLES_TITLE,
      subtitle: top.join(', '),
      value: top.length
    }));
    return slides;
  }

  private static makeSlide(year: number, id: string, data: YearInReviewSlideData): CDYearInReviewSlide {
    const slide = new CDYearInReviewSlide();
    slide.id = id;
    slide.year = year;
    slide.reportYear = year;
    slide.data = JSON.stringify(data);
    return slide;
  }

  private slideData(slide: CDYearInReviewSlide): YearInReviewSlideData {
    const raw: string | null = slide.data;
    const empty: YearInReviewSlideData = {};
    if (raw === null || raw === '') {
      return empty;
    }
    return JSON.parse(raw) as YearInReviewSlideData;
  }

  private slideTitle(slide: CDYearInReviewSlide): string {
    const title: string | undefined = this.slideData(slide).title;
    return title !== undefined ? title : '';
  }

  private slideSubtitle(slide: CDYearInReviewSlide): string {
    const subtitle: string | undefined = this.slideData(slide).subtitle;
    return subtitle !== undefined ? subtitle : '';
  }

  // the slide's personalized count (articles read, edits, …)
  private slideValue(slide: CDYearInReviewSlide): string {
    const value: number | undefined = this.slideData(slide).value;
    return value !== undefined ? value.toString() : '';
  }

  // isLastSlide — the share button hides and "Next" becomes "Finish".
  private isLastSlide(): boolean {
    return this.currentSlideIndex >= this.items.length - 1;
  }

  build() {
    Column() {
      // WMFYearInReviewHeaderView
      Row() {
        if (this.shouldShowTopNavDonateButton) {
          // WMFYearInReviewDonateButton
          Button('Donate')
            .id('year_in_review_donate')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 0, right: 0 })
            .onClick(() => {
              this.tappedDonate();
            })
        } else {
          Blank()
        }
        Image($r('app.media.w'))
          .height(20)
          .objectFit(ImageFit.Contain)
        Blank()
        // WMFLargeCloseButton(imageType: .plainX) -> tappedDone()
        Button() {
          SymbolGlyph($r('sys.symbol.multiply'))
            .fontSize(NAV_BUTTON_SYMBOL_SIZE)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('multiply')
          .attributeModifier(NAV_ICON_BUTTON)
          .onClick(() => {
            this.tappedDone();
          })
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16 })

      // WMFYearInReviewBodyView
      if (this.isShowingIntro) {
        // WMFYearInReviewSlideIntroV3View: the scrolling content over the pinned buttons.
        Column() {
          Scroll() {
            Column() {
              Image($r('app.media.puzzle_globe_hand'))
                .width('100%')
                .objectFit(ImageFit.Contain)
              Text(this.introTitle)
                .width('100%')
                .textAlign(TextAlign.Center)
                .fontSize(28)
                .lineHeight(34)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.theme_text'))
                .padding({ left: 32, right: 32 })
                .margin({ top: 16 })
              Text(this.introSubtitle)
                .width('100%')
                .textAlign(TextAlign.Center)
                .fontSize(17)
                .lineHeight(22)
                .fontColor($r('app.color.theme_text'))
                .padding({ left: 32, right: 32 })
                .margin({ top: 16 })
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          // footer + the two pinned buttons share one 32pt-inset column (a %-width child
          // cannot carry horizontal margins without overflowing its parent).
          Column() {
          Text(this.introFooter)
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(13)
            .lineHeight(17)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ bottom: 16 })
          // primaryButtonTitle -> tappedPrimaryButton()
          Button() {
            if (this.isPopulatingReport) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color($r('app.color.wmf_white'))
            } else {
              Text('Get started')
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.wmf_white'))
            }
          }
            .id('get_started')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(46)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.theme_link'))
            .fontColor($r('app.color.wmf_white'))
            .enabled(!this.isPopulatingReport)
            .onClick(() => {
              this.tappedPrimaryButton();
            })
          // secondaryButtonTitle -> tappedSecondaryButton()
          Button('Learn more')
            .id('learn_more')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(46)
            .fontSize(17)
            .backgroundColor($r('app.color.gray100'))
            .fontColor($r('app.color.theme_link'))
            .margin({ top: 16 })
            .onClick(() => {
              this.tappedSecondaryButton();
            })
          }
          .width('100%')
          .padding({ left: 32, right: 32, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column() {
          // the paged TabView over viewModel.slides
          Swiper() {
            ForEach(this.items, (slide: CDYearInReviewSlide) => {
              Column() {
                Text(this.slideValue(slide))
                  .width('100%')
                  .fontSize(48)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.theme_text'))
                Text(this.slideTitle(slide))
                  .width('100%')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.theme_text'))
                  .margin({ top: 8 })
                Text(this.slideSubtitle(slide))
                  .width('100%')
                  .fontSize(17)
                  .lineHeight(24)
                  .fontColor($r('app.color.theme_text'))
                  .margin({ top: 12 })
              }
              .width('100%')
              .height('100%')
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .padding({ left: 32, right: 32 })
            }, (slide: CDYearInReviewSlide) => slide.id)
          }
          .index(this.currentSlideIndex)
          .indicator(false)
          .width('100%')
          .layoutWeight(1)
          .onChange((index: number) => {
            this.currentSlideIndex = index;
            if (index === 1) {
              this.hasSeenTwoSlides = true;
            }
          })

          // WMFYearInReviewToolbarView
          Row() {
            if (!this.isLastSlide()) {
              Button('Share')
                .id('share')
                .type(ButtonType.Normal)
                .backgroundColor(Color.Transparent)
                .fontSize(17)
                .fontColor($r('app.color.theme_link'))
                .padding({ left: 0, right: 0 })
                .onClick(() => {
                  this.tappedShare();
                })
            }
            Blank()
            Button(this.isLastSlide() ? 'Finish' : 'Next')
              .id('next')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_link'))
              .padding({ left: 0, right: 0 })
              .onClick(() => {
                this.tappedNext();
              })
          }
          .width('100%')
          .height(52)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 32, right: 32 })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .id('WMFYearInReviewView')
    .width('100%')
    .height('100%')
    // full-screen cover: below the status bar, or the close X sits under the clock
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    // the sheet's rounded top edge over the presenting screen
    .borderRadius({ topLeft: 16, topRight: 16 })
    .clip(true)
  }

  // tappedPrimaryButton(): populates the report, then leaves the intro for the slides.
  private tappedPrimaryButton(): void {
    this.populateReport().then(() => {
      this.isShowingIntro = false;
    }).catch((e: Error) => {
      console.error('yir: populate failed: ' + e.message);
      this.isShowingIntro = false;
    });
  }

  // tappedSecondaryButton(): opens the Year in Review information page.
  private tappedSecondaryButton(): void {
    const params: Record<string, string> = { 'url': YEAR_IN_REVIEW_LEARN_MORE_URL };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private tappedDone(): void {
    if (this.onClose !== undefined) {
      this.onClose(this.hasSeenTwoSlides);
    }
  }

  // WMFYearInReviewDonateButton -> the donate flow; on HarmonyOS that is the web page.
  private tappedDonate(): void {
    this.showDonate = true;
    const params: Record<string, string> = { 'url': DONATE_URL };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params }).then(() => {
      this.showDonate = false;
    }).catch((e: Error) => {
      console.error('yir: donate open failed: ' + e.message);
      this.showDonate = false;
    });
  }

  // The toolbar share button. No ShareKit in this SDK: copy the slide text to the clipboard
  // and confirm by toast (self-signed-capabilities.md — never a silent no-op).
  private tappedShare(): void {
    this.isSharing = true;
    const slides: CDYearInReviewSlide[] = this.items;
    const index: number = this.currentSlideIndex;
    const slide: CDYearInReviewSlide | null =
      index >= 0 && index < slides.length ? slides[index] : null;
    const detail: string = slide !== null
      ? this.slideValue(slide) + ' ' + this.slideTitle(slide) : '';
    const text: string = (detail.trim() !== '' ? detail.trim() + ' — ' : '') + SHARE_TEXT;
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.isSharing = false;
      this.getUIContext().getPromptAction().showToast({ message: 'Year in Review copied' });
    }).catch((e: Error) => {
      this.isSharing = false;
      console.error('yir: share failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not share this slide' });
    });
  }

  // nextButtonTitle / finishButtonTitle
  private tappedNext(): void {
    if (this.isLastSlide()) {
      // tappedNext on the last slide dismisses with hasSeenTwoSlides: true
      this.hasSeenTwoSlides = true;
      this.tappedDone();
    } else {
      this.currentSlideIndex = this.currentSlideIndex + 1;
      if (this.currentSlideIndex === 1) {
        this.hasSeenTwoSlides = true;
      }
    }
  }
}

// Routed, not a cover: hosted in the profile sheet's bindContentCover this view never redrew
// on its own state, so "Get started" did nothing and the slides never appeared.
@Entry
@Component
struct WMFYearInReviewViewPage {
  build() {
    Column() {
      WMFYearInReviewView({
        // .dismiss(hasSeenTwoSlides:) -> presentSurveyIfNeeded(): the survey once, in place of
        // Year in Review
        onClose: (hasSeenTwoSlides: boolean): void => {
          if (hasSeenTwoSlides && !Prefs.getBoolean(YIR_SURVEY_PRESENTED_KEY, false)) {
            Prefs.putBoolean(YIR_SURVEY_PRESENTED_KEY, true);
            router.replaceUrl({ url: 'pages/YearInReviewSurveyViewControllerPage' });
          } else {
            router.back();
          }
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
