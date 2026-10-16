// comp_notifications_cell — ported from Wikipedia/Code/NotificationsCenterCell.swift setup():
//   foregroundContentContainer
//     leadingContainer > leadingImageView                (the notification-type glyph)
//     mainVerticalStackView
//       headerTextContainer > headerLabel + relativeTimeAgoLabel
//       internalHorizontalStackView
//         internalVerticalNotificationContentStack > subheaderLabel, messageSummaryLabel,
//                                                    metaStackView (metaImageView + metaLabel)
//         projectSourceContainer > projectSourceLabel / projectSourceImage
//   cellSeparator
// Text semantics from NotificationsCenterCellViewModel+TextExtensions.swift:
//   headerLabel        = verboseTitle (the type's title)
//   subheaderLabel     = "Alert from <agentName>"
//   messageSummaryLabel= message body
//   metaLabel          = footerText == notification.titleFull
//   relativeTimeAgoLabel = dateText
//   projectSourceLabel = the wiki's language code, uppercased
// The leading glyph is RemoteNotificationType.imageName, resolved from the (category, type)
// pair in RemoteNotification+CoreDataClass.typeFrom(category:type:section:).
// The swipe actions (More / Mark as read-unread) are the hosting list item's swipeAction
// (NotificationsCenterViewControllerPage.swipeButtons).
// Users: screen_notifications_center.
// S5: styled on the app baseline + the source cell's own type roles (NotificationsCenterCell
// fonts: header .headline, subheader .subheadline, message .callout, time .boldFootnote,
// meta .mediumFootnote, projectSourceLabel .caption1 in a bordered inset label). S0196
// captured the education modal, not the inbox, so the source styling is the ground truth.
import { RemoteNotification } from '../model/RemoteNotification';

@Component
export struct NotificationsCenterCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop item: RemoteNotification = new RemoteNotification();
  // NotificationsCenterCellDisplayState — an unread cell is drawn emphasized.
  @Prop isEditing: boolean = false;
  // NotificationsCenterCellDisplayState.isSelected (editing)
  @Prop isSelected: boolean = false;
  onTap?: () => void;

  // RemoteNotificationType.imageName, keyed on the echo category (the type only splits
  // categories that share one glyph, so the category is enough here).
  private leadingImage(): Resource {
    const category: string = this.item.categoryString !== null ? this.item.categoryString : '';
    if (category === 'edit-user-talk') {
      return $r('app.media.notifications_type_user_talk_message');
    }
    if (category === 'mention' || category === 'mention-success' || category === 'mention-failure') {
      return $r('app.media.notifications_type_mention');
    }
    if (category === 'reverted') {
      return $r('app.media.notifications_type_edit_revert');
    }
    if (category === 'user-rights') {
      return $r('app.media.notifications_type_user_rights');
    }
    if (category === 'page-review') {
      return $r('app.media.notifications_type_page_reviewed');
    }
    if (category === 'article-linked' || category === 'wikibase-action') {
      return $r('app.media.notifications_type_link');
    }
    if (category === 'edit-thank') {
      return $r('app.media.notifications_type_thanks');
    }
    if (category === 'cx' || category === 'thank-you-edit' || category === 'system-noemail') {
      return $r('app.media.notifications_type_milestone');
    }
    if (category === 'login-fail' || category === 'login-success' || category === 'system') {
      return $r('app.media.notifications_type_login_notify');
    }
    if (category === 'emailuser') {
      return $r('app.media.notifications_type_email');
    }
    return $r('app.media.notifications_type_default');
  }

  // headerLabel — commonViewModel.verboseTitle, the notification type's own title.
  private headerText(): string {
    const header: string | null = this.item.messageHeader;
    return header !== null ? header : '';
  }

  // subheaderLabel — "Alert from %1$@" with the origin agent.
  private subheaderText(): string {
    const agent: string | null = this.item.agentName;
    return agent !== null && agent !== '' ? 'Alert from ' + agent : '';
  }

  private bodyText(): string {
    const body: string | null = this.item.messageBody;
    return body !== null ? body : '';
  }

  // metaLabel — footerText == notification.titleFull
  private metaText(): string {
    const title: string | null = this.item.titleFull;
    return title !== null ? title : '';
  }

  // metaImageView — NotificationsCenterCellViewModel.footerIconType: the login types get a
  // lock, the unknown/system types a link, otherwise the title's namespace decides
  // (talk/user/userTalk -> person.circle.fill, main -> doc.plaintext.fill, file -> photo).
  private metaImage(): Resource {
    const category: string = this.item.categoryString !== null ? this.item.categoryString : '';
    if (category === 'login-fail' || category === 'login-success') {
      return $r('sys.symbol.lock');
    }
    if (category === 'system' || category === 'system-emailonly') {
      return $r('sys.symbol.link');
    }
    const ns: number = this.item.titleNamespaceKey;
    if (ns === 1 || ns === 2 || ns === 3) {
      return $r('sys.symbol.person_crop_circle_fill');
    }
    if (ns === 6) {
      return $r('sys.symbol.ohos_photo');
    }
    return $r('sys.symbol.doc_plaintext_fill');
  }

  // relativeTimeAgoLabel — dateText
  private dateText(): string {
    const date: number | null = this.item.date;
    if (date === null) {
      return '';
    }
    const minutes: number = Math.floor((Date.now() - date) / 60000);
    if (minutes < 1) {
      return 'now';
    }
    if (minutes < 60) {
      return minutes.toString() + 'm';
    }
    if (minutes < 1440) {
      return Math.floor(minutes / 60).toString() + 'h';
    }
    if (minutes < 10080) {
      return Math.floor(minutes / 1440).toString() + 'd';
    }
    return new Date(date).toLocaleDateString();
  }

  // projectSourceLabel — the wiki's language code, uppercased ("enwiki" -> "EN")
  private projectText(): string {
    const wiki: string | null = this.item.wiki;
    if (wiki === null || wiki === '') {
      return '';
    }
    return wiki.replace('wiki', '').toUpperCase();
  }

  build() {
    // Rule 12 list-row exception: one shared row id ending in `itemroot`, resolved by index.
    Column() {
      Row() {
        // leadingContainer > leadingImageView. Editing swaps the type glyph for the selection
        // circle: a secondary-text ring, filled with the link colour and a checkmark when the
        // cell is selected (NotificationsCenterCellStyle.leadingImage / -BackgroundColor /
        // -BorderColor).
        if (this.isEditing) {
          Stack() {
            if (this.isSelected) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor([Color.White])
            }
          }
          .id('notification_selection')
          .width(28)
          .height(28)
          .borderRadius(14)
          .border({ width: 1.5, color: this.isSelected ? $r('app.color.theme_link') : $r('app.color.theme_secondary_text') })
          .backgroundColor(this.isSelected ? $r('app.color.theme_link') : Color.Transparent)
          .margin({ right: 12, top: 2 })
        } else {
        Image(this.leadingImage())
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .opacity(this.item.isRead ? 0.5 : 1)
          .margin({ right: 12, top: 2 })
        }

        // mainVerticalStackView
        Column() {
          // headerTextContainer
          Row() {
            Text(this.headerText())
              .layoutWeight(1)
              .fontSize(17)
              .fontWeight(this.item.isRead ? FontWeight.Regular : FontWeight.Bold)
              .fontColor($r('app.color.theme_text'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.dateText())
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.theme_secondary_text'))
              .margin({ left: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // internalHorizontalStackView
          Row() {
            // internalVerticalNotificationContentStack
            Column() {
              Text(this.subheaderText())
                .width('100%')
                .fontSize(15)
                .fontWeight(this.item.isRead ? FontWeight.Regular : FontWeight.Bold)
                .fontColor($r('app.color.theme_secondary_text'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
              Text(this.bodyText())
                .width('100%')
                .fontSize(16)
                .lineHeight(22)
                .fontColor($r('app.color.theme_text'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
              // metaStackView (metaImageView from footerIconType, metaLabel)
              Row() {
                SymbolGlyph(this.metaImage())
                  .fontSize(14)
                  .fontColor([$r('app.color.theme_secondary_text')])
                Text(this.metaText())
                  .layoutWeight(1)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.theme_secondary_text'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 5 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ top: 6 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            // projectSourceContainer — the caption1 inset label in its own bordered pill
            Text(this.projectText())
              .fontSize(12)
              .fontColor($r('app.color.theme_secondary_text'))
              .borderRadius(4)
              .border({ width: 1, color: $r('app.color.theme_secondary_text') })
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .margin({ left: 8, top: 2 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 12, bottom: 12 })

      // cellSeparator
      Divider()
        .width('100%')
        .color($r('app.color.gray200'))
    }
    .id('notification_itemroot')
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16 })
    // a selected cell sits on batchSelectionBackground
    .backgroundColor(this.isEditing && this.isSelected ? $r('app.color.theme_batch_selection_background')
      : (this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .onClick(() => {
      if (this.onTap !== undefined) {
        this.onTap();
      }
    })
  }
}
