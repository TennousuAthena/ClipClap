import { KeyCode } from '@kit.InputKit';
import { describe, expect, it } from '@ohos/hypium';
import { HotkeyConfig } from '../main/ets/model/HotkeyConfig';

export default function hotkeyConfigTest() {
  describe('HotkeyConfig', () => {
    it('defaultConfig_usesCtrlShiftV', 0, () => {
      const config = new HotkeyConfig();

      expect(config.label).assertEqual('Ctrl + Shift + V');
      expect(config.finalKey).assertEqual(KeyCode.KEYCODE_V);
      expect(config.preKeys).assertDeepEquals([KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_SHIFT_LEFT]);
    });

    it('create_respectsEnabledModifiersAndFinalKey', 0, () => {
      const config = HotkeyConfig.create(true, false, true, KeyCode.KEYCODE_A, 'Ctrl + Alt + A');

      expect(config.label).assertEqual('Ctrl + Alt + A');
      expect(config.finalKey).assertEqual(KeyCode.KEYCODE_A);
      expect(config.preKeys).assertDeepEquals([KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_ALT_LEFT]);
    });

    it('create_allowsNoModifierShortcut', 0, () => {
      const config = HotkeyConfig.create(false, false, false, KeyCode.KEYCODE_SPACE, 'Space');

      expect(config.label).assertEqual('Space');
      expect(config.finalKey).assertEqual(KeyCode.KEYCODE_SPACE);
      expect(config.preKeys.length).assertEqual(0);
    });

    it('toOptions_disablesRepeatAndKeepsKeys', 0, () => {
      const config = HotkeyConfig.create(false, true, false, KeyCode.KEYCODE_Z, 'Shift + Z');
      const options = config.toOptions();

      expect(options.preKeys).assertDeepEquals([KeyCode.KEYCODE_SHIFT_LEFT]);
      expect(options.finalKey).assertEqual(KeyCode.KEYCODE_Z);
      expect(options.isRepeat).assertFalse();
    });
  });
}
