// screen_temp_accounts_settings — presentation: page, pushed from screen_settings_tab.
// No outgoing nav edges in the inventory graph.
//
// S3 structure from Wikipedia/Code/Temp Accounts/TempAccountsSettingsViewController.swift:
// a SubSettingsViewController table with ONE section — titleForHeaderInSection is
// CommonStrings.tempAccount, the rows are the two WMFSettingsTableViewCells the view model
// builds (Talk page, icon "thank" on a blue600 badge, controlTag 1; End session, icon
// "person-circle-x" on a red600 badge, controlTag 2), both with the .viewController
// disclosure, and the section footer is "Temporary account will expire in 90 days".
// The nav bar carries a centerCompact "Temporary Account" title and the push back button.
// S4: didSelectRowAt case 1 -> showUserTalkPage() (UserTalkCoordinator for the temp
// username on the primary site); case 2 -> confirmEndTempAccountSession(), the "Exit
// session" alert with Log out / Cancel, whose Log out ends the session through svc_session.
// The header renders the temporary account's own name from svc_session
// (WMFCurrentUser.name where isTemp), falling back to the section title when no temporary
// session is active — which is the state the capture recorded.
// conditionalVariant (isTemp): with no temporary account the End session row is hidden and
// only the informational copy remains.
// S5: capture base.ui.json (402x874) — nav bar y62..116, the grouped header band y116..171,
// 44pt rows inset to [20,382] with their 30pt title column starting at x79, and the 13pt
// uppercase footer at y259.
import { upperText } from '../common/LocaleText';
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { WMFCurrentUser, WMFCurrentUserAuthState } from '../model/WMFCurrentUser';
import { SessionStore } from '../common/SessionStore';
import { Prefs } from '../common/Prefs';
import { WMFSettingsTableViewCell, SettingsDisclosureType } from '../components/WMFSettingsTableViewCell';

@Entry
@Component
struct TempAccountsSettingsViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfBaseBg') wmfBaseBg: string = '';

  // spec stateVar: items <- svc_session. TempAccountsSettingsViewController's view model
  // builds the section's rows from the session (`sections`/`items` in
  // TempAccountsSettingsViewController.swift): the Talk-page row always, the End-session row
  // only while a temporary account is active.
  @State items: string[] = [];
  @State currentUser: WMFCurrentUser | null = null;
  @State showEndSessionAlert: boolean = false;

  aboutToAppear(): void {
    try {
      Prefs.init(getContext(this) as common.UIAbilityContext);
      SessionStore.restore();
    } catch (e) {
      // svc_session is this screen's only data source; without it the page still renders
      // its informational copy rather than going blank.
      console.error('tempAccounts: session unavailable: ' + (e as Error).message);
    }
    this.currentUser = SessionStore.currentUser.value;
    this.items = this.isTemp() ? ['talk_page', 'end_session'] : ['talk_page'];
  }

  // WMFCurrentUser.name where isTemp — the temporary account this screen is about.
  private tempAccountName(): string {
    const u: WMFCurrentUser | null = this.currentUser;
    if (u !== null && u.authState === WMFCurrentUserAuthState.temporary && u.name !== '') {
      return u.name;
    }
    return 'Temporary Account';
  }

  private isTemp(): boolean {
    const u: WMFCurrentUser | null = this.currentUser;
    return u !== null && u.authState === WMFCurrentUserAuthState.temporary;
  }

  // showUserTalkPage(): UserTalkCoordinator(username:siteURL:).start()
  private openTalkPage(): void {
    const params: Record<string, string> = { 'talkPageTitle': 'User talk:' + this.tempAccountName() };
    router.pushUrl({ url: 'pages/TalkPageViewControllerPage', params: params });
  }

  // endTempAccountSession(): drop the temporary session and pop back to Settings.
  private endTempAccountSession(): void {
    try {
      SessionStore.clear();
    } catch (e) {
      console.error('tempAccounts: end session failed: ' + (e as Error).message);
    }
    this.currentUser = SessionStore.currentUser.value;
    router.back();
  }

  // confirmEndTempAccountSession()
  private confirmEndSession(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.settings_temp_account_end_session_title'),
      message: $r('app.string.settings_temp_account_end_session_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {
          console.info('tempAccounts: end session cancelled');
        }
      },
      secondaryButton: {
        value: $r('app.string.settings_temp_account_end_session_confirm'),
        fontColor: $r('app.color.theme_destructive'),
        action: (): void => {
          this.endTempAccountSession();
        }
      }
    });
  }

  private iconTint(color: string): ColorFilter {
    const n: number = parseInt(color.replace('#', ''), 16);
    return new ColorFilter([
      0, 0, 0, ((n >> 16) & 0xFF) / 255, 0,
      0, 0, 0, ((n >> 8) & 0xFF) / 255, 0,
      0, 0, 0, (n & 0xFF) / 255, 0,
      0, 0, 0, 1, 0
    ]);
  }

  build() {
    Column() {
      // WMFNavigationBar: push back button + centerCompact title.
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.chevron_left'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .colorFilter(this.iconTint('#3366CC'))
          }
          .id('BackButton')
          .accessibilityText('Temporary Account')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            router.back();
          })
          Blank()
        }
        .width('100%')

        Text($r('app.string.temporary_account'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          // titleForHeaderInSection — the temporary account this screen describes.
          Text(this.tempAccountName())
            .width('100%')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })

          Column() {
            if (this.items.indexOf('talk_page') >= 0) {
              WMFSettingsTableViewCell({
              title: 'Talk page',
              disclosureType: SettingsDisclosureType.viewController,
              rowId: 'talk_page',
              iconImage: $r('app.media.thank'),
              iconColor: $r('app.color.blue600'),
              onTap: (): void => {
                this.openTalkPage();
              }
              })
            }
            // conditionalVariant: currentUser.isTemp == false -> End session row hidden
            if (this.isTemp() && this.items.indexOf('end_session') >= 0) {
              WMFSettingsTableViewCell({
                title: 'End session',
                disclosureType: SettingsDisclosureType.viewController,
                rowId: 'end_session',
                iconImage: $r('app.media.person_circle_x'),
                iconColor: $r('app.color.red600'),
                onTap: (): void => {
                  this.confirmEndSession();
                }
              })
            }
          }
          .width('100%')
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(10)
          .clip(true)

          // WMFTableHeaderFooterLabelView, .footer
          Text(upperText(getContext(this) as common.Context, $r('app.string.settings_temp_accounts_talk_page_footer')))
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.theme_secondary_text'))
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 4, right: 4, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .id('TempAccountsSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfBaseBg !== '' ? this.wmfBaseBg : $r('app.color.theme_base_background')))
  }
}
