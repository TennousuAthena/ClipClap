import { UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { StatusBarViewExtensionAbility } from '@kit.DeskTopExtensionKit';
import { StatusBarService } from '../core/statusbar/StatusBarService';

const DOMAIN = 0x0000;
const TAG = 'ClipClapStatusQuick';

export default class StatusBarQuickAbility extends StatusBarViewExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Status bar quick operation session created.');
    StatusBarService.getInstance().openPopupFromTray();
    try {
      session.terminateSelf().catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'Failed to terminate status bar quick session. Cause: %{public}s',
          JSON.stringify(err));
      });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to close status bar quick session. Cause: %{public}s', JSON.stringify(error));
    }
  }
}
