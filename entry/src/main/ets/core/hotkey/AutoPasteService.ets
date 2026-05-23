import { KeyCode } from '@kit.InputKit';

const AUTO_PASTE_DELAY_MS = 160;
const KEY_TYPE_DOWN = 0;
const KEY_TYPE_UP = 1;
const KEY_SOURCE_KEYBOARD = 1;
const INTENTION_UNKNOWN = -1;
const META_KEY_NONE = 0;
const META_KEY_CTRL = 1;

export class AutoPasteService {
  private static instance: AutoPasteService = new AutoPasteService();

  static getInstance(): AutoPasteService {
    return AutoPasteService.instance;
  }

  async pasteAfterDelay(delay: number = AUTO_PASTE_DELAY_MS): Promise<boolean> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, delay);
    });
    return this.sendPasteShortcut();
  }

  private sendPasteShortcut(): boolean {
    try {
      const ctrlDown = sendKeyEvent(this.createKeyEvent(KEY_TYPE_DOWN, KeyCode.KEYCODE_CTRL_LEFT, 'Ctrl',
        META_KEY_NONE));
      const vDown = sendKeyEvent(this.createKeyEvent(KEY_TYPE_DOWN, KeyCode.KEYCODE_V, 'V', META_KEY_CTRL));
      const vUp = sendKeyEvent(this.createKeyEvent(KEY_TYPE_UP, KeyCode.KEYCODE_V, 'V', META_KEY_CTRL));
      const ctrlUp = sendKeyEvent(this.createKeyEvent(KEY_TYPE_UP, KeyCode.KEYCODE_CTRL_LEFT, 'Ctrl',
        META_KEY_NONE));
      return ctrlDown && vDown && vUp && ctrlUp;
    } catch (err) {
      return false;
    }
  }

  private createKeyEvent(type: number, keyCode: number, keyText: string, metaKey: number): KeyEvent {
    return {
      type: type,
      keyCode: keyCode,
      keyText: keyText,
      keySource: KEY_SOURCE_KEYBOARD,
      deviceId: 0,
      metaKey: metaKey,
      timestamp: Date.now(),
      stopPropagation: () => {},
      intentionCode: INTENTION_UNKNOWN
    } as KeyEvent;
  }
}
