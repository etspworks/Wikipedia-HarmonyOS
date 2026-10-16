// screen_search_results — presentation: page, reached from SearchViewControllerPage
// (SearchResultsViewController pushed with a prefilled term; embedded inside the search
// screen in its captured form).
// Ported from Wikipedia/Code/SearchResultsViewController.swift + its
// SearchResultsListViewController child: the results collection renders one
// ArticleRightAlignedImageCollectionViewCell per MWKSearchResult (title = displayTitleHTML
// bolded on the search term, description = descriptionForSearchResult(), right-aligned
// thumbnail), tapping a row saves the term to the recent-search list and opens the article
// (tappedSearchResultAction -> articleTappedAction). Results come from WMFSearchFetcher:
// prefix_search first, then full_text_search appended when the prefix pass returned < 12
// (appendToPreviousResults) — the paginated axis. An empty result set shows the
// .noSearchResults empty view.
// S5: no standalone capture — styled to match the host search screen's result list
// (capture S0034) and the app baseline tokens.
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ArticleRightAlignedImageCollectionViewCell } from '../components/ArticleRightAlignedImageCollectionViewCell';
import { MWKSearchResult } from '../model/MWKSearchResult';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { SearchService, WMFSearchResults } from '../common/SearchService';
import { RecentSearchStore } from '../common/RecentSearchStore';
import { HistoryStore } from '../common/HistoryStore';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { Prefs, PrefKeys } from '../common/Prefs';
import { advertiseActivity, resignActivity } from '../common/Continuation';

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

@Entry
@Component
struct SearchResultsViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // spec stateVar: items <- svc_search
  @State items: MWKSearchResult[] = [];
  // searchTerm the container was pushed with (prefilledSearchTerm)
  @State searchTerm: string = '';
  // S6: the visual states of the search S4 already wired.
  @State isLoading: boolean = false;
  @State loadError: string = '';
  private itemsSource: SearchResultDataSource = new SearchResultDataSource();
  // siteURL — the wiki the search runs against (selectedSiteURL / primarySiteURL)
  private host: string = 'en.wikipedia.org';
  private didAppendFullText: boolean = false;

  private activityURI: string = '';

  aboutToDisappear(): void {
    if (this.activityURI !== '') {
      resignActivity(getContext(this) as common.UIAbilityContext, this.activityURI);
    }
  }

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    Prefs.init(ctx);
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      this.searchTerm = params['term'] ?? '';
    }
    this.itemsSource.reload(this.items);
    Database.init(ctx).then(() => {
      this.search().catch((e: Error) => {
        console.error('searchResults: search failed: ' + e.message);
      });
    }).catch((e: Error) => {
      console.error('searchResults: db init failed: ' + e.message);
    });
  }

  private describeError(e: Object): string {
    if (e instanceof Error) {
      return e.message;
    }
    return JSON.stringify(e);
  }

  // searchAndMakeResultsVisible(for:) — prefix search, then the full-text append when the
  // prefix pass came back with fewer than 12 rows.
  private async search(): Promise<void> {
    const term: string = this.searchTerm;
    if (term.trim().length === 0) {
      return;
    }
    const stored: string = Prefs.getString(PrefKeys.searchLanguage, '');
    if (stored !== '') {
      this.host = stored + '.wikipedia.org';
    } else {
      try {
        const lang: MWKLanguageLink = await LanguageStore.appLanguage();
        this.host = lang.languageCode + '.wikipedia.org';
      } catch (e) {
        console.warn('searchResults: app language unavailable, defaulting to en');
      }
    }
    // wmf_searchResultsActivitySearchSiteURL(_:searchTerm:): the results continue on another device
    this.activityURI = 'https://' + this.host + '/w/index.php?search=' + encodeURIComponent(term);
    advertiseActivity(getContext(this) as common.UIAbilityContext, this.activityURI);
    this.didAppendFullText = false;
    this.isLoading = true;
    this.loadError = '';
    try {
      const prefix: WMFSearchResults =
        await SearchService.prefixSearch(this.host, term, SearchService.maxResultLimit);
      this.items = prefix.results;
      this.itemsSource.reload(this.items);
      this.isLoading = false;
      if (prefix.results.length < 12) {
        await this.appendFullText();
      }
    } catch (e) {
      this.items = [];
      this.itemsSource.reload(this.items);
      this.loadError = 'The app failed to search. Please check your connection and try again.';
      console.error('searchResults: prefix search failed: ' + this.describeError(e));
    } finally {
      this.isLoading = false;
    }
  }

  // fetchArticles(..., fullTextSearch: true, appendToPreviousResults:)
  private async appendFullText(): Promise<void> {
    if (this.didAppendFullText) {
      return;
    }
    this.didAppendFullText = true;
    try {
      const full: WMFSearchResults =
        await SearchService.fullTextSearch(this.host, this.searchTerm,
          SearchService.maxResultLimit);
      const merged: MWKSearchResult[] = this.items.slice(0);
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
      this.items = merged;
      this.itemsSource.reload(this.items);
    } catch (e) {
      console.warn('searchResults: full-text search failed: ' + this.describeError(e));
    }
  }

  // tappedSearchResultAction — saveLastSearch() then articleTappedAction; the article's
  // read-history row is written on the way in (ArticleCoordinator).
  private openArticle(result: MWKSearchResult): void {
    const articleTitle: string = result.title ?? result.displayTitle ?? '';
    if (this.searchTerm !== '') {
      RecentSearchStore.addEntry(this.searchTerm, 'https://' + this.host);
    }
    const articleKey: string =
      'https://' + this.host + '/wiki/' + articleTitle.replace(/ /g, '_');
    HistoryStore.addToReadHistory(articleKey, null, articleTitle, result.wikidataDescription,
      null, result.thumbnailURL, result.articleID)
      .catch((e: Error): void => {
        console.error('searchResults: history write failed: ' + e.message);
      });
    const params: Record<string, string> = { 'articleTitle': articleTitle };
    router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: params });
  }

  // full_text_search continuation (appendToPreviousResults)
  private loadMore(): void {
    if (this.didAppendFullText || this.searchTerm.trim().length === 0) {
      return;
    }
    this.appendFullText().catch((e: Error): void => {
      console.error('searchResults: full-text append failed: ' + e.message);
    });
  }

  build() {
    Column() {
      // platform push-navigation back affordance
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_link')])
        }
          .id('BackButton')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            router.back();
          })
        Text(this.searchTerm)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // trailing spacer matching the back button, keeping the iOS inline title centred
        Row()
          .width(44)
          .height(44)
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8 })
      .border({ width: { bottom: 1 }, color: $r('app.color.gray200') })

      if (this.isLoading && this.items.length === 0) {
        // S6 loading visual — the prefix search is in flight.
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.theme_secondary_text'))
        }
        .id('search_results_loading')
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0 && this.searchTerm.length > 0) {
        // emptyViewType = .noSearchResults (or the fetch failed)
        Column() {
          Text(this.loadError !== '' ? this.loadError : 'No results found')
            .id('search_empty_view')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(17)
            .lineHeight(24)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 32, right: 32 })
      } else {
      List() {
        LazyForEach(this.itemsSource, (result: MWKSearchResult) => {
          ListItem() {
            ArticleRightAlignedImageCollectionViewCell({
              title: result.displayTitle ?? result.title ?? '',
              description: result.wikidataDescription ?? '',
              imageURL: result.thumbnailURL ?? '',
              showSaveButton: false,
              // contextMenuConfigurationForItem — hold a result for the peek preview
              enablePreview: true,
              host: this.host,
              articleTitle: result.title ?? result.displayTitle ?? '',
              articleKey: 'https://' + this.host + '/wiki/' +
                (result.title ?? result.displayTitle ?? '').replace(/ /g, '_'),
              onTap: (): void => {
                this.openArticle(result);
              }
            })
          }
          // one row of a repeated list — shared id, index-resolved by replay (Rule 12)
          .id('search_result_itemroot')
        }, (result: MWKSearchResult) => result.articleID.toString() + '_' + (result.title ?? ''))
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .divider({ strokeWidth: 1, color: $r('app.color.gray200') })
      .onReachEnd(() => {
        this.loadMore();
      })
      }
    }
    .id('SearchResultsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
