// screen_preferred_languages — presentation: modal, hosted by
// SettingsTabViewControllerPage (.bindContentCover). NOT a routed page.
// Hosts overlay: WMFLanguagesView (modal cover).
// Wired edge: preferred_languages -> explore_feed_settings (routed page).
//
// S3 structure from Wikipedia/Code/WMFLanguagesViewController.m
// (@implementation WMFPreferredLanguagesViewController, l.497) + its
// WMFLanguagesViewController+Extensions.swift navigation-bar config:
//   configureNavigationBarFromObjC: centerCompact title (= WMFCommonStrings
//   .wikipediaLanguages, "Wikipedia languages") + a leading plainX close button
//   (closeButtonPressed -> dismiss). hideLanguageFilter = YES on this subclass, so NO
//   search bar. updateEditButton puts editButtonItem on the right ONLY when
//   preferredLanguages.count > 1 — the capture (S0103) shows it disabled, and it is not on
//   this screen's controlInventory, so it is not rendered.
//   numberOfSectionsInTableView: showPreferredLanguages (section 0) +
//   showExploreFeedCustomizationSettings (section 1, set by the presenting
//   SettingsCoordinator/WMFSettingsViewController).
//   section 0 — header titleForHeaderInSection -> "YOUR LANGUAGES" (uppercased);
//     rows = languageFilter.filteredPreferredLanguages, each a WMFLanguageCell
//     (configureCell: languageName = link.name autonym, articleTitle = link.pageTitleText;
//     WMFPreferredLanguagesViewController.cellForRowAt sets isPrimary = (row == 0), which
//     renders the "PRIMARY" badge);
//     footer = WMFArticleLanguagesSectionFooter with buttonHidden:NO — the
//     "Add another language" button (addLanguageButtonTapped -> allLanguagesViewController
//     presented modally) above the "settings-primary-language-details" prose.
//   section 1 — header "EXPLORE FEED LANGUAGE SETTINGS"; one WMFSettingsTableViewCell
//     (configureExploreFeedCustomizationCell, disclosureType ViewController, title
//     WMFCommonStrings.customizeExploreFeedTitle) whose didSelectRowAt pushes
//     WMFExploreFeedSettingsViewController; footer = the
//     "settings-languages-feed-customization" prose with buttonHidden:YES.
// From Settings a preferred-language row has no effect (the delegate implements
// didUpdatePreferredLanguages, not didSelectLanguage). From the search language bar's More
// the delegate is SearchLanguagesBarViewController, whose didSelectLanguage makes the row
// the search language and dismisses the picker; a user talk page's Change language picks the
// wiki to reload on: onSelectLanguage.
// Rule 12: close_button / Preferred Languages Add Language Button / customize_explore_feed
// are the SOURCE slugs from the capture; the language rows share
// 'preferred_language_itemroot' (Rule 12's list-row exception).
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { LanguageStore } from '../common/LanguageStore';
import { Prefs, PrefKeys } from '../common/Prefs';
import { TALK_LANGUAGE_PICK_KEY, TalkLanguagePick } from '../common/TalkPageService';
import { upperText } from '../common/LocaleText';
import { localizedLanguageName } from '../common/LanguageService';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { NAV_ICON_BUTTON, NAV_TEXT_BUTTON, NAV_BUTTON_IMAGE_SIZE, NAV_BUTTON_SYMBOL_SIZE } from '../components/NavButton';

@Component
export struct WMFPreferredLanguagesView {
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // dismissal of the cover this view is mounted in (closeButtonPressed -> dismiss).
  onClose?: () => void;
  // languagesController(_:didSelectLanguage:) — set only when search or a talk page opened this.
  onSelectLanguage?: (link: MWKLanguageLink) => void;
  // rows <- MWKLanguageLinkController.preferredLanguages (bindingContract: svc_lang_store).
  @State items: MWKLanguageLink[] = [];
  // Bumped by the routed host on every onPageShow. A child component never receives
  // onPageShow itself, so the list stayed stale after the picker appended a language.
  @Prop @Watch('loadLanguages') showTick: number = 0;
  // S6: load/error visuals for the svc_lang_store read wired in S4.
  @State loading: boolean = true;
  @State loadError: string = '';
  // setEditing: — Edit turns the rows into an editable copy (minus to delete, drag to
  // reorder); Done commits it and dismisses, X dismisses and throws it away.
  @State editing: boolean = false;
  @State draft: MWKLanguageLink[] = [];
  // the row whose minus was tapped: it shows its Delete button (UITableView confirmation)
  @State armedDelete: string = '';
  private lastAddTap: number = 0;

  aboutToAppear(): void {
    this.loadLanguages();
  }

  // viewDidAppear -> loadLanguages -> reloadDataSections.
  private loadLanguages(): void {
    this.loading = true;
    this.loadError = '';
    LanguageStore.preferredLanguages().then((links: MWKLanguageLink[]) => {
      this.items = links;
      this.loading = false;
    }).catch((e: Error) => {
      console.error('preferred languages: load failed: ' + e.message);
      this.loadError = e.message;
      this.loading = false;
    });
  }

  @Builder
  deleteAction(link: MWKLanguageLink) {
    Button($r('app.string.article_delete'))
      .id('delete_language')
      .type(ButtonType.Normal)
      .height('100%')
      .fontSize(15)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.theme_destructive'))
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.deleteRow(link);
      })
  }

  private deleteRow(link: MWKLanguageLink): void {
    if (this.editing) {
      if (this.draft.length > 1) {
        this.draft = this.draft.filter((l: MWKLanguageLink): boolean =>
          l.contentLanguageCode !== link.contentLanguageCode);
      }
      this.armedDelete = '';
      return;
    }
    LanguageStore.removePreferredLanguage(link.contentLanguageCode).then(() => {
      this.loadLanguages();
    }).catch((e: Error) => {
      console.error('preferred languages: remove failed: ' + e.message);
    });
  }

  private startEditing(): void {
    this.draft = this.items.slice(0);
    this.armedDelete = '';
    this.editing = true;
  }

  // Done: save the edited order (removals included) and dismiss.
  private finishEditing(): void {
    const codes: string[] = this.draft.map((l: MWKLanguageLink): string => l.contentLanguageCode);
    const before: string[] = this.items.map((l: MWKLanguageLink): string => l.contentLanguageCode);
    this.editing = false;
    const done = (): void => this.closeButtonPressed();
    if (codes.join('|') === before.join('|')) {
      done();
      return;
    }
    LanguageStore.setPreferredCodes(codes).then(done).catch((e: Error) => {
      console.error('preferred languages: save failed: ' + e.message);
      done();
    });
  }

  private ctx(): common.Context {
    return getContext(this) as common.Context;
  }

  // S6: the section card's non-content states, styled on the S5 row metrics.
  @Builder
  statusRow(message: string) {
    Row() {
      if (this.loading) {
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
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  // S5 (capture S0103 — pages/WMFPreferredLanguagesViewController/base.png): iOS
  // inset-grouped modal. Page #EAECF0 (gray200), white content-sized cards inset 20 vp on
  // the 10 vp card radius, 13 vp uppercase gray section headers indented to the card's
  // content edge (36 vp), 13/18 gray footer prose at the 16 vp screen margin.
  // The capture also shows a trailing "Edit" pill in the navigation bar: it is disabled
  // there, the source installs editButtonItem only when preferredLanguages.count > 1, and
  // it is not on this screen's controlInventory — so it is not rendered.

  // WMFArticleLanguagesSectionHeader — the uppercased section title.
  @Builder
  sectionHeader(title: string) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 16, right: 16, top: 32, bottom: 8 })
  }

  // WMFArticleLanguagesSectionFooter titleLabel (setShortTextAsProse).
  @Builder
  sectionFooter(title: string) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor($r('app.color.theme_secondary_text'))
      .margin({ top: 12 })
  }

  // WMFLanguageCell: the autonym over the language's name in the device language, the
  // PRIMARY badge on the first row. Editing adds the leading red minus (and, once tapped,
  // the trailing Delete button) and the trailing reorder handle.
  @Builder
  languageRow(link: MWKLanguageLink, isPrimary: boolean) {
    Row() {
      if (this.editing && this.draft.length > 1) {
        SymbolGlyph($r('sys.symbol.minus_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.theme_destructive')])
          .margin({ right: 12 })
          .id('delete_language_minus')
          .onClick(() => {
            this.armedDelete = this.armedDelete === link.contentLanguageCode ? '' : link.contentLanguageCode;
          })
      }
      Column() {
        Text(link.name)
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.theme_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // the stored link can carry no translated name (English did not); ask ICU then
        Text(link.localizedName !== '' ? link.localizedName : localizedLanguageName(link.languageCode, link.name))
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (isPrimary) {
        Text(upperText(this.ctx(), $r('app.string.settings_primary_language')))
          .id('primary_badge')
          .fontSize(12)
          .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .backgroundColor($r('app.color.theme_secondary_text'))
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .margin({ left: 12 })
      }
      if (this.editing && this.armedDelete === link.contentLanguageCode) {
        Button($r('app.string.article_delete'))
          .id('delete_language')
          .type(ButtonType.Normal)
          .height(36)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.theme_destructive'))
          .borderRadius(6)
          .margin({ left: 12 })
          .onClick(() => {
            this.deleteRow(link);
          })
      }
      if (this.editing) {
        // reorder control: press and hold the row to drag it (ForEach.onMove)
        SymbolGlyph($r('sys.symbol.line_3_horizontal'))
          .id('reorder_handle')
          .fontSize(20)
          .fontColor([$r('app.color.theme_secondary_text')])
          .margin({ left: 12 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .id('preferred_language_itemroot')
    .onClick(() => {
      const cb: ((link: MWKLanguageLink) => void) | undefined = this.onSelectLanguage;
      if (cb !== undefined && !this.editing) {
        cb(link);
      }
    })
  }

  build() {
    Column() {
      // WMFNavigationBar: leading plainX close button, centerCompact title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.close'))
              .width(NAV_BUTTON_IMAGE_SIZE)
              .height(NAV_BUTTON_IMAGE_SIZE)
              .objectFit(ImageFit.Contain)
          }
          // Id scoping: this screen is an overlay, so its nodes share the host page's
          // component tree. The source slug is the part after the dot: close_button.
          .id('WMFPreferredLanguagesViewController.close_button')
          .attributeModifier(NAV_ICON_BUTTON)
          .accessibilityText($r('app.string.action_cancel'))
          .onClick(() => {
            this.closeButtonPressed();
          })
          Blank()
        }
        .width('100%')

        Text($r('app.string.languages_wikipedia'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
        // editButtonItem — installed when there is more than one language (updateEditButton);
        // while editing it is the Done check (link-blue glyph on the round title-bar button).
        if (this.items.length > 1 || this.editing) {
          Row() {
            Blank()
            if (this.editing) {
              Button() {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(NAV_BUTTON_SYMBOL_SIZE)
                  .fontColor([$r('app.color.theme_link')])
              }
              .id('preferred_languages_done')
              .attributeModifier(NAV_ICON_BUTTON)
              .onClick(() => {
                this.finishEditing();
              })
            } else {
              Button($r('app.string.edit_menu_item'))
                .id('preferred_languages_edit')
                .attributeModifier(NAV_TEXT_BUTTON)
                .fontColor($r('app.color.theme_link'))
                .onClick(() => {
                  this.startEditing();
                })
            }
          }
          .width('100%')
          // this full-width row sits over the X in the Stack; let taps outside its button through
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8, bottom: 10 })

      Scroll() {
        Column() {
          // MARK: preferred-languages section
          this.sectionHeader(upperText(this.ctx(), $r('app.string.article_languages_yours')))
          Column() {
            if (this.loading) {
              this.statusRow('Loading languages')
            } else if (this.loadError !== '') {
              this.statusRow('Unable to load your languages')
            } else if (this.items.length === 0) {
              this.statusRow('No languages yet')
            } else {
              // tableView:commitEditingStyle: a row swipes to Delete while more than one
              // language is left (canEditRowAtIndexPath). Without it a language added by
              // mistake could never be taken off the list.
              List() {
                if (this.editing) {
                  ForEach(this.draft, (link: MWKLanguageLink, index: number) => {
                    ListItem() {
                      this.languageRow(link, index === 0)
                    }
                    .swipeAction(this.draft.length > 1 ? { end: this.deleteAction(link) } : {})
                  }, (link: MWKLanguageLink) => link.contentLanguageCode)
                    // moveRowAtIndexPath: a held row drags to a new place (the draft only;
                    // onMove is bound once, so it lives on the edit-mode ForEach)
                    .onMove((from: number, to: number) => {
                      const next: MWKLanguageLink[] = this.draft.slice(0);
                      const moved: MWKLanguageLink[] = next.splice(from, 1);
                      next.splice(to, 0, moved[0]);
                      this.draft = next;
                    })
                } else {
                  ForEach(this.items, (link: MWKLanguageLink, index: number) => {
                    ListItem() {
                      this.languageRow(link, index === 0)
                    }
                    .swipeAction(this.items.length > 1 ? { end: this.deleteAction(link) } : {})
                  }, (link: MWKLanguageLink) => link.contentLanguageCode)
                }
              }
              .width('100%')
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .clip(true)
          // section footer: the add button above the primary-language prose.
          Button($r('app.string.welcome_languages_add_button'))
            .id('Preferred Languages Add Language Button')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .padding({ left: 0, right: 0, top: 8, bottom: 4 })
            .margin({ top: 2 })
            .onClick(() => {
              this.addLanguageButtonTapped();
            })
          this.sectionFooter(this.ctx().resourceManager.getStringSync($r('app.string.settings_primary_language_details')))

          // MARK: explore-feed customization section
          this.sectionHeader(upperText(this.ctx(), $r('app.string.explore_feed_language_settings')))
          Row() {
            Text($r('app.string.explore_customize_feed'))
              .layoutWeight(1)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            // Picker/disclosure accessory: iOS draws the chevron, ArkUI does not.
            Image($r('app.media.chevron_right'))
              .width(9)
              .height(16)
              .objectFit(ImageFit.Contain)
              .colorFilter(this.iconTint('#C8CCD1'))
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 13, bottom: 13 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(22)
          .clip(true)
          .id('customize_explore_feed')
          .onClick(() => {
            this.openExploreFeedSettings();
          })
          this.sectionFooter(this.ctx().resourceManager.getStringSync($r('app.string.settings_languages_feed_customization')))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('WMFPreferredLanguagesViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }

  // chevron_right.png is a solid-black raster template; .fillColor is SVG-only and
  // .colorBlend does not tint a raster, so rebuild the color from the alpha channel.
  private iconTint(hex: string): ColorFilter {
    const n: number = parseInt(hex.replace('#', ''), 16);
    const r: number = ((n >> 16) & 0xFF) / 255;
    const g: number = ((n >> 8) & 0xFF) / 255;
    const b: number = (n & 0xFF) / 255;
    return new ColorFilter([
      0, 0, 0, r, 0,
      0, 0, 0, g, 0,
      0, 0, 0, b, 0,
      0, 0, 0, 1, 0
    ]);
  }

  // addLanguageButtonTapped: opens the all-languages picker. It used to be a cover inside
  // this screen's own cover; a cover nested in a cover is destroyed mid-build here, so the
  // tap produced nothing at all. It is a routed page now.
  private addLanguageButtonTapped(): void {
    // a double tap pushed the picker twice
    if (Date.now() - this.lastAddTap < 1000) {
      return;
    }
    this.lastAddTap = Date.now();
    router.pushUrl({ url: 'pages/WMFLanguagesViewControllerPage' }).catch((e: Error) => {
      console.error('preferred languages: route failed: ' + e.message);
    });
  }

  private openExploreFeedSettings(): void {
    router.pushUrl({ url: 'pages/ExploreFeedSettingsViewControllerPage' });
  }

  // closeButtonPressed -> dismiss(animated:) + userDismissalCompletionBlock.
  private closeButtonPressed(): void {
    if (this.onClose !== undefined) {
      this.onClose();
    }
  }
}


// Routed host. The screen was presented with .bindContentCover from Search and from Settings,
// which drew its title and close button under the status bar and made the "Add another
// language" picker a cover inside a cover. As a page it gets the system inset and its own
// lifetime.
@Entry
@Component
struct PreferredLanguagesPage {
  // The picker appends the language itself, so the list is re-read on the way back.
  @State showTick: number = 0;

  // 'search' from the search language bar's More, 'talk' from a user talk page's Change
  // language: a row tap picks that language. '' (Settings, onboarding): rows do nothing.
  private selectsLanguageFor: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string> | undefined;
    this.selectsLanguageFor = params !== undefined && params !== null ? (params['selectsLanguageFor'] ?? '') : '';
  }

  private selectLanguage(contentLanguageCode: string, languageCode: string): void {
    if (this.selectsLanguageFor === 'search') {
      Prefs.putString(PrefKeys.searchLanguage, contentLanguageCode);
    } else {
      const pick: TalkLanguagePick = { languageCode: languageCode, articleTitle: '' };
      AppStorage.setOrCreate<string>(TALK_LANGUAGE_PICK_KEY, JSON.stringify(pick));
    }
    router.back();
  }

  onPageShow(): void {
    this.showTick++;
  }

  build() {
    Column() {
      WMFPreferredLanguagesView({
        showTick: this.showTick,
        onClose: (): void => {
          router.back();
        },
        // languagesController(_:didSelectLanguage:) then dismiss. Search re-reads the stored
        // language (wmf_currentSearchContentLanguageCode) when it shows again; the talk page
        // reads its pick from AppStorage.
        onSelectLanguage: this.selectsLanguageFor !== '' ? (link: MWKLanguageLink): void => {
          this.selectLanguage(link.contentLanguageCode, link.languageCode);
        } : undefined
      })
    }
    .width('100%')
    .height('100%')
  }
}
