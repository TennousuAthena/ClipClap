import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ImagePreviewWindowController } from './ImagePreviewWindowController';
import { MIN_POPUP_HEIGHT, MIN_POPUP_WIDTH, SettingsStore } from '../settings/SettingsStore';

const DOMAIN = 0x0000;
const TAG = 'ClipClapPopup';
const POPUP_WINDOW_NAME = 'ClipClapPopup';
const INACTIVE_IGNORE_MS = 700;
const SAVE_RECT_DEBOUNCE_MS = 200;

export class PopupWindowController {
  private static instance: PopupWindowController = new PopupWindowController();
  private context?: common.UIAbilityContext;
  private windowStage?: window.WindowStage;
  private popupWindow?: window.Window;
  private isCreating: boolean = false;
  private isHideOnBlurEnabled: boolean = true;
  private ignoreInactiveUntil: number = 0;
  private windowEventCallback: (event: window.WindowEventType) => void = () => {};
  private windowRectCallback: (options: window.RectChangeOptions) => void = () => {};
  private saveRectTimer: number = -1;

  static getInstance(): PopupWindowController {
    return PopupWindowController.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setWindowStage(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
  }

  setHideOnBlurEnabled(isEnabled: boolean): void {
    this.isHideOnBlurEnabled = isEnabled;
  }

  async showPopup(): Promise<void> {
    this.ignoreInactiveUntil = Date.now() + INACTIVE_IGNORE_MS;
    if (this.popupWindow) {
      try {
        await this.popupWindow.setWindowFocusable(true);
        await this.popupWindow.showWindow();
      } catch (err) {
        const error = err as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Failed to focus existing popup. Cause: %{public}s', JSON.stringify(error));
      }
      return;
    }
    if (this.isCreating) {
      return;
    }

    this.isCreating = true;
    try {
      await this.destroyPopup();
      const popup = await this.createPopupWindow();
      await this.prepareAndShow(popup);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to show popup. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.isCreating = false;
    }
  }

  async hidePopup(): Promise<void> {
    await this.destroyPopup();
  }

  startMoving(): void {
    if (!this.popupWindow) {
      return;
    }
    this.popupWindow.startMoving().catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'Failed to start moving popup. Cause: %{public}s', JSON.stringify(err));
    });
  }

  resizeByDrag(startWidth: number, startHeight: number, deltaX: number, deltaY: number): void {
    if (!this.popupWindow) {
      return;
    }
    const width = this.normalizeWidth(startWidth + deltaX);
    const height = this.normalizeHeight(startHeight + deltaY);
    this.popupWindow.resize(width, height).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'Failed to resize popup. Cause: %{public}s', JSON.stringify(err));
    });
  }

  getCurrentSize(): Array<number> {
    if (this.popupWindow) {
      try {
        const properties = this.popupWindow.getWindowProperties();
        return [properties.windowRect.width, properties.windowRect.height];
      } catch (err) {
      }
    }
    const settings = SettingsStore.getInstance().getSettings();
    return [settings.popupWidth, settings.popupHeight];
  }

  saveCurrentRect(): void {
    this.saveCurrentPosition();
  }

  async destroyPopup(): Promise<void> {
    await ImagePreviewWindowController.getInstance().hidePreview();
    if (!this.popupWindow) {
      return;
    }
    await this.saveCurrentPosition();
    try {
      this.popupWindow.off('windowEvent', this.windowEventCallback);
    } catch (err) {
    }
    try {
      this.popupWindow.off('windowRectChange', this.windowRectCallback);
    } catch (err) {
    }
    if (this.saveRectTimer >= 0) {
      clearTimeout(this.saveRectTimer);
      this.saveRectTimer = -1;
    }
    try {
      await this.popupWindow.destroyWindow();
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to destroy popup. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.popupWindow = undefined;
    }
  }

  private async createPopupWindow(): Promise<window.Window> {
    if (this.context) {
      try {
        const config: window.Configuration = {
          name: POPUP_WINDOW_NAME,
          windowType: window.WindowType.TYPE_FLOAT,
          ctx: this.context
        };
        return await window.createWindow(config);
      } catch (err) {
        const error = err as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Float window unavailable, fallback to sub window. Cause: %{public}s',
          JSON.stringify(error));
      }
    }

    if (!this.windowStage) {
      throw new Error('WindowStage is not ready.');
    }
    const settings = SettingsStore.getInstance().getSettings();
    const rect: window.Rect = {
      left: settings.popupLeft,
      top: settings.popupTop,
      width: settings.popupWidth,
      height: settings.popupHeight
    };
    const options: window.SubWindowOptions = {
      title: POPUP_WINDOW_NAME,
      decorEnabled: false,
      isModal: false,
      windowRect: rect,
      zLevel: 1,
      maximizeSupported: false,
      outlineEnabled: true
    };
    try {
      return await this.windowStage.createSubWindowWithOptions(POPUP_WINDOW_NAME, options);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to create sub window. Cause: %{public}s', JSON.stringify(error));
      throw new Error('Failed to create popup sub window.');
    }
  }

  private async prepareAndShow(popup: window.Window): Promise<void> {
    this.popupWindow = popup;
    this.registerWindowEvents(popup);
    this.registerWindowRectEvents(popup);
    try {
      popup.setWindowDecorVisible(false);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Window decor visibility update failed. Cause: %{public}s', JSON.stringify(error));
    }

    try {
      const settings = SettingsStore.getInstance().getSettings();
      await this.enableResize(popup);
      await popup.resize(settings.popupWidth, settings.popupHeight);
      await popup.moveWindowTo(settings.popupLeft, settings.popupTop);
      await popup.setWindowFocusable(true);
      await popup.setUIContent('pages/Popup');
      await popup.showWindow();
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to prepare popup window. Cause: %{public}s', JSON.stringify(error));
      await this.destroyPopup();
      throw new Error('Failed to prepare popup window.');
    }
  }

  private registerWindowRectEvents(popup: window.Window): void {
    this.windowRectCallback = (options: window.RectChangeOptions) => {
      this.scheduleSaveRect(options.rect);
    };
    try {
      popup.on('windowRectChange', this.windowRectCallback);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to register window rect event. Cause: %{public}s', JSON.stringify(error));
    }
  }

  private async enableResize(popup: window.Window): Promise<void> {
    try {
      await popup.setWindowLimits({
        minWidth: MIN_POPUP_WIDTH,
        minHeight: MIN_POPUP_HEIGHT
      });
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to set popup resize limits. Cause: %{public}s', JSON.stringify(error));
    }

    try {
      await popup.setResizeByDragEnabled(true);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to enable popup resize by drag. Cause: %{public}s', JSON.stringify(error));
    }
  }

  private scheduleSaveRect(rect: window.Rect): void {
    if (this.saveRectTimer >= 0) {
      clearTimeout(this.saveRectTimer);
    }
    this.saveRectTimer = setTimeout(() => {
      this.saveRectTimer = -1;
      SettingsStore.getInstance().setPopupWindowRect(rect.left, rect.top, rect.width, rect.height);
    }, SAVE_RECT_DEBOUNCE_MS);
  }

  private normalizeWidth(value: number): number {
    if (value < MIN_POPUP_WIDTH) {
      return MIN_POPUP_WIDTH;
    }
    return Math.floor(value);
  }

  private normalizeHeight(value: number): number {
    if (value < MIN_POPUP_HEIGHT) {
      return MIN_POPUP_HEIGHT;
    }
    return Math.floor(value);
  }

  private registerWindowEvents(popup: window.Window): void {
    this.windowEventCallback = (event: window.WindowEventType) => {
      if (Date.now() < this.ignoreInactiveUntil) {
        return;
      }
      if (this.isHideOnBlurEnabled && event === window.WindowEventType.WINDOW_INACTIVE) {
        this.hidePopup();
      }
    };
    try {
      popup.on('windowEvent', this.windowEventCallback);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to register window event. Cause: %{public}s', JSON.stringify(error));
    }
  }

  private async saveCurrentPosition(): Promise<void> {
    if (!this.popupWindow) {
      return;
    }
    try {
      const properties = this.popupWindow.getWindowProperties();
      await SettingsStore.getInstance().setPopupWindowRect(properties.windowRect.left, properties.windowRect.top,
        properties.windowRect.width, properties.windowRect.height);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to save popup position. Cause: %{public}s', JSON.stringify(error));
    }
  }
}
