// NSUserActivity Handoff on HarmonyOS: cross-device app continuation. A screen that the source
// makes the current activity (Search: wmf_searchViewActivity, search results:
// wmf_searchResultsActivity, Settings: wmf_settingsViewActivity) advertises its wikipedia://
// link while it is on screen; EntryAbility.onContinue hands that link to the other device,
// which opens it through the ordinary link routing (intentForUri).
import { AbilityConstant, common } from '@kit.AbilityKit';

const CONTINUATION_URI_KEY: string = 'wmfContinuationURI';
export const CONTINUATION_WANT_PARAM: string = 'continuationURI';

function setState(ctx: common.UIAbilityContext, state: AbilityConstant.ContinueState): void {
  try {
    ctx.setMissionContinueState(state).catch((e: Error) => {
      console.error('continuation: state failed: ' + e.message);
    });
  } catch (e) {
    console.error('continuation: state threw: ' + (e as Error).message);
  }
}

// NSUserActivity.wmf_makeActive
export function advertiseActivity(ctx: common.UIAbilityContext, uri: string): void {
  AppStorage.setOrCreate<string>(CONTINUATION_URI_KEY, uri);
  setState(ctx, AbilityConstant.ContinueState.ACTIVE);
}

// the screen went away: nothing to continue unless another screen took over meanwhile
export function resignActivity(ctx: common.UIAbilityContext, uri: string): void {
  if (AppStorage.get<string>(CONTINUATION_URI_KEY) !== uri) {
    return;
  }
  AppStorage.setOrCreate<string>(CONTINUATION_URI_KEY, '');
  setState(ctx, AbilityConstant.ContinueState.INACTIVE);
}

export function currentActivityURI(): string {
  return AppStorage.get<string>(CONTINUATION_URI_KEY) ?? '';
}
