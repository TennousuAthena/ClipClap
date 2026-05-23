import { common } from '@kit.AbilityKit';
import { BusinessError, Callback, emitter } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { PopupWindowController } from '../window/PopupWindowController';

const DOMAIN = 0x0000;
const TAG = 'ClipClapStatusBar';
const TRAY_ICON_SIZE = 18;
const TRAY_ICON_PADDING = 3;
const TRAY_ICON_STROKE = 2;
const QUICK_OPERATION_HEIGHT = 1;
const TRAY_ACTIVATION_DEBOUNCE_MS = 700;

export class StatusBarService {
  private static instance: StatusBarService = new StatusBarService();
  private context?: common.UIAbilityContext;
  private isRegistered: boolean = false;
  private lastActivationAt: number = 0;
  private iconClickCallback: Callback<emitter.EventData> = () => {};

  static getInstance(): StatusBarService {
    return StatusBarService.instance;
  }

  async register(context: common.UIAbilityContext): Promise<void> {
    if (this.isRegistered) {
      return;
    }

    this.context = context;
    try {
      const icons = await this.createStatusBarIcon();
      const title = this.getResourceString(context, 'EntryAbility_label', 'ClipClap');
      const item: statusBarManager.StatusBarItem = {
        icons: icons,
        quickOperation: {
          title: title,
          height: QUICK_OPERATION_HEIGHT,
          abilityName: 'StatusBarQuickAbility',
          moduleName: 'entry',
          loadingStatus: false
        },
        hoverTips: title
      };

      this.iconClickCallback = () => {
        this.openPopupFromTray();
      };
      statusBarManager.on('statusBarIconClick', this.iconClickCallback);
      statusBarManager.addToStatusBar(context, item);
      this.isRegistered = true;
    } catch (err) {
      const error = err as BusinessError;
      try {
        statusBarManager.off('statusBarIconClick', this.iconClickCallback);
      } catch (offErr) {
      }
      hilog.error(DOMAIN, TAG, 'Failed to register status bar item. Cause: %{public}s', JSON.stringify(error));
    }
  }

  openPopupFromTray(): void {
    const now = Date.now();
    if (now - this.lastActivationAt < TRAY_ACTIVATION_DEBOUNCE_MS) {
      return;
    }
    this.lastActivationAt = now;
    PopupWindowController.getInstance().showPopup();
  }

  unregister(): void {
    if (!this.isRegistered) {
      return;
    }

    try {
      statusBarManager.off('statusBarIconClick', this.iconClickCallback);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to unregister status bar click event. Cause: %{public}s',
        JSON.stringify(error));
    }

    try {
      if (this.context) {
        statusBarManager.removeFromStatusBar(this.context);
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to remove status bar item. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.isRegistered = false;
      this.context = undefined;
    }
  }

  private async createStatusBarIcon(): Promise<statusBarManager.StatusBarIcon> {
    const whitePixelMap = await this.createMonochromeIcon(255);
    const blackPixelMap = await this.createMonochromeIcon(28);
    const icon: statusBarManager.StatusBarIcon = {
      white: whitePixelMap,
      black: blackPixelMap
    };
    return icon;
  }

  private async createMonochromeIcon(color: number): Promise<image.PixelMap> {
    const buffer = new ArrayBuffer(TRAY_ICON_SIZE * TRAY_ICON_SIZE * 4);
    const pixels = new Uint8Array(buffer);
    for (let row = 0; row < TRAY_ICON_SIZE; row++) {
      for (let col = 0; col < TRAY_ICON_SIZE; col++) {
        const offset = (row * TRAY_ICON_SIZE + col) * 4;
        const isMarked = this.isClipboardGlyphPixel(row, col);
        pixels[offset] = color;
        pixels[offset + 1] = color;
        pixels[offset + 2] = color;
        pixels[offset + 3] = isMarked ? 255 : 0;
      }
    }

    const options: image.InitializationOptions = {
      size: {
        width: TRAY_ICON_SIZE,
        height: TRAY_ICON_SIZE
      },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: false
    };
    return await image.createPixelMap(buffer, options);
  }

  private isClipboardGlyphPixel(row: number, col: number): boolean {
    const left = TRAY_ICON_PADDING;
    const right = TRAY_ICON_SIZE - TRAY_ICON_PADDING - 1;
    const top = TRAY_ICON_PADDING + 2;
    const bottom = TRAY_ICON_SIZE - TRAY_ICON_PADDING - 1;
    const clipTop = TRAY_ICON_PADDING;
    const clipLeft = 6;
    const clipRight = 11;

    if (row >= clipTop && row < clipTop + TRAY_ICON_STROKE && col >= clipLeft && col <= clipRight) {
      return true;
    }
    if (row >= top && row <= bottom && col >= left && col <= right) {
      if (row < top + TRAY_ICON_STROKE || row > bottom - TRAY_ICON_STROKE) {
        return true;
      }
      if (col < left + TRAY_ICON_STROKE || col > right - TRAY_ICON_STROKE) {
        return true;
      }
    }
    if (row === 9 && col >= 7 && col <= 12) {
      return true;
    }
    if (row === 12 && col >= 6 && col <= 11) {
      return true;
    }
    return false;
  }

  private getResourceString(context: common.UIAbilityContext, name: string, fallback: string): string {
    try {
      return context.resourceManager.getStringByNameSync(name);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to get resource string. Cause: %{public}s', JSON.stringify(error));
    }
    return fallback;
  }
}
