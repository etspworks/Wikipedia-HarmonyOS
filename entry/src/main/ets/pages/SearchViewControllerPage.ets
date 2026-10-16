// screen_search — presentation: page (Search root tab).
// Ported from Wikipedia/Code/SearchViewController.swift + its two embedded children:
//   * SearchResultsViewController (the search-results container; swaps between the
//     recently-searched list and the results list, and owns the language bar), and
//   * SearchLanguagesBarViewController (comp_search_bar).
// Source view tree (SearchViewController.viewDidLoad / configureNavigationBar):
//   nav bar: title "Search", deleteButton ("Clear", leading of the tabs button and only
//            while search is inactive), tabsButtonConfig ("Tabs Button"),
//            profileButtonConfig ("profile-button"), and the UISearchController search bar
//            ("Search Field", placeholder CommonStrings.searchBarPlaceholder).
//   body:    historyViewController (WMFHistoryView) embedded as the always-present
//            background (embedHistoryIfNeeded), hidden while the search controller is
//            active; the search controller then shows searchResultsVC, which renders
//            WMFRecentlySearchedView while the term is empty and the results collection
//            (ArticleRightAlignedImageCollectionViewCell rows, SearchResultsListViewController)
//            once a term is typed. Language bar sits above that content.
//   tab bar: comp_root_tab_bar (WMFAppViewController), Search = index 4.
// S3: structure only — colors/typography/spacing in S5.
import { UnreadNotificationsDot } from '../components/UnreadNotificationsDot';
import { router, KeyboardAvoidMode, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Database } from '../common/Database';
import { SearchLanguagesBarViewController } from '../components/SearchLanguagesBarViewController';
import { ArticleRightAlignedImageCollectionViewCell } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { RootTabBar, isRootTabSwitch, ROOT_TITLE_FONT_SIZE } from '../components/RootTabBar';
import { EmptyViewController } from '../components/EmptyViewController';
import { WMFProfileViewSheet } from './WMFProfileViewPage';
import { WMFArticleTabsView } from './WMFArticleTabsViewPage';
import { MWKSearchResult } from '../model/MWKSearchResult';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { HistorySection, HistoryItem, HistoryStore } from '../common/HistoryStore';
import { RecentSearchEntry, RecentSearchStore } from '../common/RecentSearchStore';
import { SearchService, WMFSearchResults } from '../common/SearchService';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs, PrefKeys, WMFDataPrefKeys } from '../common/Prefs';
import { NAV_ICON_BUTTON, NAV_TEXT_BUTTON, NAV_BUTTON_GAP, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE, ROOT_BAR_HEIGHT } from '../components/NavButton';
import { advertiseActivity, resignActivity } from '../common/Continuation';

// wmf_searchViewActivity
const SEARCH_ACTIVITY_URI: string = 'wikipedia://search';

// prefix_search / full_text_search results — paginated (WMFMaxSearchResultLimit + full-text
// append), so the collection is lazy.
class SearchResultDataSource implements IDataSource {
  private items: MWKSearchResult[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): MWKSearchResult {
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

  reload(items: MWKSearchResult[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// recordsProvider fetches up to 1000 history records, grouped per day by
// viewedDateWithoutTime — the day sections are the lazy axis.
class HistorySectionDataSource implements IDataSource {
  private sections: HistorySection[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.sections.length;
  }

  getData(index: number): HistorySection {
    return this.sections[index];
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

  reload(sections: HistorySection[]): void {
    this.sections = sections;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

// The search API's displayTitle is HTML: italics and <span class="searchmatch"> highlights.
// The row renders plain text, so the markup has to come off first.
function stripSearchMarkup(html: string): string {
  return html.replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, '\'')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .trim();
}

@Entry
@Component
export struct SearchViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // spec stateVars
  @State searchTerm: string = '';
  @State results: MWKSearchResult[] = [];
  @State recentSearches: RecentSearchEntry[] = [];
  // SearchViewController.isSearchActive (willPresent/didDismissSearchController)
  @State isSearchActive: boolean = false;
  // historyViewModel.sections — the body behind the search controller
  @State historySections: HistorySection[] = [];
  // languageBarLanguages() + selectedSearchContentLanguageCode (comp_search_bar)
  @State languages: MWKLanguageLink[] = [];
  @State selectedLanguageCode: string = '';
  // deleteButtonPressed — "Are you sure you want to delete all your recent items?"
  // profileCoordinator (sheet) / tabsCoordinator (full-screen cover)
  @State showProfileSheet: boolean = false;
  @State showTabsCover: boolean = false;
  // openLanguagePicker() presents WMFPreferredLanguagesViewController modally (overFullScreen)
  // S6: the visual states of feat_search that S4 already wired — the fetch is in flight
  // (WMFSearchFetcher task running) and the fetch failed (failure(error, .prefix), which the
  // source surfaces through WMFAlertManager rather than the empty view).
  @State isSearching: boolean = false;
  @State searchError: string = '';
  // true until the first loadHistory() resolves — lets historyBody() tell "still
  // loading" apart from "genuinely empty" on a cold launch.
  @State isHistoryLoading: boolean = true;
  // A history read that FAILS must not look like "no history" — round 5 of this screen's fix
  // loop was spent on exactly that mistake, because the only trace was a console.error the
  // device never emits. Non-empty = the last fetch threw; shown in the body's error slot.
  @State historyError: string = '';
  // resolves once Database.init has completed; every store read awaits it.
  private dbReady: Promise<void> | null = null;
  private resultsSource: SearchResultDataSource = new SearchResultDataSource();
  private historySource: HistorySectionDataSource = new HistorySectionDataSource();
  // updateSearchResults(for:) — searchTask + `try? await Task.sleep(for: .milliseconds(100))`
  private searchTimer: number = -1;
  // lastSearchSiteURL / searchTerm — the source skips a refetch when neither changed.
  private lastSearchTerm: string = '';
  private lastSearchHost: string = '';
  // the prefix-search fallback (fullTextSearch appendToPreviousResults) already ran
  // Settings > Ara > "Aramada dilleri göster" (showSearchLanguageBar); it used to be written
  // there and read nowhere, so the bar always showed.
  @State showLanguageBar: boolean = true;
  private didAppendFullText: boolean = false;
  // While the keyboard is up the tab bar stays behind it, as on the source: with RESIZE the
  // page shrank above the keyboard and carried the tab bar up with it, eating the results.
  @State keyboardUp: boolean = false;
  private keyboardWindow: window.Window | null = null;
  private keyboardListener: Callback<number> = (height: number): void => {
    this.keyboardUp = height > 0;
  };

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // The search field sits at the foot of this screen, so the default keyboard behaviour —
    // translating the whole page up — pushed the results list off the top of the screen and
    // the first, most relevant result with it. RESIZE shrinks the page instead, which keeps
    // the list anchored under the title.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    window.getLastWindow(ctx).then((w: window.Window): void => {
      this.keyboardWindow = w;
      w.on('keyboardHeightChange', this.keyboardListener);
    }).catch((e: Error) => {
      console.warn('search: keyboard height unavailable: ' + e.message);
    });
    Prefs.init(ctx);
    // viewDidAppear: NSUserActivity.wmf_makeActive(wmf_searchView())
    advertiseActivity(ctx, SEARCH_ACTIVITY_URI);
    this.showLanguageBar = Prefs.getBoolean(WMFDataPrefKeys.showSearchLanguageBar, true);
    this.resultsSource.reload(this.results);
    this.historySource.reload(this.historySections);
    // reloadRecentSearches — dataStore.recentSearchList.entries (preferences)
    this.recentSearches = RecentSearchStore.entries();
    this.bootstrap(ctx).catch((e: Error) => {
      console.error('search: bootstrap failed: ' + e.message);
    });
  }

  // viewWillAppear(_:) — the source re-runs the history fetch every time the screen comes
  // back, not only when it is built. router.back() from the article does NOT re-run
  // aboutToAppear, so without this the read-history row the article just wrote is never
  // shown and the list stays as empty as it was at construction.
  onPageShow(): void {
    this.showLanguageBar = Prefs.getBoolean(WMFDataPrefKeys.showSearchLanguageBar, true);
    this.recentSearches = RecentSearchStore.entries();
    this.reloadHistory().catch((e: Error) => {
      console.error('search: history reload failed: ' + e.message);
    });
    this.reloadLanguages().catch((e: Error) => {
      console.error('search: language reload failed: ' + e.message);
    });
  }

  // preferredLanguagesDidChange -> updateSearchLanguageButtons, and the More picker's
  // didSelectLanguage -> selectedSearchContentLanguageCode, which re-runs the search.
  private async reloadLanguages(): Promise<void> {
    const ready: Promise<void> | null = this.dbReady;
    if (ready === null) {
      return;
    }
    await ready;
    const before: string = this.selectedLanguageCode;
    await this.loadLanguages();
    if (this.selectedLanguageCode !== before && this.searchTerm.trim().length > 0) {
      await this.runSearch(this.searchTerm);
    }
  }

  // Database.init MUST finish before anything reads the store — but once it has,
  // history (this page's PRIMARY content) must not sit behind the language bar or
  // any other secondary bootstrap step. Start it first and let loadLanguages() run
  // alongside, not before it, so the first history render is not delayed by an
  // unrelated fetch.
  private async bootstrap(ctx: common.UIAbilityContext): Promise<void> {
    const ready: Promise<void> = Database.init(ctx);
    this.dbReady = ready;
    await ready;
    const historyTask: Promise<void> = this.loadHistory();
    this.loadLanguages().catch((e: Error) => {
      console.error('search: language bootstrap failed: ' + e.message);
    });
    await historyTask;
  }

  private async reloadHistory(): Promise<void> {
    const ready: Promise<void> | null = this.dbReady;
    if (ready === null) {
      return;
    }
    await ready;
    await this.loadHistory();
  }

  aboutToDisappear(): void {
    resignActivity(getContext(this) as common.UIAbilityContext, SEARCH_ACTIVITY_URI);
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    if (this.keyboardWindow !== null) {
      this.keyboardWindow.off('keyboardHeightChange', this.keyboardListener);
      this.keyboardWindow = null;
    }
  }

  // languageBarLanguages() = languageLinkController.preferredLanguages;
  // selectedSearchContentLanguageCode = wmf_currentSearchContentLanguageCode ?? appLanguage.
  private async loadLanguages(): Promise<void> {
    try {
      this.languages = await LanguageStore.preferredLanguages();
      const stored: string = Prefs.getString(PrefKeys.searchLanguage, '');
      if (stored !== '') {
        this.selectedLanguageCode = stored;
      } else {
        const app: MWKLanguageLink = await LanguageStore.appLanguage();
        this.selectedLanguageCode = app.contentLanguageCode;
      }
    } catch (e) {
      console.error('search: language bar unavailable: ' + this.describeError(e));
    }
  }

  // historyDataController.recordsProvider — WMFArticle rows with a viewedDate.
  private async loadHistory(): Promise<void> {
    try {
      this.historySections = await HistoryStore.fetchHistorySections();
      this.historySource.reload(this.historySections);
      this.historyError = '';
    } catch (e) {
      const message: string = this.describeError(e);
      console.error('search: history unavailable: ' + message);
      this.historyError = message;
    } finally {
      this.isHistoryLoading = false;
    }
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // siteURL — selectedSiteURL of the language bar, else the app language wiki.
  private searchHost(): string {
    const code: string = this.selectedLanguageCode !== '' ? this.selectedLanguageCode : 'en';
    return code + '.wikipedia.org';
  }

  private siteURL(): string {
    return 'https://' + this.searchHost();
  }

  // search(for:suggested:) — prefix search, then the full-text fallback when the prefix
  // search came back with fewer than 12 rows (WMFSearchFetcher appendToPreviousResults).
  private async runSearch(term: string): Promise<void> {
    const host: string = this.searchHost();
    this.lastSearchTerm = term;
    this.lastSearchHost = host;
    this.didAppendFullText = false;
    this.isSearching = true;
    this.searchError = '';
    try {
      const prefix: WMFSearchResults =
        await SearchService.prefixSearch(host, term, SearchService.maxResultLimit);
      if (this.searchTerm !== term) {
        return;      // a newer keystroke already owns the field
      }
      this.results = prefix.results;
      this.resultsSource.reload(this.results);
      this.isSearching = false;
      if (prefix.results.length < 12) {
        await this.appendFullTextResults(host, term);
      }
    } catch (e) {
      if (this.searchTerm === term) {
        // failure(error, .prefix) — emptyViewType .noSearchResults, results cleared
        this.results = [];
        this.resultsSource.reload(this.results);
        this.searchError = this.describeError(e);
      }
      console.error('search: prefix search failed: ' + this.describeError(e));
    } finally {
      if (this.searchTerm === term) {
        this.isSearching = false;
      }
    }
  }

  // S6 empty/error copy: WMFEmptyView noSearchResultsEmptyView carries only its message
  // label; a failed fetch is the source's alert text, shown in the same slot here.
  private searchEmptyMessage(): string {
    if (this.searchError !== '') {
      return 'The app failed to search. Please check your connection and try again.';
    }
    return 'No results found';
  }

  // WMFHistoryViewModel section headers — "Today" / "Yesterday" / a formatted date, never
  // the raw viewedDateWithoutTime key.
  // WMFHistoryViewModel's section header. Resources, not literals: these two words are the
  // history list's only chrome and they have to follow the device language ("Dün" on a
  // Turkish device, "Yesterday" on an English one).
  private dayLabel(dateWithoutTime: number): ResourceStr {
    const now: Date = new Date();
    const today: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const day: number = 24 * 60 * 60 * 1000;
    if (dateWithoutTime >= today) {
      return $r('app.string.relative_date_today');
    }
    if (dateWithoutTime >= today - day) {
      return $r('app.string.relative_date_yesterday');
    }
    return new Date(dateWithoutTime).toLocaleDateString();
  }

  // fetchArticles(..., fullTextSearch: true, appendToPreviousResults: results)
  private async appendFullTextResults(host: string, term: string): Promise<void> {
    if (this.didAppendFullText) {
      return;
    }
    this.didAppendFullText = true;
    try {
      const full: WMFSearchResults =
        await SearchService.fullTextSearch(host, term, SearchService.maxResultLimit);
      if (this.searchTerm !== term) {
        return;
      }
      const merged: MWKSearchResult[] = this.results.slice(0);
      const seen: Set<number> = new Set<number>();
      for (const existing of merged) {
        seen.add(existing.articleID);
      }
      for (const result of full.results) {
        if (!seen.has(result.articleID)) {
          merged.push(result);
          seen.add(result.articleID);
        }
      }
      this.results = merged;
      this.resultsSource.reload(this.results);
    } catch (e) {
      // failure(error, .full) is swallowed when the prefix results were non-empty.
      console.warn('search: full-text search failed: ' + this.describeError(e));
    }
  }

  // saveLastSearch() — MWKRecentSearchEntry(url: searchSiteURL, searchTerm:) added to the
  // recent-search list and saved, then reloadRecentSearches().
  private saveLastSearch(term: string): void {
    if (term === '') {
      return;
    }
    RecentSearchStore.addEntry(term, this.siteURL());
    this.recentSearches = RecentSearchStore.entries();
  }

  // articleTappedAction — LinkCoordinator pushes the article; the ArticleCoordinator's
  // read-history row (WMFArticle.addToReadHistory) is written for the tapped result so the
  // history list and the article deep links see it even before the article page finishes
  // loading.
  private openArticle(articleTitle: string, description: string | null,
    thumbnailURL: string | null, pageID: number | null, languageCode: string = ''): void {
    const host: string = languageCode !== '' ? languageCode + '.wikipedia.org' : this.searchHost();
    const code: string = host.split('.')[0];
    const articleKey: string = 'https://' + host + '/wiki/' + articleTitle.replace(/ /g, '_');
    // The write must not start before the store is open: requireStore() throws while
    // Database.init is still in flight, and this chain's catch would drop that on the floor.
    // init() is idempotent and resolves immediately once the store exists.
    Database.init(getContext(this) as common.UIAbilityContext)
      .then((): Promise<void> => HistoryStore.addToReadHistory(articleKey, null, articleTitle,
        description, null, thumbnailURL, pageID))
      .then((): void => {
        this.loadHistory().catch((e: Error): void => {
          console.error('search: history reload failed: ' + e.message);
        });
      })
      .catch((e: Error): void => {
        console.error('search: history write failed: ' + this.describeError(e));
      });
    const params: Record<string, string> = { 'articleTitle': articleTitle, 'languageCode': code };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  // The standalone results screen (SearchResultsViewController pushed with a prefilled term,
  // e.g. from the feed's "search this wiki" entry points).
  private openSearchResults(term: string): void {
    const params: Record<string, string> = { 'term': term };
    router.pushUrl({ url: 'pages/SearchResultsViewControllerPage', params: params });
  }

  // updateSearchResults(for:) — empty text shows the recently-searched list again;
  // otherwise the search is debounced by 100 ms (searchTask) before it runs.
  private onSearchTermChanged(value: string): void {
    this.searchTerm = value;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    if (value.trim().length === 0) {
      this.results = [];
      this.resultsSource.reload(this.results);
      this.lastSearchTerm = '';
      this.isSearching = false;
      this.searchError = '';
      return;
    }
    this.isSearchActive = true;
    // the source returns early when neither the term nor the site URL moved
    if (this.lastSearchTerm === value && this.lastSearchHost === this.searchHost()) {
      return;
    }
    this.searchTimer = setTimeout((): void => {
      this.searchTimer = -1;
      this.runSearch(value).catch((e: Error): void => {
        console.error('search: search failed: ' + e.message);
      });
    }, 100);
  }

  @Builder
  navigationBar() {
    Row() {
      // WMFNavigationBarTitleConfig(title: CommonStrings.searchTitle) — the iOS large
      // title is a framework default, composed explicitly here (mapping-tables §7).
      Text($r('app.string.search_title'))
        .fontSize(ROOT_TITLE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
      Blank()
      // capture S0033: Clear | Tabs | Profile as separate title-bar buttons (NavButton),
      // glyphs on textPrimary.
      Row({ space: NAV_BUTTON_GAP }) {
        // deleteButton — clears the history list (leading of the tabs button)
        if (!this.isSearchActive) {
          // deleteButton is disabled while there is nothing to clear, which is what tells the
          // reader the empty history is empty rather than unloaded.
          Button($r('app.string.search_clear_title'))
            .id('clear')
            .attributeModifier(NAV_TEXT_BUTTON)
            .fontColor(this.hasHistory() ?
              $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
            .opacity(this.hasHistory() ? 1 : 0.4)
            .enabled(this.hasHistory())
            .onClick(() => {
              this.confirmClearHistory();
            })
        }
        Button() {
          Image($r('app.media.article_tabs_square'))
            .width(NAV_BUTTON_IMAGE_SIZE)
            .height(NAV_BUTTON_IMAGE_SIZE)
            .objectFit(ImageFit.Contain)
            .fillColor($r('app.color.theme_text'))
        }
        .id('Tabs Button')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          router.pushUrl({ url: 'pages/WMFArticleTabsViewPage' }).catch((e: Error) => {
            console.error('article tabs push failed: ' + e.message);
          });
        })
        Button() {
          Stack({ alignContent: Alignment.BottomStart }) {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
              .fontSize(NAV_BUTTON_SYMBOL_SIZE)
              .fontColor([$r('app.color.theme_text')])
            // unread notifications: the source's badge on the profile button
            UnreadNotificationsDot()
          }
        }
        .id('profile-button')
        .attributeModifier(NAV_ICON_BUTTON)
        .onClick(() => {
          this.showProfileSheet = true;
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .height(ROOT_BAR_HEIGHT)
    .padding({ left: 16, right: 16 })
    // profileCoordinator presents the profile as a sheet; the root Column already carries
    // the clear-history confirmation sheet and one node takes only one bindSheet.
    .bindSheet($$this.showProfileSheet, this.profileSheetBuilder(), { showClose: false })
  }

  @Builder
  searchBar() {
    // capture S0033/S0034: the search bar floats over the bottom of the screen — a white
    // pill (magnifier + field + the field's own clear glyph) with a separate white close
    // circle beside it while the search controller is active.
    Row() {
      Row() {
        Image($r('app.media.search'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .margin({ left: 16, right: 4 })
        TextInput({ placeholder: $r('app.string.search_field_placeholder_text'), text: this.searchTerm })
          .id('Search Field')
          .layoutWeight(1)
          .height(48)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 4, right: 4 })
          .fontSize(17)
          .fontColor($r('app.color.theme_text'))
          .placeholderColor($r('app.color.theme_secondary_text'))
          .placeholderFont({ size: 17 })
          .onFocus(() => {
            this.isSearchActive = true;
          })
          .onChange((value: string) => {
            this.onSearchTermChanged(value);
          })
        // UISearchBar's own clear button — the gray filled x inside the field
        if (this.searchTerm.length > 0) {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(20)
              .fontColor([$r('app.color.theme_secondary_text')])
          }
            .id('search_clear_text')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(40)
            .height(48)
            .onClick(() => {
              // resetSearchResults()
              this.onSearchTermChanged('');
            })
        }
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius(24)
      .clip(true)
      .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })

      // the search controller's Cancel/Close control — its own white circle
      if (this.isSearchActive) {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(24)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('search_close')
          .type(ButtonType.Circle)
          .width(48)
          .height(48)
          .margin({ left: 10 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .shadow({ radius: 8, color: '#1F000000', offsetY: 2 })
          .onClick(() => {
            this.onSearchTermChanged('');
            this.isSearchActive = false;
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }

  // WMFHistoryView — the body of the screen while the search controller is inactive.
  @Builder
  historyBody() {
    Column() {
      // capture S0033: "History" sits as a bold section title under the large title
      Text($r('app.string.history_title'))
        .id('history_header')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
        .padding({ left: 16, top: 14, bottom: 10 })
      if (this.isHistoryLoading && this.historySections.length === 0) {
        // S6 loading visual — the first history fetch is in flight; never render
        // this as "no history" while it is still running.
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('history_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.historySections.length === 0) {
        // WMFEmptyView(.noHistory) — the source never leaves this area blank. Without it an
        // empty history read as a rendering failure: a "History" heading over nothing.
        Column() {
          Text($r('app.string.search_recent_empty_title'))
            .id('history_empty_title')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .width('100%')
            .textAlign(TextAlign.Center)
          Text($r('app.string.search_recent_empty_subtitle'))
            .id('history_empty_subtitle')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .id('history_empty_view')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else if (this.historyError !== '' && this.historySections.length === 0) {
        // S6 error visual — the fetch threw. Same WMFEmptyView slot the search body uses,
        // so a failed read is visible instead of being indistinguishable from empty history.
        EmptyViewController({ message: 'The app failed to load your history. Please try again.' })
          .id('history_error_view')
      } else {
      List() {
        // One ListItemGroup per day, so every history row is its own ListItem and can carry
        // the swipe-to-delete action. While the whole day was a single ListItem the gesture
        // had nothing per-row to act on.
        LazyForEach(this.historySource, (section: HistorySection) => {
          ListItemGroup({ header: this.historySectionHeader(section) }) {
            ForEach(section.items, (item: HistoryItem) => {
              ListItem() {
                ArticleRightAlignedImageCollectionViewCell({
                  title: item.titleHtml,
                  description: item.description ?? '',
                  imageURL: item.imageURLString ?? '',
                  showSaveButton: false,
                  // one row of a repeated list — shared id on the TAPPABLE row root (Rule 12)
                  rowId: 'history_itemroot',
                  onTap: (): void => {
                    // The row's key names the wiki it was read on (an article opened in another
                    // language version); reopening it on the search wiki found no such page.
                    const host: string = item.articleKey.replace('https://', '').split('/')[0];
                    this.openArticle(item.titleHtml, item.description, item.imageURLString, null,
                      host.endsWith('.wikipedia.org') ? host.split('.')[0] : '');
                  }
                })
              }
              .swipeAction({ end: this.deleteHistoryAction(item) })
            }, (item: HistoryItem) => item.id)
          }
        // keyed by its rows too: a date-only key kept the old group after a row was removed
        }, (section: HistorySection) => section.dateWithoutTime.toString() + ':' +
          section.items.map((i: HistoryItem) => i.id).join(','))
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  // WMFRecentlySearchedView row .swipeActions: the icon-only trash on the destructive tint ->
  // deleteItemAction (removeEntry + save + reloadRecentSearches).
  @Builder
  deleteRecentSearchAction(entry: RecentSearchEntry) {
    Button() {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(22)
        .fontColor([Color.White])
    }
      .id('search_recent_delete')
      .accessibilityText($r('app.string.article_delete'))
      .type(ButtonType.Normal)
      .width(72)
      .height('100%')
      .backgroundColor($r('app.color.theme_destructive'))
      .onClick(() => {
        RecentSearchStore.removeEntry(entry.searchTerm);
        this.recentSearches = RecentSearchStore.entries();
      })
  }

  // WMFRecentlySearchedView — shown by the results container while the term is empty.
  @Builder
  recentlySearchedBody() {
    Column() {
      Row() {
        Text('Recently searched')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        Blank()
        Button($r('app.string.search_clear_title'))
          .id('Search Clear Recent Searches Button')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(17)
          .fontColor($r('app.color.theme_link'))
          .padding({ left: 8, right: 0 })
          .onClick(() => {
            // deleteAllRecentSearches() — removeAllEntries + save + reloadRecentSearches
            RecentSearchStore.removeAllEntries();
            this.recentSearches = RecentSearchStore.entries();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      if (this.recentSearches.length === 0) {
        // WMFEmptyView(.noHistory): a title over its explanatory subtitle, both localized.
        // This was one untranslated literal, which is what the empty-history cases report.
        Column() {
          Text($r('app.string.search_recent_empty_title'))
            .id('search_recent_empty')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .width('100%')
            .textAlign(TextAlign.Center)
          Text($r('app.string.search_recent_empty_subtitle'))
            .id('search_recent_empty_subtitle')
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 40, bottom: 40 })
      }
      List() {
        ForEach(this.recentSearches, (entry: RecentSearchEntry) => {
          ListItem() {
            Text(entry.searchTerm)
              .fontSize(18)
              .fontColor($r('app.color.theme_text'))
              .width('100%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          // one row of a repeated list — shared id, index-resolved by replay (Rule 12)
          .id('search_recent_term_itemroot')
          .swipeAction({ end: this.deleteRecentSearchAction(entry) })
          .onClick(() => {
            // selectAction -> resetSearchResults + populateSearchBarAction
            this.isSearchActive = true;
            this.onSearchTermChanged(entry.searchTerm);
          })
        }, (entry: RecentSearchEntry) => entry.searchTerm)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .divider({ strokeWidth: 1, color: $r('app.color.gray200'), startMargin: 16 })
    }
    .id('Search Recent Searches View')
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // SearchResultsListViewController — one ArticleRightAlignedImageCollectionViewCell per
  // MWKSearchResult; emptyViewType .noSearchResults when the fetch returned nothing.
  @Builder
  resultsBody() {
    Column() {
      if (this.isSearching && this.results.length === 0) {
        // S6 loading visual — the search task is in flight and nothing is on screen yet.
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('search_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0 && this.searchTerm.length > 0) {
        // resultsViewController.emptyViewType = .noSearchResults — WMFEmptyView
        // noSearchResultsEmptyView keeps only the message label.
        EmptyViewController({ message: this.searchEmptyMessage() })
          .id('search_empty_view')
      } else {
      List() {
        LazyForEach(this.resultsSource, (result: MWKSearchResult) => {
          ListItem() {
            ArticleRightAlignedImageCollectionViewCell({
              // displayTitle carries the search-index markup (<i>…</i>, <span class="searchmatch">),
              // which rendered as literal tags in the row.
              title: stripSearchMarkup(result.displayTitle ?? result.title ?? ''),
              // the typed term in bold (SearchResultsListViewController: boldedString)
              boldedString: this.searchTerm,
              description: result.wikidataDescription ?? '',
              imageURL: result.thumbnailURL ?? '',
              showSaveButton: false,
              // one row of a repeated list — shared id on the TAPPABLE row root (Rule 12)
              rowId: 'search_result_itemroot',
              // contextMenuConfigurationForItem — hold a result for the peek preview
              enablePreview: true,
              host: this.searchHost(),
              articleTitle: result.title ?? result.displayTitle ?? '',
              articleKey: 'https://' + this.searchHost() + '/wiki/' +
                (result.title ?? result.displayTitle ?? '').replace(/ /g, '_'),
              onTap: (): void => {
                // tappedSearchResultAction — saveLastSearch() then articleTappedAction
                this.saveLastSearch(this.searchTerm);
                this.openArticle(result.title ?? result.displayTitle ?? '',
                  result.wikidataDescription, result.thumbnailURL, result.articleID);
              }
            })
          }
        }, (result: MWKSearchResult) => result.articleID.toString() + '_' + (result.title ?? ''))
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .divider({ strokeWidth: 1, color: $r('app.color.gray200') })
      .onReachEnd(() => {
        // S4: full_text_search continuation (appendToPreviousResults)
        this.openSearchResultsIfNeeded();
      })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // onReachEnd — the paginated tail of a search is the full-text append the source runs
  // through appendToPreviousResults.
  private openSearchResultsIfNeeded(): void {
    const term: string = this.searchTerm;
    if (term.trim().length === 0 || this.didAppendFullText) {
      return;
    }
    this.appendFullTextResults(this.searchHost(), term).catch((e: Error): void => {
      console.error('search: full-text append failed: ' + e.message);
    });
  }

  @Builder
  historySectionHeader(section: HistorySection) {
    // WMFHistoryViewModel section header (Today / Yesterday / date)
    Text(this.dayLabel(section.dateWithoutTime))
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.theme_text'))
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 6 })
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  // WMFHistoryView's per-row delete — swiping a row reveals it, and removing the last row
  // leaves the history empty state.
  @Builder
  deleteHistoryAction(item: HistoryItem) {
    Button($r('app.string.action_remove'))
      .id('history_delete')
      .type(ButtonType.Normal)
      .fontSize(15)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.theme_destructive'))
      .height('100%')
      .width(96)
      .onClick(() => {
        this.deleteHistoryItem(item);
      })
  }

  private hasHistory(): boolean {
    return this.historySections.length > 0;
  }

  private deleteHistoryItem(item: HistoryItem): void {
    HistoryStore.removeFromReadHistory(item.articleKey).then(() => {
      this.loadHistory().catch((e: Error) => {
        console.error('search: history reload failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('search: history delete failed: ' + e.message);
    });
  }

  // deleteAllButtonPressed raises a confirmation alert over the list. HarmonyOS asks for a
  // destructive confirmation with a centred AlertDialog - Cancel left, the action right in the
  // destructive red - not the iOS-style ActionSheet this was (plain "Yes, delete all" text
  // sliding up over the tab bar, with an empty message line and Cancel far below it).
  private confirmClearHistory(): void {
    AlertDialog.show({
      // the question alone as the dialog text: a title over an empty message left a blank line
      message: $r('app.string.history_clear_confirmation_heading'),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.action_cancel'),
        action: (): void => {
        }
      },
      secondaryButton: {
        value: $r('app.string.history_clear_delete_all'),
        fontColor: $r('app.color.theme_destructive'),
        action: (): void => {
          this.clearAllHistory();
        }
      }
    });
  }

  private clearAllHistory(): void {
    // deleteAll() - clearReadHistory + deleteAllPageViews
    HistoryStore.clearReadHistory()
      .then((): void => {
        this.loadHistory().catch((err: Error): void => {
          console.error('search: history reload failed: ' + err.message);
        });
      })
      .catch((e: Error): void => {
        console.error('search: clear history failed: ' + this.describeError(e));
      });
  }


  @Builder
  profileSheetBuilder() {
    WMFProfileViewSheet({
      onClose: (): void => {
        this.showProfileSheet = false;
      }
    })
  }

  @Builder
  tabsCoverBuilder() {
    WMFArticleTabsView({
      onClose: (): void => {
        this.showTabsCover = false;
      }
    })
  }

  // a root-tab switch is instant, like UITabBarController; other routes keep the slide
  pageTransition() {
    if (isRootTabSwitch()) {
      PageTransitionEnter({ duration: 0 })
      PageTransitionExit({ duration: 0 })
    }
  }

  build() {
    Column() {
      // UISearchController hides the navigation bar while it is active — capture
      // "Search Field" shows the language bar directly under the status bar.
      if (!this.isSearchActive) {
        this.navigationBar()
      }

      // searchLanguageBarViewController — pinned above the results container
      // (updateLanguageBarVisibility)
      if (this.isSearchActive && this.showLanguageBar) {
        Column() {
          SearchLanguagesBarViewController({
            languages: this.languages,
            selectedLanguageCode: this.selectedLanguageCode,
            onSelectLanguage: (languageCode: string): void => {
              // didChangeSelectedSearchContentLanguageCode ->
              // wmf_currentSearchContentLanguageCode + search()
              this.selectedLanguageCode = languageCode;
              Prefs.putString(PrefKeys.searchLanguage, languageCode);
              if (this.searchTerm.trim().length > 0) {
                this.runSearch(this.searchTerm).catch((e: Error): void => {
                  console.error('search: language switch search failed: ' + e.message);
                });
              }
            },
            onTapMore: (): void => {
              // The language picker was a cover over this page, which drew its title and
              // close button under the status bar and left the nested all-languages picker
              // unreachable. Routed page.
              router.pushUrl({ url: 'pages/WMFPreferredLanguagesViewControllerPage',
                params: { 'selectsLanguageFor': 'search' } })
                .catch((e: Error) => {
                  console.error('search: language picker route failed: ' + e.message);
                });
            }
          })
        }
        .width('100%')
      }

      // conditionalVariants: empty term -> recently searched (search active) or the
      // history body (search inactive); a term -> the results collection.
      if (this.searchTerm.length === 0) {
        if (this.isSearchActive) {
          this.recentlySearchedBody()
        } else {
          this.historyBody()
        }
      } else {
        this.resultsBody()
      }

      // capture S0033/S0034: the search field floats at the BOTTOM of the screen, beside
      // the (collapsed) root tab bar — not under the navigation bar.
      this.searchBar()

      // comp_root_tab_bar — Search is tab index 4
      // tabsCoordinator's full-screen cover hangs off this wrapper, NOT the root Column:
      // the root already carries the clear-history bindSheet and a node honours only one of
      // bindSheet / bindContentCover, so on the root the cover was dropped and
      // "Tabs Button" was a no-op. The cover is full-screen whatever it anchors to.
      Column() {
        if (!this.keyboardUp) {
          RootTabBar({ selected: 4 })
        }
      }
      .width('100%')
      .bindContentCover($$this.showTabsCover, this.tabsCoverBuilder())
    }
    .id('Search View')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
