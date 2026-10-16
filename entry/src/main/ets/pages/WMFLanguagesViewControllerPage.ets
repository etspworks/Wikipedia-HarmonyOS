// screen_languages — presentation: modal, hosted by WMFPreferredLanguagesView
// (.bindContentCover). NOT a routed page.
// S3 structure from Wikipedia/Code/WMFLanguagesViewController.m: table of
// WMFLanguageCell rows (localizedName + name) with WMFArticleLanguagesSectionHeader
// sections (preferred / other, mutually exclusive per showPreferredLanguages /
// showAllLanguages), filtered by MWKLanguageFilter (filter text field).
// Rows bound to sitematrix via svc_languages (S4 fills); row tap appends the
// language to preferred via svc_lang_store (plan control add_language — row id
// keeps the itemroot suffix for index-resolved replay, slug kept as prefix).
import { topSafeInset } from '../common/SafeArea';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { LanguageStore } from '../common/LanguageStore';
import { LanguageService, localizedLanguageName, capitalizeFirst } from '../common/LanguageService';
import { upperText, searchFold } from '../common/LocaleText';
import { Prefs } from '../common/Prefs';
import { TALK_LANGUAGE_PICK_KEY, TalkLanguagePick } from '../common/TalkPageService';

class LanguageDataSource implements IDataSource {
  private items: MWKLanguageLink[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): MWKLanguageLink {
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

  reload(items: MWKLanguageLink[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }
}

@Component
export struct WMFLanguagesView {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State preferredLanguages: MWKLanguageLink[] = [];
  @State otherLanguages: MWKLanguageLink[] = [];
  @State filterText: string = '';
  onSelect?: (lang: MWKLanguageLink) => void;
  // WMFArticleLanguagesViewController mode: set, the list is the article's own language
  // versions and a pick opens that version instead of adding a preferred language.
  articleTitle: string = '';
  articleHost: string = '';
  // Hosted in the article's sheet the view needs no status-bar inset.
  topInset: number = topSafeInset();
  // every language the sitematrix knows; the two sections are filtered out of it
  @State items: MWKLanguageLink[] = [];
  private otherSource: LanguageDataSource = new LanguageDataSource();
  private allPreferred: MWKLanguageLink[] = [];
  private allOther: MWKLanguageLink[] = [];

  // The cover this view is mounted in can be dismissed while `load()` is still awaiting the
  // sitematrix fetch. Writing @State after that logs
  // `AceStateMgmt: View WMFLanguagesView is already in process of destruction` (an app-owned
  // E line, so the landing hilog window fails the whole state) and the write is dropped
  // anyway — the component that would render it is gone.
  private disposed: boolean = false;
  private appearedAt: number = 0;

  aboutToAppear(): void {
    this.appearedAt = Date.now();
    Prefs.init(getContext(this) as common.UIAbilityContext);
    this.load().catch((e: Error) => {
      console.error('languages: load failed: ' + e.message);
    });
  }

  aboutToDisappear(): void {
    this.disposed = true;
  }

  // languagesController: the sitematrix list (cached copy first, then refreshed).
  private async load(): Promise<void> {
    if (this.articleTitle !== '') {
      const links: MWKLanguageLink[] =
        await LanguageService.fetchArticleLanguages(this.articleHost, this.articleTitle);
      // langlinks leaves out the wiki being read; the source lists it too, under the
      // reader's languages ("Türkçe / Turkish / <this article>").
      const current: string = this.articleHost.split('.')[0];
      if (current !== '' && !links.some((l: MWKLanguageLink): boolean => l.languageCode === current)) {
        const known: MWKLanguageLink | undefined = LanguageService.cachedLanguages()
          .find((l: MWKLanguageLink): boolean => l.languageCode === current);
        links.unshift(MWKLanguageLink.fromJson({
          languageCode: current,
          pageTitleText: this.articleTitle,
          localizedName: localizedLanguageName(current, current),
          name: capitalizeFirst(known !== undefined ? known.name : localizedLanguageName(current, current))
        }));
      }
      const preferredCodes: string[] = (await LanguageStore.preferredLanguages())
        .map((l: MWKLanguageLink): string => l.languageCode);
      if (this.disposed) {
        return;
      }
      this.allPreferred = links.filter((l: MWKLanguageLink): boolean => preferredCodes.includes(l.languageCode));
      this.allOther = links.filter((l: MWKLanguageLink): boolean => !preferredCodes.includes(l.languageCode));
      this.applyFilter();
      return;
    }
    const cached: MWKLanguageLink[] = LanguageService.cachedLanguages();
    let all: MWKLanguageLink[] = cached;
    if (cached.length === 0) {
      all = await LanguageService.fetchAllLanguages();
    }
    const other: MWKLanguageLink[] = await LanguageStore.otherLanguages();
    if (this.disposed) {
      return;
    }
    this.items = all;
    // Adding a language (the only non-article use): the source's picker lists only languages
    // not yet added. Listing the reader's own let a tap on one move it to the end.
    this.allPreferred = [];
    this.allOther = other;
    this.applyFilter();
  }

  // MWKLanguageFilter: matches the localized name, the autonym and the language code.
  private applyFilter(): void {
    // Also guarded here, not only in `load()`: the filter runs from the TextInput's onChange
    // and from the data source's own reload, and a notification that reaches a LazyForEach
    // whose view is gone is what ArkUI reports as
    // `View WMFLanguagesView is already in process of destruction, will not execute
    // observeComponentCreation2` — a re-render scheduled for a destroyed view, not a bad write.
    if (this.disposed) {
      return;
    }
    const needle: string = searchFold(this.filterText.trim());
    this.preferredLanguages = this.matching(this.allPreferred, needle);
    this.otherLanguages = this.matching(this.allOther, needle);
    this.otherSource.reload(this.otherLanguages);
  }

  private matching(links: MWKLanguageLink[], needle: string): MWKLanguageLink[] {
    if (needle === '') {
      return links.slice(0);
    }
    const out: MWKLanguageLink[] = [];
    for (const link of links) {
      if (searchFold(link.localizedName).includes(needle) ||
        searchFold(link.name).includes(needle) ||
        searchFold(link.languageCode).includes(needle)) {
        out.push(link);
      }
    }
    return out;
  }

  // WMFLanguageCell. Article mode (WMFArticleLanguagesViewController) reads autonym /
  // translated name / the article's title in that language, as the source's cell does; the
  // preferred-languages picker keeps translated name over autonym.
  @Builder
  languageRow(lang: MWKLanguageLink) {
    Column({ space: 2 }) {
      Text(this.articleTitle !== '' ? lang.name : lang.localizedName)
        .fontSize(18)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Start)
      Text(this.articleTitle !== '' ? lang.localizedName : lang.name)
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Start)
      if (this.articleTitle !== '') {
        Text(lang.pageTitleText)
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // S5 (capture WMFPreferredLanguagesViewController/"Preferred Languages Add
      // Language Button"): grouped gray page, centered inline title, pill search
      // field, and one inset white card carrying the language rows.
      Text($r('app.string.article_languages_label'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 56, right: 56, top: 12, bottom: 12 })

      // MWKLanguageFilter text field
      // a search field (magnifier + clear button), as the source's filter field is
      Search({ placeholder: $r('app.string.article_languages_filter_placeholder'), value: this.filterText })
        .id('language_filter_field')
        .width('92%')
        .alignSelf(ItemAlign.Center)
        .height(44)
        .textFont({ size: 17 })
        .fontColor($r('app.color.theme_text'))
        .placeholderColor($r('app.color.theme_secondary_text'))
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .borderRadius(22)
        .margin({ bottom: 16 })
        .onChange((v: string) => {
          this.filterText = v;
          this.applyFilter();
        })

      List() {
        // preferred section (WMFArticleLanguagesSectionHeader + filteredPreferredLanguages)
        if (this.preferredLanguages.length > 0) {
          ListItem() {
            Text(upperText(getContext(this) as common.Context, $r('app.string.article_languages_yours')))
              .fontSize(13)
              .fontColor($r('app.color.theme_secondary_text'))
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 6 })
          }
          ForEach(this.preferredLanguages, (lang: MWKLanguageLink) => {
            ListItem() {
              this.languageRow(lang)
            }
            .id('preferred_language_itemroot')
            .onClick(() => {
              this.selectLanguage(lang);
            })
          }, (lang: MWKLanguageLink) => lang.languageCode)
        }
        ListItem() {
          Text(upperText(getContext(this) as common.Context, $r('app.string.article_languages_others')))
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 6 })
        }
        // other languages (filteredOtherLanguages — large, lazy)
        LazyForEach(this.otherSource, (lang: MWKLanguageLink) => {
          ListItem() {
            this.languageRow(lang)
          }
          // add_language row — shared id, index-resolved by replay (Rule 12 exception)
          .id('add_language_itemroot')
          .onClick(() => {
            this.selectLanguage(lang);
          })
        }, (lang: MWKLanguageLink) => lang.languageCode)
      }
      .layoutWeight(1)
      .cachedCount(10)
      .scrollBar(BarState.Off)
      .width('92%')
      .alignSelf(ItemAlign.Center)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .borderRadius({ topLeft: 12, topRight: 12 })
      .clip(true)
      .divider({
        strokeWidth: 1,
        color: $r('app.color.gray200'),
        startMargin: 16,
        endMargin: 0
      })
    }
    .id('WMFLanguagesViewController')
    // Presented as a cover, which draws under the status bar: start below it.
    .padding({ top: this.topInset })
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }

  // add_language: append to the preferred languages (svc_lang_store), then the host
  // dismisses the sheet with the chosen language.
  private selectLanguage(lang: MWKLanguageLink): void {
    // The source's modal takes no touches while it is presenting; here the rest of a double tap
    // on "Add another language" landed on the first row and added it.
    if (Date.now() - this.appearedAt < 500) {
      return;
    }
    if (this.articleTitle !== '') {
      if (this.onSelect !== undefined) {
        this.onSelect(lang);
      }
      return;
    }
    LanguageStore.appendPreferredLanguage(lang.contentLanguageCode).then(() => {
      this.load().catch((e: Error) => {
        console.error('languages: reload failed: ' + e.message);
      });
      if (this.onSelect !== undefined) {
        this.onSelect(lang);
      }
    }).catch((e: Error) => {
      console.error('languages: append failed: ' + e.message);
    });
  }
}


// The language picker was presented with .bindContentCover over the article. The cover was
// torn down while load() was still awaiting the sitematrix fetch — hilog showed
// "View WMFLanguagesView is already in process of destruction" — so the list arrived after the
// component was gone and the reader saw the "Find language" field over an empty card. It also
// drew under the status bar, leaving the title beneath the clock with no reachable close
// control. Routed as a page it keeps its own lifetime and gets the system inset, which is the
// same fix this port applied to onboarding, the tab overview, login and the games splash.
@Entry
@Component
struct LanguagesPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  private articleTitle: string = '';
  private articleHost: string = '';
  // opened by the talk page's Change language: the pick goes back to the talk page
  private picksTalkLanguage: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    if (params !== undefined && params !== null) {
      this.articleTitle = params['articleTitle'] ?? '';
      this.articleHost = params['host'] ?? '';
      this.picksTalkLanguage = params['picksTalkLanguage'] === 'true';
    }
  }

  build() {
    Column() {
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
        Blank()
      }
      .width('100%')
      .height(44)
      .padding({ left: 8, right: 8 })

      WMFLanguagesView({
        articleTitle: this.articleTitle,
        articleHost: this.articleHost,
        onSelect: (lang: MWKLanguageLink): void => {
          console.info('languages: chose ' + lang.contentLanguageCode);
          if (this.articleTitle === '') {
            router.back();
            return;
          }
          if (this.picksTalkLanguage) {
            const pick: TalkLanguagePick = { languageCode: lang.languageCode, articleTitle: lang.pageTitleText };
            AppStorage.setOrCreate<string>(TALK_LANGUAGE_PICK_KEY, JSON.stringify(pick));
            router.back();
            return;
          }
          // The chosen language version replaces the picker; Back returns to the original.
          const params: Record<string, string> = {
            'articleTitle': lang.pageTitleText,
            'languageCode': lang.languageCode
          };
          router.replaceUrl({ url: 'pages/ArticleViewControllerPage', params: params })
            .catch((e: Error) => console.error('languages: article route failed: ' + e.message));
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
