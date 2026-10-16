// comp_talk_page_cell — ported from Wikipedia/Code/TalkPageCell.swift (rootContainer >
// stackView > topicView, plus the expanded elements appended in configure(viewModel:…):
// a lead-reply spacer/button and, per reply, a TalkPageCellCommentSeparator +
// TalkPageCellCommentView) and Wikipedia/Code/TalkPageCellTopicView.swift, whose
// setup()/configure() re-arranges three exclusive layouts:
//   expanded          -> [subscribe, spacer, disclosure] / title / metadata / comment
//   collapsed w/ lead -> [title, spacer, disclosure] / metadata / comment
//   other content     -> [title, spacer, disclosure] / comment          (no metadata row)
// The metadata row is timestamp | spacer | activeUsers | spacer | repliesCount.
// The subscribe button shows for a signed-in reader on a titled topic (configure's
// shouldHideSubscribe).
// Users: screen_talk_page.
// S5: styled from captured states S0279 (collapsed cards) / S0280 (expanded thread) —
// white content-sized card on the grouped gray page, 10pt radius, hairline border; topic
// title 20 regular, metadata 15 secondary with person/bubble glyphs, comment 17/24.
import { TalkPageItem } from '../model/TalkPageItem';

// The API returns HTML fragments (threaditemshtml); the cell's text views render attributed
// text, so strip the markup for the plain Text nodes.
function stripTags(html: string): string {
  return html.replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&ndash;/g, '–')
    .replace(/&mdash;/g, '—')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, '\'')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

// TalkPageFindInPageSearchController.search order: the topic title, the lead comment (or
// the other content), then each reply.
export function talkFindTexts(item: TalkPageItem): string[] {
  const title: string = item.html !== null ? stripTags(item.html) : '';
  const texts: string[] = [title !== '' ? title : (item.name ?? '')];
  const all: TalkPageItem[] = item.replies;
  if (all.length > 0) {
    for (const reply of all) {
      texts.push(reply.html !== null ? stripTags(reply.html) : '');
    }
  } else {
    texts.push(item.otherContent !== null ? stripTags(item.otherContent) : '');
  }
  return texts;
}

export function talkFindCount(text: string, query: string): number {
  if (query === '') {
    return 0;
  }
  const lower: string = text.toLowerCase();
  let n: number = 0;
  let at: number = lower.indexOf(query);
  while (at >= 0) {
    n++;
    at = lower.indexOf(query, at + query.length);
  }
  return n;
}

// The key of one match: the thread id and the match's place within that thread.
export function talkFindKey(threadId: string, index: number): string {
  return threadId + '#' + index;
}

// The id of the Text that renders one talkFindTexts field of a thread.
export function talkFindFieldId(threadId: string, field: number): string {
  return 'talk_find_' + threadId + '_' + field;
}

// applyTextHighlightIfNecessary: every match on yellow600 at 40%, the selected one on full
// yellow600. ponytail: the source's 60% on the dark themes is not split out.
const FIND_MATCH_BG: string = '#66FFCC33';
const FIND_ACTIVE_BG: string = '#FFCC33';

class FindPiece {
  text: string;
  bg: string;

  constructor(text: string, bg: string) {
    this.text = text;
    this.bg = bg;
  }
}

@Component
export struct TalkPageCell {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  // The heading thread item: name == topicName, html == topicTitleHtml,
  // replies == the thread's comments (replies[0] is the lead comment).
  @Prop item: TalkPageItem = new TalkPageItem();
  // TalkPageCellViewModel.isThreadExpanded — the ids of the expanded threads, shared with
  // TalkPageViewControllerPage's @Provide. @Consume (not @Prop + a parent callback): the
  // cell is built by LazyForEach, which re-runs its item builder only when the IDataSource
  // notifies a key change, so a @Prop handed down from page state never re-syncs on a
  // toggle. Writing this @Consume marks THIS live cell dirty and syncs back to the page.
  @Consume('talkExpandedIds') expandedIds: string[];
  // Find in page: the lower-cased term and the key of the selected match.
  @Consume('talkFindQuery') findQuery: string;
  @Consume('talkFindActive') findActive: string;
  // TalkPageCellViewModel.isSubscribed / isUserPermanent: the subscribed topic names and
  // whether the reader is signed in, shared with the page.
  @Consume('talkSubscribedNames') subscribedNames: string[];
  @Consume('talkUserIsPermanent') userIsPermanent: boolean;
  // TalkPageCellDelegate.userDidTapSubscribeButton
  onSubscribe: (item: TalkPageItem) => void = () => {};
  // TalkPageCellReplyDelegate.tappedReply: the comment being replied to
  onReply: (comment: TalkPageItem) => void = () => {};

  private isExpanded(): boolean {
    return this.expandedIds.indexOf(this.item.id) >= 0;
  }

  // topicView.disclosureButton -> TalkPageCellDelegate.userDidTapDisclosureButton
  private toggleExpanded(): void {
    const id: string = this.item.id;
    const next: string[] = [];
    let removed: boolean = false;
    for (const existing of this.expandedIds) {
      if (existing === id) {
        removed = true;
      } else {
        next.push(existing);
      }
    }
    if (!removed) {
      next.push(id);
    }
    this.expandedIds = next;
  }

  // topicTitleTextView: topicTitleHtml, falling back to the heading's name.
  private topicTitle(): string {
    const html: string | null = this.item.html;
    const title: string = html !== null ? stripTags(html) : '';
    if (title !== '') {
      return title;
    }
    const name: string | null = this.item.name;
    return name !== null ? name : '';
  }

  // leadComment == the first reply; nil when the thread carries only unsigned content.
  private leadComment(): TalkPageItem | null {
    return this.item.replies.length > 0 ? this.item.replies[0] : null;
  }

  // otherContentHtml is shown in place of the lead comment (unsigned content, no metadata).
  private isOtherContent(): boolean {
    return this.item.replies.length === 0 && this.item.otherContent !== null;
  }

  // topicCommentTextView: the lead comment's html, or the thread's othercontent.
  private commentText(): string {
    const lead: TalkPageItem | null = this.leadComment();
    if (lead !== null) {
      const html: string | null = lead.html;
      return html !== null ? stripTags(html) : '';
    }
    const other: string | null = this.item.otherContent;
    return other !== null ? stripTags(other) : '';
  }

  private timestampText(): string {
    const lead: TalkPageItem | null = this.leadComment();
    const ts: string | null = lead !== null ? lead.timestamp : this.item.timestamp;
    return ts !== null ? ts : '';
  }

  // activeUsersCount: distinct authors across the thread's comments.
  private activeUsersCount(): number {
    const authors: string[] = [];
    for (const reply of this.item.replies) {
      const author: string | null = reply.author;
      if (author !== null && author !== '' && authors.indexOf(author) < 0) {
        authors.push(author);
      }
    }
    return authors.length;
  }

  // repliesCount == replies.count + 1 (the lead comment).
  private repliesCount(): number {
    return this.item.replies.length;
  }

  // The replies rendered under the topic when the thread is expanded (all but the lead).
  private expandedReplies(): TalkPageItem[] {
    const out: TalkPageItem[] = [];
    const all: TalkPageItem[] = this.item.replies;
    for (let i = 1; i < all.length; i++) {
      out.push(all[i]);
    }
    return out;
  }

  // field: 0 the title, 1 the lead comment, 1 + i reply i (talkFindTexts order).
  private findPieces(text: string, field: number): FindPiece[] {
    const q: string = this.findQuery;
    if (q === '') {
      return [new FindPiece(text, '')];
    }
    let k: number = 0;
    const texts: string[] = talkFindTexts(this.item);
    for (let i = 0; i < field && i < texts.length; i++) {
      k += talkFindCount(texts[i], q);
    }
    const out: FindPiece[] = [];
    const lower: string = text.toLowerCase();
    let at: number = 0;
    let hit: number = lower.indexOf(q);
    while (hit >= 0) {
      if (hit > at) {
        out.push(new FindPiece(text.substring(at, hit), ''));
      }
      const active: boolean = talkFindKey(this.item.id, k) === this.findActive;
      out.push(new FindPiece(text.substring(hit, hit + q.length), active ? FIND_ACTIVE_BG : FIND_MATCH_BG));
      k++;
      at = hit + q.length;
      hit = lower.indexOf(q, at);
    }
    if (at < text.length) {
      out.push(new FindPiece(text.substring(at), ''));
    }
    return out;
  }

  @Builder
  findSpans(text: string, field: number) {
    ForEach(this.findPieces(text, field), (piece: FindPiece) => {
      Span(piece.text)
        .textBackgroundStyle({ color: piece.bg !== '' ? piece.bg : Color.Transparent })
    }, (piece: FindPiece, i: number) => field + '_' + i + '_' + this.findQuery + '_' + this.findActive)
  }

  // TalkPageCell.leadReplyButton: a filled link-coloured capsule under the lead comment.
  @Builder
  leadReplyButton() {
    Button() {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
          .fontSize(13)
          .fontColor([(this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background'))])
        Text($r('app.string.talk_page_reply_button'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
      }
    }
      .id('talk_lead_reply_itemroot')
      .type(ButtonType.Capsule)
      .backgroundColor($r('app.color.theme_link'))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .margin({ top: 16 })
      .onClick(() => {
        const lead: TalkPageItem | null = this.leadComment();
        if (lead !== null) {
          this.onReply(lead);
        }
      })
  }

  // TalkPageCellCommentView.replyButton: plain link-coloured Reply under each reply.
  @Builder
  commentReplyButton(reply: TalkPageItem) {
    Button() {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
          .fontSize(17)
          .fontColor([$r('app.color.theme_link')])
        Text($r('app.string.talk_page_reply_button'))
          .fontSize(17)
          .fontColor($r('app.color.theme_link'))
      }
    }
      .id('talk_reply_itemroot')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .padding(0)
      .height(32)
      .margin({ top: 6 })
      .onClick(() => {
        this.onReply(reply);
      })
  }

  // TalkPageCellCommentView: replyDepthIndicator + comment text + author/timestamp.
  @Builder
  commentView(reply: TalkPageItem, field: number) {
    Column() {
      Text() {
        this.findSpans(reply.html !== null ? stripTags(reply.html) : '', field)
      }
        .id(talkFindFieldId(this.item.id, field))
        .width('100%')
        .fontSize(17)
        .lineHeight(24)
        .fontColor($r('app.color.theme_text'))
      Row() {
        Text(reply.author !== null ? reply.author : '')
          .fontSize(15)
          .fontColor($r('app.color.theme_link'))
        Text(reply.timestamp !== null ? reply.timestamp : '')
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 6 })
      this.commentReplyButton(reply)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // replyDepthIndicator: the vertical depth rule down the left edge of a reply.
    .border({ width: { left: 2 }, color: $r('app.color.gray200') })
    .padding({ left: 12, top: 12, bottom: 12 })
  }

  // topicView.metadataHorizontalStack
  @Builder
  metadataRow() {
    Row() {
      Text(this.timestampText())
        .fontSize(15)
        .fontColor($r('app.color.theme_secondary_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      Row() {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
        Text(this.activeUsersCount().toString())
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ left: 5 })
      }
      .alignItems(VerticalAlign.Center)

      Row() {
        SymbolGlyph($r('sys.symbol.text_bubble_left_2'))
          .fontSize(16)
          .fontColor([$r('app.color.theme_secondary_text')])
        Text(this.repliesCount().toString())
          .fontSize(15)
          .fontColor($r('app.color.theme_secondary_text'))
          .margin({ left: 5 })
      }
      .alignItems(VerticalAlign.Center)
      .margin({ left: 18 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 6 })
  }

  // configure: shouldHideSubscribe = !isUserPermanent || topicTitleHtml.isEmpty || showingOtherContent
  private showsSubscribe(): boolean {
    return this.userIsPermanent && (this.item.html ?? '') !== '' && !this.isOtherContent();
  }

  private isSubscribed(): boolean {
    return this.subscribedNames.indexOf(this.item.name ?? '') >= 0;
  }

  // .subscribeMetadataReplies: [subscribe, spacer, disclosure] above the title.
  @Builder
  subscribeRow() {
    Row() {
      Button() {
        Row({ space: 6 }) {
          SymbolGlyph(this.isSubscribed() ? $r('sys.symbol.bell_fill') : $r('sys.symbol.bell'))
            .fontSize(18)
            .fontColor([$r('app.color.theme_link')])
          Text(this.isSubscribed() ? $r('app.string.talk_page_unsubscribe_to_topic')
            : $r('app.string.talk_page_subscribe_to_topic'))
            .fontSize(17)
            .fontColor($r('app.color.theme_link'))
        }
      }
        .id('talk_subscribe_itemroot')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .height(30)
        .onClick(() => {
          this.onSubscribe(this.item);
        })
      Blank()
      this.disclosureButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // topicView.disclosureButton — the "Expand thread" / "Collapse thread" control.
  // Rule 12 list-row exception: one shared id ending in `itemroot`, resolved by index.
  @Builder
  disclosureButton() {
    Button() {
      SymbolGlyph(this.isExpanded() ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(20)
        .fontColor([$r('app.color.theme_secondary_text')])
    }
      .id('expand_thread_itemroot')
      .accessibilityText(this.isExpanded()
        ? $r('app.string.talk_page_collapse_thread_button')
        : $r('app.string.talk_page_expand_thread_button'))
      // TalkPageCellTopicView also flips the button's accessibility STATE, not only its
      // label: an expanded disclosure reports as selected. Without it the only trace of the
      // toggle is the appended reply views, which sit below the fold for any card but the
      // first — the tap then reads as a no-op to anything inspecting the tree.
      .accessibilitySelected(this.isExpanded())
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .width(44)
      .height(30)
      .padding(0)
      .onClick(() => {
        this.toggleExpanded();
      })
  }

  build() {
    // rootContainer > stackView
    Column() {
      if (this.isExpanded()) {
        // expanded layout == .metadataReplies ([title, spacer, disclosure]): the subscribe
        // button is hidden on this screen, so the title stays on the disclosure row
        // (captured S0280) and only its line limits open up.
        if (this.showsSubscribe()) {
          this.subscribeRow()
          Text() {
            this.findSpans(this.topicTitle(), 0)
          }
            .id(talkFindFieldId(this.item.id, 0))
            .width('100%')
            .fontSize(20)
            .lineHeight(26)
            .fontColor($r('app.color.theme_text'))
            .margin({ top: 8 })
        } else {
        Row() {
          Text() {
            this.findSpans(this.topicTitle(), 0)
          }
            .id(talkFindFieldId(this.item.id, 0))
            .layoutWeight(1)
            .fontSize(20)
            .lineHeight(26)
            .fontColor($r('app.color.theme_text'))
          this.disclosureButton()
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        }
        this.metadataRow()
        Text() {
          this.findSpans(this.commentText(), 1)
        }
          .id(talkFindFieldId(this.item.id, 1))
          .width('100%')
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_text'))
          .margin({ top: 8 })
        // leadReplySpacer + leadReplyButton (not for a thread of other content)
        if (!this.isOtherContent()) {
          this.leadReplyButton()
        }
        // expanded elements appended to stackView: separator + comment view per reply
        ForEach(this.expandedReplies(), (reply: TalkPageItem, i: number) => {
          Divider()
            .width('100%')
            .color($r('app.color.theme_border'))
            .margin({ top: 12 })
          this.commentView(reply, i + 2)
        }, (reply: TalkPageItem) => reply.id + '_' + this.findQuery + '_' + this.findActive)
      } else {
        // collapsed layout: the title moves into the disclosure row unless the subscribe
        // button holds it
        if (this.showsSubscribe()) {
          this.subscribeRow()
          Text() {
            this.findSpans(this.topicTitle(), 0)
          }
            .id(talkFindFieldId(this.item.id, 0))
            .width('100%')
            .fontSize(20)
            .lineHeight(26)
            .fontColor($r('app.color.theme_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 8 })
        } else {
        Row() {
          Text() {
            this.findSpans(this.topicTitle(), 0)
          }
            .id(talkFindFieldId(this.item.id, 0))
            .layoutWeight(1)
            .fontSize(20)
            .lineHeight(26)
            .fontColor($r('app.color.theme_text'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.disclosureButton()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        }
        if (!this.isOtherContent()) {
          this.metadataRow()
        }
        Text() {
          this.findSpans(this.commentText(), 1)
        }
          .id(talkFindFieldId(this.item.id, 1))
          .width('100%')
          .fontSize(17)
          .lineHeight(24)
          .fontColor($r('app.color.theme_text'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
    .borderRadius(10)
    .border({ width: 1, color: $r('app.color.gray200') })
  }
}
