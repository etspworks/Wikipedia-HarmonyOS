// Ported from Wikipedia/Code/TalkPageFetcher.swift (action=discussiontoolspageinfo response).

export enum TalkPageItemType {
  comment = 'comment',
  heading = 'heading'
}

export interface TalkPageItemJson {
  type?: string;
  level?: number;
  id?: string;
  html?: string;
  name?: string;
  headingLevel?: number;
  replies?: TalkPageItemJson[];
  othercontent?: string;
  author?: string;
  timestamp?: string;
}

interface TalkPageThreadItemsJson {
  threaditemshtml?: TalkPageItemJson[];
}

export interface TalkPageAPIResponseJson {
  discussiontoolspageinfo?: TalkPageThreadItemsJson;
}

export class TalkPageItem {
  type: TalkPageItemType = TalkPageItemType.comment;
  level: number | null = null;
  id: string = '';
  html: string | null = null;
  name: string | null = null;
  headingLevel: number | null = null;
  replies: TalkPageItem[] = [];
  otherContent: string | null = null;              // JSON: othercontent
  author: string | null = null;
  timestamp: string | null = null;                 // ISO 8601

  static fromJson(j: TalkPageItemJson): TalkPageItem {
    const out = new TalkPageItem();
    out.type = j.type === 'heading' ? TalkPageItemType.heading : TalkPageItemType.comment;
    out.level = j.level ?? null;
    out.id = j.id ?? '';
    out.html = j.html ?? null;
    out.name = j.name ?? null;
    out.headingLevel = j.headingLevel ?? null;
    const repliesJson = j.replies;
    if (repliesJson !== undefined) {
      const replies: TalkPageItem[] = [];
      for (const replyJson of repliesJson) {
        replies.push(TalkPageItem.fromJson(replyJson));
      }
      out.replies = replies;
    }
    out.otherContent = j.othercontent ?? null;
    out.author = j.author ?? null;
    out.timestamp = j.timestamp ?? null;
    return out;
  }

  // TalkPageViewModel.coffeeRollFromItems: the lead section arrives as a leading heading
  // with no replies and no title, carrying only othercontent (the page's TemplateStyles /
  // banner markup). iOS routes it to TalkPageCoffeeRollViewController, never the topic list.
  private static isCoffeeRoll(item: TalkPageItem): boolean {
    return item.type === TalkPageItemType.heading
      && item.replies.length === 0
      && (item.html ?? '') === ''
      && (item.otherContent ?? '') !== '';
  }

  // TalkPageViewModel.validTopLevelTopics: trim the leading coffee roll, then drop topics
  // with nothing to show.
  private static validTopLevelTopics(items: TalkPageItem[]): TalkPageItem[] {
    const out: TalkPageItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: TalkPageItem = items[i];
      if (i === 0 && TalkPageItem.isCoffeeRoll(item)) {
        continue;
      }
      if (item.replies.length === 0 && (item.html ?? '') === '' && (item.otherContent ?? '') === '') {
        continue;
      }
      out.push(item);
    }
    return out;
  }

  // TalkPageViewModel.coffeeRollFromItems -> coffeeRollText: the lead section's markup as
  // plain text (styles and tags dropped), or '' when the page has none.
  static coffeeRollFromResponse(j: TalkPageAPIResponseJson): string {
    const first = j.discussiontoolspageinfo?.threaditemshtml?.[0];
    if (first === undefined) {
      return '';
    }
    const item: TalkPageItem = TalkPageItem.fromJson(first);
    if (!TalkPageItem.isCoffeeRoll(item)) {
      return '';
    }
    return (item.otherContent ?? '')
      .replace(/<style[\s\S]*?<\/style>/g, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;|&#160;/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/\s+([.,;:])/g, '$1')
      .replace(/\s+/g, ' ')
      .trim();
  }

  // TalkPageViewModel.recursivelyFlattenReplies: every comment of the tree, depth first.
  private static flattenReplies(items: TalkPageItem[], out: TalkPageItem[]): void {
    for (const item of items) {
      if (item.type === TalkPageItemType.comment) {
        out.push(item);
      }
      TalkPageItem.flattenReplies(item.replies, out);
    }
  }

  // TalkPageViewModel.cleanTalkPageItems: drop the nested copies of subtopics (the API also
  // returns them at the top level), trim the coffee roll and empty topics, then flatten each
  // topic's reply tree into one level, as the cells show it. A reply to a comment arrives
  // nested under that comment, so without the flattening it never showed.
  static threadItemsFromResponse(j: TalkPageAPIResponseJson): TalkPageItem[] {
    const items: TalkPageItem[] = [];
    const threadItems = j.discussiontoolspageinfo?.threaditemshtml;
    if (threadItems !== undefined) {
      for (const itemJson of threadItems) {
        const item: TalkPageItem = TalkPageItem.fromJson(itemJson);
        item.replies = item.replies.filter((r: TalkPageItem) => r.type !== TalkPageItemType.heading);
        items.push(item);
      }
    }
    const topics: TalkPageItem[] = TalkPageItem.validTopLevelTopics(items);
    for (const topic of topics) {
      const flat: TalkPageItem[] = [];
      TalkPageItem.flattenReplies(topic.replies, flat);
      for (const reply of flat) {
        reply.replies = [];
      }
      topic.replies = flat;
    }
    return topics;
  }
}
