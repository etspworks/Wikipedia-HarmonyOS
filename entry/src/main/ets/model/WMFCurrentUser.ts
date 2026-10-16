// Ported from Wikipedia/Code/WMFCurrentUserFetcher.swift (meta=userinfo|globaluserinfo).

export enum WMFCurrentUserAuthState {
  ip = 0,
  temporary = 1,
  permanent = 2
}

export interface WMFCurrentUserJson {
  id?: number;
  globalUserID?: number;
  name?: string;
  groups?: string[];
  editcount?: number;
  isBlocked?: boolean;
  anon?: boolean;
  temp?: boolean;
  registrationdate?: string;
}

export class WMFCurrentUser {
  userID: number = 0;
  globalUserID: number = 0;
  name: string = '';
  groups: string[] = [];
  editCount: number = 0;
  isBlocked: boolean = false;
  authState: WMFCurrentUserAuthState = WMFCurrentUserAuthState.ip;
  registrationDateString: string | null = null;

  get isPermanent(): boolean {
    return this.authState === WMFCurrentUserAuthState.permanent;
  }

  static fromJson(j: WMFCurrentUserJson): WMFCurrentUser {
    const out = new WMFCurrentUser();
    out.userID = j.id ?? 0;
    out.globalUserID = j.globalUserID ?? 0;
    out.name = j.name ?? '';
    out.groups = j.groups ?? [];
    out.editCount = j.editcount ?? 0;
    out.isBlocked = j.isBlocked ?? false;
    const isIP: boolean = j.anon ?? false;
    const isTemp: boolean = j.temp ?? false;
    if (isIP) {
      out.authState = WMFCurrentUserAuthState.ip;
    } else if (isTemp) {
      out.authState = WMFCurrentUserAuthState.temporary;
    } else {
      out.authState = WMFCurrentUserAuthState.permanent;
    }
    out.registrationDateString = j.registrationdate ?? null;
    return out;
  }
}
