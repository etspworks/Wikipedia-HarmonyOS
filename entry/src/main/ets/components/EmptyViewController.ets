// comp_empty_view — ported from Wikipedia/Code/EmptyViewController.swift (a scroll view hosting
// one WMFEmptyView, centered) + Wikipedia/Code/WMFEmptyView.{h,m}, whose nib carries
// imageView / titleLabel / messageLabel / actionLabel + actionLine / button and whose factory
// methods remove the parts a given empty type does not use (noSearchResultsEmptyView keeps only
// messageLabel; noSavedPagesEmptyView keeps title + message; …). Each part is therefore
// optional here: pass '' to leave it out.
// Users: screen_notifications_center, screen_saved, screen_search.
// S5: styled on the app's baseline tokens (centered, secondary-gray message on the
// page background) — the source WMFEmptyView is plain centered text, no chrome.

@Component
export struct EmptyViewController {
  // WMFEmptyView.imageView — the empty type's artwork, omitted by the factory methods that
  // build a text-only empty view. Constant for the lifetime of the screen that mounts this
  // view, so a plain member (never re-assigned by the parent) is enough.
  emptyImage?: Resource;
  // WMFEmptyView.imageView height/width constraint (NotificationsCenterView: 185)
  imageSize: number = 185;
  // WMFEmptyView.titleLabel
  @Prop emptyTitle: string = '';
  // WMFEmptyView.messageLabel
  @Prop message: string = '';
  // WMFEmptyView.actionLabel (+ actionLine above it) — a footer note, not interactive
  @Prop actionText: string = '';
  // WMFEmptyView.button — the only interactive part of the empty view
  @Prop buttonTitle: string = '';
  // the calling screen's own source slug for that button (Rule 12)
  @Prop buttonId: string = 'empty_view_button';
  // S5 style knobs: the shared empty view is captured differently per host, so the
  // deviating values are passed in and DEFAULT to what every existing host renders
  // today (title 22 Bold, content-width radius-8 button) — no host but the one that
  // measures otherwise changes.
  @Prop titleFontSize: number = 22;
  @Prop buttonCapsule: boolean = false;
  onButtonTap?: () => void;

  build() {
    // EmptyViewController.scrollView + emptyContainerView, centered in the available height
    Scroll() {
      Column() {
        if (this.emptyImage !== undefined) {
          Image(this.emptyImage)
            .width(this.imageSize)
            .height(this.imageSize)
            .objectFit(ImageFit.Contain)
            .margin({ bottom: 15 })
        }
        if (this.emptyTitle !== '') {
          Text(this.emptyTitle)
            .textAlign(TextAlign.Center)
            .width('100%')
            .fontSize(this.titleFontSize)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.theme_text'))
            .margin({ bottom: 8 })
        }
        if (this.message !== '') {
          Text(this.message)
            .textAlign(TextAlign.Center)
            .width('100%')
            .fontSize(17)
            .lineHeight(24)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        if (this.actionText !== '') {
          // actionLine
          Divider()
            .width('100%')
            .strokeWidth(1)
            .color($r('app.color.gray200'))
            .margin({ top: 20, bottom: 12 })
          Text(this.actionText)
            .textAlign(TextAlign.Center)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.theme_secondary_text'))
        }
        if (this.buttonTitle !== '') {
          Button(this.buttonTitle)
            .id(this.buttonId)
            .type(ButtonType.Normal)
            .backgroundColor($r('app.color.theme_link'))
            .borderRadius(this.buttonCapsule ? 23 : 8)
            .fontSize(17)
            .fontColor($r('app.color.wmf_white'))
            .height(46)
            .width(this.buttonCapsule ? '100%' : undefined)
            .margin({ top: 20 })
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              if (this.onButtonTap !== undefined) {
                this.onButtonTap();
              }
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 32, right: 32, top: 48, bottom: 48 })
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Center)
    .scrollBar(BarState.Off)
  }
}
