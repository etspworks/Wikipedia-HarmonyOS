// The red dot the source puts on the profile button while the account has unread
// notifications (WMFNavigationBarProfileButtonConfig needsBadge). Sits at the glyph's bottom
// leading corner, ringed in the bar colour so it reads over the glyph.
import { UNREAD_NOTIFICATIONS_KEY } from '../common/NotificationsService';

@Component
export struct UnreadNotificationsDot {
  @StorageProp(UNREAD_NOTIFICATIONS_KEY) unread: number = 0;

  build() {
    if (this.unread > 0) {
      Circle()
        .width(9)
        .height(9)
        .fill($r('app.color.theme_destructive'))
        .stroke($r('app.color.theme_mid_background'))
        .strokeWidth(1.5)
        .id('profile_unread_dot')
    }
  }
}
