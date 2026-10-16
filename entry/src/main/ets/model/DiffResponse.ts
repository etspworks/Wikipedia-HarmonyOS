// Ported from Wikipedia/Code/DiffNetworkModels.swift (REST compare response).

export enum DiffItemType {
  context = 0,
  addLine = 1,
  deleteLine = 2,
  change = 3,
  moveSource = 4,
  moveDestination = 5
}

export enum DiffHighlightRangeType {
  add = 0,
  deleteRange = 1                                  // source: `delete` (reserved word in ArkTS)
}

export enum DiffLinkDirection {
  down = 0,
  up = 1
}

export class DiffSection {
  level: number = 0;
  heading: string = '';
  offset: number = 0;
}

export class DiffItemOffset {
  from: number | null = null;
  to: number | null = null;
}

export class DiffSideMetaData {
  sections: DiffSection[] = [];
}

export class DiffHighlightRange {
  start: number = 0;
  length: number = 0;
  type: DiffHighlightRangeType = DiffHighlightRangeType.add;
}

export class DiffMoveInfo {
  id: string = '';
  linkId: string = '';
  linkDirection: DiffLinkDirection = DiffLinkDirection.down;
}

export class DiffItem {
  type: DiffItemType = DiffItemType.context;
  text: string = '';
  highlightRanges: DiffHighlightRange[] = [];
  moveInfo: DiffMoveInfo | null = null;
  offset: DiffItemOffset = new DiffItemOffset();
  lineNumber: number | null = null;

  get isMoveBased(): boolean {
    return this.type === DiffItemType.moveSource || this.type === DiffItemType.moveDestination;
  }
}

interface DiffSectionJson {
  level?: number;
  heading?: string;
  offset?: number;
}

interface DiffItemOffsetJson {
  from?: number;
  to?: number;
}

interface DiffSideMetaDataJson {
  sections?: DiffSectionJson[];
}

interface DiffHighlightRangeJson {
  start?: number;
  length?: number;
  type?: number;
}

interface DiffMoveInfoJson {
  id?: string;
  linkId?: string;
  linkDirection?: number;
}

interface DiffItemJson {
  type?: number;
  text?: string;
  highlightRanges?: DiffHighlightRangeJson[];
  moveInfo?: DiffMoveInfoJson;
  offset?: DiffItemOffsetJson;
  lineNumber?: number;
}

export interface DiffResponseJson {
  diff?: DiffItemJson[];
  from?: DiffSideMetaDataJson;
  to?: DiffSideMetaDataJson;
}

function sideFromJson(j: DiffSideMetaDataJson): DiffSideMetaData {
  const out = new DiffSideMetaData();
  const sectionsJson = j.sections;
  if (sectionsJson !== undefined) {
    const sections: DiffSection[] = [];
    for (const sectionJson of sectionsJson) {
      const section = new DiffSection();
      section.level = sectionJson.level ?? 0;
      section.heading = sectionJson.heading ?? '';
      section.offset = sectionJson.offset ?? 0;
      sections.push(section);
    }
    out.sections = sections;
  }
  return out;
}

function itemFromJson(j: DiffItemJson): DiffItem {
  const out = new DiffItem();
  out.type = (j.type ?? 0) as DiffItemType;
  out.text = j.text ?? '';
  const rangesJson = j.highlightRanges;
  if (rangesJson !== undefined) {
    const ranges: DiffHighlightRange[] = [];
    for (const rangeJson of rangesJson) {
      const range = new DiffHighlightRange();
      range.start = rangeJson.start ?? 0;
      range.length = rangeJson.length ?? 0;
      range.type = (rangeJson.type ?? 0) as DiffHighlightRangeType;
      ranges.push(range);
    }
    out.highlightRanges = ranges;
  }
  const moveInfoJson = j.moveInfo;
  if (moveInfoJson !== undefined) {
    const moveInfo = new DiffMoveInfo();
    moveInfo.id = moveInfoJson.id ?? '';
    moveInfo.linkId = moveInfoJson.linkId ?? '';
    moveInfo.linkDirection = (moveInfoJson.linkDirection ?? 0) as DiffLinkDirection;
    out.moveInfo = moveInfo;
  }
  const offsetJson = j.offset;
  if (offsetJson !== undefined) {
    const offset = new DiffItemOffset();
    offset.from = offsetJson.from ?? null;
    offset.to = offsetJson.to ?? null;
    out.offset = offset;
  }
  out.lineNumber = j.lineNumber ?? null;
  return out;
}

export class DiffResponse {
  diff: DiffItem[] = [];
  from: DiffSideMetaData = new DiffSideMetaData();
  to: DiffSideMetaData = new DiffSideMetaData();

  static fromJson(j: DiffResponseJson): DiffResponse {
    const out = new DiffResponse();
    const diffJson = j.diff;
    if (diffJson !== undefined) {
      const items: DiffItem[] = [];
      for (const itemJson of diffJson) {
        items.push(itemFromJson(itemJson));
      }
      out.diff = items;
    }
    const fromJson = j.from;
    if (fromJson !== undefined) {
      out.from = sideFromJson(fromJson);
    }
    const toJson = j.to;
    if (toJson !== undefined) {
      out.to = sideFromJson(toJson);
    }
    return out;
  }
}
