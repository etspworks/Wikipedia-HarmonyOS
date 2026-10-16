// screen_create_reading_list — presentation: modal, hosted by
// ReadingListsViewControllerPage (.bindContentCover) and by the add-articles flow in
// ArticleViewControllerPage. NOT a routed page.
// S3 structure from Wikipedia/Code/CreateReadingListViewController.swift (viewDidLoad +
// CreateReadingListViewController.xib outlets, confirmed by capture S0328):
//   configureNavigationBar(): centerCompact title CommonStrings.createNewListTitle
//     ("Create a new list") + a leading plain-X close button (closeButtonTapped).
//   the scroll view's form: readingListNameLabel ("Reading list name") over
//     readingListNameTextField (placeholder "reading list title") with
//     readingListNameErrorLabel beneath it (hidden until handleReadingListNameError),
//     descriptionLabel ("Description") over descriptionTextField (placeholder
//     "optional short description"), then createReadingListButton ("Create reading list"),
//     which starts DISABLED and is enabled by textFieldDidChange when the name field holds
//     non-whitespace text and no name error is showing — the source's own condition.
//   importLoadingView + importSpinner: shown only in importing mode (encodedPageIds).
// The insert into svc_saved_store and the host dismiss are S4's pass.
// S5/S6 style (capture S0328 + S0324, 402x874pt): presented as a white page-sheet whose
// rounded top starts at y=62 over the dimmed host; the form is inset 57pt each side — the
// XIB's Caption1 (12pt) gray label over a 14pt system underlined field (1pt #72777D rule),
// then the 40pt capsule "Create reading list", DISABLED in the capture (#EAECF0 fill, gray
// label). The 54pt bar carries the plain-X at x20 (36x36) and the centered 17pt title, per
// S0324 — the state the app's own create_a_new_list tap produces.
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { HttpClient } from '../common/HttpClient';
import { rootTabAt } from '../components/RootTabBar';


import { Database } from '../common/Database';
import { SavedStore, ReadingListWithId } from '../common/SavedStore';

// WMFAppTabType.saved
const SAVED_TAB_INDEX: number = 2;

// ImportedReadingList (base64 JSON in the limport link)
interface ImportedReadingList {
  name?: string;
  description?: string;
  list?: Record<string, number[]>;
}

interface PageIdsPage {
  pageid?: number;
  title?: string;
  missing?: boolean;
}

interface PageIdsQuery {
  pages?: PageIdsPage[];
}

interface PageIdsResponse {
  query?: PageIdsQuery;
}
@Component
export struct CreateReadingListView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // readingListNameTextField.text
  @State listName: string = '';
  // descriptionTextField.text
  @State listDescription: string = '';
  // readingListNameErrorLabel — hidden while empty (hideReadingListError). The host raises
  // it from handleReadingListNameError(_:), so it is a @Prop, not a local @State; typing in
  // the name field still clears it locally exactly as textFieldDidChange does.
  @Prop nameError: string = '';
  // isInImportingMode -> importLoadingView with importSpinner
  @Prop isImporting: boolean = false;
  // isInImportingMode: the "Import shared reading list" title
  @Prop isImportMode: boolean = false;
  // the imported list's default name ("My Reading List"), filled in once the articles load
  @Prop @Watch('applyImportedName') importedName: string = '';
  // a failed import leaves the form disabled (readingListNameTextField.isEnabled = false)
  @Prop importFailed: boolean = false;

  applyImportedName(): void {
    if (this.importedName !== '' && this.listName === '') {
      this.listName = this.importedName;
    }
  }
  // delegate.createReadingListViewController(_:didCreateReadingListWith:description:articles:)
  onCreate?: (name: string, description: string) => void;
  // closeButtonTapped(_:) -> navigationController?.dismiss(animated:)
  onClose?: () => void;

  // shouldEnableCreateReadingListButton: a non-empty name and no name error.
  private canCreate(): boolean {
    return this.listName.trim() !== '' && this.nameError === '' && !this.isImporting && !this.importFailed;
  }

  build() {
    // the cover fills the window; the sheet itself starts 62pt down over the dimmed host
    Column() {
      Column() {
        // WMFNavigationBar: leading plain-X close, centerCompact title. Capture S0324 sizes
        // it — a 54pt bar with no background of its own, the 36x36 close at x20 and the
        // centered 17pt title.
        Stack() {
          Row() {
            Button() {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(20)
                .fontColor([$r('app.color.theme_text')])
            }
            // Id scoping: this screen is an overlay, so its nodes share the host page's
            // component tree. The source slug is the part after the dot: close_button.
            .id('CreateReadingListViewController.close_button')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(36)
            .height(36)
            .onClick(() => {
              this.closeButtonTapped();
            })
            Blank()
          }
          .width('100%')
          .padding({ left: 20 })

          Text(this.isImportMode ? $r('app.string.import_shared_reading_list_title')
            : $r('app.string.reading_list_create_new_list_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.theme_text'))
        }
        .width('100%')
        .height(54)

        if (this.isImporting) {
          // importLoadingView + importSpinner
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              // readingListNameLabel
              Text($r('app.string.reading_list_create_new_list_reading_list_name'))
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.theme_secondary_text'))
              // readingListNameTextField
              TextInput({ placeholder: $r('app.string.reading_list_new_list_name_placeholder'), text: this.listName })
                .id('readingListNameTextField')
                // The keyboard's uncommitted word is preview text, which onChange leaves out: a
                // typed name stayed '' until committed and 'Create' never enabled.
                .enablePreviewText(false)
                // the ReadingLists API keeps names in a 255-wide column; longer ones would never sync
                .maxLength(255)
                // ThemeableTextField: a clear button while there is text
                .cancelButton({ style: CancelButtonStyle.INPUT })
                .width('100%')
                .height(28)
                .fontSize(14)
                .fontColor($r('app.color.theme_text'))
                .placeholderColor($r('app.color.theme_secondary_text'))
                .placeholderFont({ size: 14 })
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .margin({ top: 5 })
                .onChange((value: string) => {
                  this.textFieldDidChange(value);
                })
                // the source's returnKeyType .next: the key reads "İleri" and moves to the
                // description field instead of closing the keyboard
                .enterKeyType(EnterKeyType.Next)
                .onSubmit((key: EnterKeyType, event: SubmitEvent) => {
                  event.keepEditableState();
                  this.getUIContext().getFocusController().requestFocus('descriptionTextField');
                })
              Divider()
                .width('100%')
                .strokeWidth(1)
                .color($r('app.color.theme_secondary_text'))
              // readingListNameErrorLabel
              if (this.nameError !== '') {
                Text(this.nameError)
                  .width('100%')
                  .fontSize(12)
                  .fontColor($r('app.color.theme_destructive'))
                  .margin({ top: 4 })
              }

              // descriptionLabel
              Text($r('app.string.reading_list_create_new_list_description'))
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.theme_secondary_text'))
                .margin({ top: 25 })
              // descriptionTextField
              TextInput({ placeholder: $r('app.string.reading_list_new_list_description_placeholder'), text: this.listDescription })
                .id('descriptionTextField')
                // The keyboard's uncommitted word is preview text, which onChange leaves out: a
                // typed name stayed '' until committed and 'Create' never enabled.
                .enablePreviewText(false)
                .cancelButton({ style: CancelButtonStyle.INPUT })
                .width('100%')
                .height(28)
                .fontSize(14)
                .fontColor($r('app.color.theme_text'))
                .placeholderColor($r('app.color.theme_secondary_text'))
                .placeholderFont({ size: 14 })
                .caretColor($r('app.color.theme_link'))
                .backgroundColor(Color.Transparent)
                .borderRadius(0)
                .padding({ left: 0, right: 0, top: 0, bottom: 0 })
                .onChange((value: string) => {
                  this.listDescription = value;
                })
              Divider()
                .width('100%')
                .strokeWidth(1)
                .color($r('app.color.theme_secondary_text'))

              // createReadingListButton (WMFAuthButton) — enabled: theme_link capsule with a
              // white label; disabled (the captured state): #EAECF0 fill, gray label.
              Button($r('app.string.reading_list_create_new_list_button_title'))
                .id('createReadingListButton')
                .type(ButtonType.Capsule)
                .width('100%')
                .height(40)
                .fontSize(17)
                .fontColor(this.canCreate() ? $r('app.color.wmf_white') : $r('app.color.gray400'))
                .backgroundColor(this.canCreate()
                  ? $r('app.color.theme_link') : $r('app.color.gray200'))
                .margin({ top: 30 })
                .enabled(this.canCreate())
                .onClick(() => {
                  this.createReadingListButtonPressed();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 57, right: 57, top: 16, bottom: 24 })
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
      }
      .id('CreateReadingListViewController')
      .width('100%')
      .layoutWeight(1)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius({ topLeft: 20, topRight: 20 })
      .clip(true)
      .margin({ top: 62 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#33000000')
  }

  // textFieldDidChange(_:) — typing in the name field clears the name error.
  private textFieldDidChange(value: string): void {
    this.listName = value;
    this.nameError = '';
  }

  // createReadingListButtonPressed() — trims both fields and hands them to the delegate.
  private createReadingListButtonPressed(): void {
    if (!this.canCreate()) {
      return;
    }
    const cb: ((name: string, description: string) => void) | undefined = this.onCreate;
    if (cb !== undefined) {
      cb(this.listName.trim(), this.listDescription.trim());
    }
  }

  private closeButtonTapped(): void {
    const cb: (() => void) | undefined = this.onClose;
    if (cb !== undefined) {
      cb();
    }
  }
}

// Routed host. Inside a .bindContentCover the view's own @State (the typed name) never
// redrew - the field changed but 'Create' stayed disabled - and the article's create cover
// passed no callbacks at all, so neither Create nor X did anything. As a page it redraws
// normally. Params: articleKey / articleTitle (optional) - the article the list is created
// for, added to it once it exists (createReadingListViewController(_:didCreate...:articles:)).
@Entry
@Component
struct CreateReadingListPage {
  @State nameError: string = '';
  private articleKey: string = '';
  private articleTitle: string = '';
  // the Saved / list edit bars hand over several articles, and a move names the list they leave
  private articleKeys: string[] = [];
  private moveFromListId: number = 0;
  // CreateReadingListViewController(encodedPageIds:) — a shared list being imported
  private encodedPageIds: string = '';
  @State isImporting: boolean = false;
  @State importFailed: boolean = false;
  @State importedName: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string> | undefined;
    if (p !== undefined && p !== null) {
      this.articleKey = p['articleKey'] ?? '';
      this.articleTitle = p['articleTitle'] ?? '';
      try {
        this.articleKeys = JSON.parse(p['articleKeys'] ?? '[]') as string[];
      } catch (e) {
        this.articleKeys = [];
      }
      this.moveFromListId = parseInt(p['moveFromListId'] ?? '0') || 0;
      this.encodedPageIds = decodeURIComponent(p['encodedPageIds'] ?? '');
    }
    if (this.encodedPageIds !== '') {
      this.isImporting = true;
      this.articlesFromEncodedPageIds(this.encodedPageIds).then((keys: string[]) => {
        this.articleKeys = keys;
        this.isImporting = false;
        this.importedName = getContext(this).resourceManager.getStringSync(
          $r('app.string.import_shared_reading_list_default_title').id);
      }).catch((e: Error) => {
        console.error('createReadingList: import failed: ' + e.message);
        this.isImporting = false;
        this.importFailed = true;
        promptAction.showToast({ message: getContext(this).resourceManager.getStringSync(
          $r('app.string.fetcher_error_generic').id) });
      });
    }
  }

  // articlesFromEncodedPageIds: the payload is base64 JSON {"list": {"en": [pageIds], ...}}; each
  // wiki's page ids are turned into titles (pageURLsFromImportedReadingList) and article keys.
  private async articlesFromEncodedPageIds(encoded: string): Promise<string[]> {
    const json: string = new util.TextDecoder().decodeToString(
      new util.Base64Helper().decodeSync(encoded));
    const imported: ImportedReadingList = JSON.parse(json) as ImportedReadingList;
    const keys: string[] = [];
    for (const entry of Object.entries(imported.list ?? {})) {
      const host: string = entry[0] + '.wikipedia.org';
      const ids: number[] = entry[1] as number[];
      const url: string = HttpClient.buildURL('https://' + host + '/w/api.php',
        { 'action': 'query', 'pageids': ids.join('|'), 'format': 'json', 'formatversion': '2' });
      const resp: PageIdsResponse = await HttpClient.getJson<PageIdsResponse>(url);
      for (const page of resp.query?.pages ?? []) {
        if (page.title !== undefined && page.missing !== true) {
          keys.push('https://' + host + '/wiki/' + encodeURIComponent(page.title.replace(/ /g, '_')));
        }
      }
    }
    if (keys.length === 0) {
      throw new Error('failureFetchingPageURLs');
    }
    return keys;
  }

  private async create(name: string, description: string): Promise<void> {
    this.nameError = '';
    await Database.init(getContext(this) as common.UIAbilityContext);
    const created: ReadingListWithId =
      await SavedStore.createReadingList(name, description !== '' ? description : null);
    if (this.articleKey !== '') {
      await SavedStore.addArticleToList(created.listRowId, this.articleKey, null, this.articleTitle);
    }
    // A batch from an edit bar used to arrive without its articles, so the new list stayed empty.
    for (const k of this.articleKeys) {
      await SavedStore.addArticleToList(created.listRowId, k, null,
        decodeURIComponent(k.split('/wiki/')[1] ?? '').replace(/_/g, ' '));
      if (this.moveFromListId !== 0) {
        await SavedStore.removeArticleFromList(this.moveFromListId, k);
      }
    }
    if (this.encodedPageIds !== '') {
      // showImportedReadingList: the Saved tab, with the new list pushed on it as an import (its
      // survey prompt)
      await router.replaceUrl({ url: rootTabAt(SAVED_TAB_INDEX).url });
      router.pushUrl({ url: 'pages/ReadingListDetailViewControllerPage',
        params: { 'listRowId': String(created.listRowId), 'fromImport': 'true' } });
      return;
    }
    router.back();
  }

  build() {
    Column() {
      CreateReadingListView({
        nameError: this.nameError,
        isImportMode: this.encodedPageIds !== '',
        isImporting: this.isImporting,
        importFailed: this.importFailed,
        importedName: this.importedName,
        onClose: (): void => {
          router.back();
        },
        onCreate: (name: string, description: string): void => {
          this.create(name, description).catch((e: Error) => {
            this.nameError = e.message === 'listExistsWithTheSameName'
              ? getContext(this).resourceManager.getStringSync($r('app.string.reading_list_exists_with_same_name'))
              : e.message;
          });
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
