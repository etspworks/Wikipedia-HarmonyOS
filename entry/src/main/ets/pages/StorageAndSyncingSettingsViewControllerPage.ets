// screen_storage_and_syncing — Wikipedia/Code/StorageAndSyncingSettingsViewController.swift.
// Settings > Article storage and syncing: the "Sync saved articles and lists" switch (turning
// it off asks first, as the source's disable-sync alert does), the "Show Saved reading list"
// switch (the default list as its own row in Saved > Reading lists), and "Update synced
// reading lists", which requests a full sync and says so. Settings opened it as a cover that
// held one bare switch; it is a routed page like the other settings screens.
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Prefs } from '../common/Prefs';
import { ReadingListSyncService } from '../common/ReadingListSyncService';
import { SessionStore } from '../common/SessionStore';
import { Database } from '../common/Database';
import { SavedStore } from '../common/SavedStore';
import { WMFArticle } from '../model/WMFArticle';

export const SYNC_ENABLED_KEY: string = 'WMFIsSyncEnabled';
export const SHOW_DEFAULT_LIST_KEY: string = 'WMFShowDefaultReadingList';

interface SwitchCardParams {
  title: Resource;
  id: string;
  isOn: boolean;
  onChange: (isOn: boolean) => void;
}

@Entry
@Component
struct StorageAndSyncingSettingsPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State syncEnabled: boolean = false;
  @State showDefaultList: boolean = false;
  // eraseSavedArticles: the confirmation panel (image, title, confirm button, footer)
  @State showErasePanel: boolean = false;

  aboutToAppear(): void {
    this.syncEnabled = Prefs.getBoolean(SYNC_ENABLED_KEY, false);
    this.showDefaultList = Prefs.getBoolean(SHOW_DEFAULT_LIST_KEY, false);
  }

  private text(res: Resource): string {
    return (getContext(this) as common.Context).resourceManager.getStringSync(res);
  }

  // ReadingListsController.setSyncEnabled; turning it off asks first (the source's alert).
  private setSyncEnabled(isOn: boolean): void {
    if (isOn) {
      // the switch coming back on after "No" (sync never went off) is not a new setup
      if (Prefs.getBoolean(SYNC_ENABLED_KEY, false)) {
        this.syncEnabled = true;
        return;
      }
      this.applySync(true);
      return;
    }
    // mirror the switch's own off position first: "No" then sets it back to on, a real change
    // that redraws the switch (re-assigning an unchanged true left it showing off)
    this.syncEnabled = false;
    this.getUIContext().showAlertDialog({
      title: $r('app.string.settings_storage_and_syncing_disable_sync_alert_title'),
      message: $r('app.string.settings_storage_and_syncing_disable_sync_alert_message'),
      autoCancel: false,
      primaryButton: {
        value: $r('app.string.settings_storage_and_syncing_disable_sync_alert_no'),
        action: () => {
          this.syncEnabled = true;
        }
      },
      secondaryButton: {
        value: $r('app.string.settings_storage_and_syncing_disable_sync_alert_yes'),
        action: () => {
          this.applySync(false);
        }
      }
    });
  }

  private applySync(isOn: boolean): void {
    this.syncEnabled = isOn;
    Prefs.putBoolean(SYNC_ENABLED_KEY, isOn);
    if (!SessionStore.isLoggedIn) {
      return;
    }
    const call: Promise<void> = isOn ? ReadingListSyncService.setup() : ReadingListSyncService.teardown();
    call.then(() => {
      if (isOn) {
        this.fullSync();
      }
    }).catch((e: Error) => {
      console.error('storage: sync toggle failed: ' + e.message);
      promptAction.showToast({ message: $r('app.string.reading_lists_sync_error_no_internet_connection') });
    });
  }

  // "Update synced reading lists": a full sync in the background, announced as the source does.
  private fullSync(): void {
    promptAction.showToast({ message: $r('app.string.settings_storage_and_syncing_full_sync') });
    Database.init(getContext(this) as common.UIAbilityContext)
      .then(() => ReadingListSyncService.syncToDatabase())
      .catch((e: Error) => {
        console.error('storage: full sync failed: ' + e.message);
        promptAction.showToast({ message: $r('app.string.reading_lists_sync_error_no_internet_connection') });
      });
  }

  private eraseSavedArticles(): void {
    this.showErasePanel = false;
    Database.init(getContext(this) as common.UIAbilityContext)
      .then(() => SavedStore.savedArticles())
      .then(async (articles: WMFArticle[]) => {
        for (const a of articles) {
          if (a.key !== null) {
            await SavedStore.userUnsave(a.key);
          }
        }
        promptAction.showToast({ message: $r('app.string.settings_storage_and_syncing_erase_saved_articles_done') });
      })
      .catch((e: Error) => {
        console.error('storage: erase saved articles failed: ' + e.message);
      });
  }

  @Builder
  erasePanel() {
    Column() {
      Image($r('app.media.saved_blank'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
        .margin({ top: 24 })
      Text($r('app.string.settings_storage_and_syncing_erase_saved_articles_panel_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
      Button($r('app.string.settings_storage_and_syncing_erase_saved_articles_button'))
        .id('erase_saved_articles_confirm')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.theme_destructive'))
        .margin({ top: 24 })
        .onClick(() => {
          this.eraseSavedArticles();
        })
      Text($r('app.string.settings_storage_and_syncing_erase_saved_articles_footer'))
        .width('100%')
        .fontSize(13)
        .lineHeight(18)
        .fontColor($r('app.color.theme_secondary_text'))
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 32 })
  }

  @Builder
  footer(res: Resource) {
    Text(res)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor($r('app.color.theme_secondary_text'))
      .padding({ left: 20, right: 20, top: 8, bottom: 20 })
  }

  // One object argument: ArkUI passes it by reference, so the switch follows its state
  // variable - a plain boolean argument is copied and the switch never redrew (the sync
  // switch stayed off after "No" restored the setting).
  @Builder
  switchCard(p: SwitchCardParams) {
    Row() {
      Text(p.title)
        .layoutWeight(1)
        .fontSize(17)
        .fontColor($r('app.color.theme_text'))
      Toggle({ type: ToggleType.Switch, isOn: p.isOn })
        .id(p.id)
        .margin({ left: 12 })
        .onChange(p.onChange)
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 20, right: 16, top: 8, bottom: 8 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(28)
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.theme_text')])
        }
        .id('BackButton')
        .type(ButtonType.Circle)
        .width(44)
        .height(44)
        .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
        .onClick(() => {
          router.back();
        })
        Text($r('app.string.settings_storage_and_syncing_title'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(2)
        Blank()
          .width(44)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })

      Scroll() {
        Column() {
          this.switchCard({ title: $r('app.string.settings_storage_and_syncing_enable_sync_title'),
            id: 'sync_saved_articles', isOn: this.syncEnabled, onChange: (isOn: boolean) => {
              this.setSyncEnabled(isOn);
            } })
          this.footer($r('app.string.settings_storage_and_syncing_enable_sync_footer_text'))
          this.switchCard({ title: $r('app.string.settings_storage_and_syncing_show_default_reading_list_title'),
            id: 'show_saved_reading_list', isOn: this.showDefaultList, onChange: (isOn: boolean) => {
              this.showDefaultList = isOn;
              Prefs.putBoolean(SHOW_DEFAULT_LIST_KEY, isOn);
            } })
          this.footer($r('app.string.settings_storage_and_syncing_show_default_reading_list_footer_text'))
          Row() {
            Text($r('app.string.settings_storage_and_syncing_server_sync_title'))
              .layoutWeight(1)
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([$r('app.color.theme_secondary_text')])
          }
          .id('update_synced_reading_lists')
          .width('100%')
          .height(56)
          .padding({ left: 20, right: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(28)
          .onClick(() => {
            this.fullSync();
          })
          this.footer($r('app.string.settings_storage_and_syncing_server_sync_footer_text'))
          // eraseSavedArticles row (destructive)
          Row() {
            Text($r('app.string.settings_storage_and_syncing_erase_saved_articles_title'))
              .layoutWeight(1)
              .fontSize(17)
              .fontColor($r('app.color.theme_destructive'))
          }
          .id('erase_saved_articles')
          .width('100%')
          .height(56)
          .padding({ left: 20, right: 16 })
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .borderRadius(28)
          .onClick(() => {
            this.showErasePanel = true;
          })
          .bindSheet($$this.showErasePanel, this.erasePanel(),
            { height: SheetSize.FIT_CONTENT, dragBar: true, showClose: true })
        }
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .id('StorageAndSyncingSettingsViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
