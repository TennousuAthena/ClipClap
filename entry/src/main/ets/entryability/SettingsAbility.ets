import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ImagePreviewWindowController } from '../core/window/ImagePreviewWindowController';
import { PopupWindowController } from '../core/window/PopupWindowController';
import { SettingsStore } from '../core/settings/SettingsStore';
import { HotkeyService } from '../core/hotkey/HotkeyService';
import { ClipboardHistoryStore } from '../services/ClipboardHistoryStore';

const DOMAIN = 0x0000;
const CURRENT_COLOR_MODE = 'currentColorMode';
const WINDOW_COUNT_KEY = 'openWindowCount';

export default class SettingsAbility extends UIAbility {
  private isExitConfirmed: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsAbility', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate(CURRENT_COLOR_MODE, this.context.config.colorMode);
    hilog.info(DOMAIN, 'SettingsAbility', '%{public}s', 'Ability onCreate');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    AppStorage.setOrCreate(CURRENT_COLOR_MODE, newConfig.colorMode);
    hilog.info(DOMAIN, 'SettingsAbility', 'Color mode updated: %{public}s', JSON.stringify(newConfig.colorMode));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'SettingsAbility', '%{public}s', 'Ability onWindowStageCreate');

    const prevCount = AppStorage.get<number>(WINDOW_COUNT_KEY) ?? 0;
    AppStorage.setOrCreate(WINDOW_COUNT_KEY, prevCount + 1);

    ImagePreviewWindowController.getInstance().setWindowStage(windowStage);
    PopupWindowController.getInstance().setWindowStage(windowStage);
    HotkeyService.getInstance().setContext(this.context as common.UIAbilityContext);

    SettingsStore.getInstance().init(this.context).then(() => {
      const settings = SettingsStore.getInstance().getSettings();
      ClipboardHistoryStore.getInstance().setMaxHistoryItems(settings.maxHistoryItems);
      ClipboardHistoryStore.getInstance().setListeningEnabled(settings.isListeningEnabled);
      ClipboardHistoryStore.getInstance().setPlainTextPasteEnabled(settings.isPlainTextPasteEnabled);
      ClipboardHistoryStore.getInstance().setRecordLocalFilesEnabled(settings.isDebugModeEnabled &&
        settings.isRecordLocalFilesEnabled);
      PopupWindowController.getInstance().setHideOnBlurEnabled(settings.isHideOnBlurEnabled);
      HotkeyService.getInstance().configure(settings);
      HotkeyService.getInstance().register();
    });
    ClipboardHistoryStore.getInstance().init(this.context);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'SettingsAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'SettingsAbility', 'Succeeded in loading settings content.');
    });
  }

  onWindowStageDestroy(): void {
    HotkeyService.getInstance().clearContext(this.context as common.UIAbilityContext);
    ImagePreviewWindowController.getInstance().destroyPreview();
    const prevCount = AppStorage.get<number>(WINDOW_COUNT_KEY) ?? 1;
    AppStorage.setOrCreate(WINDOW_COUNT_KEY, Math.max(prevCount - 1, 0));
    hilog.info(DOMAIN, 'SettingsAbility', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onPrepareToTerminate(): boolean {
    if (this.isExitConfirmed) {
      return false;
    }
    const windowCount = AppStorage.get<number>(WINDOW_COUNT_KEY) ?? 1;
    if (windowCount <= 1) {
      this.showExitConfirmDialog();
      return true;
    }
    return false;
  }

  private getUIContext(): UIContext | undefined {
    try {
      const win = this.context.windowStage.getMainWindowSync();
      return win.getUIContext();
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsAbility', 'Failed to get UIContext. Cause: %{public}s', JSON.stringify(err));
      return undefined;
    }
  }

  private showExitConfirmDialog(): void {
    const uiContext = this.getUIContext();
    if (!uiContext) {
      this.isExitConfirmed = true;
      try {
        this.context.terminateSelf();
      } catch (err) {
        hilog.error(DOMAIN, 'SettingsAbility', 'Failed to terminate. Cause: %{public}s', JSON.stringify(err));
      }
      return;
    }
    try {
      const resMgr = this.context.resourceManager;
      const exitLabel = resMgr.getStringSync($r('app.string.action_exit').id);
      const cancelLabel = resMgr.getStringSync($r('app.string.action_cancel').id);
      uiContext.showAlertDialog({
        title: $r('app.string.exit_confirm_title'),
        message: $r('app.string.exit_confirm_message'),
        alignment: DialogAlignment.Center,
        buttons: [
          {
            value: exitLabel,
            action: () => {
              this.isExitConfirmed = true;
              this.context.terminateSelf();
            }
          },
          {
            value: cancelLabel,
            action: () => {
            }
          }
        ],
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        autoCancel: true,
        cancel: () => {
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsAbility', 'Failed to show exit dialog. Cause: %{public}s', JSON.stringify(err));
    }
  }
}
