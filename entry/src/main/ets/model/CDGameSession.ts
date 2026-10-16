// Ported from WMFData.xcdatamodeld entity CDGameSession.

export interface CDGameSessionRow {
  completedDate?: number;
  contentData?: string;
  currentQuestionIndex?: number;
  dailyGameDate?: string;
  gameType?: string;
  identifier?: string;
  projectID?: string;
  score?: number;
  status?: number;
}

export class CDGameSession {
  completedDate: number | null = null;             // epoch ms
  contentData: string = '';                        // source: Binary (serialized game content JSON)
  currentQuestionIndex: number = 0;
  dailyGameDate: string | null = null;
  gameType: string = '';
  identifier: string = '';                         // UUID
  projectID: string = '';
  score: number = 0;
  status: number = 0;

  static fromRow(r: CDGameSessionRow): CDGameSession {
    const out = new CDGameSession();
    out.completedDate = r.completedDate ?? null;
    out.contentData = r.contentData ?? '';
    out.currentQuestionIndex = r.currentQuestionIndex ?? 0;
    out.dailyGameDate = r.dailyGameDate ?? null;
    out.gameType = r.gameType ?? '';
    out.identifier = r.identifier ?? '';
    out.projectID = r.projectID ?? '';
    out.score = r.score ?? 0;
    out.status = r.status ?? 0;
    return out;
  }
}
