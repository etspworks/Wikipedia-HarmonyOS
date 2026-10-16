// comp_page_history_cell — ported from Wikipedia/Code/PageHistoryCollectionViewCell.swift
// (setup + sizeThatFits). One revision row: an optional leading BatchEditSelectView shown
// only in compare (editing) mode, then two panes inside roundedContent/editableContent —
// leading pane timeLabel over sizeDiffLabel ("+N" / "-N"), trailing pane authorButton
// (author icon + user name) over the 2-line commentLabel, which is prefixed by the
// minor-edit glyph when the revision isMinor and falls back to "Empty edit summary".
// The author icon is "user-edit", "anon" (isAnon) or the temp glyph (isTemp).
// Users: screen_page_history.
// S5 (captures S0316/S0317): styled from the source's own apply(theme:)/updateFonts —
// roundedContent radius 6, 1pt theme.colors.border, paperBackground, inner margins 15;
// timeLabel .mediumSubheadline secondaryText; sizeDiffLabel .mediumSubheadline in
// accent (>0) / destructive (<0) / link (0); authorButton .footnote link; commentLabel
// .footnote primaryText, .italicFootnote secondaryText when empty. Leading pane is
// availableWidth/3, trailing the rest (layoutWeight 1 : 2).

@Component
export struct PageHistoryCollectionViewCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // WMFPageHistoryRevision fields, as configure(cell:at:) assigns them.
  @Prop displayTime: string = '';
  @Prop author: string = '';
  @Prop isAnon: boolean = false;
  @Prop isTemp: boolean = false;
  @Prop sizeDiff: number = 0;
  @Prop comment: string = '';
  @Prop isMinor: boolean = false;
  // state == .editing (compare selection mode) and this row's selection.
  @Prop isEditing: boolean = false;
  @Prop isSelected: boolean = false;
  // enableEditing(!maxNumberOfRevisionsSelected)
  @Prop isEditingEnabled: boolean = true;

  private authorImage(): Resource {
    if (this.isAnon) {
      return $r('app.media.anon');
    }
    if (this.isTemp) {
      return $r('app.media.temp');
    }
    return $r('app.media.user_edit');
  }

  private selectImage(): Resource {
    if (this.isSelected) {
      return $r('app.media.selected');
    }
    if (!this.isEditingEnabled) {
      return $r('app.media.selection_disabled');
    }
    return $r('app.media.unselected');
  }

  // sizeDiffLabel.text = added ? "+\(sizeDiff)" : "\(sizeDiff)"
  private sizeDiffText(): string {
    return this.sizeDiff > 0 ? '+' + this.sizeDiff.toString() : this.sizeDiff.toString();
  }

  // CommonStrings.emptyEditSummary when the revision carries no comment.
  private commentText(): ResourceStr {
    return this.comment === '' ? $r('app.string.empty_edit_summary') : this.comment;
  }

  // sizeDiffLabel colour: accent when bytes were added, destructive when removed,
  // link when the revision changed nothing.
  private sizeDiffColor(): Resource {
    if (this.sizeDiff > 0) {
      return $r('app.color.theme_accent');
    }
    if (this.sizeDiff < 0) {
      return $r('app.color.theme_destructive');
    }
    return $r('app.color.theme_link');
  }

  build() {
    Row() {
      // selectView — alpha 0 outside editing mode.
      if (this.isEditing) {
        Image(this.selectImage())
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .margin({ right: 10 })
      }

      // leading pane
      Column() {
        Text(this.displayTime)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_secondary_text'))
          .maxLines(1)
        Text(this.sizeDiffText())
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.sizeDiffColor())
          .margin({ top: 10 })
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // trailing pane
      Column() {
        Row() {
          Image(this.authorImage())
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
          Text(this.author)
            .fontSize(13)
            .fontColor($r('app.color.theme_link'))
            .margin({ left: 8 })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          if (this.isMinor) {
            Image($r('app.media.minor_edit'))
              .width(14)
              .height(14)
              .objectFit(ImageFit.Contain)
              .margin({ right: 4 })
          }
          Text(this.commentText())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .fontSize(13)
            .fontStyle(FontStyle.Italic)
            .fontColor(this.comment === ''
              ? $r('app.color.theme_secondary_text')
              : $r('app.color.theme_text'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 6 })
      }
      .layoutWeight(2)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 15, right: 15, top: 12, bottom: 12 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(6)
    .border({ width: 1, color: $r('app.color.theme_border') })
  }
}
