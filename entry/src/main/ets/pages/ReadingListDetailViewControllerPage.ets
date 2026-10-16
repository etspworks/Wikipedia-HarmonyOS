// screen_reading_list_detail — presentation: page, pushed from screen_reading_lists /
// screen_saved. Wired edge: reading_list_detail -> article.
//
// S3 structure from Wikipedia/Code/ReadingListDetailViewController.swift (+ its
// ReadingListDetailUnderBarViewController and the shared SavedArticlesCollectionView):
//   nav bar   — the back button, the list's own title, and the Sort and Edit bar buttons;
//               Edit swaps the right item for Cancel while editing.
//   searchBar — "Search reading list", filtering the entries in place.
//   under bar — the "<n> ARTICLES" count header for the current list.
//   list      — one comp_article_rt_cell per ReadingListEntry of THIS list; in edit mode each
//               row gains the leading selection control and a batch toolbar
//               (Add to… / Move to… / Remove) appears above the tab bar.
//   tab bar   — comp_root_tab_bar (the detail is pushed inside the Saved tab's stack).
//
// S4: every row, the title and the count come from svc_saved_store (SavedStore.articlesForList
// / entriesForList for THIS list row) — never a literal from the capture. Sort switches
// between title and recently-added order using each entry's createdDate; Remove deletes the
// selected entries through SavedStore.removeArticleFromList, which is the write path backing
// this screen's own list.
// S5: capture base.ui.json (402x874) — nav bar y62..116 with Sort at x250 and Edit at x327,
// the search field [16,117][386,161], the 13pt uppercase "4 ARTICLES" header at y196, and
// 120pt rows with a 20pt title over a 15pt secondary description at x16.
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { WMFArticle } from '../model/WMFArticle';
import { ReadingListEntry } from '../model/ReadingListEntry';
import { SavedStore, ReadingListWithId } from '../common/SavedStore';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { RootTabBar } from '../components/RootTabBar';
import { ArticleRightAlignedImageCollectionViewCell } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { searchFold } from '../common/LocaleText';
import { ENTRY_LIMIT_ERROR } from '../common/ReadingListSyncService';

// ReadingListDetailViewController.importSurveyURLs
const IMPORT_SURVEY_URLS: Record<string, string> = {
  'en': 'https://docs.google.com/forms/d/e/1FAIpQLSf7W1Hs20HcP-Ho4T_Rlr8hdpT4oKxYQJD3rdE5RCINl5l6RQ/viewform?usp=sf_link',
  'ar': 'https://docs.google.com/forms/d/e/1FAIpQLSeKCRBtnF4V1Gwv2aRsJi8GppfofbiECU6XseZbVRbYijynfg/viewform?usp=sf_link',
  'bn': 'https://docs.google.com/forms/d/e/1FAIpQLSeY25GeA8dFOKlVCNpHc5zTUIYUeB3W6fntTitTIQRjl7BCQw/viewform?usp=sf_link',
  'fr': 'https://docs.google.com/forms/d/e/1FAIpQLSe_EXLDJxk-9y0ux-c9LERNou7CqhzoSZfL952PKH8bqCGMpA/viewform?usp=sf_link',
  'de': 'https://docs.google.com/forms/d/e/1FAIpQLSfS2-gQJtCUnFMJl-C0BdrWNxpb-PeXjoDeCR4z80gSCoA-RA/viewform?usp=sf_link',
  'hi': 'https://docs.google.com/forms/d/e/1FAIpQLSdnjiMH4L9eIpwuk3JLdsjKirvQ5GvLwp_8aaLKiESf-zhtHA/viewform?usp=sf_link',
  'pt': 'https://docs.google.com/forms/d/e/1FAIpQLSfbRhbf-cqmZC-vn1S_OTdsJ0zpiVW7vfFpWQgZtzQbU0dZEw/viewform?usp=sf_link',
  'es': 'https://docs.google.com/forms/d/e/1FAIpQLSelTK2ZeuEOk2T9P-E5OeKZoE9VvmCXLx9v3lc-A-onWXSsog/viewform?usp=sf_link',
  'ur': 'https://docs.google.com/forms/d/e/1FAIpQLSdPcGIn049-8g-JgxJ8lFRa8UGg4xcWdL6Na18GuDCUD8iUXA/viewform?usp=sf_link'
};

// The entries of the current reading list.
class ReadingListEntryDataSource implements IDataSource {
  private items: WMFArticle[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): WMFArticle {
    return this.items[index];
  }

  registerDataChangeListener(l: DataChangeListener): void {
    this.listeners.push(l);
  }

  unregisterDataChangeListener(l: DataChangeListener): void {
    const i: number = this.listeners.indexOf(l);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  reload(items: WMFArticle[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Entry
@Component
struct ReadingListDetailViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // spec stateVar: items <- svc_saved_store
  @State items: WMFArticle[] = [];
  // readingList.canonicalName (bindingContract: list name header)
  @State listName: string = '';
  // ReadingListDetailHeaderView: the description and whether the fields can be edited (not
  // on the default list), the fields' working text, and whether one of them is being edited
  @State listDescription: string = '';
  @State isDefaultList: boolean = false;
  @State draftName: string = '';
  @State draftDescription: string = '';
  @State isTextEditing: boolean = false;
  @State searchText: string = '';
  // conditionalVariant: isEditing
  @State isEditing: boolean = false;
  @State selectedKeys: string[] = [];
  // addArticlesToReadingList is presented MODALLY over this page: its view controller is a
  // hosted @Component here (unregistered by design), like every other overlay in this app.
  // ReadingListsSortOrder: 'title' | 'recentlyAdded'
  @State sortOrder: string = 'recentlyAdded';
  @State isLoading: boolean = true;
  // entries the server refused for the list's entry limit (ReadingListEntry alert label)
  @State syncErrorKeys: string[] = [];
  @State loadError: string = '';

  private listRowId: number = 0;
  private createdDates: Map<string, number> = new Map<string, number>();
  private itemsSource: ReadingListEntryDataSource = new ReadingListEntryDataSource();

  // back from the list picker: the counts and entries may have changed
  private shownOnce: boolean = false;

  onPageShow(): void {
    if (this.shownOnce) {
      this.load().catch((e: Error) => {
        console.error('readingListDetail: reload failed: ' + e.message);
      });
    }
    this.shownOnce = true;
  }

  // showImportSharedReadingListSurveyPromptIfNeeded: five seconds after an imported list opens,
  // unless the reader ever chose Take survey, "Could you help us improve \"Share reading
  // lists\"?" with Take survey (the survey for the app language, in the browser) / Not now.
  private fromImport: boolean = false;
  private importSurveyTimer: number = -1;

  private showImportSharedReadingListSurveyPromptIfNeeded(): void {
    if (!this.fromImport || Prefs.getBoolean(PrefKeys.tappedToImportSharedReadingListSurvey, false)) {
      return;
    }
    LanguageStore.appLanguage().then((lang: MWKLanguageLink) => {
      const surveyURL: string = IMPORT_SURVEY_URLS[lang.languageCode] ?? IMPORT_SURVEY_URLS['en'];
      this.importSurveyTimer = setTimeout(() => {
        this.importSurveyTimer = -1;
        this.getUIContext().showAlertDialog({
          title: $r('app.string.import_shared_reading_list_survey_prompt_title'),
          message: $r('app.string.import_shared_reading_list_survey_prompt_subtitle'),
          buttons: [
            { value: $r('app.string.import_shared_reading_list_survey_prompt_button_take_survey'), action: () => {
              Prefs.putBoolean(PrefKeys.tappedToImportSharedReadingListSurvey, true);
              (getContext(this) as common.UIAbilityContext).openLink(surveyURL).catch((e: Error) => {
                console.error('readingListDetail: survey link failed: ' + e.message);
              });
            } },
            { value: $r('app.string.not_now_title'), action: () => {} }
          ]
        });
      }, 5000);
    }).catch((e: Error) => {
      console.error('readingListDetail: app language failed: ' + e.message);
    });
  }

  aboutToDisappear(): void {
    if (this.importSurveyTimer !== -1) {
      clearTimeout(this.importSurveyTimer);
    }
  }

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      const raw: string = params['listRowId'] ?? '';
      if (raw !== '') {
        this.listRowId = parseInt(raw);
      }
      this.fromImport = params['fromImport'] === 'true';
    }
    this.showImportSharedReadingListSurveyPromptIfNeeded();
    Database.init(ctx).then(() => {
      this.load().catch((e: Error) => {
        console.error('readingListDetail: load failed: ' + e.message);
        this.isLoading = false;
      });
    }).catch((e: Error) => {
      console.error('readingListDetail: db init failed: ' + e.message);
      this.loadError = 'Your saved articles could not be opened.';
      this.isLoading = false;
    });
  }

  // readingList + its entries — both from svc_saved_store.
  private async load(): Promise<void> {
    try {
      if (this.listRowId === 0) {
        // ReadingListDetailViewController(for: defaultReadingList) — the Saved list.
        const def: ReadingListWithId = await SavedStore.fetchOrCreateDefaultReadingList();
        this.listRowId = def.listRowId;
        this.listName = def.list.canonicalName ?? '';
        this.isDefaultList = true;
      } else {
        const lists: ReadingListWithId[] = await SavedStore.readingLists();
        for (const l of lists) {
          if (l.listRowId === this.listRowId) {
            this.listName = l.list.canonicalName ?? '';
            this.listDescription = l.list.readingListDescription ?? '';
            this.isDefaultList = l.list.isDefault;
          }
        }
      }
      if (this.isDefaultList) {
        this.listDescription = getContext(this).resourceManager.getStringSync(
          $r('app.string.reading_lists_default_list_description').id);
      }
      if (!this.isTextEditing) {
        this.draftName = this.listName;
        this.draftDescription = this.listDescription;
      }
      const entries: ReadingListEntry[] = await SavedStore.entriesForList(this.listRowId);
      this.createdDates = new Map<string, number>();
      this.syncErrorKeys = [];
      for (const e of entries) {
        if (e.articleKey !== null) {
          this.createdDates.set(e.articleKey, e.createdDate ?? 0);
          if (e.errorCode === ENTRY_LIMIT_ERROR) {
            this.syncErrorKeys.push(e.articleKey);
          }
        }
      }
      this.items = await SavedStore.articlesForList(this.listRowId);
      this.itemsSource.reload(this.visibleItems());
    } catch (e) {
      console.error('readingListDetail: entries failed: ' + this.describeError(e));
      this.loadError = 'Your saved articles could not be loaded.';
    } finally {
      this.isLoading = false;
    }
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // The search bar filters the list in place; the sort order reorders it.
  private visibleItems(): WMFArticle[] {
    const term: string = searchFold(this.searchText.trim());
    const out: WMFArticle[] = [];
    for (const a of this.items) {
      const title: string = a.displayTitle ?? '';
      if (term === '' || searchFold(title).indexOf(term) >= 0) {
        out.push(a);
      }
    }
    if (this.sortOrder === 'title') {
      out.sort((x: WMFArticle, y: WMFArticle) =>
        (x.displayTitle ?? '').localeCompare(y.displayTitle ?? ''));
    } else {
      out.sort((x: WMFArticle, y: WMFArticle) =>
        this.createdDateOf(y) - this.createdDateOf(x));
    }
    return out;
  }

  private createdDateOf(a: WMFArticle): number {
    const key: string | null = a.key;
    if (key === null) {
      return 0;
    }
    const d: number | undefined = this.createdDates.get(key);
    return d === undefined ? 0 : d;
  }

  private refreshVisible(): void {
    this.itemsSource.reload(this.visibleItems());
  }

  private isSelected(a: WMFArticle): boolean {
    return a.key !== null && this.selectedKeys.indexOf(a.key) >= 0;
  }

  private toggleSelection(a: WMFArticle): void {
    const key: string | null = a.key;
    if (key === null) {
      return;
    }
    const i: number = this.selectedKeys.indexOf(key);
    const next: string[] = this.selectedKeys.slice();
    if (i >= 0) {
      next.splice(i, 1);
    } else {
      next.push(key);
    }
    this.selectedKeys = next;
  }

  // removeSelectedArticles -> ReadingListsController.remove(entries:)
  private removeSelected(): void {
    const keys: string[] = this.selectedKeys.slice();
    if (keys.length === 0) {
      return;
    }
    this.removeKeys(keys).catch((e: Error) => {
      console.error('readingListDetail: remove failed: ' + e.message);
    });
  }

  private async removeKeys(keys: string[]): Promise<void> {
    for (const key of keys) {
      await SavedStore.removeArticleFromList(this.listRowId, key);
    }
    this.selectedKeys = [];
    this.isEditing = false;
    await this.load();
  }

  // addArticlesToReadingList / moveArticlesToReadingList
  // a routed page: as a content cover the picker's lists never drew
  private openAddToReadingList(move: boolean): void {
    if (this.selectedKeys.length === 0) {
      return;
    }
    const params: Record<string, string> = { 'articleKeys': JSON.stringify(this.selectedKeys) };
    // Move to…: the picker takes the articles out of this list after adding them elsewhere
    // (it used to run the same code as Add to…, so nothing ever left the list)
    if (move) {
      params['moveFromListId'] = String(this.listRowId);
    }
    this.selectedKeys = [];
    this.isEditing = false;
    router.pushUrl({ url: 'pages/AddArticlesToReadingListViewControllerPage', params: params });
  }






  private openArticle(a: WMFArticle): void {
    const articleTitle: string = a.displayTitle ?? '';
    const params: Record<string, string> = { 'articleTitle': articleTitle, 'articleKey': a.key ?? '' };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  private sortMenu(): MenuElement[] {
    return [
      {
        value: 'Title',
        action: (): void => {
          this.sortOrder = 'title';
          this.refreshVisible();
        }
      },
      {
        value: 'Recently added',
        action: (): void => {
          this.sortOrder = 'recentlyAdded';
          this.refreshVisible();
        }
      }
    ];
  }

  // readingListDetailHeaderView(_:didEdit:description:): updateReadingList, then the
  // navigation title follows the new name.
  private finishTextEditing(): void {
    const name: string = this.draftName.trim() !== '' ? this.draftName : this.listName;
    const description: string = this.draftDescription;
    this.isTextEditing = false;
    this.getUIContext().getFocusController().clearFocus();
    SavedStore.updateReadingList(this.listRowId, name, description).then(() => {
      this.listName = name;
      this.listDescription = description;
    }).catch((e: Error) => {
      console.error('readingListDetail: rename failed: ' + e.message);
    });
  }

  // cancelEditing: the fields go back to the stored name and description
  private cancelTextEditing(): void {
    this.draftName = this.listName;
    this.draftDescription = this.listDescription;
    this.isTextEditing = false;
    this.getUIContext().getFocusController().clearFocus();
  }

  private countHeader(): string {
    const n: number = this.items.length;
    return String(n) + (n === 1 ? ' ARTICLE' : ' ARTICLES');
  }

  build() {
    Column() {
      // WMFNavigationBar: back button, the list title, Sort and Edit/Cancel.
      Stack() {
        Row() {
          if (this.isTextEditing) {
            // the header's text editing: Cancel restores the fields
            Button($r('app.string.cancel'))
              .id('cancel_text_edit')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .height(44)
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.cancelTextEditing();
              })
          } else {
          Button($r('app.string.saved_title'))
            .id('BackButton')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .height(44)
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
            .onClick(() => {
              router.back();
            })
          }
          Blank()
          if (this.isTextEditing) {
            // Done saves the fields
            Button($r('app.string.notifications_center_done'))
              .id('done_text_edit')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .height(36)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_link'))
              // titleTextFieldTextDidChange: Done needs a non-blank name
              .enabled(this.draftName.trim() !== '')
              .opacity(this.draftName.trim() !== '' ? 1 : 0.4)
              .onClick(() => {
                this.finishTextEditing();
              })
          } else if (!this.isEditing) {
            Button('Sort')
              .id('sort')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .height(36)
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .bindMenu(this.sortMenu())
            Button('Edit')
              .id('edit')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .height(36)
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .margin({ left: 20 })
              .onClick(() => {
                this.isEditing = true;
              })
          } else {
            Button($r('app.string.cancel'))
              .id('cancel_edit')
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .height(36)
              .fontSize(17)
              .fontColor($r('app.color.theme_link'))
              .onClick(() => {
                this.isEditing = false;
                this.selectedKeys = [];
              })
          }
        }
        .width('100%')

        // bindingContract: list name header <- ReadingList.canonicalName
        Text(this.listName)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })

      // searchBar
      Row() {
        Image($r('app.media.search'))
          .width(20)
          .height(19)
          .objectFit(ImageFit.Contain)
        TextInput({ text: this.searchText, placeholder: 'Search reading list' })
          .id('Search Field')
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .fontSize(17)
          .placeholderColor($r('app.color.theme_secondary_text'))
          .onChange((value: string) => {
            this.searchText = value;
            this.refreshVisible();
          })
      }
      .width('100%')
      .height(44)
      .margin({ top: 15, left: 16, right: 16 })
      .padding({ left: 12, right: 12 })
      .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
      .borderRadius(10)
      .alignItems(VerticalAlign.Center)

      // ReadingListDetailHeaderView: articleCountLabel, then titleTextField (boldTitle1) and
      // descriptionTextField (footnote, secondary), editable unless this is the default list.
      Text(this.countHeader())
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .padding({ left: 20, right: 20, top: 20, bottom: 6 })
      TextInput({ text: this.draftName })
        .id('reading_list_title_field')
        .enabled(!this.isDefaultList)
        .width('100%')
        .height(44)
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .enterKeyType(EnterKeyType.Done)
        .onFocus(() => {
          this.isTextEditing = true;
        })
        .onChange((v: string) => {
          this.draftName = v;
        })
        .onSubmit(() => {
          if (this.draftName.trim() !== '') {
            this.finishTextEditing();
          }
        })
      TextInput({ text: this.draftDescription })
        .id('reading_list_description_field')
        .enabled(!this.isDefaultList)
        .width('100%')
        .height(32)
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .enterKeyType(EnterKeyType.Done)
        .onFocus(() => {
          this.isTextEditing = true;
        })
        .onChange((v: string) => {
          this.draftDescription = v;
        })
        .onSubmit(() => {
          this.finishTextEditing();
        })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('reading_list_detail_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          Text(this.loadError !== '' ? this.loadError : 'No saved articles in this list yet.')
            .fontSize(17)
            .lineHeight(24)
            .textAlign(TextAlign.Center)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 32, right: 32 })
        }
        .id('reading_list_detail_empty')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          LazyForEach(this.itemsSource, (item: WMFArticle) => {
            ListItem() {
              Row() {
                if (this.isEditing) {
                  // Batch-selection control, 56pt leading gutter in the capture.
                  // system symbols in theme colours: the bitmaps were white on the white row
                  SymbolGlyph(this.isSelected(item)
                    ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
                    .fontSize(24)
                    .fontColor([this.isSelected(item) ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text')])
                    .margin({ left: 16, right: 16 })
                }
                Column() {
                  ArticleRightAlignedImageCollectionViewCell({
                    title: item.displayTitle ?? '',
                    description: item.wikidataDescription ?? '',
                    imageURL: item.imageURLString ?? '',
                    showSaveButton: false,
                    rowId: 'reading_list_entry_itemroot',
                    onTap: (): void => {
                      if (this.isEditing) {
                        this.toggleSelection(item);
                      } else {
                        this.openArticle(item);
                      }
                    }
                  })
                  if (this.syncErrorKeys.includes(item.key ?? '')) {
                    Text($r('app.string.reading_lists_article_not_synced_article_limit_exceeded'))
                      .fontSize(12)
                      .fontColor($r('app.color.theme_warning'))
                      .padding({ left: 16, right: 16, bottom: 8 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }, (item: WMFArticle, index: number) => (item.key ?? '') + '_' + index)
        }
        .width('100%')
        .layoutWeight(1)
      }

      // Edit-mode batch toolbar (conditionalVariant: isEditing).
      if (this.isEditing) {
        Row() {
          Button($r('app.string.action_add_to'))
            .id('add_to')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .height(30)
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .opacity(this.selectedKeys.length > 0 ? 1 : 0.4)
            .onClick(() => {
              this.openAddToReadingList(false);
            })
          Button($r('app.string.action_move_to'))
            .id('move_to')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .height(30)
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .opacity(this.selectedKeys.length > 0 ? 1 : 0.4)
            .onClick(() => {
              this.openAddToReadingList(true);
            })
          Button($r('app.string.action_remove'))
            .id('remove')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .height(30)
            .fontSize(15)
            .fontColor($r('app.color.theme_destructive'))
            .opacity(this.selectedKeys.length > 0 ? 1 : 0.4)
            .onClick(() => {
              this.removeSelected();
            })
        }
        .width('100%')
        .height(30)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      }

      RootTabBar({ selected: 2 })
    }
    .id('ReadingListDetailViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
