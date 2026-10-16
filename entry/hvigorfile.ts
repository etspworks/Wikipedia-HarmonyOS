import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// The home-screen quick actions (UIApplicationShortcutItems) live in
// resources/base/profile/shortcuts_config.json, and each want there must name the app's
// bundleName. It is rendered from shortcuts_config.template.json with the bundleName of
// AppScope/app.json5, so re-signing locally under another bundle name keeps them working.
function renderShortcutsConfig(): void {
  const appJson: string = fs.readFileSync(path.resolve(__dirname, '../AppScope/app.json5'), 'utf-8');
  const match: RegExpMatchArray | null = appJson.match(/"bundleName"\s*:\s*"([^"]+)"/);
  const template: string = fs.readFileSync(path.resolve(__dirname, 'shortcuts_config.template.json'), 'utf-8');
  const rendered: string = template.split('${bundleName}').join(match !== null ? match[1] : '');
  const target: string = path.resolve(__dirname, 'src/main/resources/base/profile/shortcuts_config.json');
  if (!fs.existsSync(target) || fs.readFileSync(target, 'utf-8') !== rendered) {
    fs.writeFileSync(target, rendered);
  }
}

renderShortcutsConfig();

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
