// screen_section_editor — presentation: page, pushed from the article's pencil action sheet.
//
// Two modes behind one screen, matching the two rows of that sheet:
//   'section'     -> SectionEditorViewController: the wikitext of one section, loaded with
//                    action=query&rvsection and published with action=edit.
//   'description' -> DescriptionEditViewController: the article's short description, loaded
//                    from the summary the article already has and published to Wikidata.
// Both used to open the remote ?action=edit page inside SinglePageWebViewController, which
// serves the VisualEditor bootstrap — a JavaScript shell that cannot run in a natively
// rendered document, so the reader saw "The editor will now load..." forever or, on a
// malformed URL, "This page could not be loaded."
import { router, KeyboardAvoidMode } from '@kit.ArkUI';
import { EditService } from '../common/EditService';
import { topSafeInset } from '../common/SafeArea';
import { SessionStore } from '../common/SessionStore';
import { WikitextEditorView, WikitextEditorController } from '../components/WikitextEditorView';
import { EditorState, LinkInfo, linkAtSelection, insertLink, editLink, removeLink } from '../common/WikitextFormatter';
import { LINK_WIZARD_RESULT_KEY } from './InsertLinkViewControllerPage';
import { InsertMediaSession, INSERT_MEDIA_RESULT_KEY } from '../common/InsertMedia';
import { EDIT_PREVIEW_NEXT_KEY } from './EditPreviewViewControllerPage';
import { EditNoticesView, noticeRuns } from '../components/EditNoticesView';
import { HtmlRun } from '../common/SimpleHtml';
import { Prefs, PrefKeys } from '../common/Prefs';
import { intentForUri } from '../entryability/RouteTable';
import { ReadingThemesControlsView } from './ReadingThemesControlsViewControllerPage';

// DescriptionEditViewController.maximumDescriptionLength
const MAX_DESCRIPTION_LENGTH: number = 90;

@Entry
@Component
struct SectionEditorViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State mode: string = 'section';               // section | description
  @State articleTitle: string = '';
  @State host: string = 'en.wikipedia.org';
  @State languageCode: string = 'en';
  private anchor: string = '';
  private sectionIndex: number = 0;

  @State text: string = '';
  @State isLoading: boolean = true;
  @State isPublishing: boolean = false;
  @State loadError: string = '';
  @State statusMessage: string = '';
  @State editSummary: string = '';
  // TempAccountSheetCoordinator.presentIPEditorSheet: a logged-out reader first sees
  // "You are not logged in" with log in / continue without logging in.
  @State showIPSheet: boolean = false;
  // the source editor's undo / redo bar buttons follow its undo manager
  @State canUndo: boolean = false;
  @State canRedo: boolean = false;
  // the wikitext as loaded: Next is enabled once it changed (sourceEditorDidChangeText)
  private originalText: string = '';
  // Preview's Next -> the save step (summary, Publish)
  @State showSaveSheet: boolean = false;
  // the page's edit notices (EditNoticesViewModel); the nav bar gets their button when there are any
  @State editNotices: HtmlRun[] = [];
  @State showEditNotices: boolean = false;
  @State showReadingThemes: boolean = false;
  // focusNavigationView: "Find and replace" with its close button while the find bar is up
  @State findActive: boolean = false;
  private editorController: WikitextEditorController = new WikitextEditorController();
  // the editor's state when Insert link / Edit link opened (preselectedTextRange)
  private linkState: EditorState | null = null;
  // the editor's state when Insert media opened
  private mediaState: EditorState | null = null;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined) {
      this.mode = params['mode'] ?? 'section';
      this.articleTitle = params['articleTitle'] ?? '';
      this.host = params['host'] ?? this.host;
      this.anchor = params['anchor'] ?? '';
      this.languageCode = params['languageCode'] ?? this.host.split('.')[0];
      if (this.mode === 'description') {
        this.text = params['description'] ?? '';
      }
    }
    this.showIPSheet = !SessionStore.isLoggedIn;
    // the editor's toolbar is the text view's input accessory: the page shrinks above the keyboard
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.load();
  }

  // Back from the login screen signed in: loginSuccessCompletion -> didTapContinue. Back from
  // Insert link / Edit link: insertLink / editLink / removeLink on the selection kept for it.
  onPageShow(): void {
    if (AppStorage.get<boolean>(EDIT_PREVIEW_NEXT_KEY) === true) {
      AppStorage.setOrCreate<boolean>(EDIT_PREVIEW_NEXT_KEY, false);
      this.showSaveSheet = true;
    }
    // insertImage(wikitext:): the wikitext replaces the selection, the caret after it
    const media: string = AppStorage.get<string>(INSERT_MEDIA_RESULT_KEY) ?? '';
    const mediaState: EditorState | null = this.mediaState;
    if (media !== '' && mediaState !== null) {
      AppStorage.setOrCreate<string>(INSERT_MEDIA_RESULT_KEY, '');
      this.mediaState = null;
      const t: string = mediaState.text;
      const caret: number = mediaState.start + media.length;
      this.editorController.apply(new EditorState(t.substring(0, mediaState.start) + media +
        t.substring(mediaState.end), caret, caret));
    }
    const raw: string = AppStorage.get<string>(LINK_WIZARD_RESULT_KEY) ?? '';
    const state: EditorState | null = this.linkState;
    if (raw !== '' && state !== null) {
      AppStorage.setOrCreate<string>(LINK_WIZARD_RESULT_KEY, '');
      this.linkState = null;
      const result: Record<string, string> = JSON.parse(raw) as Record<string, string>;
      const action: string = result['action'] ?? '';
      if (action === 'insert') {
        this.editorController.apply(insertLink(state, result['page'] ?? ''));
      } else if (action === 'edit') {
        this.editorController.apply(editLink(state, result['page'] ?? '', result['label'] ?? null));
      } else if (action === 'remove') {
        this.editorController.apply(removeLink(state));
      }
    }
    if (this.showIPSheet && SessionStore.isLoggedIn) {
      this.showIPSheet = false;
    }
  }

  // ip-account-edit-sheet-subtitle: \$1..\$2 bold, \$3..\$4 the Learn more link, \$5 a paragraph break.
  private ipSubtitleParts(): string[] {
    try {
      return getContext(this).resourceManager
        .getStringSync($r('app.string.ip_account_edit_sheet_subtitle').id)
        .split(/\\?\$\d/);
    } catch (e) {
      return [];
    }
  }

  private openLearnMore(): void {
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: {
      'url': 'https://www.mediawiki.org/wiki/Special:MyLanguage/Help:Temporary_accounts?uselang=' + this.languageCode
    } as Record<string, string> }).catch((e: Error) => {
      console.error('sectionEditor: learn more route failed: ' + e.message);
    });
  }

  @Builder
  ipSheet() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.theme_text')])
        }
        .id('ip_sheet_close')
        .type(ButtonType.Circle)
        .width(40)
        .height(40)
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .onClick(() => {
          router.back();
        })
      }
      .width('100%')

      Scroll() {
        Column() {
          Image($r('app.media.locked_edit'))
            .height(160)
            .objectFit(ImageFit.Contain)
            .margin({ top: 8, bottom: 24 })
          Text($r('app.string.ip_account_warning_title'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .textAlign(TextAlign.Center)
            .margin({ bottom: 16 })
          if (this.ipSubtitleParts().length >= 6) {
            Text() {
              Span(this.ipSubtitleParts()[0])
              Span(this.ipSubtitleParts()[1]).fontWeight(FontWeight.Bold)
              Span(this.ipSubtitleParts()[2])
              Span(this.ipSubtitleParts()[3]).fontColor($r('app.color.theme_link'))
                .onClick(() => {
                  this.openLearnMore();
                })
              Span(this.ipSubtitleParts()[4] + '\n\n' + this.ipSubtitleParts()[5])
            }
            .width('100%')
            .fontSize(16)
            .lineHeight(22)
            .fontColor($r('app.color.theme_text'))
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Button($r('app.string.ip_account_cta_top'))
        .id('ip_sheet_login')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.theme_link'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/WMFLoginViewControllerPage' }).catch((e: Error) => {
            console.error('sectionEditor: login route failed: ' + e.message);
          });
        })
      Button($r('app.string.ip_account_cta_bottom'))
        .id('ip_sheet_continue')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
        .margin({ top: 10 })
        .onClick(() => {
          this.showIPSheet = false;
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: topSafeInset() + 12, bottom: 32 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  private load(): void {
    if (this.articleTitle === '') {
      this.isLoading = false;
      this.loadError = 'No article to edit.';
      return;
    }
    if (this.mode === 'description') {
      // The description arrives with the route (the article already fetched its summary);
      // nothing else has to be loaded before the field is editable.
      this.isLoading = false;
      return;
    }
    this.isLoading = true;
    this.loadError = '';
    // loadEditNotices runs beside the wikitext fetch; a failure just means no notices
    const notices: Promise<string[]> = EditService.fetchEditNotices(this.host, this.articleTitle)
      .catch((e: Error): string[] => {
        console.error('sectionEditor: edit notices failed: ' + e.message);
        return [];
      });
    EditService.sectionIndexForAnchor(this.host, this.articleTitle, this.anchor)
      .then((index: number) => {
        this.sectionIndex = index;
        return EditService.fetchSectionWikitext(this.host, this.articleTitle, index);
      })
      .then((wikitext: string) => {
        this.text = wikitext;
        this.originalText = wikitext;
        this.isLoading = false;
        return notices;
      })
      .then((html: string[] | undefined) => {
        // presentEditNoticesIfNecessary: on load when Always display edit notices is on (and
        // not over the account sheet)
        this.editNotices = noticeRuns(html ?? []);
        if (this.editNotices.length > 0 && !this.showIPSheet &&
          Prefs.getBoolean(PrefKeys.alwaysDisplayEditNotices, true)) {
          this.showEditNotices = true;
        }
      })
      .catch((e: Error) => {
        console.error('sectionEditor: load failed: ' + e.message);
        this.isLoading = false;
        this.loadError = e.message;
      });
  }

  private screenTitle(): ResourceStr {
    if (this.mode === 'description') {
      return $r('app.string.description_edit_pencil_title');
    }
    return this.anchor === '' ?
      $r('app.string.description_edit_pencil_introduction') : $r('app.string.editor_title_section');
  }

  private canPublish(): boolean {
    if (this.isLoading || this.isPublishing || this.loadError !== '') {
      return false;
    }
    if (this.mode === 'description') {
      return this.text.length > 0 && this.text.length <= MAX_DESCRIPTION_LENGTH;
    }
    return this.text.length > 0 && this.text !== this.originalText;
  }

  private publish(): void {
    if (!this.canPublish()) {
      return;
    }
    this.isPublishing = true;
    this.statusMessage = '';
    const done = (): void => {
      this.isPublishing = false;
      this.getUIContext().getPromptAction()
        .showToast({ message: $r('app.string.editor_published') });
      router.back();
    };
    const failed = (e: Error): void => {
      console.error('sectionEditor: publish failed: ' + e.message);
      this.isPublishing = false;
      this.statusMessage = e.message;
    };
    if (this.mode === 'description') {
      EditService.wikidataItemID(this.host, this.articleTitle)
        .then((itemID: string) =>
          EditService.publishDescription(this.languageCode, itemID, this.text))
        .then(done)
        .catch(failed);
      return;
    }
    EditService.publishSection(this.host, this.articleTitle, this.sectionIndex,
      this.text, this.editSummary).then(done).catch(failed);
  }

  // WMFNavigationBar: leading X (discard), centred title, trailing Publish.
  @Builder
  navigationBar() {
    Row() {
      Button() {
        Image($r('app.media.close'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
      }
      .id('close_button')
      .type(ButtonType.Circle)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .accessibilityText('Close')
      .onClick(() => {
        router.back();
      })

      Text(this.screenTitle())
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // the edit notices sheet's anchor (one bindSheet per node; the root has the save sheet)
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showEditNotices, this.editNoticesSheet(), { height: SheetSize.LARGE, dragBar: false,
          showClose: false })
      if (this.mode === 'section' && this.editNotices.length > 0) {
        // EditorNavigationItemController.addEditNoticesButton: before undo, diffCompareAccent
        Button() {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_diff_compare_accent')])
        }
        .id('editor_edit_notices')
        .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.edit_notices').id))
        .type(ButtonType.Normal)
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showEditNotices = true;
        })
      }
      if (this.mode === 'section') {
        // EditorNavigationItemController: undo, redo, then Next
        Button() {
          SymbolGlyph($r('sys.symbol.undo'))
            .fontSize(20)
            .fontColor([this.canUndo ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text')])
        }
        .id('editor_undo')
        .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.action_undo').id))
        .type(ButtonType.Normal)
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .enabled(this.canUndo)
        .onClick(() => {
          this.editorController.undo();
        })
        Button() {
          SymbolGlyph($r('sys.symbol.redo'))
            .fontSize(20)
            .fontColor([this.canRedo ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text')])
        }
        .id('editor_redo')
        .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.action_redo').id))
        .type(ButtonType.Normal)
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .enabled(this.canRedo)
        .onClick(() => {
          this.editorController.redo();
        })
      }
      if (this.mode === 'section') {
        // readingThemesControlsButton (textformat.size): the reading themes popover with the
        // Syntax Highlighting switch (showsSyntaxHighlighting)
        Button() {
          SymbolGlyph($r('sys.symbol.textformat'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_link')])
        }
        .id('editor_reading_themes')
        .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.article_toolbar_reading_themes_controls_toolbar_item').id))
        .type(ButtonType.Normal)
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showReadingThemes = !this.showReadingThemes;
        })
        .bindPopup(this.showReadingThemes, {
          builder: this.readingThemesBuilder(),
          popupColor: (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')),
          enableArrow: false,
          radius: 10,
          width: '100%',
          shadow: ShadowStyle.OUTER_DEFAULT_MD,
          onStateChange: (e) => {
            if (!e.isVisible) {
              this.showReadingThemes = false;
            }
          }
        })
      }
      Button() {
        Text(this.mode === 'section' ? $r('app.string.button_next') : $r('app.string.button_publish'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.canPublish() ?
            $r('app.color.theme_link') : $r('app.color.theme_secondary_text'))
      }
      .id('publish')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .enabled(this.canPublish())
      .onClick(() => {
        // EditFlow.editorPreviewSave: Next -> Preview -> Next -> save
        if (this.mode === 'section') {
          router.pushUrl({ url: 'pages/EditPreviewViewControllerPage', params: { 'host': this.host,
            'articleTitle': this.articleTitle, 'wikitext': this.text } });
        } else {
          this.publish();
        }
      })
    }
    .width('100%')
    .height(44)
    .padding({ left: 8, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  descriptionBody() {
    Column() {
      // The source's own description_edit_for_article carries MediaWiki's \$1 placeholder,
      // which ArkUI does not substitute — it renders literally. These two lines use %s
      // placeholders instead.
      Text($r('app.string.editor_description_for_article', this.articleTitle))
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
      // learnMoreButton -> showAboutWikidataPage: the Short description guideline on English
      // (ShortDescriptionController), Article description help elsewhere (WikidataDescriptionController)
      Text($r('app.string.learn_more_title'))
        .id('description_learn_more')
        .fontSize(15)
        .fontColor($r('app.color.theme_link'))
        .padding({ top: 6, bottom: 6 })
        .margin({ bottom: 6 })
        .onClick(() => {
          if (this.host.startsWith('en.') || this.host.startsWith('test.')) {
            router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage',
              params: { 'url': 'https://en.wikipedia.org/wiki/Wikipedia:Short_description' } });
          } else {
            router.pushUrl({ url: 'pages/DescriptionHelpViewControllerPage' });
          }
        })

      TextArea({ text: $$this.text, placeholder: $r('app.string.description_add_title') })
        .id('description_field')
        .width('100%')
        .height(96)
        .fontSize(17)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(8)

      Text($r('app.string.editor_length_counter',
        this.text.length.toString(), MAX_DESCRIPTION_LENGTH.toString()))
        .width('100%')
        .textAlign(TextAlign.End)
        .fontSize(13)
        .fontColor(this.text.length > MAX_DESCRIPTION_LENGTH ?
          Color.Red : $r('app.color.theme_secondary_text'))
        .margin({ top: 6 })

      Text($r('app.string.description_edit_warning'))
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  sectionBody() {
    WikitextEditorView({
      text: $text,
      controller: this.editorController,
      onUndoStateChange: (canUndo: boolean, canRedo: boolean): void => {
        this.canUndo = canUndo;
        this.canRedo = canRedo;
      },
      onFindModeChange: (active: boolean): void => {
        this.findActive = active;
      },
      // sourceEditorViewControllerDidTapImage: Insert media, keeping the selection to replace
      onImage: (): void => {
        this.mediaState = this.editorController.state();
        InsertMediaSession.start(this.articleTitle, this.host);
        router.pushUrl({ url: 'pages/InsertMediaViewControllerPage' });
      },
      // sourceEditorViewControllerDidTapLink: Edit link on an existing link, otherwise Insert
      // link with the selection as the search term
      onLink: (state: EditorState): void => {
        this.linkState = state;
        const link: LinkInfo | null = linkAtSelection(state);
        if (link !== null) {
          router.pushUrl({ url: 'pages/EditLinkViewControllerPage', params: { 'host': this.host,
            'page': link.page, 'label': link.label ?? '' } });
        } else {
          router.pushUrl({ url: 'pages/InsertLinkViewControllerPage', params: { 'host': this.host,
            'searchTerm': state.text.substring(state.start, state.end) } });
        }
      }
    })
  }

  @Builder
  readingThemesBuilder() {
    ReadingThemesControlsView({ showsSyntaxHighlighting: true })
  }

  @Builder
  editNoticesSheet() {
    EditNoticesView({
      runs: this.editNotices,
      onClose: (): void => {
        this.showEditNotices = false;
      },
      onLink: (href: string): void => this.openEditNoticeLink(href)
    })
  }

  // editNoticesControllerUserTapped -> editorDidCancelEditing(navigateToURL:): leave the editor
  // for the link
  private openEditNoticeLink(href: string): void {
    this.showEditNotices = false;
    const url: string = href.startsWith('//') ? 'https:' + href :
      href.startsWith('/') ? 'https://' + this.host + href : href;
    const intent = intentForUri(url);
    router.back();
    if (intent !== null && intent.route !== '') {
      router.pushUrl({ url: intent.route, params: intent.params });
    } else {
      router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: { 'url': url } });
    }
  }

  // the save step: summary and Publish (EditSaveViewController)
  @Builder
  saveSheet() {
    Column({ space: 12 }) {
      TextInput({ text: $$this.editSummary,
        placeholder: $r('app.string.edit_summary_placeholder_text') })
        .id('edit_summary')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .borderRadius(8)
      Button($r('app.string.button_publish'))
        .id('save_publish')
        .width('100%')
        .height(46)
        .enabled(this.canPublish())
        .backgroundColor($r('app.color.theme_link'))
        .onClick(() => {
          this.showSaveSheet = false;
          this.publish();
        })
    }
    .width('100%')
    .padding(16)
  }

  // EditorViewController.setupFocusNavigationView
  @Builder
  findHeader() {
    Row() {
      Text($r('app.string.find_replace_header'))
        .layoutWeight(1)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      Button() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(20)
          .fontColor([$r('app.color.theme_text')])
      }
      .id('find_header_close')
      .type(ButtonType.Normal)
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.editorController.closeFind();
      })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 8 })
  }

  build() {
    Stack() {
    Column() {
      if (this.findActive) {
        this.findHeader()
      } else {
        this.navigationBar()
      }

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(44)
            .height(44)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError !== '') {
        Column() {
          Text($r('app.string.editor_load_failed'))
            .fontSize(17)
            .fontColor($r('app.color.theme_text'))
          Text(this.loadError)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else if (this.mode === 'description') {
        Column() {
          this.descriptionBody()
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Column() {
          this.sectionBody()
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.statusMessage !== '') {
        Text(this.statusMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(Color.Red)
          .padding({ left: 16, right: 16, bottom: 12 })
      }
    }
    .bindSheet($$this.showSaveSheet, this.saveSheet(), { height: SheetSize.FIT_CONTENT, dragBar: true })
    .id('SectionEditorViewController')
    .width('100%')
    .height('100%')
    .padding({ top: topSafeInset() })
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))

      if (this.showIPSheet) {
        this.ipSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
