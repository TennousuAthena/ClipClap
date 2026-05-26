import { describe, expect, it } from '@ohos/hypium';
import { AppSettings } from '../main/ets/model/AppSettings';

export default function appSettingsTest() {
  describe('AppSettings', () => {
    it('createDefault_returnsExpectedHotkeyAndCapacityDefaults', 0, () => {
      const settings = AppSettings.createDefault();

      expect(settings.hotkeyLabel).assertEqual('Ctrl + Shift + V');
      expect(settings.hotkeyFinalKey).assertEqual(2038);
      expect(settings.isHotkeyCtrlEnabled).assertTrue();
      expect(settings.isHotkeyShiftEnabled).assertTrue();
      expect(settings.isHotkeyAltEnabled).assertFalse();
      expect(settings.isHotkeyMetaEnabled).assertFalse();
      expect(settings.maxHistoryItems).assertEqual(60);
    });

    it('createDefault_keepsDeveloperAndFloatingWindowDisabled', 0, () => {
      const settings = AppSettings.createDefault();

      expect(settings.isDebugModeEnabled).assertFalse();
      expect(settings.isFloatingWindowPresentationEnabled).assertFalse();
      expect(settings.isStatusBarIconEnabled).assertFalse();
      expect(settings.isAutoPasteEnabled).assertFalse();
      expect(settings.isRecordLocalFilesEnabled).assertFalse();
    });

    it('createDefault_setsMainWindowBoundsForCompactManager', 0, () => {
      const settings = AppSettings.createDefault();

      expect(settings.popupLeft).assertEqual(260);
      expect(settings.popupTop).assertEqual(90);
      expect(settings.popupWidth).assertEqual(760);
      expect(settings.popupHeight).assertEqual(860);
    });
  });
}
