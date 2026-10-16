// svc_game_store — CDGameSession persistence for the "Which Came First" daily game.
// Ported from WMFData/Sources/WMFData/Data Controllers/Games/WMFGamesDataController.swift
// (session CRUD, answer submission, stats, archive) — CoreData -> relationalStore.

import { util } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { Database } from './Database';
import { Prefs, WMFDataPrefKeys } from './Prefs';
import { CDGameSession } from '../model/CDGameSession';
import { WMFFeedOnThisDayEvent } from '../model/WMFFeedOnThisDayEvent';

export const WHICH_CAME_FIRST_GAME_TYPE: string = 'which-came-first';

// WMFGameSessionStatus (WMFGameSession.swift).
export enum GameSessionStatus {
  InProgress = 0,
  Completed = 1
}

// WMFWhichCameFirstEvent — one option of a question (subset persisted in contentData).
export interface WhichCameFirstEvent {
  text?: string;
  year?: number;
  pages?: string[];
  thumbnailURL?: string;
}

// WMFWhichCameFirstQuestion (persisted inside CDGameSession.contentData JSON).
export interface WhichCameFirstQuestion {
  id?: string;
  optionA?: WhichCameFirstEvent;
  optionB?: WhichCameFirstEvent;
  correctAnswer?: string;
}

// WMFWhichCameFirstGameState — { questions, answers[questionId] = "A"|"B" }.
export interface WhichCameFirstGameState {
  questions?: WhichCameFirstQuestion[];
  answers?: Record<string, string>;
}

// GKMersenneTwisterRandomSource(seed:) — MT19937-64; nextInt() is the high 32 bits of each
// 64-bit output. nextInt(upperBound:) reduces those 32 bits with %, except that a power-of-two
// bound takes the top bits. arrayByShufflingObjects(in:) is an inside-out Fisher-Yates with
// nextInt(upperBound: i + 1). Checked against GameplayKit on macOS for several seeds and sizes,
// so the same day yields the source's questions in the source's order.
export class GKMersenneTwister {
  private static readonly NN: number = 312;
  private static readonly MM: number = 156;
  private static readonly M64: bigint = (BigInt(1) << BigInt(64)) - BigInt(1);
  private mt: bigint[] = [];
  private mti: number = GKMersenneTwister.NN;

  constructor(seed: number) {
    const M64: bigint = GKMersenneTwister.M64;
    this.mt.push(BigInt(seed) & M64);
    for (let i = 1; i < GKMersenneTwister.NN; i++) {
      const prev: bigint = this.mt[i - 1];
      this.mt.push((BigInt('6364136223846793005') * (prev ^ (prev >> BigInt(62))) + BigInt(i)) & M64);
    }
  }

  private next64(): bigint {
    const NN: number = GKMersenneTwister.NN;
    if (this.mti >= NN) {
      const upper: bigint = BigInt('0xFFFFFFFF80000000');
      const lower: bigint = BigInt('0x7FFFFFFF');
      const matrix: bigint = BigInt('0xB5026F5AA96619E9');
      for (let i = 0; i < NN; i++) {
        const x: bigint = (this.mt[i] & upper) | (this.mt[(i + 1) % NN] & lower);
        this.mt[i] = this.mt[(i + GKMersenneTwister.MM) % NN] ^ (x >> BigInt(1)) ^
          ((x & BigInt(1)) !== BigInt(0) ? matrix : BigInt(0));
      }
      this.mti = 0;
    }
    let x: bigint = this.mt[this.mti++];
    x ^= (x >> BigInt(29)) & BigInt('0x5555555555555555');
    x ^= (x << BigInt(17)) & BigInt('0x71D67FFFEDA60000');
    x ^= (x << BigInt(37)) & BigInt('0xFFF7EEE000000000');
    x ^= x >> BigInt(43);
    return x & GKMersenneTwister.M64;
  }

  // 0 <= result < bound
  nextInt(bound: number): number {
    const high: bigint = (this.next64() >> BigInt(32)) & BigInt('0xFFFFFFFF');
    if ((bound & (bound - 1)) === 0) {
      const bits: number = Math.round(Math.log2(bound));
      return bits === 0 ? 0 : Number(high >> BigInt(32 - bits));
    }
    return Number(high % BigInt(bound));
  }

  shuffled<T>(items: T[]): T[] {
    const out: T[] = [];
    for (let i = 0; i < items.length; i++) {
      const j: number = this.nextInt(i + 1);
      if (j === i) {
        out.push(items[i]);
      } else {
        out.push(out[j]);
        out[j] = items[i];
      }
    }
    return out;
  }
}

// WMFGamesDataController.makeWhichCameFirstQuestions — a standalone 1-4 digit number in the
// event text could reveal the answer year, so those events are dropped.
function textRevealsYear(text: string): boolean {
  return new RegExp('\\b\\d{1,4}\\b').test(text);
}

function optionFromEvent(event: WMFFeedOnThisDayEvent): WhichCameFirstEvent {
  const titles: string[] = [];
  for (const preview of event.articlePreviews) {
    if (preview.displayTitle !== '') {
      titles.push(preview.displayTitle);
    }
  }
  const option: WhichCameFirstEvent = {
    text: event.text === null ? '' : event.text,
    year: event.year === null ? 0 : event.year,
    pages: titles
  };
  // Source takes the thumbnail of the first page that has one.
  let thumb: string | null = null;
  for (const preview of event.articlePreviews) {
    if (preview.thumbnailURL !== null && preview.thumbnailURL !== '') {
      thumb = preview.thumbnailURL;
      break;
    }
  }
  if (thumb !== null && thumb !== '') {
    option.thumbnailURL = thumb;
  }
  return option;
}

// WMFGamesDataController.makeWhichCameFirstQuestions — shared by the game and the Explore
// card, which previews the first question's two events.
export function makeWhichCameFirstQuestions(events: WMFFeedOnThisDayEvent[], month: number, day: number,
  year: number, count: number): WhichCameFirstQuestion[] {
  // Exclude BC/BCE and future events, events with no pages, and answer-revealing text.
  const filtered: WMFFeedOnThisDayEvent[] = [];
  for (const event of events) {
    const eventYear: number = event.year === null ? 0 : event.year;
    const text: string = event.text === null ? '' : event.text;
    if (event.articlePreviews.length > 0 && eventYear > 0 && eventYear <= year &&
      !textRevealsYear(text)) {
      filtered.push(event);
    }
  }
  filtered.sort((a: WMFFeedOnThisDayEvent, b: WMFFeedOnThisDayEvent) =>
    (a.year === null ? 0 : a.year) - (b.year === null ? 0 : b.year));

  // Deduplicate by year (keep the first event per year).
  let pool: WMFFeedOnThisDayEvent[] = [];
  for (const event of filtered) {
    const last: WMFFeedOnThisDayEvent | null = pool.length > 0 ? pool[pool.length - 1] : null;
    if (last === null || last.year !== event.year) {
      pool.push(event);
    }
  }

  // Date-seeded shuffle so the same day always produces the same questions.
  pool = new GKMersenneTwister(month * 100 + day).shuffled(pool);

  const questions: WhichCameFirstQuestion[] = [];
  while (questions.length < count && pool.length > 0) {
    const first: WMFFeedOnThisDayEvent = pool[0];
    pool = pool.slice(1);
    const firstYear: number = first.year === null ? 0 : first.year;
    const yearSpread: number = Math.max(Math.trunc(390.0 - 0.19043 * firstYear), 5);

    let partnerIndex: number = -1;
    for (let i = 0; i < pool.length; i++) {
      const candidate: WMFFeedOnThisDayEvent = pool[i];
      const candidateYear: number = candidate.year === null ? 0 : candidate.year;
      if (Math.abs(firstYear - candidateYear) <= yearSpread) {
        partnerIndex = i;
        break;
      }
    }
    if (partnerIndex < 0) {
      let bestDelta: number = -1;
      for (let i = 0; i < pool.length; i++) {
        const candidate: WMFFeedOnThisDayEvent = pool[i];
        const candidateYear: number = candidate.year === null ? 0 : candidate.year;
        const delta: number = Math.abs(firstYear - candidateYear);
        if (bestDelta < 0 || delta < bestDelta) {
          bestDelta = delta;
          partnerIndex = i;
        }
      }
    }
    if (partnerIndex < 0) {
      continue;
    }
    const second: WMFFeedOnThisDayEvent = pool[partnerIndex];
    const secondYear: number = second.year === null ? 0 : second.year;
    if (secondYear === firstYear) {
      continue;
    }
    // Source removes every remaining event sharing the partner's year and text.
    const remaining: WMFFeedOnThisDayEvent[] = [];
    for (const candidate of pool) {
      if (candidate.year !== second.year || candidate.text !== second.text) {
        remaining.push(candidate);
      }
    }
    pool = remaining;

    // Randomize which slot each event lands in (Bool.random(), not the seeded source), then
    // mark the earlier event correct.
    const flip: boolean = Math.random() < 0.5;
    const slotA: WhichCameFirstEvent = optionFromEvent(flip ? second : first);
    const slotB: WhichCameFirstEvent = optionFromEvent(flip ? first : second);
    const yearA: number = slotA.year === undefined ? 0 : slotA.year;
    const yearB: number = slotB.year === undefined ? 0 : slotB.year;
    const question: WhichCameFirstQuestion = {
      id: util.generateRandomUUID(),
      optionA: slotA,
      optionB: slotB,
      correctAnswer: yearA < yearB ? 'A' : 'B'
    };
    questions.push(question);
  }
  return questions;
}


// WMFWhichCameFirstStats.
export class GameStats {
  gamesPlayed: number = 0;
  currentStreak: number = 0;
  bestStreak: number = 0;
  averageScore: number = 0;
}

// WMFWhichCameFirstAnswerResult.
export class AnswerResult {
  isCorrect: boolean = false;
  correctAnswer: string = '';
}

// WMFWhichCameFirstArchiveData — completed date -> score, plus paused dates.
export class ArchiveEntry {
  dailyGameDate: string = '';
  score: number = 0;
  paused: boolean = false;
}

const SESSION_COLUMNS: string =
  'identifier, completedDate, contentData, currentQuestionIndex, dailyGameDate, ' +
  'gameType, projectID, score, status';

function mapSessionRow(rs: relationalStore.ResultSet): CDGameSession {
  const out = new CDGameSession();
  out.identifier = Database.colString(rs, 'identifier') ?? '';
  out.completedDate = Database.colLong(rs, 'completedDate');
  out.contentData = Database.colString(rs, 'contentData') ?? '';
  out.currentQuestionIndex = Database.colLong(rs, 'currentQuestionIndex') ?? 0;
  out.dailyGameDate = Database.colString(rs, 'dailyGameDate');
  out.gameType = Database.colString(rs, 'gameType') ?? '';
  out.projectID = Database.colString(rs, 'projectID') ?? '';
  out.score = Database.colLong(rs, 'score') ?? 0;
  out.status = Database.colLong(rs, 'status') ?? 0;
  return out;
}

async function persistSession(s: CDGameSession): Promise<void> {
  const values: relationalStore.ValuesBucket = {
    'identifier': s.identifier,
    'completedDate': s.completedDate,
    'contentData': s.contentData,
    'currentQuestionIndex': s.currentQuestionIndex,
    'dailyGameDate': s.dailyGameDate,
    'gameType': s.gameType,
    'projectID': s.projectID,
    'score': s.score,
    'status': s.status
  };
  await Database.insert('CDGameSession', values);
}

export class GameStore {
  // fetchSession(gameType:project:dailyGameDate:) — dailyGameDate null matches the
  // undated session (source predicate "dailyGameDate == nil").
  static async fetchSession(gameType: string, projectID: string,
    dailyGameDate: string | null): Promise<CDGameSession | null> {
    let sql: string = 'SELECT ' + SESSION_COLUMNS + ' FROM CDGameSession ' +
      'WHERE gameType = ? AND projectID = ?';
    const args: relationalStore.ValueType[] = [gameType, projectID];
    if (dailyGameDate !== null) {
      sql += ' AND dailyGameDate = ?';
      args.push(dailyGameDate);
    } else {
      sql += ' AND dailyGameDate IS NULL';
    }
    const rows: CDGameSession[] = await Database.query<CDGameSession>(sql, args, mapSessionRow);
    return rows.length > 0 ? rows[0] : null;
  }

  // createSession — new UUID, status inProgress, index 0, score 0.
  static async createSession(gameType: string, projectID: string,
    dailyGameDate: string | null, contentDataJSON: string): Promise<CDGameSession> {
    const s = new CDGameSession();
    s.identifier = util.generateRandomUUID();
    s.gameType = gameType;
    s.projectID = projectID;
    s.dailyGameDate = dailyGameDate;
    s.status = GameSessionStatus.InProgress;
    s.contentData = contentDataJSON;
    s.currentQuestionIndex = 0;
    s.score = 0;
    s.completedDate = null;
    await persistSession(s);
    return s;
  }

  // fetchSessions(gameType:project:) — sorted dailyGameDate DESC.
  static async fetchSessions(gameType: string, projectID: string): Promise<CDGameSession[]> {
    return await Database.query<CDGameSession>(
      'SELECT ' + SESSION_COLUMNS + ' FROM CDGameSession ' +
      'WHERE gameType = ? AND projectID = ? ORDER BY dailyGameDate DESC',
      [gameType, projectID], mapSessionRow);
  }

  // fetchOrStartWhichCameFirstDailySession core: existing daily session or a new one.
  static async fetchOrStartDailySession(projectID: string, dailyGameDate: string,
    contentDataJSON: string): Promise<CDGameSession> {
    const existing: CDGameSession | null =
      await GameStore.fetchSession(WHICH_CAME_FIRST_GAME_TYPE, projectID, dailyGameDate);
    if (existing !== null) {
      return existing;
    }
    return await GameStore.createSession(WHICH_CAME_FIRST_GAME_TYPE, projectID,
      dailyGameDate, contentDataJSON);
  }

  // submitWhichCameFirstAnswer — records the answer in the game state, updates index/score,
  // completes the session when every question is answered.
  static async submitAnswer(sessionIdentifier: string, questionIdentifier: string,
    pickedOption: string): Promise<AnswerResult> {
    if (pickedOption !== 'A' && pickedOption !== 'B') {
      throw new Error('invalidPickedOption');
    }
    const rows: CDGameSession[] = await Database.query<CDGameSession>(
      'SELECT ' + SESSION_COLUMNS + ' FROM CDGameSession WHERE identifier = ?',
      [sessionIdentifier], mapSessionRow);
    if (rows.length === 0) {
      throw new Error('sessionNotFound');
    }
    const session: CDGameSession = rows[0];
    const state: WhichCameFirstGameState =
      JSON.parse(session.contentData) as WhichCameFirstGameState;
    const questions: WhichCameFirstQuestion[] = state.questions ?? [];
    let question: WhichCameFirstQuestion | null = null;
    for (const q of questions) {
      if (q.id === questionIdentifier) {
        question = q;
        break;
      }
    }
    if (question === null) {
      throw new Error('sessionNotFound');
    }
    const correctAnswer: string = question.correctAnswer ?? '';
    const isCorrect: boolean = pickedOption === correctAnswer;

    let answers: Record<string, string> = state.answers ?? {};
    answers[questionIdentifier] = pickedOption;
    state.answers = answers;

    let answeredCount: number = 0;
    let correctCount: number = 0;
    for (const q of questions) {
      const qid: string = q.id ?? '';
      const picked: string | undefined = answers[qid];
      if (picked !== undefined) {
        answeredCount += 1;
        if (picked === (q.correctAnswer ?? '')) {
          correctCount += 1;
        }
      }
    }

    session.contentData = JSON.stringify(state);
    session.currentQuestionIndex = answeredCount;
    session.score = correctCount;
    if (answeredCount === questions.length) {
      session.status = GameSessionStatus.Completed;
      session.completedDate = Date.now();
    }
    await persistSession(session);

    const result = new AnswerResult();
    result.isCorrect = isCorrect;
    result.correctAnswer = correctAnswer;
    return result;
  }

  // fetchWhichCameFirstStats — games played, streaks over consecutive dailyGameDates,
  // average score rounded to 1 decimal; streak resets if last play before yesterday.
  static async fetchStats(projectID: string): Promise<GameStats> {
    const sessions: CDGameSession[] =
      await GameStore.fetchSessions(WHICH_CAME_FIRST_GAME_TYPE, projectID);
    const completed: CDGameSession[] = [];
    for (const s of sessions) {
      if (s.status === GameSessionStatus.Completed) {
        completed.push(s);
      }
    }
    const stats = new GameStats();
    stats.gamesPlayed = completed.length;
    if (completed.length > 0) {
      let totalScore: number = 0;
      for (const s of completed) {
        totalScore += s.score;
      }
      stats.averageScore = Math.round((totalScore / completed.length) * 10) / 10;
    }

    const dated: CDGameSession[] = [];
    for (const s of completed) {
      if (s.dailyGameDate !== null) {
        dated.push(s);
      }
    }
    dated.sort((a: CDGameSession, b: CDGameSession): number => {
      const ad: string = a.dailyGameDate ?? '';
      const bd: string = b.dailyGameDate ?? '';
      return ad < bd ? -1 : (ad > bd ? 1 : 0);
    });

    const dayMs: number = 24 * 60 * 60 * 1000;
    let bestStreak: number = 0;
    let currentStreak: number = 0;
    let previousDayMs: number | null = null;
    for (const s of dated) {
      const entryDayMs: number = Date.parse(s.dailyGameDate ?? '');
      if (previousDayMs !== null && entryDayMs === previousDayMs + dayMs) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
      bestStreak = Math.max(bestStreak, currentStreak);
      previousDayMs = entryDayMs;
    }
    if (dated.length > 0) {
      const now = new Date();
      const todayMs: number = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
      const lastMs: number = Date.parse(dated[dated.length - 1].dailyGameDate ?? '');
      if (lastMs !== todayMs && lastMs !== todayMs - dayMs) {
        currentStreak = 0;
      }
    } else {
      currentStreak = 0;
    }
    stats.currentStreak = currentStreak;
    stats.bestStreak = bestStreak;
    return stats;
  }

  // fetchWhichCameFirstArchiveData — completed dates with score + in-progress (paused) dates.
  static async fetchArchive(projectID: string): Promise<ArchiveEntry[]> {
    const sessions: CDGameSession[] =
      await GameStore.fetchSessions(WHICH_CAME_FIRST_GAME_TYPE, projectID);
    const out: ArchiveEntry[] = [];
    for (const s of sessions) {
      if (s.dailyGameDate === null) {
        continue;
      }
      const entry = new ArchiveEntry();
      entry.dailyGameDate = s.dailyGameDate;
      entry.score = s.score;
      entry.paused = s.status === GameSessionStatus.InProgress;
      out.push(entry);
    }
    return out;
  }

  // clearAllSessions.
  static async clearAllSessions(): Promise<void> {
    await Database.execute('DELETE FROM CDGameSession', []);
  }

  // markGamesAnnouncementSeen / resetAnnouncementSeen / hasSeenGamesAnnouncement.
  static markAnnouncementSeen(): void {
    Prefs.putBoolean(WMFDataPrefKeys.hasSeenGamesAnnouncement, true);
  }

  static resetAnnouncementSeen(): void {
    Prefs.putBoolean(WMFDataPrefKeys.hasSeenGamesAnnouncement, false);
  }

  // WMFDeveloperSettingsDataController.clearGamesPersistence: every session plus the
  // announcement flag, so the invitation and a fresh daily game come back.
  static async clearGamesPersistence(): Promise<void> {
    await Database.execute('DELETE FROM CDGameSession');
    GameStore.resetAnnouncementSeen();
  }

  static hasSeenAnnouncement(): boolean {
    return Prefs.getBoolean(WMFDataPrefKeys.hasSeenGamesAnnouncement, false);
  }
}
