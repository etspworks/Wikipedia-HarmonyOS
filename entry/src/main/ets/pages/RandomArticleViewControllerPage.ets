// screen_random_article — presentation: page. S3: real structure from source
// (Wikipedia/Code/RandomArticleViewController.swift, an ArticleViewController subclass:
// the SAME article surface plus WMFRandomDiceButton in a second toolbar, whose target
// `loadAndShowAnotherRandomArticle` fetches another random article and shows it).
// Body rendered NATIVELY (same reason as ArticleViewControllerPage: the on-device drivers
// see nothing inside a Web, and every in-document link must be its own addressable node).
// The block/section parser is duplicated from ArticleViewControllerPage on purpose — its
// helpers are module-private there and that file belongs to another screen.
// Nav-bar Home/Search/Tabs/Profile are deliberately absent: this screen's controlInventory
// does not list them.
import { ArticleToolbarGlyph } from '../components/ArticleToolbarGlyph';
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { formatString, lastEditedString } from '../common/Plural';
import { pasteboard } from '@kit.BasicServicesKit';
import { ReadingThemesControlsView } from './ReadingThemesControlsViewControllerPage';
import { TocItem } from '../components/TableOfContentsViewController';
import { TableOfContentsView } from './TableOfContentsViewControllerPage';
import { ArticleFooterView } from '../components/ArticleFooterView';
import { showArticleOnMap } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { PageIssuesTableView } from './PageIssuesTableViewControllerPage';
import { ArticleSummary } from '../model/ArticleSummary';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { ArticleService } from '../common/ArticleService';
import { SavedStore } from '../common/SavedStore';
import { HistoryStore } from '../common/HistoryStore';
import { LanguageStore } from '../common/LanguageStore';
import { destinationFor, LinkDestination, LinkKind } from '../common/WikiLinks';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { WMFFontFamilies } from '../common/ThemeManager';
import { ArticleBlock, ArticleSection, ArticleSegment, ParsedArticle, parseArticle, stripTags }
  from './ArticleViewControllerPage';
import { ArticleFigureView, ArticlePieView, ArticleTableView, externalLinkMark } from '../components/ArticleBlockViews';
import { readableInlineColor, swatchPixelMap } from '../common/Swatch';
import { intentForDestination } from '../entryability/RouteTable';

// The body is parsed by the article screen's parseArticle (one parser for both screens: this
// page's own copy missed the collapsed tables and the figures).

@Entry
@Component
struct RandomArticleViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';
  // the gesture-handle strip under the toolbar (vp, 0 with button navigation)
  @StorageProp('navIndicatorInset') navIndicatorInset: number = 0;
  // the app's effective colour mode (EntryAbility keeps it current)
  @StorageProp('wmfIsDark') wmfIsDark: boolean = false;

  // bindingContract: the article shown is the RANDOM summary (random_summary), its body the
  // mobile-html of that title (page_mobile_html) — never a captured literal.
  @State articleTitle: string = '';
  @State summary: ArticleSummary | null = null;
  @State leadBlocks: ArticleBlock[] = [];
  @State sections: ArticleSection[] = [];
  @State editProtected: boolean = false;
  @State pronunciationURL: string = '';
  @State tocItems: TocItem[] = [];
  // footer related pages (RelatedSearchFetcher) — the plan's spec'd `items`
  @State items: ArticleSummary[] = [];
  @State hasPageIssues: boolean = false;
  @State showPageIssues: boolean = false;
  @State isLoading: boolean = false;
  @State loadError: string = '';
  // conditionalVariants: article.savedDate != nil -> filled save glyph
  @State savedDate: number | null = null;
  @State isSaved: boolean = false;
  // WMFRandomDiceButton.isEnabled = !isRandomArticleLoading
  @State isRolling: boolean = false;
  // overlays hosted by this page (one flag + discriminator per binding node)
  // the table of contents panel (TableOfContentsView), opened by the toolbar
  @State showToc: boolean = false;
  @State showThemesPopup: boolean = false;
  @State showFindBar: boolean = false;
  @State findQuery: string = '';
  private scroller: Scroller = new Scroller();
  private sectionTops: Map<string, number> = new Map<string, number>();
  private host: string = 'en.wikipedia.org';
  private projectID: string = 'wikipedia.en';

  aboutToAppear(): void {
    // the serif face of the level-2 headings (the device ships no Latin serif)
    this.getUIContext().getFont().registerFont({
      familyName: 'WMFSerif', familySrc: $rawfile('fonts/NotoSerif-Regular.ttf') });
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    Database.init(ctx).then(() => {
      this.loadRandomArticle();
    }).catch((e: Error) => {
      console.error('random: db init failed: ' + e.message);
      this.loadRandomArticle();
    });
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // RandomArticleFetcher.fetchRandomArticle(withSiteURL:) — the die button and the first
  // appearance take the same path.
  private loadRandomArticle(): void {
    // Rapid taps on the die each started their own fetch; the responses raced and the card
    // could settle on a half-applied state. A roll already in flight wins.
    if (this.isLoading) {
      return;
    }
    this.load().catch((e: Error) => {
      this.isLoading = false;
      this.isRolling = false;
      this.loadError = e.message;
    });
  }

  private async load(): Promise<void> {
    this.isLoading = true;
    this.isRolling = true;
    this.loadError = '';
    this.resetArticleState();
    try {
      const lang: MWKLanguageLink = await LanguageStore.appLanguage();
      this.host = lang.languageCode + '.wikipedia.org';
      this.projectID = 'wikipedia.' + lang.languageCode;
    } catch (e) {
      console.warn('random: app language unavailable, defaulting to en');
    }
    try {
      const random: ArticleSummary = await ArticleService.fetchRandomSummary(this.host);
      this.summary = random;
      this.articleTitle = random.title !== null ? random.title : '';
    } catch (e) {
      this.isLoading = false;
      this.isRolling = false;
      this.loadError = this.describeError(e);
      return;
    }
    if (this.articleTitle === '') {
      this.isLoading = false;
      this.isRolling = false;
      this.loadError = 'No random article was returned.';
      return;
    }
    try {
      this.applyBody(await ArticleService.fetchMobileHtml(this.host, this.articleTitle));
    } catch (e) {
      console.warn('random: mobile-html unavailable: ' + this.describeError(e));
      this.loadError = this.describeError(e);
    }
    this.isLoading = false;
    this.isRolling = false;

    // history WRITE path — the random article that was read is a read-history row
    try {
      await HistoryStore.addToReadHistory(this.articleKey(), null, this.getDisplayTitle(),
        this.summary !== null ? this.summary.articleDescription : null, null,
        this.summary !== null && this.summary.thumbnail !== null ? this.summary.thumbnail.source : null,
        this.summary !== null ? this.summary.id : null);
      await HistoryStore.addPageView(this.articleTitle, 0, this.projectID, null);
    } catch (e) {
      console.error('random: history write failed: ' + this.describeError(e));
    }

    try {
      const saved: boolean = await SavedStore.isSaved(this.articleKey());
      this.isSaved = saved;
      this.savedDate = saved ? Date.now() : null;
    } catch (e) {
      console.error('random: saved lookup failed: ' + this.describeError(e));
    }

    try {
      // the footer's Read more: three, in the API's order
      this.items = await ArticleService.fetchRelatedArticles(this.host, this.articleTitle, 3, true);
    } catch (e) {
      console.warn('random: related pages unavailable: ' + this.describeError(e));
    }
  }

  // Every per-article field is cleared before a reroll so the previous article's body,
  // toolbar state and footer cannot survive it.
  private resetArticleState(): void {
    this.summary = null;
    this.leadBlocks = [];
    this.sections = [];
    this.editProtected = false;
    this.pronunciationURL = '';
    this.tocItems = [];
    this.items = [];
    this.hasPageIssues = false;
    this.sectionTops = new Map<string, number>();
    this.savedDate = null;
    this.isSaved = false;
    this.showToc = false;
    this.showFindBar = false;
    this.findQuery = '';
    this.scroller.scrollEdge(Edge.Top);
  }

  private applyBody(html: string): void {
    const parsed: ParsedArticle = parseArticle(html);
    this.leadBlocks = parsed.lead;
    this.sections = parsed.sections;
    this.hasPageIssues = parsed.hasPageIssues;
    this.editProtected = parsed.editProtected;
    this.pronunciationURL = parsed.pronunciationURL;
    const toc: TocItem[] = [];
    for (const section of parsed.sections) {
      const item = new TocItem();
      item.anchor = section.anchor;
      item.title = section.title;
      item.level = section.level - 1;
      toc.push(item);
    }
    this.tocItems = toc;
  }

  private lastEdited(): string {
    return lastEditedString(getContext(this), this.summary !== null ? this.summary.timestamp : null);
  }

  private getDisplayTitle(): string {
    if (this.summary !== null && this.summary.displayTitle !== null) {
      return stripTags(this.summary.displayTitle);
    }
    return this.articleTitle;
  }

  private articleURL(): string {
    return 'https://' + this.host + '/wiki/' + this.articleTitle.replace(/ /g, '_');
  }

  private articleKey(): string {
    return this.articleURL();
  }

  // An in-document link / related page leaves the random route for the article route
  // (the source pushes an ArticleViewController for a link, a RandomArticleViewController
  // only for the die).
  private openArticle(articleTitle: string): void {
    if (articleTitle === '') {
      return;
    }
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  private openSinglePageWeb(url: string): void {
    try {
      webview.WebviewController.prepareForPageLoad(url, true, 2);
    } catch (e) {
      console.warn('random: web preconnect failed: ' + this.describeError(e));
    }
    const params: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: params });
  }

  private openSegment(seg: ArticleSegment): void {
    if (seg.kind === 'wiki') {
      // Router.destination(for:), as on the article screen
      const d: LinkDestination = destinationFor(this.host.split('.')[0], seg.target);
      if (d.kind === LinkKind.Article) {
        router.pushUrl({ url: 'pages/ArticleViewControllerPage',
          params: { 'articleTitle': d.title, 'languageCode': d.languageCode } });
      } else if (d.kind === LinkKind.Talk) {
        router.pushUrl({ url: 'pages/TalkPageViewControllerPage',
          params: { 'talkPageTitle': d.title, 'languageCode': d.languageCode } });
      } else if (d.kind !== LinkKind.Web) {
        const intent = intentForDestination(d);
        router.pushUrl({ url: intent.route, params: intent.params });
      } else {
        this.openSinglePageWeb(d.url);
      }
    } else if (seg.kind === 'external') {
      this.openSinglePageWeb(seg.target);
    } else {
      this.scrollToSection('References');
    }
  }

  // A subsection of a closed hideable section is hidden with it.
  private sectionShown(s: ArticleSection): boolean {
    return s.under === '' || this.sections.some((p: ArticleSection) => p.anchor === s.under && p.expanded);
  }

  private firstCollapsible(): string {
    const first: ArticleSection | undefined = this.sections.find((s: ArticleSection) => s.collapsible);
    return first !== undefined ? first.anchor : '';
  }

  private toggleSection(anchor: string): void {
    const next: ArticleSection[] = [];
    for (const section of this.sections) {
      if (section.anchor === anchor) {
        section.expanded = !section.expanded;
      }
      next.push(section);
    }
    this.sections = next;
  }

  private scrollToSection(anchor: string): void {
    const target: ArticleSection | undefined = this.sections.find((s: ArticleSection) => s.anchor === anchor);
    const parent: string = target !== undefined ? target.under : '';
    const next: ArticleSection[] = [];
    for (const section of this.sections) {
      if (section.anchor === anchor || section.anchor === parent) {
        section.expanded = true;
      }
      next.push(section);
    }
    this.sections = next;
    const top: number | undefined = this.sectionTops.get(anchor);
    if (top !== undefined) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: top });
    }
  }

  private recordSectionTop(anchor: string, y: Length | undefined): void {
    if (y === undefined) {
      return;
    }
    const top: number = Number.parseFloat(y.toString());
    if (!Number.isNaN(top)) {
      this.sectionTops.set(anchor, top);
    }
  }

  // The pencil presents the source's edit action sheet over the article
  // (showEditSectionOrTitleDescriptionDialogForSection); both rows open the native editor,
  // as the article screen's do.
  private editSection(anchor: string): void {
    // HarmonyOS action menu (as the Places filter): a centred list with its own Cancel. The
    // ActionSheet this was opened with empty title/message lines and squeezed the two rows.
    this.getUIContext().getPromptAction().showActionMenu({
      buttons: [
        { text: $r('app.string.description_edit_pencil_title'), color: $r('app.color.theme_link') },
        { text: $r('app.string.description_edit_pencil_introduction'), color: $r('app.color.theme_link') }
      ]
    }).then((r) => {
      if (r.index === 0) {
        this.openEditor('description', '');
      } else {
        this.openEditor('section', anchor);
      }
    }).catch(() => {
      // cancelled
    });
  }

  private openEditor(mode: string, anchor: string): void {
    const params: Record<string, string> = {
      'mode': mode,
      'articleTitle': this.articleTitle,
      'host': this.host,
      'anchor': anchor,
      'languageCode': this.host.split('.')[0],
      'description': this.summary?.articleDescription ?? ''
    };
    router.pushUrl({ url: 'pages/SectionEditorViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('random: editor route failed: ' + e.message);
      });
  }

  private toggleSave(): void {
    const willSave: boolean = this.savedDate === null;
    this.isSaved = willSave;
    this.savedDate = willSave ? Date.now() : null;
    SavedStore.toggleSave(this.articleKey(), null, this.getDisplayTitle()).then((saved: boolean) => {
      this.isSaved = saved;
      this.savedDate = saved ? Date.now() : null;
    }).catch((e: Error) => {
      console.error('random: toggleSave failed: ' + e.message);
      this.isSaved = !willSave;
      this.savedDate = willSave ? null : Date.now();
    });
  }

  // No ShareKit in this SDK: copy the article URL and confirm by toast
  // (self-signed-capabilities.md — the action must never silently no-op).
  private share(): void {
    const text: string = this.getDisplayTitle() + ' ' + this.articleURL();
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.getUIContext().getPromptAction().showToast({ message: 'Article link copied' });
    }).catch((e: Error) => {
      console.error('random: share failed: ' + e.message);
      this.getUIContext().getPromptAction().showToast({ message: 'Could not share this article' });
    });
  }

  @Builder
  blockView(b: ArticleBlock) {
    if (b.kind === 'img') {
      ArticleFigureView({
        block: b,
        dark: this.wmfIsDark,
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        }
      })
    } else if (b.kind === 'pie') {
      ArticlePieView({
        block: b,
        dark: this.wmfIsDark,
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        }
      })
    } else if (b.kind === 'quote') {
      // Template:Quote box, as on the article screen
      Column() {
        ForEach(b.children, (c: ArticleBlock) => {
          this.textBlockView(c)
        }, (c: ArticleBlock) => c.key)
      }
      .width('calc(100% - 32vp)')
      .margin({ left: 16, right: 16, top: 8, bottom: 8 })
      .padding({ top: 8, bottom: 8 })
      .border({ width: 1, color: '#A2A9B1' })
      .backgroundColor(b.fill !== '' ? b.fill : (this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    } else if (b.kind === 'bq') {
      // blockquote, as on the article screen: a 3 px bar at the text margin, serif text inside
      Column() {
        ForEach(b.children, (c: ArticleBlock) => {
          this.textBlockView(c)
        }, (c: ArticleBlock) => c.key)
      }
      .width('calc(100% - 16vp)')
      .margin({ left: 16, top: 8, bottom: 8 })
      .padding({ top: 8, bottom: 8 })
      .border({ width: { left: 3 }, color: this.wmfIsDark ? '#54595D' : '#C8CCD1' })
    } else if (b.kind === 'table') {
      ArticleTableView({
        block: b,
        defaultOpen: Prefs.getBoolean(PrefKeys.isAutomaticTableOpeningEnabled, false),
        dark: this.wmfIsDark,
        panelColor: (this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')),
        onLink: (seg: ArticleSegment): void => {
          this.openSegment(seg);
        },
        scroller: this.scroller,
        scrollId: 'article_body_scroll'
      })
    } else {
      this.textBlockView(b)
    }
  }

  @Builder
  textBlockView(b: ArticleBlock) {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      if (b.kind === 'li' && b.bullet) {
        Text('• ')
          .fontSize(17)
          .lineHeight(26)
          .fontColor($r('app.color.theme_secondary_text'))
      }
      ForEach(b.segments, (seg: ArticleSegment, i: number) => {
        if (seg.kind === 'swatch') {
          // a legend / colour-box square
          Image(swatchPixelMap(seg.color, seg.borderColor))
            .width(14)
            .height(14)
            .margin({ right: 4 })
        } else if (seg.kind === 'text') {
          Text(seg.text)
            .fontFamily(b.kind === 'bqp' ? WMFFontFamilies.serifStack : undefined)
            .fontSize((b.kind === 'note' ? 15 : 17) * (seg.sup ? 0.75 : 1))
            .lineHeight(seg.sup ? 17 : (b.kind === 'note' ? 22 : 26))
            // <sup> (reference markers) at the top of the line, as the source's superscript
            .alignSelf(seg.sup ? ItemAlign.Start : ItemAlign.Auto)
            .fontWeight(seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(seg.italic !== (b.kind === 'note') ? FontStyle.Italic : FontStyle.Normal)
            .fontColor(b.kind === 'note' ? $r('app.color.theme_secondary_text')
              : (readableInlineColor(seg.color, this.wmfIsDark) !== '' ? readableInlineColor(seg.color, this.wmfIsDark)
                : (b.kind === 'qp' && b.fill !== '' ? (b.ink !== '' ? b.ink : '#202122') : $r('app.color.theme_text'))))
            .backgroundColor(seg.background !== '' && !this.wmfIsDark ? seg.background : Color.Transparent)
            .constraintSize({ maxWidth: '100%' })
        } else {
          Text(seg.text)
            .id(seg.slug + '_articlelink_itemroot')
            .fontFamily(b.kind === 'bqp' ? WMFFontFamilies.serifStack : undefined)
            .fontSize((b.kind === 'note' ? 15 : 17) * (seg.sup ? 0.75 : 1))
            .lineHeight(seg.sup ? 17 : (b.kind === 'note' ? 22 : 26))
            .alignSelf(seg.sup ? ItemAlign.Start : ItemAlign.Auto)
            .fontWeight(seg.bold ? FontWeight.Bold : FontWeight.Normal)
            .fontStyle(seg.italic !== (b.kind === 'note') ? FontStyle.Italic : FontStyle.Normal)
            .fontColor(b.kind === 'qp' && b.fill !== '' ? '#3366CC' : $r('app.color.theme_link'))
            .constraintSize({ maxWidth: '100%' })
            .onClick(() => {
              this.openSegment(seg);
            })
          if (seg.externalMark) {
            Image(externalLinkMark(this.wmfIsDark, false))
              .width(13)
              .height(13)
              .margin({ left: 2 })
          }
        }
      }, (seg: ArticleSegment, i: number) => b.key + '_' + i)
    }
    .width('100%')
    .padding(b.kind === 'bqp' ? { left: 32, right: 40, top: 4, bottom: 4 }
      : { left: b.kind === 'li' && b.bullet ? 32 : 16, right: 16, top: 6, bottom: 6 })
  }

  // the system back closes the table of contents first
  onBackPress(): boolean {
    if (this.showToc) {
      this.setTocShown(false);
      return true;
    }
    return false;
  }

  private setTocShown(shown: boolean): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.showToc = shown;
    });
  }

  // tableOfContentsController(_:didSelectItem:): the title row goes to the top
  private selectTocItem(anchor: string): void {
    if (anchor === '') {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
    } else {
      this.scrollToSection(anchor);
    }
    this.setTocShown(false);
  }

  @Builder
  themesPopupBuilder() {
    ReadingThemesControlsView()
  }

  // The bar's surface runs on through the gesture-handle strip below its 56 vp, so the items
  // drop by about a third of that strip (capped), as the root tab bar's do. Visual only.
  private toolbarItemOffset(): number {
    return Math.min(this.navIndicatorInset * 0.35, 12);
  }

  build() {
    Column() {
      // navigation bar — only the implicit back affordance this screen's inventory declares
      Row() {
        Button() {
          Image($r('app.media.chevron_left'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
          .id('BackButton')
          .accessibilityText('Back')
          .type(ButtonType.Circle)
          .width(44)
          .height(44)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            router.back();
          })
        Blank()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))

      // article body (native render of the random article's mobile-html)
      Scroll(this.scroller) {
        Column() {
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color($r('app.color.theme_secondary_text'))
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .justifyContent(FlexAlign.Center)
          } else if (this.loadError !== '') {
            Column({ space: 12 }) {
              Text($r('app.string.empty_no_article_message'))
                .fontSize(17)
                .lineHeight(24)
                .fontColor($r('app.color.theme_text'))
              Text(this.loadError)
                .fontSize(13)
                .fontColor($r('app.color.theme_secondary_text'))
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
          } else {
            Image(this.summary !== null && this.summary.original !== null ? this.summary.original.source : '')
              .id('Article Lead Image')
              .width('100%')
              .height(240)
              .objectFit(ImageFit.Cover)
              .backgroundColor($r('app.color.gray200'))
            Row() {
              Text(this.getDisplayTitle())
                .flexShrink(1)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.theme_text'))
              // the title's pronunciation button, as on the article screen
              if (this.pronunciationURL !== '') {
                Image($r('app.media.title_pronunciation'))
                  .colorFilter(new ColorFilter(this.wmfIsDark
                    ? [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0]
                    : [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]))
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .opacity(this.wmfIsDark ? 0.7 : 0.54)
                  .margin({ left: 10, right: 10 })
                  .id('title_pronunciation')
                  .accessibilityText('Listen to pronunciation')
                  .onClick(() => {
                    this.openSinglePageWeb(this.pronunciationURL);
                  })
              }
            }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .padding({ left: 16, right: 16, top: 16 })
            Text(this.summary !== null && this.summary.articleDescription !== null
              ? this.summary.articleDescription : '')
              .fontSize(17)
              .fontColor($r('app.color.theme_secondary_text'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 4 })
            // S6 (capture base.png): a short hairline rule under the description
            Divider()
              .width(60)
              .strokeWidth(1)
              .color($r('app.color.gray200'))
              .margin({ left: 16, top: 16, bottom: 8 })
            ForEach(this.leadBlocks, (b: ArticleBlock) => {
              this.blockView(b)
            }, (b: ArticleBlock) => b.key)

            // sections: the edit pencil where PCS offers one; a toggle only on the sections the source
            // starts closed (the shared `itemroot` ids are Rule 12's list-row exception, resolved by index)
            ForEach(this.sections, (s: ArticleSection, idx: number) => {
              Column() {
                if (this.sectionShown(s)) {
                  // hr.pcs-fold-hr: the hairline above the first closed section
                  if (s.collapsible && this.firstCollapsible() === s.anchor) {
                    Divider()
                      .strokeWidth(1)
                      .color($r('app.color.gray200'))
                      .margin({ left: 16, right: 16, top: 16, bottom: 4 })
                  }
                  Row() {
                    // pcs-section-control: the chevron before the title, down while closed
                    if (s.collapsible) {
                      Button() {
                        Image(s.expanded ? $r('app.media.chevron_up') : $r('app.media.chevron_down'))
                          .colorFilter(new ColorFilter(this.wmfIsDark
                            ? [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0]
                            : [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]))
                          .width(14)
                          .height(14)
                          .objectFit(ImageFit.Contain)
                      }
                        .id('expand_section_itemroot')
                        .accessibilityText(s.expanded ? 'Collapse section' : 'Expand section')
                        .type(ButtonType.Normal)
                        .backgroundColor(Color.Transparent)
                        .width(24)
                        .height(40)
                        .margin({ right: 6 })
                        .onClick(() => {
                          this.toggleSection(s.anchor);
                        })
                    }
                    // the source's section headings: level 2 in the serif face, deeper ones bold sans
                    Text(s.title)
                      .layoutWeight(1)
                      .fontFamily(s.level <= 2 ? WMFFontFamilies.serifStack : undefined)
                      .fontSize(s.level <= 2 ? 24 : 18)
                      .fontWeight(s.level <= 2 ? FontWeight.Normal : FontWeight.Bold)
                      .fontColor($r('app.color.theme_text'))
                    if (s.editable) {
                      Button() {
                        Image(this.editProtected ? $r('app.media.pencil_protected') : $r('app.media.pencil'))
                          .width(18)
                          .height(18)
                          .objectFit(ImageFit.Contain)
                      }
                        .id(idx === 0 ? 'edit_section_on_protected' : 'edit_section_itemroot')
                        .accessibilityText(this.editProtected ? 'Edit section on protected page' : 'Edit section')
                        .type(ButtonType.Normal)
                        .backgroundColor(Color.Transparent)
                        .width(40)
                        .height(40)
                        .onClick(() => {
                          this.editSection(s.anchor);
                        })
                    }
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .padding({ left: s.collapsible ? 10 : 16, right: 8, top: 8, bottom: 8 })
                  .onClick(() => {
                    if (s.collapsible) {
                      this.toggleSection(s.anchor);
                    }
                  })
                  if (s.expanded) {
                    ForEach(s.blocks, (b: ArticleBlock) => {
                      this.blockView(b)
                    }, (b: ArticleBlock) => b.key)
                  }
                }
              }
              .width('100%')
              .onAreaChange((_o: Area, n: Area) => {
                this.recordSectionTop(s.anchor, n.position.y);
              })
            // The key carries the open state (its own, and its hideable parent's for a subsection):
            // sections are plain (unobserved) objects, so a toggle only redraws a section when its key changes.
            }, (s: ArticleSection) => s.anchor + (s.expanded ? '_open' : '_closed') + (this.sectionShown(s) ? '' : '_hidden'))
          }

          // footer: About this article, Read more and the licence (PCS Footer, setupFooter)
          ArticleFooterView({
            lastEdited: this.lastEdited(),
            hasPageIssues: this.hasPageIssues,
            hasCoordinates: this.summary !== null && this.summary.coordinates !== null,
            related: this.items,
            onTalkPage: (): void => {
              const params: Record<string, string> = { 'articleTitle': this.articleTitle };
              router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params });
            },
            onEditHistory: (): void => {
              const params: Record<string, string> = {
                'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0] };
              router.pushUrl({ url: 'pages/PageHistoryViewControllerPage', params: params });
            },
            onPageIssues: (): void => {
              this.showPageIssues = true;
            },
            onSimilarPages: (): void => {
              const params: Record<string, string> = { 'articleTitle': this.articleTitle };
              router.pushUrl({ url: 'pages/DisambiguationPagesViewControllerPage', params: params });
            },
            onRelated: (title: string): void => {
              this.openArticle(title);
            },
            onViewOnMap: (): void => {
              const s: ArticleSummary | null = this.summary;
              if (s !== null && s.coordinates !== null) {
                showArticleOnMap(this.getUIContext().getRouter(), this.articleTitle,
                  s.articleDescription ?? '', s.thumbnail !== null ? s.thumbnail.source : '',
                  s.coordinates.lat, s.coordinates.lon);
              }
            },
            onLicense: (): void => {
              this.openSinglePageWeb('https://creativecommons.org/licenses/by-sa/4.0/');
            },
            onBrowser: (): void => {
              this.openSinglePageWeb(this.articleURL());
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .id('article_body_scroll')
      .layoutWeight(1)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .align(Alignment.Top)

      // find-in-page bar (toolbar toggle)
      if (this.showFindBar) {
        Row() {
          TextInput({ placeholder: 'Find in page', text: this.findQuery })
            .id('find_in_page_field')
            .layoutWeight(1)
            .height(36)
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
            .placeholderColor($r('app.color.theme_secondary_text'))
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .borderRadius(8)
            .onChange((v: string) => {
              this.findQuery = v;
            })
            .onSubmit(() => {
              this.findNext();
            })
          Button('Done')
            .id('find_in_page_done')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .height(36)
            .padding({ left: 12, right: 4 })
            .onClick(() => {
              this.showFindBar = false;
              this.findQuery = '';
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .border({ width: { top: 1 }, color: $r('app.color.gray200') })
      }

      // second toolbar — the WMFRandomDiceButton this subclass adds (setupSecondToolbar)
      Row() {
        Button() {
          // S5 (capture base.png): a blue capsule carrying the white die glyph and the
          // 'Randomizer' label, floating in its own white capsule over the article.
          Row({ space: 10 }) {
            Image($r('app.media.random_mini'))
              .width(26)
              .height(26)
              .padding(5)
              .objectFit(ImageFit.Contain)
              .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
              .borderRadius(6)
            Text('Randomizer')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          }
          .alignItems(VerticalAlign.Center)
        }
          .id('Randomizer')
          .accessibilityText('Randomizer')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.theme_link'))
          .borderRadius(22)
          .width(184)
          .height(44)
          // diceButton.isEnabled = !isRandomArticleLoading
          .enabled(!this.isRolling)
          .opacity(this.isRolling ? 0.6 : 1)
          .onClick(() => {
            this.loadRandomArticle();
          })
      }
      .id('Second Toolbar')
      .width(196)
      .height(56)
      .margin({ bottom: 8 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(28)
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })

      // bottom toolbar (ArticleToolbarController — capture order). Each control is a
      // wrapper carrying the capture's resource-id around the button carrying the action
      // contract's name: the drivers match on visible text or .id() only, and these
      // controls are icon-only.
      Row() {
        Row() {
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.toc'), w: 33, h: 33 })
            }
              .id('Table of contents')
              .accessibilityText('Table of contents')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.setTocShown(true);
              })
          }
            .id('Article Table of Contents Button')
            .width(48)
            .height(48)
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.language'), w: 28, h: 24 })
            }
              .id('Change language')
              .accessibilityText('Change language')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                router.pushUrl({ url: 'pages/WMFLanguagesViewControllerPage' }).catch((e: Error) => {
                  console.error('random: languages route failed: ' + e.message);
                });
              })
          }
            .id('Article Languages Button')
            .width(48)
            .height(48)
          Stack() {
            Button() {
              // conditionalVariants(article.savedDate): filled bookmark once saved. The id
              // carries the state because .accessibilityText() never reaches the uitest dump.
              ArticleToolbarGlyph({
                icon: this.savedDate !== null ? $r('app.media.save_filled') : $r('app.media.save'),
                w: 16,
                h: 23,
                glyphId: this.savedDate !== null ? 'save_state_on' : 'save_state_off'
              })
            }
              .id('Saved. Activate to unsave.')
              .accessibilityText(this.savedDate !== null ? 'Saved. Activate to unsave.' : 'Save for later')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.toggleSave();
              })
          }
            .id('Article Save Button')
            .width(48)
            .height(48)
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.find_in_page'), w: 19, h: 25 })
            }
              .id('Find in page')
              .accessibilityText('Find in page')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.showFindBar = true;
              })
          }
            .id('Article Find In Page Button')
            .width(48)
            .height(48)
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: $r('app.media.font_size'), w: 24, h: 20 })
            }
              .id('font size')
              .accessibilityText('font size')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .onClick(() => {
                this.showThemesPopup = true;
              })
          }
            .id('Article Theme Button')
            .width(48)
            .height(48)
          Stack() {
            Button() {
              ArticleToolbarGlyph({ icon: null })
            }
              .id('More')
              .accessibilityText('More')
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .width(48)
              .height(48)
              .bindMenu([
                {
                  value: 'Share',
                  action: (): void => {
                    this.share();
                  }
                } as MenuElement,
                {
                  value: 'Article talk page',
                  action: (): void => {
                    const params: Record<string, string> = { 'articleTitle': this.articleTitle };
                    router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params });
                  }
                } as MenuElement,
                {
                  value: 'Article revision history',
                  action: (): void => {
                    const params: Record<string, string> = {
                      'articleTitle': this.articleTitle, 'languageCode': this.host.split('.')[0] };
                    router.pushUrl({ url: 'pages/PageHistoryViewControllerPage', params: params });
                  }
                } as MenuElement,
                {
                  value: 'Edit source',
                  action: (): void => {
                    this.editSection('');
                  }
                } as MenuElement
              ])
          }
            .id('Article More Button')
            .width(48)
            .height(48)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)
        .translate({ y: this.toolbarItemOffset() })
      }
      .id('Toolbar')
      // A HarmonyOS bottom toolbar, as on the article screen: full width on the page surface with a
      // hairline above, its surface running under the navigation indicator. It replaces the iOS
      // 26 floating pill (92% wide, radius 28, shadow) of the capture. No fixed height:
      // expandSafeArea is ignored on a fixed-size component, so the 56 vp come from the 48 vp
      // buttons plus the padding.
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .responseRegion({ x: 0, y: 0, width: '100%', height: 56 + this.toolbarItemOffset() })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .border({ width: { top: 0.5 }, color: $r('app.color.theme_border') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      // S6 (capture S0240 "Article Theme Button"): the reading-themes panel is a plain
      // white rounded card floating over the article above the toolbar — no arrow, no
      // tinted bubble chrome.
      .bindPopup($$this.showThemesPopup, {
        builder: this.themesPopupBuilder(),
        placement: Placement.Top,
        popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
        radius: 20,
        enableArrow: false,
        width: '92%',
        shadow: { radius: 16, color: '#1F000000', offsetY: 2 }
      })

      // TableOfContentsPresentationController: the panel slides in over the whole screen
      if (this.showToc) {
        TableOfContentsView({
          items: this.tocItems,
          articleTitle: this.articleTitle,
          onSelect: (anchor: string): void => {
            this.selectTocItem(anchor);
          },
          onClose: (): void => {
            this.setTocShown(false);
          }
        })
          .position({ x: 0, y: 0 })
          .zIndex(10)
      }
    }
    .id('RandomArticleViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    // the footer's Page issues row (showPageIssues), as on the article screen
    .bindSheet($$this.showPageIssues, this.pageIssuesSheet(), {
      height: SheetSize.LARGE,
      dragBar: false,
      backgroundColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'))
    })
  }

  @Builder
  pageIssuesSheet() {
    PageIssuesTableView({
      articleTitle: this.articleTitle,
      host: this.host,
      onClose: (): void => {
        this.showPageIssues = false;
      }
    })
  }

  // Return on the find field jumps to the first section carrying the query.
  // ponytail: first match only — add a match cursor if that matters.
  private findNext(): void {
    const query: string = this.findQuery.toLowerCase();
    if (query === '') {
      return;
    }
    for (const section of this.sections) {
      if (section.title.toLowerCase().includes(query)) {
        this.scrollToSection(section.anchor);
        return;
      }
      for (const block of section.blocks) {
        if (block.plain.toLowerCase().includes(query)) {
          this.scrollToSection(section.anchor);
          return;
        }
      }
    }
  }
}
