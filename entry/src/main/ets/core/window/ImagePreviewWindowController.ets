import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsStore } from '../settings/SettingsStore';

const DOMAIN = 0x0000;
const TAG = 'ClipClapImagePreview';
const IMAGE_PREVIEW_WINDOW_NAME = 'ClipClapImagePreview';
const IMAGE_PREVIEW_ITEM_ID = 'previewImageItemId';
const IMAGE_PREVIEW_WIDTH = 520;
const IMAGE_PREVIEW_HEIGHT = 520;
const IMAGE_PREVIEW_GAP_X = 20;

export class ImagePreviewWindowController {
  private static instance: ImagePreviewWindowController = new ImagePreviewWindowController();
  private context?: common.UIAbilityContext;
  private windowStage?: window.WindowStage;
  private previewWindow?: window.Window;
  private isCreating: boolean = false;
  private currentItemId: string = '';

  static getInstance(): ImagePreviewWindowController {
    return ImagePreviewWindowController.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setWindowStage(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
  }

  async showPreview(itemId: string): Promise<void> {
    if (this.previewWindow && this.currentItemId === itemId) {
      return;
    }
    if (this.isCreating) {
      return;
    }
    this.isCreating = true;
    this.currentItemId = itemId;
    AppStorage.setOrCreate(IMAGE_PREVIEW_ITEM_ID, itemId);
    try {
      await this.destroyPreview();
      const preview = await this.createPreviewWindow();
      await this.prepareAndShow(preview);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to show image preview. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.isCreating = false;
    }
  }

  async hidePreview(): Promise<void> {
    await this.destroyPreview();
  }

  async destroyPreview(): Promise<void> {
    if (!this.previewWindow) {
      return;
    }
    try {
      await this.previewWindow.destroyWindow();
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Failed to destroy image preview. Cause: %{public}s', JSON.stringify(error));
    } finally {
      this.currentItemId = '';
      this.previewWindow = undefined;
    }
  }

  private async createPreviewWindow(): Promise<window.Window> {
    if (this.context) {
      try {
        const config: window.Configuration = {
          name: IMAGE_PREVIEW_WINDOW_NAME,
          windowType: window.WindowType.TYPE_FLOAT,
          ctx: this.context
        };
        return await window.createWindow(config);
      } catch (err) {
        const error = err as BusinessError;
        hilog.warn(DOMAIN, TAG, 'Float image preview unavailable, fallback to sub window. Cause: %{public}s',
          JSON.stringify(error));
      }
    }

    if (!this.windowStage) {
      throw new Error('WindowStage is not ready.');
    }
    const settings = SettingsStore.getInstance().getSettings();
    const rect: window.Rect = {
      left: settings.popupLeft + settings.popupWidth + IMAGE_PREVIEW_GAP_X,
      top: settings.popupTop,
      width: IMAGE_PREVIEW_WIDTH,
      height: IMAGE_PREVIEW_HEIGHT
    };
    const options: window.SubWindowOptions = {
      title: IMAGE_PREVIEW_WINDOW_NAME,
      decorEnabled: false,
      isModal: false,
      windowRect: rect,
      zLevel: 2,
      maximizeSupported: false,
      outlineEnabled: true
    };
    try {
      return await this.windowStage.createSubWindowWithOptions(IMAGE_PREVIEW_WINDOW_NAME, options);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to create image preview sub window. Cause: %{public}s',
        JSON.stringify(error));
      throw new Error('Failed to create image preview sub window.');
    }
  }

  private async prepareAndShow(preview: window.Window): Promise<void> {
    this.previewWindow = preview;
    try {
      preview.setWindowDecorVisible(false);
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Image preview decor update failed. Cause: %{public}s', JSON.stringify(error));
    }

    try {
      const settings = SettingsStore.getInstance().getSettings();
      await preview.resize(IMAGE_PREVIEW_WIDTH, IMAGE_PREVIEW_HEIGHT);
      await preview.moveWindowTo(settings.popupLeft + settings.popupWidth + IMAGE_PREVIEW_GAP_X, settings.popupTop);
      await preview.setWindowFocusable(false);
      await preview.setUIContent('pages/ImagePreview');
      await preview.showWindow();
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to prepare image preview. Cause: %{public}s', JSON.stringify(error));
      await this.destroyPreview();
      throw new Error('Failed to prepare image preview window.');
    }
  }
}
