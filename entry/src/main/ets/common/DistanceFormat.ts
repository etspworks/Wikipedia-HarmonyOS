// NSString.wmf_localizedString(forDistance:) and the compass bearing, shared by the Places list
// and the Explore nearby card, in the device locale's number and unit format.
import { i18n } from '@kit.LocalizationKit';

// Great-circle distance in metres.
export function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const rad: number = Math.PI / 180;
  const dLat: number = (lat2 - lat1) * rad;
  const dLon: number = (lon2 - lon1) * rad;
  const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Intl unit style localizes both the number and the unit word ("1,6 km", "1.6公里", "740 م").
function localizedUnit(value: number, unit: string, fractionDigits: number): string {
  try {
    return new Intl.NumberFormat(i18n.System.getSystemLocale(), {
      style: 'unit',
      unit: unit,
      unitDisplay: 'short',
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits
    }).format(value);
  } catch (e) {
    return value.toFixed(fractionDigits) + (unit === 'kilometer' ? ' km' : ' m');
  }
}

export function formatDistance(meters: number): string {
  if (meters >= 1000) {
    return localizedUnit(Math.round(meters / 100) / 10, 'kilometer', 1);
  }
  return localizedUnit(Math.round(meters), 'meter', 0);
}

export function distanceText(fromLat: number, fromLon: number, toLat: number, toLon: number): string {
  return formatDistance(distanceMeters(fromLat, fromLon, toLat, toLon));
}

// degrees clockwise from north, from (lat1, lon1) towards (lat2, lon2)
export function bearingDegrees(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const rad: number = Math.PI / 180;
  const dLon: number = (lon2 - lon1) * rad;
  const y: number = Math.sin(dLon) * Math.cos(lat2 * rad);
  const x: number = Math.cos(lat1 * rad) * Math.sin(lat2 * rad) -
    Math.sin(lat1 * rad) * Math.cos(lat2 * rad) * Math.cos(dLon);
  return (Math.atan2(y, x) / rad + 360) % 360;
}
