import { KeyCode } from '@kit.InputKit';
import { inputConsumer } from '@kit.InputKit';

export class HotkeyConfig {
  preKeys: Array<number> = [KeyCode.KEYCODE_CTRL_LEFT, KeyCode.KEYCODE_SHIFT_LEFT];
  finalKey: number = KeyCode.KEYCODE_V;
  label: string = 'Ctrl + Shift + V';

  static create(ctrlEnabled: boolean, shiftEnabled: boolean, altEnabled: boolean, finalKey: number,
    label: string, metaEnabled?: boolean): HotkeyConfig {
    const config = new HotkeyConfig();
    config.preKeys = [];
    if (ctrlEnabled) {
      config.preKeys.push(KeyCode.KEYCODE_CTRL_LEFT);
    }
    if (shiftEnabled) {
      config.preKeys.push(KeyCode.KEYCODE_SHIFT_LEFT);
    }
    if (altEnabled) {
      config.preKeys.push(KeyCode.KEYCODE_ALT_LEFT);
    }
    config.finalKey = finalKey;
    config.label = label;
    return config;
  }

  toOptions(): inputConsumer.HotkeyOptions {
    return {
      preKeys: this.preKeys,
      finalKey: this.finalKey,
      isRepeat: false
    };
  }
}
