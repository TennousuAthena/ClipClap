import { inputConsumer } from '@kit.InputKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HotkeyConfig } from '../../model/HotkeyConfig';
import { AppSettings } from '../../model/AppSettings';
import { PopupWindowController } from '../window/PopupWindowController';

const DOMAIN = 0x0000;
const TAG = 'ClipClapHotkey';

export class HotkeyService {
  private static instance: HotkeyService = new HotkeyService();
  private config: HotkeyConfig = new HotkeyConfig();
  private isRegistered: boolean = false;
  private callback: (options: inputConsumer.HotkeyOptions) => void = () => {};

  static getInstance(): HotkeyService {
    return HotkeyService.instance;
  }

  getLabel(): string {
    return this.config.label;
  }

  configure(settings: AppSettings): void {
    const nextConfig = HotkeyConfig.create(settings.isHotkeyCtrlEnabled, settings.isHotkeyShiftEnabled,
      settings.isHotkeyAltEnabled, settings.hotkeyFinalKey, settings.hotkeyLabel, settings.isHotkeyMetaEnabled);
    const shouldReregister = this.isRegistered;
    if (shouldReregister) {
      this.unregister();
    }
    this.config = nextConfig;
    if (shouldReregister) {
      this.register();
    }
  }

  register(): void {
    if (this.isRegistered) {
      return;
    }

    this.callback = () => {
      PopupWindowController.getInstance().showPopup();
    };

    try {
      inputConsumer.on('hotkeyChange', this.config.toOptions(), this.callback);
      this.isRegistered = true;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to register hotkey. Cause: %{public}s', JSON.stringify(error));
    }
  }

  unregister(): void {
    if (!this.isRegistered) {
      return;
    }

    try {
      inputConsumer.off('hotkeyChange', this.config.toOptions(), this.callback);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to unregister hotkey. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.isRegistered = false;
    }
  }
}
