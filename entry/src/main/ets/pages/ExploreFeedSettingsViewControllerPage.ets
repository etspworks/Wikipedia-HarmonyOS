// screen_explore_feed_settings — presentation: page, pushed from screen_settings_tab.
// Structure from Wikipedia/Code/ExploreFeedSettingsViewController.swift + its base
// BaseExploreFeedSettingsViewController.swift (the base renders sections/rows, the subclass
// supplies them):
//   sections = [customizationSection, mainSection]  (languagesSection only when the user has
//   more than one preferred language — displayType .multipleLanguages; the capture and this
//   app's single preferred language are .singleLanguage, where every FeedCard row is a
//   .switch row, so the languages section is not part of this screen).
//   customizationSection — headerTitle "Customize the Explore feed", items = feedCards in the
//   subclass's own order: news, onThisDay, featuredArticle, dailyGame (inserted at index 3),
//   topRead, location, random, pictureOfTheDay, continueReading, relatedPages; footer is the
//   two footer strings joined ("Hiding a card type…" + "Hiding all Explore feed cards…").
//   The suggestedEdits row is appended only when editCount >= 50 and VoiceOver is off, so it
//   is not on this screen's contract and not rendered.
//   mainSection — no header, one ExploreFeedSettingsPrimary(.entireFeed) "Explore tab" switch
//   row, footer "Turning off the Explore tab will replace the Explore tab with a Settings tab."
// Each row is a WMFSettingsTableViewCell (comp_settings_cell) configured with the FeedCard's
// title/subtitle/iconName and disclosureType .switch — tapping the row's switch toggles that
// card, it does not push a page (didSelectRowAt returns early unless .multipleLanguages).
// Rule 12: every row id is the SOURCE slug from the capture (results/traversal-source/pages/
// ExploreFeedSettingsViewController) — the shared cell puts the slug on its switch and
// <slug>_row on the row container.
// S4: state + wiring. Each FeedCard switch mirrors WMFExploreFeedContentController's
// exploreFeedPreferences entry for that WMFContentGroupKind (toggleContentGroup(of:isOn:)),
// persisted through svc_prefs (Prefs) under WMFExploreFeedPreferencesKey.<kindRawValue>;
// defaults are ON, as defaultExploreFeedPreferences seeds every customizable kind.
// The mainSection "Explore tab" switch is ExploreFeedSettingsPrimary(.entireFeed):
// isOn = UserDefaults.standard.defaultTabType == .explore, and toggling it runs the source's
// toggleAllContentGroupKinds(isOn) + defaultTabType = .explore/.settings.
import { upperText } from '../common/LocaleText';
import { router } from '@kit.ArkUI';
import { WMFSettingsTableViewCell, SettingsDisclosureType } from '../components/WMFSettingsTableViewCell';
import { common } from '@kit.AbilityKit';
import { Prefs, PrefKeys, exploreFeedCardKey, exploreFeedCardLanguageKey, isCardInFeed, setCardInFeed, isGlobalKind,
  isLanguageInFeed, setLanguageInFeed, isGlobalCardsInFeed, setGlobalCardsInFeed } from '../common/Prefs';
import { ContentGroupKind } from '../common/FeedStore';
import { LanguageStore } from '../common/LanguageStore';
import { SessionStore } from '../common/SessionStore';
import { WMFCurrentUser } from '../model/WMFCurrentUser';
import { meetsSuggestedEditsEditCount } from '../common/GrowthTasksService';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

// NSUserDefaults+WMFExtensions.swift: WMFAppDefaultTabType.explore = 0, .settings = 1.
const DEFAULT_TAB_TYPE_EXPLORE: number = 0;
export const DEFAULT_TAB_TYPE_SETTINGS: number = 1;

// The customizable kinds this screen exposes, in the subclass's own row order.
export const FEED_CARD_KINDS: ContentGroupKind[] = [
  ContentGroupKind.News,
  ContentGroupKind.OnThisDay,
  ContentGroupKind.FeaturedArticle,
  ContentGroupKind.DailyGame,
  ContentGroupKind.TopRead,
  ContentGroupKind.Location,
  ContentGroupKind.Random,
  ContentGroupKind.PictureOfTheDay,
  ContentGroupKind.ContinueReading,
  ContentGroupKind.RelatedPages
];

@Entry
@Component
struct ExploreFeedSettingsViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // FeedCard.isOn per contentGroupKind (contentGroupKind.isInFeed).
  @State newsOn: boolean = true;
  @State onThisDayOn: boolean = true;
  @State featuredArticleOn: boolean = true;
  @State dailyGameOn: boolean = true;
  @State topReadOn: boolean = true;
  @State placesOn: boolean = true;
  @State randomOn: boolean = true;
  @State pictureOfTheDayOn: boolean = true;
  @State continueReadingOn: boolean = true;
  @State relatedPagesOn: boolean = true;
  // ExploreFeedSettingsViewController: the Suggested Edits row only for 50 or more edits
  @State suggestedEditsOn: boolean = true;
  @State showsSuggestedEdits: boolean = false;
  // ExploreFeedSettingsPrimary(.entireFeed).isOn
  @State exploreTabOn: boolean = true;
  // The preferred languages drive both the row subtitle ("EN, TR") and its value text:
  // a language-specific card reads "On all" only while every preferred language is on.
  @State languages: MWKLanguageLink[] = [];
  // languagesSection: one switch per preferred language plus the global-cards switch.
  @State languageStates: Record<string, boolean> = {};
  @State globalCardsOn: boolean = true;
  // The row's value text ("Hepsinde" / "Açık" / "Kapalı"), by row id. Derived state: a row
  // that reads it rebuilds when the preferences are re-read, which a plain boolean argument
  // to the row builder did not always do.
  @State cardValues: Record<string, string> = {};

  // viewWillAppear -> tableView.reloadData(): every row re-reads its stored preference.
  aboutToAppear(): void {
    // Prefs.getSync throws when the store was never opened. EntryAbility.onCreate opens it for
    // every launch, deep links included; this stays a guard so an unreadable store renders the
    // source's defaults (every card ON, Explore the default tab) instead of killing the app.
    try {
      this.loadPreferences();
    } catch (e) {
      console.error('explore feed settings: preferences unavailable: ' + (e as Error).message);
    }
    LanguageStore.preferredLanguages().then((links: MWKLanguageLink[]) => {
      this.languages = links;
      this.loadPreferences();
    }).catch((e: Error) => {
      // The rows still render; they just fall back to the card-level value text.
      console.error('explore feed settings: languages unavailable: ' + e.message);
    });
  }

  // contentGroupKind.isGlobal — a global card has no per-language state, so the source
  // shows "Not language specific" under it and a plain On/Off value.
  private languageCodes(): string {
    const codes: string[] = [];
    for (const link of this.languages) {
      codes.push(link.contentLanguageCode.toUpperCase());
    }
    return codes.join(', ');
  }

  private languageKey(kind: ContentGroupKind, link: MWKLanguageLink): string {
    return exploreFeedCardLanguageKey(kind, link.contentLanguageCode);
  }

  // BaseExploreFeedSettingsViewController's detail text for a FeedCard row. Every one of
  // these read as an English literal on a Turkish device.
  private detailText(kind: ContentGroupKind, isOn: boolean, isGlobal: boolean): string {
    if (!isOn) {
      return this.text($r('app.string.explore_feed_preferences_feed_card_visibility_all_languages_off'));
    }
    if (isGlobal || this.languages.length === 0) {
      return this.text($r('app.string.explore_feed_preferences_feed_card_visibility_global_cards_on'));
    }
    let onCount: number = 0;
    for (const link of this.languages) {
      if (Prefs.getBoolean(this.languageKey(kind, link), true)) {
        onCount += 1;
      }
    }
    if (onCount === this.languages.length) {
      return this.text($r('app.string.explore_feed_preferences_feed_card_visibility_all_languages_on'));
    }
    if (onCount === 0) {
      return this.text($r('app.string.explore_feed_preferences_feed_card_visibility_all_languages_off'));
    }
    return this.text($r('app.string.explore_feed_preferences_feed_card_visibility_global_cards_on')) +
      ' ' + onCount.toString();
  }

  // WMFSettingsTableViewCell takes plain strings (a ResourceStr is not a valid @Prop union
  // in ArkTS V1), so the screen resolves its own labels.
  private text(res: Resource): string {
    try {
      return (getContext(this) as common.Context).resourceManager.getStringSync(res);
    } catch (e) {
      console.error('explore feed settings: string unavailable: ' + (e as Error).message);
      return '';
    }
  }

  private loadPreferences(): void {
    const states: Record<string, boolean> = {};
    for (const link of this.languages) {
      states[link.contentLanguageCode] = isLanguageInFeed(link.contentLanguageCode);
    }
    this.languageStates = states;
    this.globalCardsOn = isGlobalCardsInFeed();
    this.newsOn = this.isInFeed(ContentGroupKind.News);
    this.onThisDayOn = this.isInFeed(ContentGroupKind.OnThisDay);
    this.featuredArticleOn = this.isInFeed(ContentGroupKind.FeaturedArticle);
    this.dailyGameOn = this.isInFeed(ContentGroupKind.DailyGame);
    this.topReadOn = this.isInFeed(ContentGroupKind.TopRead);
    this.placesOn = this.isInFeed(ContentGroupKind.Location);
    this.randomOn = this.isInFeed(ContentGroupKind.Random);
    this.pictureOfTheDayOn = this.isInFeed(ContentGroupKind.PictureOfTheDay);
    this.continueReadingOn = this.isInFeed(ContentGroupKind.ContinueReading);
    this.relatedPagesOn = this.isInFeed(ContentGroupKind.RelatedPages);
    this.suggestedEditsOn = this.isInFeed(ContentGroupKind.SuggestedEdits);
    const user: WMFCurrentUser | null = SessionStore.currentUser.value;
    this.showsSuggestedEdits = SessionStore.isLoggedIn && user !== null &&
      meetsSuggestedEditsEditCount(user.editCount, true);
    this.exploreTabOn =
      Prefs.getNumber(PrefKeys.defaultTabType, DEFAULT_TAB_TYPE_EXPLORE) === DEFAULT_TAB_TYPE_EXPLORE;
    const values: Record<string, string> = {};
    values['in_the_news'] = this.detailText(ContentGroupKind.News, this.newsOn, false);
    values['on_this_day'] = this.detailText(ContentGroupKind.OnThisDay, this.onThisDayOn, false);
    values['featured_article'] =
      this.detailText(ContentGroupKind.FeaturedArticle, this.featuredArticleOn, false);
    values['wikipedia_games'] = this.detailText(ContentGroupKind.DailyGame, this.dailyGameOn, false);
    values['top_read'] = this.detailText(ContentGroupKind.TopRead, this.topReadOn, false);
    values['places'] = this.detailText(ContentGroupKind.Location, this.placesOn, false);
    values['randomizer'] = this.detailText(ContentGroupKind.Random, this.randomOn, false);
    values['picture_of_the_day'] =
      this.detailText(ContentGroupKind.PictureOfTheDay, this.pictureOfTheDayOn, true);
    values['continue_reading'] =
      this.detailText(ContentGroupKind.ContinueReading, this.continueReadingOn, true);
    values['because_you_read'] =
      this.detailText(ContentGroupKind.RelatedPages, this.relatedPagesOn, true);
    values['suggested_edits'] =
      this.detailText(ContentGroupKind.SuggestedEdits, this.suggestedEditsOn, true);
    this.cardValues = values;
  }

  private cardKey(kind: ContentGroupKind): string {
    return exploreFeedCardKey(kind);
  }

  // contentGroupKind.isInFeed — defaultExploreFeedPreferences seeds every customizable kind ON.
  private isInFeed(kind: ContentGroupKind): boolean {
    return Prefs.getBoolean(this.cardKey(kind), true);
  }

  // feedContentController.toggleContentGroup(of:isOn:updateFeed:false)
  private toggleContentGroup(kind: ContentGroupKind, isOn: boolean): void {
    Prefs.putBoolean(this.cardKey(kind), isOn);
  }

  // The main switch: toggleAllContentGroupKinds(isOn) + defaultTabType = .explore/.settings.
  private toggleExploreFeed(isOn: boolean): void {
    for (const kind of FEED_CARD_KINDS) {
      Prefs.putBoolean(this.cardKey(kind), isOn);
    }
    this.newsOn = isOn;
    this.onThisDayOn = isOn;
    this.featuredArticleOn = isOn;
    this.dailyGameOn = isOn;
    this.topReadOn = isOn;
    this.placesOn = isOn;
    this.randomOn = isOn;
    this.pictureOfTheDayOn = isOn;
    this.continueReadingOn = isOn;
    this.relatedPagesOn = isOn;
    Prefs.putNumber(PrefKeys.defaultTabType,
      isOn ? DEFAULT_TAB_TYPE_EXPLORE : DEFAULT_TAB_TYPE_SETTINGS);
  }

  // WMFTableHeaderFooterLabelView, .header — uppercase secondary caption, inset by the
  // screen margin (capture: "CUSTOMIZE THE EXPLORE FEED" above the card).
  @Builder
  sectionHeader(text: Resource) {
    Text(upperText(getContext(this) as common.Context, text))
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 32, bottom: 2 })
  }

  // WMFTableHeaderFooterLabelView, .footer (setShortTextAsProse) — the source joins the
  // section's footer strings with a space, so consecutive footers carry no gap between
  // them and read as one prose block.
  @Builder
  sectionFooter(text: Resource) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16 })
  }

  // FeedCard row. The source renders it with disclosureType .switch ONLY in
  // .singleLanguage display mode; with preferred languages to customize it is a disclosure
  // row showing the card's value ("On all" / "On" / "Off") that pushes
  // FeedCardSettingsViewController for that contentGroupKind. This port had the switch
  // form wired unconditionally, so the per-card screen — which already exists and is
  // registered in main_pages.json — was unreachable from every one of these ten rows.
  @Builder
  feedCardRow(rowId: string, titleRes: Resource, kind: ContentGroupKind, icon: Resource,
    isOn: boolean, isGlobal: boolean, switchTitleRes: Resource, footerRes: Resource) {
    WMFSettingsTableViewCell({
      title: this.text(titleRes),
      subtitle: isGlobal ? this.text($r('app.string.explore_feed_preferences_global_cards_subtitle'))
        : this.languageCodes(),
      // Every card row pushes its own screen (the per-language list for a language-specific
      // card, the single "Show ... card" switch for a global one) and shows that card's
      // value beside the chevron.
      disclosureType: SettingsDisclosureType.viewControllerWithText,
      disclosureText: this.cardValues[rowId] ?? this.detailText(kind, isOn, isGlobal),
      rowId: rowId,
      iconImage: icon,
      onTap: (): void => {
        this.openFeedCardSettings(kind, this.text(titleRes), this.text(switchTitleRes),
          this.text(footerRes), isGlobal);
      }
    })
  }

  // The languages section (BaseExploreFeedSettingsViewController.languagesSection): one
  // switch per preferred language plus the global-cards switch. Turning a language off
  // takes that language's cards out of the feed; turning everything off replaces the
  // Explore tab with Settings, exactly as the entire-feed switch does.
  @Builder
  languageRow(link: MWKLanguageLink) {
    WMFSettingsTableViewCell({
      title: link.localizedName !== '' ? link.localizedName : link.languageCode.toUpperCase(),
      // the source's language row carries the code under the name ("İngilizce" / "EN")
      subtitle: link.contentLanguageCode.toUpperCase(),
      disclosureType: SettingsDisclosureType.toggle,
      rowId: 'language_' + link.contentLanguageCode,
      isSwitchOn: this.languageOn(link),
      onToggle: (value: boolean): void => {
        setLanguageInFeed(link.contentLanguageCode, value);
        this.loadPreferences();
        this.syncExploreTabWithFeed();
      }
    })
  }

  private languageOn(link: MWKLanguageLink): boolean {
    return this.languageStates[link.contentLanguageCode] ?? true;
  }

  // "Hiding all Explore feed cards in all of your languages will turn off the Explore tab."
  private syncExploreTabWithFeed(): void {
    let anyOn: boolean = this.globalCardsOn;
    for (const link of this.languages) {
      if (this.languageOn(link)) {
        anyOn = true;
      }
    }
    this.exploreTabOn = anyOn;
    Prefs.putNumber(PrefKeys.defaultTabType,
      anyOn ? DEFAULT_TAB_TYPE_EXPLORE : DEFAULT_TAB_TYPE_SETTINGS);
  }

  build() {
    Column() {
      // WMFNavigationBar: the push-navigation back button + the centered title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
          .id('BackButton')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText('Explore feed')
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        // iOS inline navigation title: centered and bold.
        Text($r('app.string.welcome_exploration_explore_feed_title'))
          .fontSize(17)
          .fontWeight(600)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 10 })

      Scroll() {
        Column() {
          // MARK: customizationSection
          this.sectionHeader($r('app.string.explore_feed_preferences_customize_explore_feed'))
          Column() {
            this.feedCardRow('in_the_news', $r('app.string.in_the_news_title'),
              ContentGroupKind.News, $r('app.media.in_the_news_mini'),
              this.newsOn, false,
              $r('app.string.explore_feed_preferences_show_news_title'),
              $r('app.string.explore_feed_preferences_show_news_footer_text'))
            this.feedCardRow('on_this_day', $r('app.string.on_this_day_title'),
              ContentGroupKind.OnThisDay, $r('app.media.on_this_day_mini'),
              this.onThisDayOn, false,
              $r('app.string.explore_feed_preferences_show_on_this_day_title'),
              $r('app.string.explore_feed_preferences_show_on_this_day_footer_text'))
            this.feedCardRow('featured_article', $r('app.string.explore_featured_article_heading'),
              ContentGroupKind.FeaturedArticle, $r('app.media.featured_mini'),
              this.featuredArticleOn, false,
              $r('app.string.explore_feed_preferences_show_featured_article_title'),
              $r('app.string.explore_feed_preferences_show_featured_article_footer_text'))
            this.feedCardRow('wikipedia_games', $r('app.string.settings_explore_games_title'),
              ContentGroupKind.DailyGame, $r('app.media.games_mini'),
              this.dailyGameOn, false,
              $r('app.string.explore_feed_preferences_games_title'),
              $r('app.string.explore_feed_preferences_show_games_footer_text'))
            this.feedCardRow('top_read', $r('app.string.explore_most_read_generic_heading'),
              ContentGroupKind.TopRead, $r('app.media.trending_mini'),
              this.topReadOn, false,
              $r('app.string.explore_feed_preferences_show_top_read_title'),
              $r('app.string.explore_feed_preferences_show_top_read_footer_text'))
            this.feedCardRow('places', $r('app.string.places_title'),
              ContentGroupKind.Location, $r('app.media.nearby_mini'),
              this.placesOn, false,
              $r('app.string.explore_feed_preferences_show_places_title'),
              $r('app.string.explore_feed_preferences_show_places_footer_text'))
            this.feedCardRow('randomizer', $r('app.string.explore_randomizer'),
              ContentGroupKind.Random, $r('app.media.random_mini'),
              this.randomOn, false,
              $r('app.string.explore_feed_preferences_show_randomizer_title'),
              $r('app.string.explore_feed_preferences_show_randomizer_footer_text'))
            this.feedCardRow('picture_of_the_day', $r('app.string.explore_potd_heading'),
              ContentGroupKind.PictureOfTheDay, $r('app.media.potd_mini'),
              this.pictureOfTheDayOn, true,
              $r('app.string.explore_feed_preferences_show_picture_of_the_day_title'),
              $r('app.string.explore_feed_preferences_show_picture_of_the_day_footer_text'))
            this.feedCardRow('continue_reading', $r('app.string.explore_continue_reading_heading'),
              ContentGroupKind.ContinueReading, $r('app.media.today_mini'),
              this.continueReadingOn, true,
              $r('app.string.explore_feed_preferences_show_continue_reading_title'),
              $r('app.string.explore_feed_preferences_show_continue_reading_footer_text'))
            this.feedCardRow('because_you_read', $r('app.string.explore_because_you_read_heading'),
              ContentGroupKind.RelatedPages, $r('app.media.recent_mini'),
              this.relatedPagesOn, true,
              $r('app.string.explore_feed_preferences_show_related_pages_title'),
              $r('app.string.explore_feed_preferences_show_related_pages_footer_text'))
            if (this.showsSuggestedEdits) {
              this.feedCardRow('suggested_edits', $r('app.string.suggested_edits_title'),
                ContentGroupKind.SuggestedEdits, $r('app.media.pencil'),
                this.suggestedEditsOn, true,
                $r('app.string.explore_feed_preferences_suggested_edits_title'),
                $r('app.string.explore_feed_preferences_global_card_footer_text'))
            }
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .clip(true)
          .margin({ bottom: 10 })
          this.sectionFooter($r('app.string.explore_feed_preferences_customize_explore_feed_footer_text'))


          // MARK: languagesSection — one switch per preferred language plus the global
          // cards switch. The screen never had it, so a reader with two languages had no way
          // to take one language out of the feed.
          this.sectionHeader($r('app.string.languages_settings_title'))
          Column() {
            ForEach(this.languages, (link: MWKLanguageLink) => {
              this.languageRow(link)
            }, (link: MWKLanguageLink) => link.contentLanguageCode)
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.explore_feed_preferences_global_cards_title')),
              subtitle: this.text($r('app.string.explore_feed_preferences_global_cards_subtitle')),
              disclosureType: SettingsDisclosureType.toggle,
              rowId: 'global_cards',
              isSwitchOn: this.globalCardsOn,
              onToggle: (value: boolean): void => {
                setGlobalCardsInFeed(value);
                this.globalCardsOn = value;
                this.syncExploreTabWithFeed();
              }
            })
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .clip(true)
          .margin({ bottom: 10 })
          // the languages section's footer, as the source has it: what switching every language
          // (and the global cards) off does - right under Küresel kartlar
          this.sectionFooter($r('app.string.explore_feed_preferences_languages_footer_text'))

          // MARK: mainSection — ExploreFeedSettingsPrimary(.entireFeed), no header
          Column() {
            WMFSettingsTableViewCell({
              title: this.text($r('app.string.explore_feed_preferences_explore_tab')),
              disclosureType: SettingsDisclosureType.toggle,
              rowId: 'explore_tab',
              isSwitchOn: this.exploreTabOn,
              onToggle: (v: boolean): void => {
                this.exploreTabOn = v;
                this.toggleExploreFeed(v);
              }
            })
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .clip(true)
          .margin({ top: 32, bottom: 10 })
          this.sectionFooter($r('app.string.explore_feed_preferences_turn_off_feed_disclosure'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('ExploreFeedSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
    // The per-card screen writes the same preference store. onPageShow does not fire for
    // this page when that screen is popped, so the row values stayed as they were until the
    // list was entered again; becoming visible is the signal that does arrive.
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean): void => {
      if (isVisible) {
        try {
          this.loadPreferences();
        } catch (e) {
          console.error('explore feed settings: preferences unavailable: ' +
            (e as Error).message);
        }
      }
    })
  }

  private lastPushAt: number = 0;

  // didSelectRowAt: a FeedCard row pushes FeedCardSettingsViewController configured with
  // that card's contentGroupKind. The pushed screen reads these exact param names.
  private openFeedCardSettings(kind: ContentGroupKind, title: string, switchTitle: string,
    footerText: string, isGlobal: boolean): void {
    // One push per tap burst: a double tap used to stack the per-card screen twice.
    const now: number = Date.now();
    if (now - this.lastPushAt < 1000) {
      return;
    }
    this.lastPushAt = now;
    const params: Record<string, string> = {
      'contentGroupKind': kind.toString(),
      'cardTitle': title,
      'switchTitle': switchTitle,
      'footerText': footerText,
      'isGlobalCard': isGlobal ? 'true' : 'false'
    };
    router.pushUrl({ url: 'pages/FeedCardSettingsViewControllerPage', params: params })
      .catch((e: Error) => {
        console.error('explore feed settings: push failed: ' + e.message);
      });
  }

  // onPageShow: the per-card screen writes the same preference store, so the row values
  // ("On all" / "On 1" / "Off") have to be re-read when the reader comes back to this list.
  onPageShow(): void {
    try {
      this.loadPreferences();
    } catch (e) {
      console.error('explore feed settings: preferences unavailable: ' + (e as Error).message);
    }
  }
}
