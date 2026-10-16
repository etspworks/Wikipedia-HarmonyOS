// screen_which_came_first — presentation: page (routed from the games splash modal).
// S3 structure from WMFComponents/.../Games/Which Came First/Core/WMFWhichCameFirstView.swift
// + Core/Cards/WMFWhichCameFirstCardView.swift. NO capture exists — structure is the source
// view hierarchy only:
//   content switches on viewModel.phase: loading | gameplay | complete | error(message)
//   gameplay = header (title, shown while showTitle && not revealed)
//            + card A (showCardA) / feedback banner (revealState) or spacer / card B (showCardB)
//            + footer (progress dots, Submit while awaitingSubmission, Next|See Results while revealing)
//   card     = event text (scrolling) + 100x100 thumbnail (only when the event has an image)
//            + result icon and date pill after reveal
// Source has Submit and Retry buttons that the plan's controlInventory omits — source wins;
// their ids come from the source localization keys, matching the plan's next-button slug.
// Styling is S5/S6.
// S4 wiring — WMFWhichCameFirstViewModel + WMFGamesDataController:
//   load()                 -> FeedService.fetchOnThisDayEvents (feed_onthisday, svc_feed)
//                             + GameStore.fetchSession / fetchOrStartDailySession (svc_game_store)
//   select()               -> viewModel.select
//   submitSelectedAnswer() -> GameStore.submitAnswer (persists the answer, index and score)
//   advance()              -> viewModel.animateOutAndAdvance / advanceInternal
import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import common from '@ohos.app.ability.common';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { formatString } from '../common/Plural';
import { whichCameFirstShareCard, ShareCardModel, ShareCardArticle } from '../components/WhichCameFirstShareCard';
import { WMFFeedOnThisDayEvent } from '../model/WMFFeedOnThisDayEvent';
import { CDGameSession } from '../model/CDGameSession';
import { FeedService } from '../common/FeedService';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import {
  AnswerResult,
  GameStore,
  WhichCameFirstEvent,
  WhichCameFirstGameState,
  WhichCameFirstQuestion,
  WHICH_CAME_FIRST_GAME_TYPE,
  makeWhichCameFirstQuestions
} from '../common/GameStore';
import { GamesNavBar, gameDateTitle } from './WMFGamesSplashScreenViewControllerPage';

// WMFGamesDataController.whichCameFirstQuestionCount / whichCameFirstSupportedLanguageCodes.
const QUESTION_COUNT: number = 5;
const OFFLINE_ERROR: string = 'offline';
const SUPPORTED_LANGUAGE_CODES: string[] = ['de', 'en', 'fr', 'pt', 'ru', 'es', 'ar', 'zh', 'tr'];

@Entry
@Component
struct WMFWhichCameFirstViewPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';

  // svc_feed — the on-this-day events the question pairs are drawn from
  @State items: WMFFeedOnThisDayEvent[] = [];
  // svc_game_store — the daily CDGameSession (score / currentQuestionIndex)
  @State session: CDGameSession | null = null;
  // gameState.questions, decoded from CDGameSession.contentData
  @State questions: WhichCameFirstQuestion[] = [];
  // viewModel.phase
  @State phase: string = 'loading';
  @State errorMessage: ResourceStr = '';
  @State currentIndex: number = 0;
  @State picked: string = '';          // '' | 'A' | 'B'  (viewModel.select)
  @State correctOption: string = '';   // revealState.correct
  @State revealed: boolean = false;
  // viewModel.progressResults: one entry per question — 'pending' | 'correct' | 'wrong'
  @State progressResults: string[] = [];
  // viewModel.hasLoaded — load() runs once per presentation
  private hasLoaded: boolean = false;
  private submitting: boolean = false;
  // the game's wiki, for the share card's article summaries
  private host: string = 'en.wikipedia.org';
  private sharing: boolean = false;
  // WMFWhichCameFirstViewModel(date:) — an archive day (yyyy-MM-dd); '' is today
  private archiveDate: string = '';
  private languageCode: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.archiveDate = params !== undefined ? (params['date'] ?? '') : '';
    this.load();
  }

  // showGameForArchiveDate: the archive goes back here with the picked day, and the game
  // reloads with it (viewModel.reload(with:)).
  onPageShow(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    const date: string = params !== undefined ? (params['date'] ?? '') : '';
    if (date !== '' && date !== this.archiveDate) {
      this.archiveDate = date;
      this.hasLoaded = false;
      this.load();
    }
  }

  // onPlayArchive -> showArchive
  private showArchive(): void {
    router.pushUrl({ url: 'pages/WMFWhichCameFirstArchiveViewControllerPage',
      params: { 'languageCode': this.languageCode } }).catch((e: Error) => {
      console.error('which came first: archive route failed: ' + e.message);
    });
  }

  private currentQuestion(): WhichCameFirstQuestion | null {
    return this.currentIndex < this.questions.length ? this.questions[this.currentIndex] : null;
  }

  private optionFor(option: string, index: number = this.currentIndex): WhichCameFirstEvent | null {
    const question: WhichCameFirstQuestion | null =
      index < this.questions.length ? this.questions[index] : null;
    if (question === null) {
      return null;
    }
    const picked: WhichCameFirstEvent | undefined =
      option === 'A' ? question.optionA : question.optionB;
    return picked === undefined ? null : picked;
  }

  // bindingContract: event pair cards <- svc_feed WMFFeedOnThisDayEvent (text, year)
  private eventText(option: string): string {
    const event: WhichCameFirstEvent | null = this.optionFor(option);
    return event === null || event.text === undefined ? '' : event.text;
  }

  private eventYear(option: string): string {
    const event: WhichCameFirstEvent | null = this.optionFor(option);
    return event === null || event.year === undefined ? '' : event.year.toString();
  }

  // Source keeps the option's thumbnailURL on the persisted question; the ported contentData
  // holds page titles only, so the image is resolved back from the fetched feed events.
  private eventThumbnail(option: string, index: number = this.currentIndex): string {
    const event: WhichCameFirstEvent | null = this.optionFor(option, index);
    if (event === null) {
      return '';
    }
    if (event.thumbnailURL !== undefined) {
      return event.thumbnailURL;
    }
    for (const item of this.items) {
      if (item.text === event.text) {
        for (const preview of item.articlePreviews) {
          const url: string | null = preview.thumbnailURL;
          if (url !== null && url !== '') {
            return url;
          }
        }
      }
    }
    return '';
  }

  // the next question's two thumbnails, fetched while the answer is on screen so Next shows
  // them at once
  private nextThumbnails(): string[] {
    const next: number = this.currentIndex + 1;
    return [this.eventThumbnail('A', next), this.eventThumbnail('B', next)].filter((u: string) => u !== '');
  }

  private totalQuestions(): number {
    return this.questions.length;
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return String(e);
  }

  // viewModel.load — resumes the day's session, or starts one from the on-this-day feed.
  private async load(): Promise<void> {
    if (this.hasLoaded) {
      return;
    }
    this.hasLoaded = true;
    this.phase = 'loading';
    this.revealed = false;
    this.picked = '';
    this.correctOption = '';
    try {
      const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
      const requested: string = params !== undefined ? (params['languageCode'] ?? '') : '';
      const lang: MWKLanguageLink = requested !== ''
        ? MWKLanguageLink.fromJson({ languageCode: requested, pageTitleText: '', localizedName: requested, name: requested })
        : await LanguageStore.appLanguage();
      if (!SUPPORTED_LANGUAGE_CODES.includes(lang.languageCode.toLowerCase())) {
        throw new Error('missingProject');
      }
      const host: string = lang.languageCode + '.wikipedia.org';
      this.host = host;
      const projectID: string = 'wikipedia.' + lang.languageCode;
      this.languageCode = lang.languageCode;
      const now = this.archiveDate !== '' ? new Date(this.archiveDate + 'T12:00:00') : new Date();
      const year: number = now.getFullYear();
      const month: number = now.getMonth() + 1;
      const day: number = now.getDate();
      const date: string = this.archiveDate !== '' ? this.archiveDate : now.toISOString().substring(0, 10);

      // svc_feed / feed_onthisday — the event pool the question pairs (and their thumbnails)
      // are drawn from.
      let fetchFailed: boolean = false;
      try {
        this.items = await FeedService.fetchOnThisDayEvents(host, lang.languageCode, month, day);
      } catch (e) {
        console.error('whichCameFirst: on-this-day fetch failed: ' + this.describeError(e));
        this.items = [];
        fetchFailed = true;
      }

      // svc_game_store — resume the day's session, or persist a new one.
      let session: CDGameSession | null =
        await GameStore.fetchSession(WHICH_CAME_FIRST_GAME_TYPE, projectID, date);
      if (session === null) {
        const questions: WhichCameFirstQuestion[] =
          makeWhichCameFirstQuestions(this.items, month, day, year, QUESTION_COUNT);
        if (questions.length !== QUESTION_COUNT) {
          // Offline with no session started today: say so, rather than the raw error name.
          throw new Error(fetchFailed ? OFFLINE_ERROR : 'insufficientQuestions');
        }
        const emptyAnswers: Record<string, string> = {};
        const state: WhichCameFirstGameState = { questions: questions, answers: emptyAnswers };
        session = await GameStore.fetchOrStartDailySession(projectID, date, JSON.stringify(state));
      }
      this.session = session;

      const state: WhichCameFirstGameState =
        JSON.parse(session.contentData) as WhichCameFirstGameState;
      this.questions = state.questions ?? [];
      const answers: Record<string, string> = state.answers ?? {};

      // Rebuild the progress row and the resume position from the persisted answers.
      const results: string[] = [];
      let answered: number = 0;
      for (const question of this.questions) {
        const qid: string = question.id ?? '';
        const pickedOption: string | undefined = answers[qid];
        if (pickedOption === undefined) {
          results.push('pending');
        } else {
          answered += 1;
          results.push(pickedOption === (question.correctAnswer ?? '') ? 'correct' : 'wrong');
        }
      }
      this.progressResults = results;
      this.currentIndex = answered;
      this.phase = answered >= this.questions.length ? 'complete' : 'gameplay';
    } catch (e) {
      this.hasLoaded = false;
      const detail: string = this.describeError(e);
      this.errorMessage = detail === OFFLINE_ERROR ? $r('app.string.no_internet_connection') : detail;
      this.phase = 'error';
    }
  }

  // viewModel.select — only before the answer is revealed.
  private select(option: string): void {
    if (this.revealed) {
      return;
    }
    this.picked = option;
  }

  // viewModel.submitSelectedAnswer — records it through GameStore.submitAnswer, which
  // persists the answer, the question index and the score on the CDGameSession.
  private async submitSelectedAnswer(): Promise<void> {
    const question: WhichCameFirstQuestion | null = this.currentQuestion();
    const session: CDGameSession | null = this.session;
    if (this.picked === '' || this.submitting || question === null || session === null) {
      return;
    }
    this.submitting = true;
    try {
      const result: AnswerResult =
        await GameStore.submitAnswer(session.identifier, question.id ?? '', this.picked);
      this.correctOption = result.correctAnswer;
      const results: string[] = [];
      for (let i = 0; i < this.progressResults.length; i++) {
        results.push(i === this.currentIndex
          ? (result.isCorrect ? 'correct' : 'wrong')
          : this.progressResults[i]);
      }
      this.progressResults = results;
      this.revealed = true;
      // score is bound to CDGameSession.score — re-read the row the store just updated.
      this.session = await GameStore.fetchSession(
        WHICH_CAME_FIRST_GAME_TYPE, session.projectID, session.dailyGameDate);
    } catch (e) {
      this.errorMessage = this.describeError(e);
      this.phase = 'error';
    } finally {
      this.submitting = false;
    }
  }

  // viewModel.animateOutAndAdvance / advanceInternal
  private advance(): void {
    this.revealed = false;
    this.picked = '';
    this.correctOption = '';
    if (this.currentIndex >= this.totalQuestions() - 1) {
      this.phase = 'complete';
      return;
    }
    this.currentIndex = this.currentIndex + 1;
  }

  // errorView Retry — source clears hasLoaded and loads again.
  private retry(): void {
    this.hasLoaded = false;
    this.errorMessage = '';
    this.load();
  }

  // WMFWhichCameFirstCardView.revealColor — green when the card is the correct pick,
  // red when it is the wrong pick, secondary text otherwise.
  private revealColor(option: string): Resource {
    if (this.correctOption === option) {
      return $r('app.color.green700');
    }
    if (this.picked === option) {
      return $r('app.color.red700');
    }
    return $r('app.color.theme_secondary_text');
  }

  // Card shadow: theme.text at 5%, dropped while the card is selected (it takes a border).
  private cardShadow(option: string): ShadowOptions {
    const shadow: ShadowOptions = this.picked === option
      ? { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 }
      : { radius: 8, color: '#0D202122', offsetX: 0, offsetY: 0 };
    return shadow;
  }

  @Builder
  eventCard(option: string, slug: string) {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Row() {
          Scroll() {
            Text(this.eventText(option))
              .fontSize(13)                       // WMFFont.footnote
              .fontColor($r('app.color.theme_text'))
              .lineHeight(18)
              .width('100%')
              .padding({ right: 2 })
          }
          .layoutWeight(1)
          .align(Alignment.TopStart)
          .scrollBar(BarState.Auto)
          .padding({ right: 8 })

          // keyed on the URL: a reused Image node keeps drawing the previous question's
          // picture until the new one arrives
          ForEach(this.eventThumbnail(option) !== '' ? [this.eventThumbnail(option)] : [], (url: string) => {
            Image(url)
              .width(100)
              .height(100)
              .objectFit(ImageFit.Cover)
              .borderRadius(2)
              .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
              .margin({ left: 16 })
          }, (url: string) => url)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .height('100%')
        .padding(16)

        // resultIcon — shown after reveal on the picked / correct card
        if (this.revealed && (this.picked === option || this.correctOption === option)) {
          Text(this.correctOption === option ? '✓' : '✕')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .fontSize(15)                         // WMFFont.subheadline
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .backgroundColor(this.correctOption === option
              ? $r('app.color.green700')
              : $r('app.color.red700'))
            .borderRadius(15)
            .margin({ right: 12, bottom: 12 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(10)
      .borderWidth(this.picked === option ? 1 : 0)
      .borderColor($r('app.color.theme_text'))
      .shadow(this.cardShadow(option))

      // datePill — the event's date, revealed with the answer
      if (this.revealed) {
        Text(this.eventYear(option))
          .fontSize(15)                           // WMFFont.subheadline
          .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .backgroundColor(this.revealColor(option))
          .borderRadius(14)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .offset({ y: 10 })
      }
    }
    .id(slug)
    .width('100%')
    .height(192)
    .onClick(() => {
      this.select(option);
    })
  }

  @Builder
  feedbackBanner() {
    Row({ space: 4 }) {
      Text(this.picked === this.correctOption
        ? $r('app.string.which_came_first_correct_feedback')
        : $r('app.string.which_came_first_incorrect_feedback'))
        .maxLines(2)
        .fontSize(13)                             // WMFFont.footnote
        .fontColor($r('app.color.theme_text'))
      if (this.picked === this.correctOption) {
        Text($r('app.string.which_came_first_correct_feedback2'))
          .maxLines(1)
          .fontSize(13)
          .fontColor($r('app.color.theme_accent'))
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  progressDots() {
    Row({ space: 8 }) {
      ForEach(this.progressResults, (result: string) => {
        // answered -> filled check (green700) / cross (red700); pending -> a plain
        // theme.newBorder circle, so the glyph is hidden and the disc is the dot.
        Text(result === 'correct' ? '✓' : (result === 'wrong' ? '✕' : '•'))
          .width(20)
          .height(20)
          .textAlign(TextAlign.Center)
          .fontSize(15)                           // WMFFont.subheadline
          .fontColor(result === 'correct'
            ? $r('app.color.green700')
            : (result === 'wrong' ? $r('app.color.red700') : Color.Transparent))
          .backgroundColor(result === 'pending'
            ? $r('app.color.theme_new_border')
            : Color.Transparent)
          .borderRadius(10)
      }, (result: string, index: number) => `${index}-${result}`)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.materialColor())
    .borderRadius(22)
  }

  // .regularMaterial over the mid background: a light grey (dark grey on dark themes)
  private materialColor(): ResourceColor {
    return this.isDark ? '#2C2D30' : '#F2F4F5';
  }

  @Builder
  footerArea() {
    Row({ space: 12 }) {
      this.progressDots()
      Blank()
      // Submit — source footer, phase == .awaitingSubmission
      if (!this.revealed && this.picked !== '') {
        Button($r('app.string.which_came_first_submit_button'))
          .id('which-came-first-submit-button')
          .type(ButtonType.Capsule)
          .fontSize(15)                           // WMFFont.semiboldSubheadline
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .backgroundColor(this.materialColor())
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => {
            this.submitSelectedAnswer();
          })
      }
      // Next / See Results — source footer, phase == .revealing
      if (this.revealed) {
        Button(this.currentIndex === this.totalQuestions() - 1
          ? $r('app.string.which_came_first_see_results_button')
          : $r('app.string.which_came_first_next_button'))
          .id('which-came-first-next-button')
          .type(ButtonType.Capsule)
          .fontSize(15)                           // WMFFont.semiboldSubheadline
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .backgroundColor(this.materialColor())
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => {
            this.advance();
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  gameplayView() {
    Column() {
      // header block — title hidden once the answer is revealed
      Stack({ alignContent: Alignment.Bottom }) {
        if (!this.revealed) {
          Text($r('app.string.which_came_first_title'))
            .textAlign(TextAlign.Center)
            .fontSize(28)                         // WMFFont.georgiaTitle1
            .fontFamily('serif')
            .fontColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
            .padding({ top: 16, bottom: 40 })
        }
      }
      .width('100%')
      .height('25%')
      .backgroundColor($r('app.color.theme_link'))

      // padding(.top, -16): the cards ride 16 up onto the blue band; the mid background does not
      Column() {
      Column() {
        this.eventCard('A', 'wcf_top_card')

        if (this.revealed) {
          this.feedbackBanner()
        } else {
          Blank().height(32)
        }

        this.eventCard('B', 'wcf_bottom_card')

        Blank()

        // prefetch: invisible 1px copies load the next pair into the image cache
        if (this.revealed) {
          Row() {
            ForEach(this.nextThumbnails(), (url: string) => {
              Image(url).width(1).height(1).opacity(0)
            }, (url: string) => 'prefetch-' + url)
          }
          .height(1)
        }

        this.footerArea()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .translate({ y: -16 })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      .zIndex(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.theme_link'))
  }

  @Builder
  completeView() {
    // WMFWhichCameFirstResultsView — score bound to the CDGameSession (svc_game_store)
    Column({ space: 16 }) {
      Text($r('app.string.which_came_first_game_complete_title'))
        .fontSize(28)                             // WMFFont.georgiaTitle1
        .fontFamily('serif')
        .fontColor($r('app.color.theme_text'))
      Text(this.session === null ? '' : `${this.session.score} / ${this.totalQuestions()}`)
        .id('wcf_score')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_link'))
      // shareScoreButton: square.and.arrow.up + "Share score" in a dimmed capsule
      Button() {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(15)
            .fontColor([Color.White])
          Text($r('app.string.which_came_first_share_score_button'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
        .id('wcf_share_score')
        .type(ButtonType.Capsule)
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor('#4D000000')
        .margin({ top: 4 })
        .onClick(() => {
          this.showShare();
        })
      // archiveButton: WMFLargeButton(.neutral, calendar.badge.clock, "Play the archive")
      Button() {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
            .fontSize(17)
            .fontColor([$r('app.color.theme_text')])
          Text($r('app.string.which_came_first_play_archive_button'))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_text'))
        }
      }
        .id('wcf_play_archive')
        .type(ButtonType.Normal)
        .borderRadius(8)
        .width('90%')
        .height(46)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .border({ width: 1, color: $r('app.color.theme_border'), radius: 8 })
        .margin({ top: 8 })
        .onClick(() => {
          this.showArchive();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // the share card needs the page as its builder context, or the snapshot has none
  @Builder
  shareCardBuilder(model: ShareCardModel) {
    whichCameFirstShareCard(model)
  }

  // makeShareArticleEvents: per question the option with a thumbnail (either one when both or
  // neither have one)
  private shareEvent(question: WhichCameFirstQuestion, index: number): WhichCameFirstEvent | undefined {
    const aImage: boolean = this.eventThumbnail('A', index) !== '';
    const bImage: boolean = this.eventThumbnail('B', index) !== '';
    if (aImage !== bImage) {
      return aImage ? question.optionA : question.optionB;
    }
    return Math.random() < 0.5 ? question.optionA : question.optionB;
  }

  private async downloadTo(url: string, path: string): Promise<boolean> {
    const request = http.createHttp();
    try {
      const resp: http.HttpResponse = await request.request(url.startsWith('//') ? 'https:' + url : url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE |
        fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, resp.result as ArrayBuffer);
      } finally {
        fileIo.closeSync(file);
      }
      return true;
    } catch (e) {
      return false;
    } finally {
      request.destroy();
    }
  }

  // WhichCameFirstCoordinator.showShare: each question's article (summary description and
  // thumbnail), the WMFWhichCameFirstShareView rendered to an image, then the share panel with
  // that image and the "I'm playing ..." text.
  private async showShare(): Promise<void> {
    if (this.sharing || this.session === null) {
      return;
    }
    this.sharing = true;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const model: ShareCardModel = new ShareCardModel();
      model.scoreSummary = formatString(ctx, $r('app.string.which_came_first_share_score_summary'),
        [String(this.session.score), String(this.totalQuestions())]);
      model.topicsTitle = ctx.resourceManager.getStringSync($r('app.string.which_came_first_share_topics_title').id);
      model.results = this.progressResults.map((r: string): boolean => r === 'correct');
      for (let i = 0; i < this.questions.length; i++) {
        const event: WhichCameFirstEvent | undefined = this.shareEvent(this.questions[i], i);
        const title: string | undefined = event?.pages?.[0];
        if (title === undefined) {
          continue;
        }
        const article: ShareCardArticle = new ShareCardArticle();
        article.title = title.replace(/_/g, ' ');
        let thumb: string = event?.thumbnailURL ?? '';
        try {
          const summary: ArticleSummary = await ArticleService.fetchSummary(this.host, title);
          article.description = summary.articleDescription ?? summary.extract ?? '';
          if (thumb === '') {
            thumb = summary.thumbnail?.source ?? '';
          }
        } catch (e) {
          console.warn('which came first: share summary failed: ' + (e as Error).message);
        }
        const path: string = ctx.cacheDir + '/wcf_share_' + i;
        if (thumb !== '' && await this.downloadTo(thumb, path)) {
          article.imagePath = path;
        }
        model.articles.push(article);
      }
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot()
        .createFromBuilder(() => { this.shareCardBuilder(model); }, 300);
      const packer: image.ImagePacker = image.createImagePacker();
      const png: ArrayBuffer = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
      packer.release();
      const cardPath: string = ctx.cacheDir + '/which_came_first_score.png';
      const file: fileIo.File = fileIo.openSync(cardPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE |
        fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, png);
      } finally {
        fileIo.closeSync(file);
      }
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: 'general.png',
        uri: fileUri.getUriFromPath(cardPath)
      });
      data.addRecord({
        utd: 'general.text',
        content: ctx.resourceManager.getStringSync($r('app.string.which_came_first_share_activity_text').id)
      });
      await new systemShare.ShareController(data).show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (e) {
      console.error('which came first: share failed: ' + (e as Error).message);
    } finally {
      this.sharing = false;
    }
  }

  @Builder
  errorView() {
    Column({ space: 16 }) {
      Text($r('app.string.which_came_first_error_title'))
        .fontSize(17)                             // WMFFont.semiboldHeadline
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      Text(this.errorMessage)
        .textAlign(TextAlign.Center)
        .fontSize(15)                             // WMFFont.subheadline
        .fontColor($r('app.color.theme_secondary_text'))
      // WMFLargeButton(style: .primary)
      Button($r('app.string.which_came_first_retry_button'))
        .id('which-came-first-retry-button')
        .type(ButtonType.Normal)
        .borderRadius(8)
        .width('100%')
        .height(46)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .backgroundColor($r('app.color.theme_link'))
        .onClick(() => {
          this.retry();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
  }

  build() {
    Column() {
      // WMFWhichCameFirstViewController: opaque theme.link bar (also behind the status bar) with
      // the close button, the game's date and the ⋯ menu
      GamesNavBar({
        title: gameDateTitle(this.session !== null && this.session.dailyGameDate !== null
          ? this.session.dailyGameDate : ''),
        titleColor: this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background'),
        onClose: (): void => {
          router.back();
        }
      })
        .backgroundColor($r('app.color.theme_link'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      Column() {
        if (this.phase === 'loading') {
          LoadingProgress().width(48).height(48).color($r('app.color.theme_link'))
        } else if (this.phase === 'error') {
          this.errorView()
        } else if (this.phase === 'complete') {
          this.completeView()
        } else {
          this.gameplayView()
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    }
    .id('WMFWhichCameFirstView')
    .width('100%')
    .height('100%')
  }
}
