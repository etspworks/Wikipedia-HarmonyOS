// comp_welcome_panels — ported from Wikipedia/Code/WMFWelcomePanelViewController.swift:
// the panel below each onboarding animation. It carries a titleLabel, the embedded
// containerController for its WMFWelcomePageType, and a capsule nextButton whose container
// is hidden on every page except .analytics ("Get started").
//   .intro      -> WMFWelcomeIntroductionViewController: descriptionLabel + the
//                  "Learn more about Wikipedia" link button (introductionLearnMoreButton),
//                  on a view identified "App Onboarding Introduction View".
//   .exploration-> WMFWelcomeExplorationViewController: the Explore feed / Places tab /
//                  On this day title+description pairs.
//   .languages  -> WMFWelcomeLanguageTableViewController: the device's preferred languages
//                  plus the "Add another language" button.
//   .analytics  -> WMFWelcomeAnalyticsViewController: the privacy copy plus the
//                  privacy-policy-and-terms link button.
// Used by screen_welcome_initial.
// S5: styled on the app baseline tokens — 24pt bold title, 15pt body on secondaryText,
// 15pt link buttons on theme.colors.link, the capsule button on link/paperBackground.
import { i18n } from '@kit.LocalizationKit';
import { MWKLanguageLink } from '../model/MWKLanguageLink';
import { LanguageStore } from '../common/LanguageStore';
import { Database } from '../common/Database';
import { Subscription } from '../common/Reactive';
import { common } from '@kit.AbilityKit';

@Component
export struct WMFWelcomePanelViewController {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // welcomePageType: 'intro' | 'exploration' | 'languages' | 'analytics'
  @Prop pageType: string = 'intro';
  onLearnMore: () => void = () => {
    console.info('welcome: learn more');
  };
  onGetStarted: () => void = () => {
    console.info('welcome: get started');
  };
  // .analytics: the privacy-policy / terms-of-use link
  onPrivacy: () => void = () => {
  };
  onAddLanguage: () => void = () => {
    console.info('welcome: add language');
  };

  // Uppercased in the device language: TextCase.UpperCase is locale-insensitive and turns
  // Turkish "Birincil" into "BIRINCIL" instead of "BİRİNCİL".
  private primaryLabel(): string {
    try {
      const label: string = getContext(this).resourceManager
        .getStringSync($r('app.string.settings_primary_language'));
      return label.toLocaleUpperCase(i18n.System.getSystemLanguage());
    } catch (e) {
      return '';
    }
  }

  // WMFWelcomeLanguageTableViewController.languages
  @State languages: MWKLanguageLink[] = [];

  private languagesSub: Subscription | null = null;

  aboutToAppear(): void {
    if (this.pageType !== 'languages') {
      return;
    }
    this.loadLanguages();
    // back from the language editor with a changed list
    this.languagesSub = LanguageStore.languagesDidChange.subscribe((): void => {
      this.loadLanguages();
    });
  }

  aboutToDisappear(): void {
    this.languagesSub?.dispose();
  }

  // Onboarding is the first screen of a fresh install, so the store is opened here: nothing
  // before it has, and the list stayed empty. Database.init is memoized.
  private loadLanguages(): void {
    Database.init(getContext(this) as common.UIAbilityContext)
      .then((): Promise<MWKLanguageLink[]> => LanguageStore.preferredLanguages())
      .then((langs: MWKLanguageLink[]) => {
        this.languages = langs;
      }).catch((e: Error) => {
        // The onboarding panel still renders its copy without the detected languages.
        console.error('welcome: preferred languages unavailable: ' + e.message);
      });
  }

  private title(): Resource {
    if (this.pageType === 'exploration') {
      return $r('app.string.welcome_explore_new_ways_title');
    }
    if (this.pageType === 'languages') {
      return $r('app.string.welcome_languages_search_title');
    }
    if (this.pageType === 'analytics') {
      return $r('app.string.welcome_data_privacy_title');
    }
    return $r('app.string.welcome_intro_free_encyclopedia_title');
  }

  // WMFWelcomeExplorationViewController's three title/description pairs.
  @Builder
  explorationRow(title: Resource, body: Resource) {
    Column() {
      Text(title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.theme_text'))
      Text(body)
        .width('100%')
        .fontSize(15)
        .lineHeight(20)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ top: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 14 })
  }

  build() {
    Column() {
      Text(this.title())
        .width('100%')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)

      if (this.pageType === 'intro') {
        Column() {
          Text($r('app.string.welcome_intro_free_encyclopedia_description'))
            .width('100%')
            .fontSize(15)
            .lineHeight(20)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 20 })
          // a label Button keeps to one line and cut the link to 'daha fazla şey ...'; the
          // source's link wraps, so the label is a Text inside the button
          Button() {
            Text($r('app.string.welcome_intro_free_encyclopedia_more'))
              .width('100%')
              .fontSize(15)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
          }
          .id('App Onboarding Introduction Learn More Button')
          .accessibilityText($r('app.string.welcome_intro_free_encyclopedia_more'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .margin({ top: 2 })
            .onClick(() => {
              this.onLearnMore();
            })
        }
        .id('App Onboarding Introduction View')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else if (this.pageType === 'exploration') {
        Column() {
          this.explorationRow($r('app.string.welcome_exploration_explore_feed_title'),
            $r('app.string.welcome_exploration_explore_feed_description'))
          this.explorationRow($r('app.string.welcome_exploration_places_title'),
            $r('app.string.welcome_exploration_places_description'))
          this.explorationRow($r('app.string.welcome_exploration_on_this_day_title'),
            $r('app.string.welcome_exploration_on_this_day_description'))
        }
        .id('App Onboarding Exploration View')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 6 })
      } else if (this.pageType === 'languages') {
        Column() {
          Text($r('app.string.welcome_languages_description'))
            .width('100%')
            .fontSize(15)
            .lineHeight(20)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 20 })
          // WMFLanguageCell: the first preferred language carries the grey "PRIMARY" pill.
          ForEach(this.languages, (lang: MWKLanguageLink, index: number) => {
            Row() {
              // the language's own name, as the source's cell ('English', not 'İngilizce')
              Text(lang.name !== '' ? lang.name : lang.localizedName)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor($r('app.color.theme_text'))
              if (index === 0) {
                Text(this.primaryLabel())
                  .id('App Onboarding Primary Language Badge')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  // WMFLanguageCell: paper-coloured text on a secondaryText pill, so the badge
                  // reads in both themes (grey on gray200 all but vanished in dark mode)
                  .fontColor($r('app.color.theme_paper_background'))
                  .backgroundColor($r('app.color.theme_secondary_text'))
                  .borderRadius(3)
                  .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 10 })
          }, (lang: MWKLanguageLink) => lang.languageCode)
          // the source: 'Add or edit preferred languages' once more than one is listed
          Button(this.languages.length > 1 ? $r('app.string.welcome_languages_add_or_edit_button')
            : $r('app.string.welcome_languages_add_button'))
            .id('App Onboarding Add Language Button')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .height(32)
            .padding(0)
            .fontSize(15)
            .fontColor($r('app.color.theme_link'))
            .margin({ top: 12 })
            .onClick(() => {
              this.onAddLanguage();
            })
        }
        .id('App Onboarding Languages View')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Column() {
          Text($r('app.string.welcome_privacy_subtitle'))
            .width('100%')
            .fontSize(15)
            .lineHeight(20)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 20 })
          // a Text label wraps to every line it needs (the label style still cut it at two)
          Button() {
            Text($r('app.string.welcome_privacy_terms_button_text'))
              .width('100%')
              .fontSize(15)
              .lineHeight(20)
              .fontColor($r('app.color.theme_link'))
          }
          .id('App Onboarding Analytics Learn More Button')
          .accessibilityText($r('app.string.welcome_privacy_terms_button_text'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .margin({ top: 2 })
            .onClick(() => {
              this.onPrivacy();
            })
          // nextButtonContainerView is only unhidden for .analytics
          Button($r('app.string.welcome_explore_continue_button'))
            .id('App Onboarding Get Started Button')
            .type(ButtonType.Capsule)
            .height(46)
            .constraintSize({ minWidth: 220 })
            .fontSize(17)
            .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
            .backgroundColor($r('app.color.theme_link'))
            .margin({ top: 24 })
            .onClick(() => {
              this.onGetStarted();
            })
        }
        .id('App Onboarding Analytics View')
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
