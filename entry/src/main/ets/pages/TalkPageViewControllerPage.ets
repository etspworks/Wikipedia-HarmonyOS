// screen_talk_page — presentation: page.
// Ported from Wikipedia/Code/TalkPageViewController.swift + TalkPageView.swift:
// a collection view of TalkPageCell topic cells over a TalkPageHeaderView
// (type / title / description + project source), with a bottom toolbar whose items are
// [share, revision, find, addTopic].
// Hosts overlay: TalkPageTopicComposeView (modal cover).
// S5: styled from captured S0279/S0280 — grouped gray page, white nav-chrome circle back
// button + centered bold title, USER TALK caption over a 34pt title, beige description band,
// content-sized white topic cards, and the floating white toolbar pill.
import { upperText } from '../common/LocaleText';
import { formatString } from '../common/Plural';
import { router, SymbolGlyphModifier, KeyboardAvoidMode, ComponentUtils, componentUtils } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { resourceManager } from '@kit.LocalizationKit';
import { TalkPageTopicComposeView } from './TalkPageTopicComposeViewControllerPage';
import { TalkPageReplyComposeView } from '../components/TalkPageReplyComposeView';
import { TalkPageItem } from '../model/TalkPageItem';
import { TalkPageCell, talkFindTexts, talkFindKey, talkFindFieldId } from '../components/TalkPageCell';
import { TalkPageService, TALK_LANGUAGE_PICK_KEY, TalkLanguagePick } from '../common/TalkPageService';
import { LanguageStore } from '../common/LanguageStore';
import { ArticleService } from '../common/ArticleService';
import { ArticleSummary } from '../model/ArticleSummary';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { SessionStore } from '../common/SessionStore';

// IDataSource over the talk page's topic threads (ambient IDataSource/DataChangeListener).
class TalkThreadDataSource implements IDataSource {
  private items: TalkPageItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): TalkPageItem {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: TalkPageItem[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct TalkPageViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State showTopicCompose: boolean = false;
  // spec stateVar: items (svc_talk) — the discussiontoolspageinfo thread items.
  @State items: TalkPageItem[] = [];
  // TalkPageCellViewModel.isThreadExpanded, by thread id. @Provide (not @State): the cell
  // reads and writes it through @Consume, so a toggle marks that live cell dirty directly.
  // A @State + @Prop hand-down cannot work here — the cell is built by LazyForEach, which
  // only re-runs its item builder when the DATA SOURCE notifies a key change, and expansion
  // lives outside the IDataSource.
  @Provide('talkExpandedIds') expandedIds: string[] = [];
  // TalkPageFindInPageState: the term (lower-cased) and the selected match's key, which the
  // cells read to highlight; the matches in search order and the selected index.
  @Provide('talkFindQuery') findQuery: string = '';
  @Provide('talkFindActive') findActive: string = '';
  // TalkPageViewModel.topics[].isSubscribed, by topic name, and isUserPermanent
  @Provide('talkSubscribedNames') subscribedNames: string[] = [];
  @Provide('talkUserIsPermanent') userIsPermanent: boolean = false;
  // WMFToastManager.showRichToast: icon, title and subtitle over the page foot
  @State toastTitle: string = '';
  @State toastSubtitle: string = '';
  @State toastIcon: Resource = $r('sys.symbol.bell_fill');
  private toastTimer: number = -1;
  // replyComposeController: the comment being replied to, and isLoading
  @State replyTarget: TalkPageItem | null = null;
  @State isPublishingReply: boolean = false;
  // TalkPageTopicReplyOnboardingHostingController: shown before the first Add topic or Reply,
  // then the action it held back runs once it is dismissed.
  @State showOnboarding: boolean = false;
  private afterOnboarding: () => void = () => {};
  @State showFindBar: boolean = false;
  @State findText: string = '';
  @State findTotal: number = 0;
  @State findIndex: number = -1;
  private findKeys: string[] = [];
  private findRows: number[] = [];
  // the talkFindTexts field each match sits in, to scroll that text into view
  private findFields: number[] = [];
  // where the match starts in its text, as a share of the text's length
  private findPlaces: number[] = [];
  private listScroller: Scroller = new Scroller();
  // TalkPageHeaderView: typeLabel / titleLabel / descriptionLabel
  @State headerType: string = '';
  @State headerTitle: string = '';
  @State headerDescription: string = '';
  // TalkPageViewModel.leadImageURL / coffeeRollText
  @State leadImageURL: string = '';
  @State coffeeRollText: string = '';
  @State showCoffeeRoll: boolean = false;
  @State isLoading: boolean = false;
  @State loadError: string = '';
  private threads: TalkThreadDataSource = new TalkThreadDataSource();
  // TalkPageViewModel.pageTitle / siteURL — the namespaced talk title and its wiki host.
  private articleTitle: string = '';
  private talkPageTitle: string = '';
  private host: string = 'en.wikipedia.org';
  // the wiki the page is read on: the app language until Change language picks another
  private languageCode: string = '';
  // TalkPageViewModel.latestRevisionID, for the Permanent link
  private latestRevisionID: number = 0;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    // The find bar sits at the foot of the screen: shrink the page for the keyboard instead
    // of translating it up, which pushed the selected match under the status bar.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.userIsPermanent = SessionStore.isLoggedIn;
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.articleTitle = params['articleTitle'] ?? '';
      // a link to another wiki's talk page names that wiki
      this.languageCode = params['languageCode'] ?? '';
      const explicit: string = params['talkPageTitle'] ?? '';
      this.talkPageTitle = explicit !== '' ? explicit : TalkPageViewControllerPage.talkTitleFor(this.articleTitle);
    }
    if (this.talkPageTitle === '') {
      // A cold deep-link launch carries no router params; EntryAbility publishes the
      // Want's talk title under this key, exactly like 'launchWebUrl'.
      this.talkPageTitle = AppStorage.get<string>('launchTalkPageTitle') ?? '';
    }
    // TalkPageViewModel.headerTitle = pageTitle without its namespace prefix.
    this.headerTitle = this.articleTitle !== '' ? this.articleTitle :
      this.talkPageTitle.substring(this.talkPageTitle.indexOf(':') + 1);
    this.headerType = TalkPageViewControllerPage.headerTypeFor(this.talkPageTitle);
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        this.loadError = e.message;
        this.isLoading = false;
      });
    }).catch((e: Error) => {
      console.error('talk: db init failed: ' + e.message);
      this.loadError = e.message;
    });
  }

  // The languages page hands its pick back through AppStorage (it is a routed page).
  onPageShow(): void {
    const pick: string | undefined = AppStorage.get<string>(TALK_LANGUAGE_PICK_KEY);
    if (pick === undefined || pick === '') {
      return;
    }
    AppStorage.setOrCreate<string>(TALK_LANGUAGE_PICK_KEY, '');
    const picked: TalkLanguagePick = JSON.parse(pick) as TalkLanguagePick;
    this.changeTalkPageLanguage(picked.languageCode, picked.articleTitle);
  }

  // changeTalkPageLanguage: reset the site (and, for an article, the title to that wiki's
  // version of it) and fetch the talk page again. Picking the current language does nothing.
  private changeTalkPageLanguage(languageCode: string, articleTitle: string): void {
    if (languageCode === '' || languageCode === this.languageCode) {
      return;
    }
    this.languageCode = languageCode;
    if (this.articleTitle !== '' && articleTitle !== '') {
      this.articleTitle = articleTitle;
      this.talkPageTitle = TalkPageViewControllerPage.talkTitleFor(articleTitle);
      this.headerTitle = articleTitle;
    }
    this.headerDescription = '';
    this.leadImageURL = '';
    this.items = [];
    this.threads.reload([]);
    this.load().catch((e: Error) => {
      this.loadError = e.message;
      this.isLoading = false;
    });
  }

  // talk-page-change-language: an article talk page lists the article's own language
  // versions (WMFArticleLanguagesViewController); a user talk page lists My languages and
  // keeps the same title.
  private openChangeLanguage(): void {
    const params: Record<string, string> = this.articleTitle !== ''
      ? { 'articleTitle': this.articleTitle, 'host': this.host, 'picksTalkLanguage': 'true' }
      : { 'selectsLanguageFor': 'talk' };
    const url: string = this.articleTitle !== ''
      ? 'pages/WMFLanguagesViewControllerPage' : 'pages/WMFPreferredLanguagesViewControllerPage';
    router.pushUrl({ url: url, params: params }).catch((e: Error) => {
      console.error('talk: change language route failed: ' + e.message);
    });
  }

  // TalkPageType — an article's talk page lives in the Talk: namespace.
  private static talkTitleFor(articleTitle: string): string {
    if (articleTitle === '' || articleTitle.indexOf(':') >= 0) {
      return articleTitle;
    }
    return 'Talk:' + articleTitle;
  }

  private static isUserTalkTitle(talkTitle: string): boolean {
    return talkTitle.indexOf('User talk:') === 0 || talkTitle.indexOf('User_talk:') === 0;
  }

  private static headerTypeFor(talkTitle: string): string {
    return TalkPageViewControllerPage.isUserTalkTitle(talkTitle) ? 'User Talk' : 'Article Talk';
  }

  // TalkPageViewModel.fetchTalkPage -> TalkPageDataController.fetchTalkPage:
  // the thread items plus the article summary that fills headerDescription.
  private async load(): Promise<void> {
    this.isLoading = true;
    this.loadError = '';
    try {
      if (this.languageCode === '') {
        const lang: MWKLanguageLink = await LanguageStore.appLanguage();
        this.languageCode = lang.languageCode;
      }
      this.host = this.languageCode + '.wikipedia.org';
      const fetched: TalkPageItem[] = await TalkPageService.fetchTalkPageItems(this.host, this.talkPageTitle);
      this.items = fetched;
      this.coffeeRollText = TalkPageService.lastCoffeeRoll;
      this.threads.reload(fetched);
      if (this.userIsPermanent) {
        const names: string[] = [];
        for (const t of fetched) {
          if (t.name !== null && t.name !== '') {
            names.push(t.name);
          }
        }
        TalkPageService.fetchSubscribedTopics(this.host, names).then((subscribed: string[]) => {
          this.subscribedNames = subscribed;
        }).catch((e: Error) => {
          console.error('talk: subscriptions failed: ' + e.message);
        });
      }
      TalkPageService.fetchLatestRevisionID(this.host, this.talkPageTitle).then((id: number) => {
        this.latestRevisionID = id;
      }).catch((e: Error) => {
        console.error('talk: revision id failed: ' + e.message);
      });
      if (this.articleTitle !== '') {
        try {
          const summary: ArticleSummary = await ArticleService.fetchSummary(this.host, this.articleTitle);
          this.headerDescription = summary.articleDescription ?? '';
          this.leadImageURL = summary.thumbnail !== null ? summary.thumbnail.source : '';
        } catch (e) {
          // populateHeaderData tolerates a missing summary — the header just has no description.
          console.error('talk: summary failed: ' + (e as Error).message);
        }
      }
    } finally {
      this.isLoading = false;
    }
  }

  private emptyHeader(): string {
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    if (TalkPageViewControllerPage.isUserTalkTitle(this.talkPageTitle)) {
      return formatString(getContext(this), $r('app.string.talk_pages_empty_view_header_user'),
        [this.headerTitle]);
    }
    return rm.getStringSync($r('app.string.talk_pages_empty_view_header_article').id);
  }

  private emptyBody(): string {
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    if (TalkPageViewControllerPage.isUserTalkTitle(this.talkPageTitle)) {
      return formatString(getContext(this), $r('app.string.talk_pages_empty_view_body_user'),
        [this.headerTitle]);
    }
    // ** ** demarcates the bold run of the article body; ArkUI renders one run here.
    return rm.getStringSync($r('app.string.talk_pages_empty_view_body_article').id)
      .replace(/\*\*/g, '');
  }

  // TalkPageEmptyView — image + header + body. Its actionButton is not in this screen's
  // controlInventory (the contract carries Expand thread / Add topic only), so the empty
  // state renders without it; Add topic stays reachable in the toolbar below.
  @Builder
  emptyView() {
    Column() {
      Image($r('app.media.talk_pages_empty_view_image'))
        .width(180)
        .height(180)
        .objectFit(ImageFit.Contain)
      Text(this.emptyHeader())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
      Text(this.emptyBody())
        .fontSize(16)
        .lineHeight(22)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  // TalkPageViewController.handleError -> the "Unable to load talk page" error state.
  @Builder
  errorView() {
    Column() {
      Image($r('app.media.unable_to_load_talk_page'))
        .width(180)
        .height(180)
        .objectFit(ImageFit.Contain)
      Text($r('app.string.talk_page_error_loading_title'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
      Text($r('app.string.talk_page_error_loading_subtitle'))
        .fontSize(16)
        .lineHeight(22)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  @Builder
  topicComposeBuilder() {
    TalkPageTopicComposeView({
      talkPageTitle: this.talkPageTitle,
      host: this.host,
      onClose: (): void => {
        this.showTopicCompose = false;
        // postTopic completion re-fetches the talk page (TalkPageViewController.didPostTopic).
        this.load().catch((e: Error) => {
          this.loadError = e.message;
        });
      }
    })
  }

  // TalkPageHeaderView (talkPageView.setupHeaderView): type, title and description beside
  // the 80pt lead image, then the coffee roll (the page's lead section, two lines + Read more)
  // on its beige band.
  @Builder
  headerView() {
    Column() {
      Row({ space: 12 }) {
        Column() {
          Text(upperText(getContext(this) as common.Context, this.headerType))
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(0.6)
            .fontColor($r('app.color.theme_secondary_text'))
          Text(this.headerTitle)
            .width('100%')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 4 })
          if (this.headerDescription !== '') {
            Text(this.headerDescription)
              .width('100%')
              .fontSize(15)
              .lineHeight(20)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ top: 6 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.leadImageURL !== '') {
          Image(this.leadImageURL)
            .id('talk_page_lead_image')
            .width(80)
            .height(80)
            .objectFit(ImageFit.Cover)
            .borderRadius(4)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16 })
      if (this.coffeeRollText !== '') {
        Column() {
          Divider().color($r('app.color.theme_secondary_text')).opacity(0.4)
          Text(this.coffeeRollText)
            .width('100%')
            .fontSize(16)
            .lineHeight(22)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.theme_text'))
            .padding({ left: 16, right: 16, top: 14 })
          Text($r('app.string.talk_pages_coffee_roll_read_more'))
            .id('talk_page_coffee_roll_read_more')
            .width('100%')
            .textAlign(TextAlign.End)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 16, right: 16, top: 4, bottom: 12 })
            .onClick(() => {
              this.showCoffeeRoll = true;
            })
        }
        .width('100%')
        .backgroundColor($r('app.color.beige100'))
        .margin({ top: 20 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12 })
    .margin({ bottom: 16 })
    .bindSheet($$this.showCoffeeRoll, this.coffeeRollSheet(), { height: SheetSize.LARGE, dragBar: true, showClose: true })
  }

  // TalkPageCoffeeRollViewController: the whole lead section, scrollable
  @Builder
  coffeeRollSheet() {
    Scroll() {
      Text(this.coffeeRollText)
        .width('100%')
        .fontSize(17)
        .lineHeight(24)
        .fontColor($r('app.color.theme_text'))
        // clear of the sheet's close button
        .padding({ left: 16, right: 16, top: 64, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      // platform push-navigation back affordance
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('BackButton')
          .type(ButtonType.Normal)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .width(44)
          .height(44)
          .borderRadius(22)
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.back();
          })
        Text($r('app.string.talk_pages_view_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .padding({ left: 8, right: 8 })
        // the navigation bar's overflow (ellipsis.circle) menu; of its items only
        // Change language is ported so far
        Button() {
          Stack() {
            Circle()
              .width(26)
              .height(26)
              .fill(Color.Transparent)
              .stroke($r('app.color.theme_link'))
              .strokeWidth(1.6)
            Row({ space: 3 }) {
              ForEach([0, 1, 2], (i: number) => {
                Circle()
                  .width(3.5)
                  .height(3.5)
                  .fill($r('app.color.theme_link'))
              }, (i: number) => i.toString())
            }
          }
        }
          .id('talk_page_overflow')
          .type(ButtonType.Normal)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .width(44)
          .height(44)
          .borderRadius(22)
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .bindMenu(this.overflowMenu())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // talkPageView.collectionView: header cell + one TalkPageCell per topic thread.
      // The empty/error views span the whole content region (emptyView is pinned to the
      // safe-area top in TalkPageView), so they replace the list, header included.
      if (this.isLoading && this.items.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.theme_secondary_text'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError !== '' && this.items.length === 0) {
        this.errorView()
      } else if (this.items.length === 0) {
        this.emptyView()
      } else {
      List({ space: 16, scroller: this.listScroller }) {
        ListItem() {
          this.headerView()
        }
        LazyForEach(this.threads, (thread: TalkPageItem) => {
          ListItem() {
            // The cell owns the disclosure toggle through @Consume('talkExpandedIds'), so
            // the row's key stays stable — expansion is a state update, not a data reload.
            TalkPageCell({
              item: thread,
              onSubscribe: (topic: TalkPageItem): void => {
                this.toggleSubscription(topic);
              },
              onReply: (comment: TalkPageItem): void => {
                // tappedReply: hideFindInPage, then the reply compose view
                if (this.showFindBar) {
                  this.closeFind();
                }
                this.onboardThen(() => {
                  this.replyTarget = comment;
                });
              }
            })
          }
          .padding({ left: 16, right: 16 })
        // the reply count is in the key: a reload after a reply keeps the thread id, and
        // LazyForEach does not rebuild an item whose key is unchanged
        }, (thread: TalkPageItem) => thread.id + '_' + thread.replies.length)
      }
      .id('talk_list')
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(Color.Transparent)
      }

      if (this.showFindBar) {
        this.findBar()
      } else {
      // talkPageView.toolbar: [shareButton, revisionButton, findButton, addTopicButton]
      // spread by flexible spaces. The floating pill is inset by its wrapper's padding (a
      // %-width child cannot carry horizontal margins without overflowing its parent).
      Column() {
        Row() {
          this.toolbarButton('talk_share', $r('sys.symbol.share'), $r('app.string.talk_page_share_button'), () => {
            this.shareTalkPage();
          })
          Blank()
          this.toolbarButton('talk_revision_history', $r('sys.symbol.arrow_counterclockwise_clock'),
            $r('app.string.talk_page_revision_history'), () => {
              this.openRevisionHistory();
            })
          Blank()
          this.toolbarButton('talk_find', $r('sys.symbol.doc_text_badge_magnifyingglass'),
            $r('app.string.talk_page_find_in_page_button'), () => {
              this.openFind();
            })
          Blank()
          this.toolbarButton('talk_add_topic', $r('sys.symbol.plus'), $r('app.string.talk_page_add_topic_button'), () => {
            this.openTopicCompose();
          })
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12 })
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(28)
        .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })
      }
    }
    .id('TalkPageViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    .bindContentCover($$this.showTopicCompose, this.topicComposeBuilder())
      if (this.replyTarget !== null) {
        TalkPageReplyComposeView({
          author: this.replyTarget.author ?? '',
          isPublishing: this.isPublishingReply,
          onPublish: (text: string): void => {
            this.publishReply(text);
          },
          onClose: (): void => {
            this.replyTarget = null;
          }
        })
      }
      // WMFToastManager: floats over the page foot, above the toolbar
      this.toastView()
    }
    .width('100%')
    .height('100%')
    // modalPresentationStyle = .pageSheet
    .bindSheet($$this.showOnboarding, this.onboardingSheet(), {
      height: SheetSize.LARGE,
      showClose: false,
      onDisappear: () => {
        this.runAfterOnboarding();
      }
    })
  }

  // TalkPageViewController.overflowMenu: the main group, then the inline submenu
  // (overflowSubmenuActions). Edit source is not ported yet.
  private overflowMenu(): MenuElement[] {
    const items: MenuElement[] = [
      this.menuItem($r('app.string.talk_page_menu_open_all'), $r('sys.symbol.rectangle_stack'), () => {
        this.expandedIds = this.items.map((t: TalkPageItem) => t.id);
      }),
      this.menuItem($r('app.string.talk_page_revision_history'), $r('sys.symbol.arrow_counterclockwise_clock'), () => {
        this.openRevisionHistory();
      }),
      // pushToDesktopWeb
      this.menuItem($r('app.string.talk_page_read_in_web'), $r('sys.symbol.desktop'), () => {
        this.openSinglePageWeb(this.talkPageURL());
      })
    ];
    // overflowSubmenuActions: Archives first
    items.push(this.menuItem($r('app.string.talk_page_archives'), $r('sys.symbol.archivebox'), () => {
      const params: Record<string, string> = { 'talkPageTitle': this.talkPageTitle, 'languageCode': this.languageCode };
      router.pushUrl({ url: 'pages/TalkPageArchivesViewControllerPage', params: params });
    }));
    if (TalkPageViewControllerPage.isUserTalkTitle(this.talkPageTitle)) {
      // userTalkOverflowSubmenuActions
      const user: string = encodeURIComponent(this.headerTitle.replace(/ /g, '_'));
      items.push(
        this.menuItem($r('app.string.talk_page_user_contributions'), $r('sys.symbol.person_crop_circle_fill'), () => {
          this.openSinglePageWeb(this.siteURL('/wiki/Special:Contributions/' + user));
        }),
        this.menuItem($r('app.string.talk_pages_user_groups'), $r('sys.symbol.person_2'), () => {
          this.openSinglePageWeb(this.siteURL('/wiki/Special:UserRights/' + user));
        }),
        this.menuItem($r('app.string.talk_pages_user_logs'), $r('sys.symbol.list_bullet'), () => {
          this.openSinglePageWeb(this.siteURL('/wiki/Special:Log/' + user));
        }));
    }
    items.push(
      this.menuItem($r('app.string.talk_page_page_info'), $r('sys.symbol.info_circle'), () => {
        this.openSinglePageWeb(this.siteURL('/w/index.php?title=' + this.encodedTitle() + '&action=info'));
      }),
      // pushToPermanentLink: title + oldid of the latest revision
      this.menuItem($r('app.string.talk_page_permanent_link'), $r('sys.symbol.link'), () => {
        this.openSinglePageWeb(this.siteURL('/w/index.php?title=' + this.encodedTitle() +
          '&oldid=' + this.latestRevisionID));
      }),
      this.menuItem($r('app.string.talk_page_change_language'), $r('sys.symbol.translate'), () => {
        this.openChangeLanguage();
      }),
      this.menuItem($r('app.string.talk_page_related_links'), $r('sys.symbol.arrowshape_turn_up_right'), () => {
        this.openSinglePageWeb(this.siteURL('/wiki/Special:WhatLinksHere/' + this.encodedTitle()));
      }),
      // pushToAboutTalkPages
      this.menuItem($r('app.string.talk_page_article_about'), $r('sys.symbol.doc_plaintext'), () => {
        this.openSinglePageWeb('https://www.mediawiki.org/wiki/Wikimedia_Apps/iOS_FAQ#Talk_pages');
      }));
    return items;
  }

  private menuItem(title: Resource, symbol: Resource, action: () => void): MenuElement {
    return {
      value: title,
      symbolIcon: new SymbolGlyphModifier(symbol).fontColor([$r('app.color.theme_text')]),
      action: action
    };
  }

  private encodedTitle(): string {
    return encodeURIComponent(this.talkPageTitle.replace(/ /g, '_'));
  }

  private siteURL(path: string): string {
    return 'https://' + this.host + path;
  }

  // TalkPageViewModel.getTalkPageURL
  private talkPageURL(): string {
    return this.siteURL('/wiki/' + this.encodedTitle());
  }

  // FindAndReplaceKeyboardBar (modern): the checkmark close button, the field capsule
  // (magnifier, field, match label, clear) and the previous/next capsule.
  @Builder
  findBar() {
    Row({ space: 8 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(20)
          .fontColor([Color.White])
      }
        .id('talk_find_close')
        .accessibilityText($r('app.string.find_replace_header_close_accessibility'))
        .type(ButtonType.Circle)
        .backgroundColor($r('app.color.theme_link'))
        .width(44)
        .height(44)
        .onClick(() => {
          this.closeFind();
        })
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.doc_text_badge_magnifyingglass'))
          .fontSize(18)
          .fontColor([$r('app.color.theme_secondary_text')])
        TextInput({ text: this.findText })
          .id('talk_find_field')
          .accessibilityText($r('app.string.find_textfield_accessibility'))
          .enablePreviewText(false)
          .layoutWeight(1)
          .height(40)
          .fontSize(17)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.theme_text'))
          .onChange((v: string) => {
            this.search(v);
          })
          .onSubmit(() => {
            this.stepFind(1);
          })
        Text(this.matchLabel())
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
        if (this.findText !== '') {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(18)
              .fontColor([$r('app.color.theme_secondary_text')])
          }
            .id('talk_find_clear')
            .accessibilityText($r('app.string.find_clear_button_accessibility'))
            .type(ButtonType.Circle)
            .backgroundColor(Color.Transparent)
            .width(28)
            .height(28)
            .onClick(() => {
              this.search('');
            })
        }
      }
      .layoutWeight(1)
      .height(44)
      .padding({ left: 12, right: 8 })
      .borderRadius(22)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
      Row() {
        this.findStepButton('talk_find_previous', $r('sys.symbol.chevron_up'),
          $r('app.string.find_previous_button_accessibility'), -1)
        this.findStepButton('talk_find_next', $r('sys.symbol.chevron_down'),
          $r('app.string.find_next_button_accessibility'), 1)
      }
      .height(44)
      .borderRadius(22)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 8, bottom: 10 })
  }

  // previous/next are enabled from two matches on (updatePreviousNextButtonsState)
  @Builder
  findStepButton(id: string, symbol: Resource, label: Resource, step: number) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor([$r('app.color.theme_secondary_text')])
    }
      .id(id)
      .accessibilityText(label)
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .enabled(this.findTotal >= 2)
      .opacity(this.findTotal >= 2 ? 1 : 0.4)
      .width(44)
      .height(44)
      .onClick(() => {
        this.stepFind(step);
      })
  }

  // userDidTapFindButton: expand every thread and open the find bar.
  private openFind(): void {
    this.expandedIds = this.items.map((t: TalkPageItem) => t.id);
    this.showFindBar = true;
    // FindAndReplaceKeyboardBar.show: the field takes focus, raising the keyboard
    setTimeout(() => {
      focusControl.requestFocus('talk_find_field');
    }, 50);
  }

  // keyboardBarDidTapReturn / hideFindInPage: reset the search and close the bar.
  private closeFind(): void {
    this.search('');
    this.showFindBar = false;
  }

  // TalkPageFindInPageState.search: the matches in thread order, none selected yet.
  private search(text: string): void {
    this.findText = text;
    const q: string = text.toLowerCase();
    this.findKeys = [];
    this.findRows = [];
    this.findFields = [];
    this.findPlaces = [];
    if (q !== '') {
      this.items.forEach((thread: TalkPageItem, row: number) => {
        let k: number = 0;
        talkFindTexts(thread).forEach((t: string, field: number) => {
          const lower: string = t.toLowerCase();
          let at: number = lower.indexOf(q);
          while (at >= 0) {
            this.findKeys.push(talkFindKey(thread.id, k++));
            this.findRows.push(row);
            this.findFields.push(field);
            this.findPlaces.push(at / t.length);
            at = lower.indexOf(q, at + q.length);
          }
        });
      });
    }
    this.findQuery = q;
    this.findTotal = this.findKeys.length;
    this.findIndex = -1;
    this.findActive = '';
  }

  // next() / previous(), looping at either end, then scrollToFindInPageResult: bring the
  // thread on screen, then the match's line to a third of the way down the list.
  // ponytail: the line is estimated from the match's place in the text (no glyph rects).
  private stepFind(step: number): void {
    const n: number = this.findTotal;
    if (n === 0) {
      return;
    }
    this.findIndex = this.findIndex < 0 ? (step > 0 ? 0 : n - 1) : (this.findIndex + step + n) % n;
    this.findActive = this.findKeys[this.findIndex];
    const thread: TalkPageItem = this.items[this.findRows[this.findIndex]];
    const fieldId: string = talkFindFieldId(thread.id, this.findFields[this.findIndex]);
    const place: number = this.findPlaces[this.findIndex];
    // index 0 is the header cell
    this.listScroller.scrollToIndex(this.findRows[this.findIndex] + 1, false, ScrollAlign.START);
    setTimeout(() => {
      const utils: ComponentUtils = this.getUIContext().getComponentUtils();
      const text: componentUtils.ComponentInfo = utils.getRectangleById(fieldId);
      const list: componentUtils.ComponentInfo = utils.getRectangleById('talk_list');
      const line: number = text.windowOffset.y + text.size.height * place;
      const dy: number = this.getUIContext().px2vp(line - list.windowOffset.y - list.size.height / 3);
      this.listScroller.scrollBy(0, dy);
    }, 50);
  }

  // updateMatchPlacement: the total alone until a match is selected, then "index / total".
  private matchLabel(): string {
    if (this.findIndex >= 0) {
      return formatString(getContext(this), $r('app.string.find_infolabel_number_matches'),
        [(this.findIndex + 1).toString(), this.findTotal.toString()]);
    }
    return this.findTotal > 0 ? this.findTotal.toString() : '';
  }

  @Builder
  toastView() {
    if (this.toastTitle !== '') {
      Row({ space: 12 }) {
        SymbolGlyph(this.toastIcon)
          .fontSize(24)
          .fontColor([$r('app.color.theme_text')])
        Column({ space: 2 }) {
          Text(this.toastTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_text'))
          if (this.toastSubtitle !== '') {
            Text(this.toastSubtitle)
              .fontSize(15)
              .fontColor($r('app.color.theme_secondary_text'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .id('talk_toast')
      .width('92%')
      .margin({ bottom: 90 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderRadius(16)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .shadow({ radius: 12, color: '#33000000', offsetY: 2 })
      .onClick(() => {
        this.toastTitle = '';
      })
    }
  }

  private showRichToast(title: Resource, subtitle: Resource | null, icon: Resource): void {
    const rm: resourceManager.ResourceManager = getContext(this).resourceManager;
    this.toastTitle = rm.getStringSync(title.id);
    this.toastSubtitle = subtitle !== null ? rm.getStringSync(subtitle.id) : '';
    this.toastIcon = icon;
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toastTitle = '';
      this.toastTimer = -1;
    }, 5000);
  }

  // tappedPublish(text:commentViewModel:): post the reply, close the compose view, reload the
  // talk page and show "Your comment was added". A failure keeps the compose view open: no
  // answer from the server is the network toast, an answer without success the alert.
  private publishReply(text: string): void {
    const target: TalkPageItem | null = this.replyTarget;
    if (target === null || this.isPublishingReply) {
      return;
    }
    this.isPublishingReply = true;
    TalkPageService.postReply(this.host, this.talkPageTitle, target.id, text).then(() => {
      this.isPublishingReply = false;
      this.replyTarget = null;
      return this.load();
    }).then(() => {
      this.showRichToast($r('app.string.talk_pages_comment_added_alert_title'), null,
        $r('sys.symbol.checkmark_circle_fill'));
    }).catch((e: Error) => {
      console.error('talk: reply failed: ' + e.message);
      if (!this.isPublishingReply) {
        return;
      }
      this.isPublishingReply = false;
      if (e.message.indexOf('discussiontoolsedit') >= 0) {
        this.getUIContext().showAlertDialog({
          title: $r('app.string.talk_page_error_alert_title'),
          message: $r('app.string.talk_page_error_alert_subtitle'),
          confirm: { value: $r('app.string.button_ok'), action: () => {} }
        });
      } else {
        this.showRichToast($r('app.string.talk_page_publish_reply_error_title'),
          $r('app.string.talk_page_publish_reply_error_subtitle'), $r('sys.symbol.exclamationmark_circle'));
      }
    });
  }

  // userDidTapSubscribeButton: flip the button at once, call the API, then the toast; a
  // failure flips it back with the failure toast.
  private toggleSubscription(topic: TalkPageItem): void {
    const name: string = topic.name ?? '';
    const wasSubscribed: boolean = this.subscribedNames.indexOf(name) >= 0;
    const flip = (on: boolean): void => {
      this.subscribedNames = on ? this.subscribedNames.concat([name])
        : this.subscribedNames.filter((n: string) => n !== name);
    };
    flip(!wasSubscribed);
    TalkPageService.subscribe(this.host, this.talkPageTitle, name, !wasSubscribed).then(() => {
      // handleSubscriptionAlert
      this.showRichToast(
        wasSubscribed ? $r('app.string.talk_page_unsubscribed_alert_title') : $r('app.string.talk_page_subscribed_alert_title'),
        wasSubscribed ? $r('app.string.talk_page_unsubscribed_alert_subtitle') : $r('app.string.talk_page_subscribed_alert_subtitle'),
        wasSubscribed ? $r('sys.symbol.bell_slash_fill') : $r('sys.symbol.bell_fill'));
    }).catch((e: Error) => {
      console.error('talk: subscribe failed: ' + e.message);
      flip(wasSubscribed);
      // subscriptionErrorAlert
      this.showRichToast(wasSubscribed ? $r('app.string.talk_page_unsubscription_failed_alert')
        : $r('app.string.talk_page_subscription_failed_alert'), null, $r('sys.symbol.exclamationmark_circle'));
    });
  }

  @Builder
  toolbarButton(id: string, symbol: Resource, label: Resource, action: () => void) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([$r('app.color.theme_text')])
    }
      .id(id)
      .accessibilityText(label)
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(44)
      .height(44)
      .onClick(action)
  }

  // userDidTapShareButton: the share sheet with the talk page URL.
  private shareTalkPage(): void {
    const record: systemShare.SharedRecord = {
      utd: 'general.hyperlink',
      content: this.talkPageURL(),
      title: this.talkPageTitle
    };
    try {
      new systemShare.ShareController(new systemShare.SharedData(record)).show(
        getContext(this) as common.UIAbilityContext, {
          selectionMode: systemShare.SelectionMode.SINGLE,
          previewMode: systemShare.SharePreviewMode.DETAIL
        }).catch((e: Error) => {
        console.error('talk: share panel failed: ' + e.message);
      });
    } catch (e) {
      console.error('talk: share panel unavailable: ' + (e as Error).message);
    }
  }

  private openRevisionHistory(): void {
    const params: Record<string, string> = { 'articleTitle': this.talkPageTitle, 'languageCode': this.languageCode };
    router.pushUrl({ url: 'pages/PageHistoryViewControllerPage', params: params });
  }

  private openTopicCompose(): void {
    this.onboardThen(() => {
      this.showTopicCompose = true;
    });
  }

  // wmf_userHasOnboardedToContributingToTalkPages: false presents the onboarding first and
  // marks it seen (presentTopicReplyOnboarding).
  private onboardThen(action: () => void): void {
    if (Prefs.getBoolean(PrefKeys.userHasOnboardedToContributingToTalkPages, false)) {
      action();
      return;
    }
    this.afterOnboarding = action;
    this.showOnboarding = true;
    Prefs.putBoolean(PrefKeys.userHasOnboardedToContributingToTalkPages, true);
  }

  // OK and a swipe down both close the sheet; once it is gone the held-back action runs
  private runAfterOnboarding(): void {
    const action: () => void = this.afterOnboarding;
    this.afterOnboarding = () => {};
    action();
  }

  // the body's lead clause is bold (talk-pages-topic-reply-onboarding-body-ios15, %1$@ = **)
  private onboardingBodyParts(): string[] {
    return formatString(getContext(this), $r('app.string.talk_pages_topic_reply_onboarding_body_ios15'), ['**'])
      .split('**');
  }

  // TalkPageTopicReplyOnboardingView
  @Builder
  onboardingSheet() {
    Column() {
      Scroll() {
        Column() {
          Text($r('app.string.talk_pages_topic_reply_onboarding_title'))
            .fontSize(28)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 64 })
          Image($r('app.media.talk_pages_empty_view_image'))
            .width(150)
            .height(150)
            .objectFit(ImageFit.Cover)
            .margin({ top: 44 })
          Text() {
            ForEach(this.onboardingBodyParts(), (part: string, i: number) => {
              Span(part)
                .fontWeight(i % 2 === 1 ? FontWeight.Bold : FontWeight.Normal)
            }, (part: string, i: number) => i.toString())
          }
            .width('100%')
            .fontSize(16)
            .lineHeight(22)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 31 })
          Text($r('app.string.talk_pages_topic_reply_onboarding_body_note_ios15'))
            .width('100%')
            .fontSize(16)
            .lineHeight(22)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 24 })
        }
        .width('100%')
        .padding({ left: 32, right: 32, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      // WMFLargeButton(style: .primary, title: OK)
      Button($r('app.string.button_ok'))
        .id('talk_onboarding_ok')
        .accessibilityDescription($r('app.string.talk_page_onboarding_button_accessibility_label'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(46)
        .borderRadius(8)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .backgroundColor($r('app.color.theme_link'))
        .margin({ left: 16, right: 16, bottom: 34 })
        .onClick(() => {
          this.showOnboarding = false;
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private openSinglePageWeb(url: string): void {
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }
}
