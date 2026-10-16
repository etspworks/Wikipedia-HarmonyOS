// Uppercasing in the device language. TextCase.UpperCase is locale-insensitive: it turned
// Turkish "Revizyon geçmişi" into "REVIZYON GEçMIşI" and "Diller" into "DILLER" (no dotted İ).
import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';

export function upperText(context: common.Context, value: ResourceStr): string {
  let text: string = '';
  if (typeof value === 'string') {
    text = value;
  } else {
    try {
      text = context.resourceManager.getStringSync(value as Resource);
    } catch (e) {
      return '';
    }
  }
  return text.toLocaleUpperCase(i18n.System.getSystemLanguage());
}

// Case-folding for search filters. toLowerCase() maps Turkish "İ" to "i" + U+0307 (combining
// dot above), so "İngilizce" never contained a typed "ingiliz"; dropping the dot fixes it.
export function searchFold(s: string): string {
  return s.toLowerCase().replace(/̇/g, '');
}
