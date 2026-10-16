// WatchlistController.presentChooseExpiryActionSheet + displayWatchSuccessMessage: the
// "Watchlist expiry" action sheet (Permanent, 1 week … 1 year) shown before a page is watched,
// and the toast title for the period picked. Shared by the article and the diff screens.
import { WatchlistExpiry } from '../common/WatchlistService';

class ExpiryOption {
  title: Resource;
  expiry: string;
  toast: Resource;

  constructor(title: Resource, expiry: string, toast: Resource) {
    this.title = title;
    this.expiry = expiry;
    this.toast = toast;
  }
}

const OPTIONS: ExpiryOption[] = [
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_permanent'), WatchlistExpiry.never,
    $r('app.string.watchlist_added_toast_permanently')),
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_one_week'), WatchlistExpiry.oneWeek,
    $r('app.string.watchlist_added_toast_one_week')),
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_one_month'), WatchlistExpiry.oneMonth,
    $r('app.string.watchlist_added_toast_one_month')),
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_three_months'), WatchlistExpiry.threeMonths,
    $r('app.string.watchlist_added_toast_three_months')),
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_six_months'), WatchlistExpiry.sixMonths,
    $r('app.string.watchlist_added_toast_six_months')),
  new ExpiryOption($r('app.string.watchlist_change_expiry_option_one_year'), WatchlistExpiry.oneYear,
    $r('app.string.watchlist_added_toast_one_year'))
];

// onPick gets the API expiry and the success toast's resource for it.
export function presentChooseExpiryActionSheet(ui: UIContext, onPick: (expiry: string, toast: Resource) => void): void {
  ui.showActionSheet({
    title: $r('app.string.watchlist_change_expiry_title'),
    message: $r('app.string.watchlist_change_expiry_subtitle'),
    autoCancel: true,
    confirm: { value: $r('app.string.cancel'), action: () => {} },
    sheets: OPTIONS.map((o: ExpiryOption): SheetInfo => ({
      title: o.title,
      action: () => onPick(o.expiry, o.toast)
    }))
  });
}
