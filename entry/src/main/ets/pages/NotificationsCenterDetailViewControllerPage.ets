// screen_notifications_center_detail — presentation: page (pushed from Notifications Center).
// S3 structure from Wikipedia/Code/NotificationsCenterDetailViewController.swift +
// NotificationsCenterDetailView.swift (grouped UITableView, 2 sections):
//   section 0: NotificationsCenterDetailHeaderCell (leading round type-icon 37x37 +
//              headerLabel over [subheaderLabel | dateLabel]),
//              NotificationsCenterDetailContentCell (bold contentTitle + contentBody),
//              NotificationsCenterDetailActionCell for viewModel.primaryAction (only when set),
//   section 1: one NotificationsCenterDetailActionCell per uniqueSecondaryActions row
//              (icon + link-styled titleLabel + trailing destinationLabel).
// Nav bar: "Notification Detail" title; back is the platform push-navigation affordance
// (implicit in plan controlInventory) — routed page, so an explicit back button renders it.
//
// S4 wiring. The source VC fetches nothing: it is handed a NotificationsCenterDetailViewModel
// built from one RemoteNotification, so this page reads that notification out of the local
// store (NotificationsService.cachedNotifications, written by the notifications center) and
// derives the same display fields:
//   headerTitle   — NotificationsCenterDetailViewModel+TextExtensions: "From {agentName}",
//                   falling back to the type title (commonViewModel.title).
//   headerSubtitle— commonViewModel.project name (ported model carries the wiki id).
//   headerDate    — commonViewModel.dateText (relative/short date off notification.date).
//   contentTitle /
//   contentBody   — commonViewModel.message / verboseTitle over messageHeader/messageBody,
//                   both .removingHTML.
//   actions       — NotificationsCenterDetailViewModel+ActionExtensions. The per-type action
//                   taxonomy (diffAction, userGroupRightsAction, …) is NOT ported; the
//                   generic path (actionForGenericLink over notification.messageLinks, which
//                   is what the ported RemoteNotification carries) is, including
//                   uniqueSecondaryActions' "drop anything sharing the primary URL" filter.
// Tap = the source didSelectRowAt: LinkCoordinator first (a wiki resource URL opens the
// native article page), else the legacy navigate (web view).
// S5 styling: iOS .insetGrouped table on theme baseBackground (#F8F9FA) with white
// content-sized cards (radius 10, 16pt inset); cell fonts from WMFFont (.boldCallout 16,
// .callout 16, .footnote 13); action rows in theme.colors.link, destinations secondaryText;
// inline centered nav title over a paperBackground bar with a hairline separator.
// Tokens from state.json generation.styleBaseline (screen_explore).
import { router } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import { RemoteNotification, RemoteNotificationLink, RemoteNotificationLinks } from '../model/RemoteNotification';
import { NotificationsService } from '../common/NotificationsService';
import { Database } from '../common/Database';

// UI-local row model for an action cell (NotificationsCenterAction: title + destinationText + url).
class NotificationDetailAction {
  title: string = '';
  destinationText: string = '';
  url: string = '';
}

function removingHTML(s: string | null): string {
  if (s === null) {
    return '';
  }
  return s.replace(/<[^>]+>/g, '').trim();
}

// URL+LinkParsing.doesOpenInBrowser — a wiki resource is handled natively, anything else
// leaves the app. CommonStrings.notificationsCenterDestination{App,Web}.
function opensInApp(url: string): boolean {
  return url.indexOf('/wiki/') >= 0;
}

function wikiTitleOf(url: string): string {
  const marker: string = '/wiki/';
  const i: number = url.indexOf(marker);
  if (i < 0) {
    return '';
  }
  return decodeURIComponent(url.substring(i + marker.length));
}

@Entry
@Component
struct NotificationsCenterDetailViewControllerPage {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  // The RemoteNotification the source hands to the detail view model.
  @State notification: RemoteNotification | null = null;
  @State headerTitle: string = '';
  @State headerSubtitle: string = '';
  @State headerDate: string = '';
  @State typeIconUrl: string = '';
  @State contentTitle: string = '';
  @State contentBody: string = '';
  @State primaryAction: NotificationDetailAction | null = null;
  @State secondaryActions: NotificationDetailAction[] = [];
  @State loading: boolean = true;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      await Database.init(getContext(this) as common.UIAbilityContext);
      const all: RemoteNotification[] = await NotificationsService.cachedNotifications();
      this.notification = this.select(all);
      this.applyViewModel();
    } catch (e) {
      this.errorText = (e as Error).message;
    } finally {
      this.loading = false;
    }
  }

  // The center pushes the tapped notification's key (falling back to its id); the store is
  // ordered date DESC, so a paramless entry (deep link) lands on the newest notification.
  private select(all: RemoteNotification[]): RemoteNotification | null {
    const params: Record<string, string> | undefined =
      router.getParams() as Record<string, string> | undefined;
    let key: string = '';
    if (params !== undefined && params !== null) {
      key = params['key'] ?? params['id'] ?? '';
    }
    if (key !== '') {
      for (const n of all) {
        if (n.key === key || n.id === key) {
          return n;
        }
      }
    }
    return all.length > 0 ? all[0] : null;
  }

  private applyViewModel(): void {
    const n: RemoteNotification | null = this.notification;
    if (n === null) {
      return;
    }
    const typeTitle: string = n.typeString ?? '';
    const agentName: string = n.agentName ?? '';
    this.headerTitle = agentName !== '' ? `From ${agentName}` : typeTitle;
    this.headerSubtitle = n.wiki ?? '';
    this.headerDate = n.date === null ? '' : new Date(n.date).toLocaleDateString();

    const header: string = removingHTML(n.messageHeader);
    const body: string = removingHTML(n.messageBody);
    this.contentTitle = header !== '' ? header : (n.titleFull ?? typeTitle);
    this.contentBody = body;

    this.applyActions(n.messageLinks);
  }

  private applyActions(links: RemoteNotificationLinks | null): void {
    this.primaryAction = null;
    this.secondaryActions = [];
    if (links === null) {
      return;
    }
    const primaryLink: RemoteNotificationLink | null = links.primary ?? links.legacyPrimary;
    const primary: NotificationDetailAction | null = this.actionForGenericLink(primaryLink);
    this.primaryAction = primary;

    // uniqueSecondaryActions: drop anything whose destination equals the primary's or an
    // already-listed secondary's.
    const seen: string[] = [];
    if (primary !== null) {
      seen.push(primary.url);
    }
    const out: NotificationDetailAction[] = [];
    for (const link of links.secondary) {
      const action: NotificationDetailAction | null = this.actionForGenericLink(link);
      if (action === null || seen.indexOf(action.url) >= 0) {
        continue;
      }
      seen.push(action.url);
      out.push(action);
    }
    this.secondaryActions = out;
  }

  // NotificationsCenterCommonViewModel+ActionExtensions.actionForGenericLink — needs both a
  // url and a label, destinationText from url.doesOpenInBrowser.
  private actionForGenericLink(link: RemoteNotificationLink | null): NotificationDetailAction | null {
    if (link === null) {
      return null;
    }
    const url: string = link.url ?? '';
    const label: string = link.label ?? '';
    if (url === '' || label === '') {
      return null;
    }
    const action: NotificationDetailAction = new NotificationDetailAction();
    action.title = label;
    action.url = url;
    action.destinationText = opensInApp(url) ? 'In app' : 'On web';
    return action;
  }

  // didSelectRowAt: LinkCoordinator (native article) first, legacy navigate (web) otherwise.
  private navigate(url: string): void {
    if (url === '') {
      return;
    }
    const title: string = wikiTitleOf(url);
    if (title !== '') {
      const articleParams: Record<string, string> = { 'articleTitle': title };
      router.pushUrl({ url: 'pages/ArticleViewControllerPage', params: articleParams });
      return;
    }
    const webParams: Record<string, string> = { 'url': url };
    router.pushUrl({ url: 'pages/SinglePageWebViewControllerPage', params: webParams });
  }

  // Primary action reads the @State field directly — ArkUI's build() transform does not
  // carry TS null-narrowing into a builder-call argument.
  @Builder
  primaryActionRow() {
    Row() {
      // titleLabel: WMFFont .callout, theme.colors.link
      Text(this.primaryAction?.title ?? '')
        .maxLines(1)
        .layoutWeight(1)
        .fontSize(16)
        .fontColor($r('app.color.theme_link'))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // destinationLabel: .footnote, secondaryText, 3pt spacer before it
      Text(this.primaryAction?.destinationText ?? '')
        .maxLines(1)
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ left: 3 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius({ bottomLeft: 10, bottomRight: 10 })
  }

  @Builder
  actionRow(action: NotificationDetailAction) {
    Row() {
      Text(action.title)
        .maxLines(1)
        .layoutWeight(1)
        .fontSize(16)
        .fontColor($r('app.color.theme_link'))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(action.destinationText)
        .maxLines(1)
        .fontSize(13)
        .fontColor($r('app.color.theme_secondary_text'))
        .margin({ left: 3 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(10)
    .margin({ top: 8 })
  }

  // NotificationsCenterDetailHeaderCell
  @Builder
  headerCell() {
    Row() {
      // RoundedImageView 37x37 in a 45pt leading container, tinted onto the type color
      Image(this.typeIconUrl)
        .width(37)
        .height(37)
        .borderRadius(18.5)
        .backgroundColor($r('app.color.theme_link'))
        .objectFit(ImageFit.Contain)
      Column() {
        // headerLabel: .boldCallout, primaryText
        Text(this.headerTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.theme_text'))
          .width('100%')
        // detailLabelStackView: spacing 3 below headerLabel, 6 between its two labels
        Row() {
          Text(this.headerSubtitle)
            .layoutWeight(1)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.headerDate)
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ left: 6 })
        }
        .width('100%')
        .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(16)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius({ topLeft: 10, topRight: 10 })
  }

  // NotificationsCenterDetailContentCell
  @Builder
  contentCell() {
    Column() {
      // attributedTitle: .boldCallout; attributedBody: .callout with lineSpacing 1.7,
      // joined by the source's "\n\n" prefix (rendered here as the 16pt gap).
      Text(this.contentTitle)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.theme_text'))
        .width('100%')
      if (this.contentBody !== '') {
        Text(this.contentBody)
          .fontSize(16)
          .lineHeight(24)
          .fontColor($r('app.color.theme_text'))
          .width('100%')
          .margin({ top: 16 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }

  @Builder
  detailList() {
    List() {
      // Section 0 — header, content, optional primary action.
      ListItem() {
        this.headerCell()
      }
      ListItem() {
        this.contentCell()
      }
      if (this.primaryAction !== null) {
        ListItem() {
          this.primaryActionRow()
        }
        .onClick((): void => {
          this.navigate(this.primaryAction?.url ?? '');
        })
        .id('notification_primary_action')
      }
      // Section 1 — uniqueSecondaryActions.
      ForEach(this.secondaryActions, (action: NotificationDetailAction) => {
        ListItem() {
          this.actionRow(action)
        }
        .onClick((): void => {
          this.navigate(action.url);
        })
        .id('notification_secondary_action_itemroot')
      }, (action: NotificationDetailAction) => action.title + action.destinationText)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      // WMFNavigationBarTitleConfig("Notification Detail") + push-navigation back.
      Row() {
        Button() {
          Text('\u2039')
            .fontSize(30)
            .fontWeight(FontWeight.Regular)
            .fontColor($r('app.color.theme_link'))
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .width(44)
        .height(44)
        .onClick((): void => {
          router.back();
        })
        .id('back')
        // inline nav title: centered in the bar, offset by the 44pt back slot
        Text('Notification Detail')
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .padding({ right: 44 })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)
      .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      .border({ width: { bottom: 0.5 }, color: $r('app.color.gray200') })

      // Loading / error / empty / content — mutually exclusive.
      if (this.loading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color($r('app.color.theme_link'))
          .margin({ top: 32 })
      } else if (this.errorText !== '') {
        Text(this.errorText)
          .layoutWeight(1)
          .width('100%')
          .fontSize(16)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .padding(24)
      } else if (this.notification === null) {
        Text('No notification')
          .layoutWeight(1)
          .width('100%')
          .fontSize(16)
          .fontColor($r('app.color.theme_secondary_text'))
          .textAlign(TextAlign.Center)
          .padding(24)
      } else {
        this.detailList()
      }
    }
    .id('NotificationsCenterDetailViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
