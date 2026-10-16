// Ported from WMFComponents/.../Suggested Edits/Image Recommendations (WMFImageRecommendations-
// ViewController / ViewModel / View, WMFImageRecommendationsBottomSheetViewController and
// WMFImageRecommendationBottomSheetView) and the delegate glue in ExploreViewController.
// "Add image" with back and the More menu (Learn more, Tutorial, Problem with feature) over the
// article summary of the current recommendation and "View article". Once it has loaded, the
// "Add this image?" sheet comes up (medium/large, not dismissible, the article stays usable):
// the image, its file name (opens the file page), description and the reason, over Yes / No /
// Not sure.
// - Yes (only after five seconds on the recommendation): Add image details, then Preview and
//   Save changes, which publishes; back here the feedback is sent and the next one loads.
// - No: the Reason survey; Submit sends the rejection and loads the next one.
// - Not sure: the next one.
// First visit: the onboarding sheet, then the Review / Inspect / Decide tooltips in turn.
import { router, SymbolGlyphModifier } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { GrowthTasksService, ImageRecommendation, ImageRecSession, IMAGE_REC_PUBLISHED_KEY } from '../common/GrowthTasksService';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { InsertMediaSession, InsertMediaSettings } from '../common/InsertMedia';
import { htmlRuns, HtmlRun } from '../common/SimpleHtml';
import { decodeEntities } from '../common/WebDocument';
import { WMFSurveyView, SurveyOption } from '../components/WMFSurveyView';
import { WMFOnboardingView, WMFOnboardingCellModel } from '../components/WMFOnboardingView';


const LEARN_MORE_URL: string = 'https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_Suggested_edits#Add_an_image';
// WMFImageRecommendationsBottomSheetViewController: Yes needs this long on a recommendation
const REVIEW_MS: number = 5000;

function stripHtml(html: string): string {
  return decodeEntities(html.replace(/<[^>]*>/g, '')).replace(/\s+/g, ' ').trim();
}

@Entry
@Component
struct WMFImageRecommendationsViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State recommendations: ImageRecommendation[] = [];
  @State current: ImageRecommendation | null = null;
  @State summary: ArticleSummary | null = null;
  @State isLoading: boolean = true;
  @State loadError: boolean = false;
  @State showSheet: boolean = false;
  @State showSurvey: boolean = false;
  @State showOnboarding: boolean = false;
  @State showMoreMenu: boolean = false;
  // the tooltip on screen: 0 none, 1 Review, 2 Inspect, 3 Decide
  @State tooltip: number = 0;
  private host: string = 'en.wikipedia.org';
  private startTime: number = 0;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.host = params?.['host'] ?? this.host;
    ImageRecSession.host = this.host;
    // viewDidAppear: the onboarding first, the recommendations after it
    if (!GrowthTasksService.hasPresentedOnboardingModal()) {
      this.showOnboarding = true;
      GrowthTasksService.setOnboarding(true, null);
    } else {
      this.fetch();
    }
  }

  // back from Save changes after publishing: feedback, the next recommendation, the toast
  onPageShow(): void {
    if (AppStorage.get<boolean>(IMAGE_REC_PUBLISHED_KEY) === true) {
      AppStorage.setOrCreate<boolean>(IMAGE_REC_PUBLISHED_KEY, false);
      this.next();
      setTimeout(() => {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.editor_edit_published') });
      }, 1000);
    } else if (this.current !== null && this.summary !== null && !this.showSheet) {
      this.presentSheet();
    }
  }

  onPageHide(): void {
    // viewWillDisappear dismisses the sheet
    this.showSheet = false;
    this.tooltip = 0;
  }

  // fetchImageRecommendationsIfNeeded
  private fetch(): void {
    this.isLoading = true;
    this.loadError = false;
    GrowthTasksService.fetch(this.host).then((recs: ImageRecommendation[]) => {
      this.recommendations = recs;
      if (recs.length === 0) {
        this.current = null;
        this.summary = null;
        this.isLoading = false;
        return;
      }
      this.populate(recs[0]);
    }).catch((e: Error) => {
      console.error('imageRecs: fetch failed: ' + e.message);
      this.isLoading = false;
      this.loadError = true;
    });
  }

  // populateImageAndArticleSummary
  private populate(rec: ImageRecommendation): void {
    this.isLoading = true;
    this.loadError = false;
    this.startTime = Date.now();
    ArticleService.fetchSummary(this.host, rec.pageTitle).then((s: ArticleSummary) => {
      rec.summary = s;
      this.current = rec;
      this.summary = s;
      this.isLoading = false;
      this.presentSheet();
    }).catch((e: Error) => {
      console.error('imageRecs: summary failed: ' + e.message);
      this.isLoading = false;
      this.loadError = true;
      this.getUIContext().getPromptAction().showToast({ message: e.message });
    });
  }

  private presentSheet(): void {
    this.showSheet = true;
    // tooltips 0.5 s after the sheet, once
    setTimeout(() => {
      if (!GrowthTasksService.hasPresentedOnboardingTooltips() && this.showSheet) {
        this.tooltip = 1;
      }
    }, 800);
  }

  // next(): drop the current one; a fresh batch when the queue runs out
  private next(): void {
    const done: ImageRecommendation | undefined = this.recommendations[0];
    if (done !== undefined) {
      GrowthTasksService.remove(this.host, done.pageId);
    }
    this.recommendations = this.recommendations.slice(1);
    this.current = null;
    this.summary = null;
    if (this.recommendations.length === 0) {
      GrowthTasksService.reset(this.host);
      this.fetch();
    } else {
      this.populate(this.recommendations[0]);
    }
  }

  private closeTooltip(): void {
    if (this.tooltip >= 3) {
      this.tooltip = 0;
      GrowthTasksService.setOnboarding(null, true);
    } else if (this.tooltip > 0) {
      this.tooltip++;
    }
  }

  private open(url: string, external: boolean): void {
    if (external) {
      (getContext(this) as common.UIAbilityContext).openLink(url).catch((e: Error) => {
        console.error('imageRecs: open failed: ' + e.message);
      });
    } else {
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
    }
  }

  private str(res: Resource): string {
    return getContext(this).resourceManager.getStringSync(res.id);
  }

  // presentProblemWithFeature: the issue-report mail
  private reportProblem(): void {
    const body: string = [this.str($r('app.string.image_recommendations_email_first_line')), '',
      this.str($r('app.string.activity_tab_email_second_line')), '',
      this.str($r('app.string.activity_tab_email_third_line')), '',
      this.str($r('app.string.activity_tab_email_fourth_line')), '',
      this.str($r('app.string.activity_tab_email_fifth_line'))].join('\n');
    const url: string = 'mailto:ios-support@wikimedia.org?subject=' +
      encodeURIComponent(this.str($r('app.string.image_recommendations_email_title'))) + '&body=' +
      encodeURIComponent(body);
    try {
      (getContext(this) as common.UIAbilityContext).openLink(url).catch(() => {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.no_email_account_alert') });
      });
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.no_email_account_alert') });
    }
  }

  // didTapYes: the details screen, then Preview and Save changes
  private yes(): void {
    const rec: ImageRecommendation | null = this.current;
    if (rec === null) {
      return;
    }
    if (Date.now() - this.startTime <= REVIEW_MS) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.image_recs_time_warning_message') });
      return;
    }
    this.showSheet = false;
    this.tooltip = 0;
    ImageRecSession.recommendation = rec;
    InsertMediaSession.start(rec.pageTitle, this.host);
    InsertMediaSession.fileTitle = 'File:' + rec.filename;
    InsertMediaSession.displayTitle = rec.displayFilename;
    InsertMediaSession.imageURL = rec.thumbUrl !== '' ? rec.thumbUrl : rec.fullUrl;
    InsertMediaSession.imageDescription = stripHtml(rec.description);
    InsertMediaSession.filePageURL = rec.descriptionUrl;
    InsertMediaSession.settings = new InsertMediaSettings();
    router.pushUrl({ url: 'pages/InsertMediaSettingsViewControllerPage', params: { 'mode': 'imageRecommendation' } });
  }

  // Reason survey Submit: the rejection, then the next recommendation
  private reject(reasons: string[]): void {
    const rec: ImageRecommendation | null = this.current;
    this.showSurvey = false;
    this.showSheet = false;
    this.tooltip = 0;
    if (rec !== null) {
      GrowthTasksService.sendFeedback(this.host, rec, false, reasons, null, null).catch((e: Error) => {
        this.getUIContext().getPromptAction().showToast({ message: e.message });
      });
    }
    this.next();
  }

  private notSure(): void {
    this.showSheet = false;
    this.tooltip = 0;
    this.next();
  }

  @Builder
  tip(title: Resource, body: Resource) {
    Column({ space: 4 }) {
      Row() {
        Text(title)
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        SymbolGlyph($r('sys.symbol.xmark'))
          .id('image_rec_tooltip_close')
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
          .onClick(() => {
            this.closeTooltip();
          })
      }
      .width('100%')
      Text(body)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.theme_text'))
    }
    .width(260)
    .padding(14)
  }

  @Builder
  tip1() {
    this.tip($r('app.string.image_rec_tooltip_1_title'), $r('app.string.image_rec_tooltip_1_body'))
  }

  @Builder
  tip2() {
    this.tip($r('app.string.image_rec_tooltip_2_title'), $r('app.string.image_rec_tooltip_2_body'))
  }

  @Builder
  tip3() {
    this.tip($r('app.string.image_rec_tooltip_3_title'), $r('app.string.image_rec_tooltip_3_body'))
  }

  @Builder
  moreMenu() {
    Menu() {
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')),
        content: $r('app.string.learn_more_title') })
        .id('image_rec_more_learn_more')
        .onClick(() => {
          this.open(LEARN_MORE_URL, false);
        })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.lightbulb')),
        content: $r('app.string.tutorial_title') })
        .id('image_rec_more_tutorial')
        .onClick(() => {
          // Tutorial replays the three tips whatever the flag says
          if (this.current !== null && this.showSheet) {
            this.tooltip = 1;
          }
        })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.flag')),
        content: $r('app.string.problem_with_feature_title') })
        .id('image_rec_more_problem')
        .onClick(() => {
          this.reportProblem();
        })
    }
  }

  // WMFArticleSummaryView
  @Builder
  articleSummary(s: ArticleSummary) {
    Column() {
      Text(stripHtml(s.displayTitle ?? ''))
        .width('100%')
        .fontSize(28)
        .fontFamily('serif')
        .fontColor($r('app.color.theme_text'))
        .margin({ top: 12 })
      if ((s.articleDescription ?? '') !== '') {
        Text(s.articleDescription ?? '')
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ top: 4 })
      }
      // the divider tooltip 1 points at
      Column()
        .id('image_rec_summary_divider')
        .width(60)
        .height(0.5)
        .margin({ top: 12, bottom: 12 })
        .backgroundColor($r('app.color.theme_border'))
        .bindPopup(this.tooltip === 1, {
          builder: this.tip1(),
          placement: Placement.Bottom,
          enableArrow: true,
          popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
          autoCancel: true,
          onStateChange: (e) => {
            if (!e.isVisible && this.tooltip === 1) {
              this.closeTooltip();
            }
          }
        })
      Text() {
        ForEach(htmlRuns(s.extractHTML ?? s.extract ?? ''), (run: HtmlRun) => {
          Span(run.text)
            .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
        })
      }
      .width('100%')
      .fontSize(16)
      .lineHeight(23)
      .fontColor($r('app.color.theme_text'))
    }
    .width('100%')
  }

  @Builder
  surveySheet() {
    WMFSurveyView({
      title: $r('app.string.image_rec_survey_title'),
      subtitle: $r('app.string.image_rec_survey_instructions_1'),
      instructions: $r('app.string.image_rec_survey_instructions_2'),
      otherPlaceholder: $r('app.string.image_rec_survey_option_6'),
      options: [
        new SurveyOption($r('app.string.image_rec_survey_option_1'), 'notrelevant'),
        new SurveyOption($r('app.string.image_rec_survey_option_2'), 'noinfo'),
        new SurveyOption($r('app.string.image_rec_survey_option_3'), 'offensive'),
        new SurveyOption($r('app.string.image_rec_survey_option_4'), 'lowquality'),
        new SurveyOption($r('app.string.image_rec_survey_option_5'), 'unfamiliar')
      ],
      multiSelect: true,
      onCancel: (): void => {
        this.showSurvey = false;
      },
      onSubmit: (selected: string[]): void => {
        this.reject(selected);
      }
    })
  }

  // WMFImageRecommendationBottomSheetView
  @Builder
  sheet() {
    Column() {
      // the survey's anchor (one bindSheet per node)
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showSurvey, this.surveySheet(), { height: SheetSize.LARGE, showClose: false,
          dragBar: false })
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 5 }) {
            Image($r('app.media.bot'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.theme_link'))
            Text($r('app.string.image_rec_add_image_title'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
          }
          .id('image_rec_sheet_header')
          .width('100%')
          .bindPopup(this.tooltip === 2, {
            builder: this.tip2(),
            placement: Placement.Bottom,
            enableArrow: true,
            popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
            autoCancel: true,
            onStateChange: (e) => {
              if (!e.isVisible && this.tooltip === 2) {
                this.closeTooltip();
              }
            }
          })
          if (this.current !== null) {
            Row({ space: 12 }) {
              Image(this.current.thumbUrl !== '' ? this.current.thumbUrl : this.current.fullUrl)
                .id('image_rec_sheet_image')
                .width(150)
                .height(150)
                .objectFit(ImageFit.Cover)
                .clip(true)
                .onClick(() => {
                  this.open(this.current?.descriptionUrl ?? '', false);
                })
              Column({ space: 8 }) {
                Text() {
                  Span((this.current as ImageRecommendation).displayFilename + '  ')
                  ImageSpan($r('app.media.mini_external'))
                    .width(14)
                    .height(14)
                    .verticalAlign(ImageSpanAlignment.CENTER)
                }
                .id('image_rec_sheet_file')
                .fontSize(16)
                .fontColor($r('app.color.theme_link'))
                .onClick(() => {
                  this.open(this.current?.descriptionUrl ?? '', false);
                })
                if (this.current.description !== '') {
                  Text(stripHtml(this.current.description))
                    .fontSize(16)
                    .fontColor($r('app.color.theme_text'))
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            Text(this.current.reason)
              .width('100%')
              .fontSize(16)
              .fontColor($r('app.color.theme_secondary_text'))
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      // the toolbar: Yes, No, Not sure
      Row() {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(16)
            .fontColor([$r('app.color.theme_link')])
          Text($r('app.string.image_recs_yes_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_link'))
        }
        .id('image_rec_yes')
        .onClick(() => {
          this.yes();
        })
        Blank()
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(16)
            .fontColor([$r('app.color.theme_link')])
          Text($r('app.string.image_recs_no_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_link'))
        }
        .id('image_rec_no')
        .onClick(() => {
          this.tooltip = 0;
          this.showSurvey = true;
        })
        Blank()
        Text($r('app.string.image_recs_not_sure_title'))
          .id('image_rec_not_sure')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_link'))
          .onClick(() => {
            this.notSure();
          })
      }
      .id('image_rec_toolbar')
      .width('100%')
      .height(56)
      .padding({ left: 24, right: 24 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      .bindPopup(this.tooltip === 3, {
        builder: this.tip3(),
        placement: Placement.Top,
        enableArrow: true,
        popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
        autoCancel: true,
        onStateChange: (e) => {
          if (!e.isVisible && this.tooltip === 3) {
            this.closeTooltip();
          }
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  @Builder
  onboardingSheet() {
    WMFOnboardingView({
      title: $r('app.string.image_rec_onboarding_title'),
      cells: [
        new WMFOnboardingCellModel($r('sys.symbol.picture_on_square'), $r('app.string.image_rec_onboarding_item_1_title'),
          $r('app.string.image_rec_onboarding_item_1_body'), true),
        new WMFOnboardingCellModel($r('sys.symbol.checkmark'), $r('app.string.image_rec_onboarding_item_2_title'),
          $r('app.string.image_rec_onboarding_item_2_body'), true),
        new WMFOnboardingCellModel($r('app.media.commons'), $r('app.string.image_rec_onboarding_item_3_title'),
          $r('app.string.image_rec_onboarding_item_3_body'))
      ],
      primaryButtonTitle: $r('app.string.continue_button_title'),
      secondaryButtonTitle: $r('app.string.image_rec_onboarding_learn_more_button'),
      onPrimary: (): void => {
        this.showOnboarding = false;
      },
      onSecondary: (): void => {
        this.open(LEARN_MORE_URL, true);
      }
    })
  }

  @Builder
  emptyOrError(image: Resource, title: Resource, subtitle: Resource, retry: boolean) {
    Column({ space: 12 }) {
      Image(image)
        .width(72)
        .height(72)
        .objectFit(ImageFit.Contain)
        .fillColor($r('app.color.theme_link'))
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
      Text(subtitle)
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
      if (retry) {
        Button($r('app.string.settings_notifications_echo_failure_try_again'))
          .id('image_rec_try_again')
          .type(ButtonType.Normal)
          .borderRadius(8)
          .backgroundColor($r('app.color.theme_link'))
          .onClick(() => {
            if (this.recommendations.length > 0) {
              this.populate(this.recommendations[0]);
            } else {
              this.fetch();
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // nav bar: back, "Add image", More
      Stack() {
        Text($r('app.string.image_rec_title'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
        Row() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_link')])
          }
          .id('image_rec_back')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showSheet = false;
            router.back();
          })
          Blank()
          Button() {
            SymbolGlyph($r('sys.symbol.ellipsis_circle'))
              .fontSize(22)
              .fontColor([$r('app.color.theme_link')])
          }
          .id('image_recommendations_more')
          .type(ButtonType.Normal)
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .bindMenu(this.moreMenu())
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
      }
      .width('100%')
      .height(54)
      // the onboarding's anchor (one bindSheet per node)
      .bindSheet($$this.showOnboarding, this.onboardingSheet(), { height: SheetSize.LARGE, showClose: false,
        dragBar: false, onDisappear: () => {
          this.fetch();
        } })

      Stack() {
        if (this.isLoading) {
          LoadingProgress()
            .width(40)
            .height(40)
        } else if (this.loadError) {
          this.emptyOrError($r('app.media.error'), $r('app.string.image_rec_error_title'),
            $r('app.string.image_rec_error_subtitle'), true)
        } else if (this.summary === null) {
          this.emptyOrError($r('app.media.photo_badge_checkmark'), $r('app.string.image_rec_empty_title'),
            $r('app.string.image_rec_empty_subtitle'), false)
        } else {
          Scroll() {
            Column() {
              this.articleSummary(this.summary as ArticleSummary)
              Row() {
                Blank()
                Row({ space: 4 }) {
                  Text($r('app.string.image_rec_view_article'))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.theme_link'))
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(14)
                    .fontColor([$r('app.color.theme_link')])
                }
                .id('image_rec_view_article')
                .onClick(() => {
                  router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: {
                    'articleTitle': this.current?.pageTitle ?? '', 'languageCode': this.host.split('.')[0] } });
                })
              }
              .width('100%')
              .margin({ top: 19 })
              // keeps the article clear of the sheet
              Column()
                .height(480)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .bindSheet($$this.showSheet, this.sheet(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        showClose: false,
        maskColor: Color.Transparent,
        enableOutsideInteractive: true,
        // isModalInPresentation: it cannot be swiped away
        onWillDismiss: (action: DismissSheetAction) => {
          console.info('imageRecs: sheet stays (reason ' + action.reason + ')');
        }
      })
    }
    .id('WMFImageRecommendationsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
