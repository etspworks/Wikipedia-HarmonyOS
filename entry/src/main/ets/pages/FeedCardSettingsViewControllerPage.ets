// screen_feed_card_settings — presentation: page, pushed from screen_explore_feed_settings
// (didSelectRowAt on a FeedCard row, configured with that row's contentGroupKind).
// No outgoing nav edges.
//
// S3 structure from Wikipedia/Code/FeedCardSettingsViewController.swift over its base
// Wikipedia/Code/BaseExploreFeedSettingsViewController.swift:
//   configure(with:dataStore:contentGroupKind:theme:) sets the navigation title to the card's
//   own title and displayType = .detail(contentGroupKind); the capture (S0164) is the
//   .news card, whose title is "In the news".
//   sections = [mainSection] for a global card, [mainSection, languagesSection] otherwise:
//   mainSection — no header; ONE ExploreFeedSettingsPrimary(for: .singleFeedCard(kind)) row,
//     title = contentGroupKind.switchTitle ("Show In the news card"), isOn =
//     contentGroupKind.isInFeed, disclosureType .switch, controlTag -1; footer =
//     contentGroupKind.togglingFeedCardFooterText.
//   languagesSection — header CommonStrings.languagesTitle ("LANGUAGES"); one
//     ExploreFeedSettingsLanguage row per preferred language (title = localizedName,
//     subtitle = contentLanguageCode.uppercased(), isOn = languageLink.isInFeed(for: kind));
//     footer = the "additional languages" text + the same toggling text.
//   Every row is a WMFSettingsTableViewCell (comp_settings_cell) configured by
//   configureCell(_:item:); the row itself does not toggle — the switch does
//   (settingsTableViewCell(_:didToggleDisclosureSwitch:): controlTag -1 toggles the card in
//   every language, a language row's tag toggles it for that language's siteURL only).
// Rule 12: show_in_the_news / BackButton are the SOURCE slugs from the capture; the language
// rows share 'feed_card_language_itemroot' (Rule 12's list-row exception — the languages
// section is a per-preferred-language list, resolved by index).
import { upperText } from '../common/LocaleText';
import { router } from '@kit.ArkUI';
import { WMFSettingsTableViewCell, SettingsDisclosureType } from '../components/WMFSettingsTableViewCell';
import { common } from '@kit.AbilityKit';
import { Prefs, exploreFeedCardKey, exploreFeedCardLanguageKey } from '../common/Prefs';
import { ContentGroupKind } from '../common/FeedStore';
import { LanguageStore } from '../common/LanguageStore';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { NAV_ICON_BUTTON, NAV_BUTTON_IMAGE_SIZE } from '../components/NavButton';

@Entry
@Component
struct FeedCardSettingsViewControllerPage {
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // configure(with:contentGroupKind:) — the pushing screen's FeedCard row. The capture's
  // state is the .news card, which is also the fallback when no route params are supplied.
  @State cardTitle: string = 'In the news';
  @State switchTitle: string = 'Show In the news card';
  @State footerText: string =
    'Turning off the In the news card will turn the card off in all available languages.';
  private contentGroupKind: number = ContentGroupKind.News;
  // WMFContentGroupKind.isGlobal — a global card has no languages section.
  private isGlobalCard: boolean = false;

  // ExploreFeedSettingsPrimary.isOn (contentGroupKind.isInFeed).
  @State cardIsOn: boolean = true;
  // languages — ExploreFeedSettingsLanguage rows, one per preferred language.
  @State languages: MWKLanguageLink[] = [];
  // isOn per language (languageLink.isInFeed(for: contentGroupKind)), by content language code.
  @State languageIsOn: Map<string, boolean> = new Map<string, boolean>();
  // S6: load/error visuals for the svc_lang_store read wired in S4.
  @State languagesLoading: boolean = true;
  @State languagesError: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    if (params !== undefined && params !== null) {
      const kind: string = params['contentGroupKind'] ?? '';
      if (kind !== '') {
        this.contentGroupKind = parseInt(kind);
      }
      this.cardTitle = params['cardTitle'] ?? this.cardTitle;
      this.switchTitle = params['switchTitle'] ?? this.switchTitle;
      this.footerText = params['footerText'] ?? this.footerText;
      this.isGlobalCard = (params['isGlobalCard'] ?? '') === 'true';
    }
    // iOS: a global card's switch footer is the "not language specific" note.
    if (this.isGlobalCard) {
      this.footerText = this.text($r('app.string.explore_feed_preferences_global_card_footer_text'));
    }
    this.reload();
  }

  // WMFSettingsTableViewCell and this screen's own header builder take plain strings.
  private text(res: Resource): string {
    try {
      return (getContext(this) as common.Context).resourceManager.getStringSync(res);
    } catch (e) {
      console.error('feed card settings: string unavailable: ' + (e as Error).message);
      return '';
    }
  }

  // reload() — every row re-reads its stored preference.
  private reload(): void {
    try {
      this.cardIsOn = Prefs.getBoolean(this.cardKey(), true);
    } catch (e) {
      console.error('feed card settings: preferences unavailable: ' + (e as Error).message);
    }
    this.languagesLoading = true;
    this.languagesError = '';
    LanguageStore.preferredLanguages().then((links: MWKLanguageLink[]) => {
      const on: Map<string, boolean> = new Map<string, boolean>();
      for (const link of links) {
        on.set(link.contentLanguageCode, Prefs.getBoolean(this.languageKey(link), true));
      }
      this.languageIsOn = on;
      this.languages = links;
      this.languagesLoading = false;
    }).catch((e: Error) => {
      console.error('feed card settings: languages unavailable: ' + e.message);
      this.languagesError = e.message;
      this.languagesLoading = false;
    });
  }

  private cardKey(): string {
    return exploreFeedCardKey(this.contentGroupKind);
  }

  private languageKey(link: MWKLanguageLink): string {
    return exploreFeedCardLanguageKey(this.contentGroupKind, link.contentLanguageCode);
  }

  // controlTag -1: toggleContentGroup(of:isOn:updateFeed:false) — the whole card.
  private toggleCard(isOn: boolean): void {
    this.cardIsOn = isOn;
    Prefs.putBoolean(this.cardKey(), isOn);
  }

  // a language row: toggleContentGroup(of:isOn:forSiteURL:updateFeed:false).
  private toggleLanguage(link: MWKLanguageLink, isOn: boolean): void {
    const next: Map<string, boolean> = new Map<string, boolean>();
    this.languageIsOn.forEach((value: boolean, key: string) => {
      next.set(key, value);
    });
    next.set(link.contentLanguageCode, isOn);
    this.languageIsOn = next;
    Prefs.putBoolean(this.languageKey(link), isOn);
  }

  // S5 (capture S0164 — pages/FeedCardSettingsViewController/base.png): iOS inset-grouped
  // table. Page gray200 (#EAECF0), white content-sized cards inset 20 vp on the capture's
  // 22 vp continuous radius; 13 vp uppercase gray header and 13/18 gray footer prose both
  // indented to the card's content edge (36 vp = the 20 vp card inset + its 16 vp padding).
  // NOTE: comp_settings_cell (components/WMFSettingsTableViewCell.ets, owned by
  // screen_settings_tab) always renders its 32 vp icon badge; the rows on THIS screen carry
  // no icon in the capture, so their title sits 52 vp further right than the source's.
  // The cell is outside this screen's write allowlist, so it is reported, not edited.

  // WMFTableHeaderFooterLabelView, .header / .footer.
  @Builder
  sectionHeader(text: string) {
    Text(upperText(getContext(this) as common.Context, text))
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 32, bottom: 8 })
  }

  // S6: the languages card's non-content states, on the comp_settings_cell row metrics.
  @Builder
  statusRow(message: string) {
    Row() {
      if (this.languagesLoading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.theme_secondary_text'))
          .margin({ right: 10 })
      }
      Text(message)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 17 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  sectionFooter(text: string) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16 })
      .margin({ top: 11 })
  }

  build() {
    Column() {
      // WMFNavigationBar: the push-navigation back button + the card's title.
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
          .accessibilityText('Back')
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        Text(this.cardTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 56, right: 56 })
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8, bottom: 32 })

      Scroll() {
        Column() {
          // MARK: mainSection — ExploreFeedSettingsPrimary(.singleFeedCard(kind))
          Column() {
            WMFSettingsTableViewCell({
              title: this.switchTitle,
              disclosureType: SettingsDisclosureType.toggle,
              rowId: 'show_in_the_news',
              isSwitchOn: this.cardIsOn,
              onToggle: (v: boolean): void => {
                this.toggleCard(v);
              }
            })
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .clip(true)
          this.sectionFooter(this.footerText)

          // MARK: languagesSection — omitted for a global card (kind.isGlobal).
          if (!this.isGlobalCard) {
            this.sectionHeader(this.text($r('app.string.languages_settings_title')))
            Column() {
              if (this.languagesLoading) {
                this.statusRow('Loading languages')
              } else if (this.languagesError !== '') {
                this.statusRow('Unable to load your languages')
              } else if (this.languages.length === 0) {
                this.statusRow('No languages yet')
              }
              ForEach(this.languages, (link: MWKLanguageLink) => {
                WMFSettingsTableViewCell({
                  title: link.localizedName,
                  subtitle: link.contentLanguageCode.toUpperCase(),
                  disclosureType: SettingsDisclosureType.toggle,
                  rowId: 'feed_card_language_itemroot',
                  isSwitchOn: this.languageIsOn.get(link.contentLanguageCode) ?? true,
                  onToggle: (v: boolean): void => {
                    this.toggleLanguage(link, v);
                  }
                })
              }, (link: MWKLanguageLink) => link.contentLanguageCode)
            }
            .width('100%')
            .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .borderRadius(22)
            .clip(true)
            this.sectionFooter(this.text($r('app.string.explore_feed_preferences_additional_languages_footer_text')) + ' ' +
              this.footerText)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('FeedCardSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }
}
