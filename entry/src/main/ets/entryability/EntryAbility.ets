import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HotkeyService } from '../core/hotkey/HotkeyService';
import { ImagePreviewWindowController } from '../core/window/ImagePreviewWindowController';
import { PopupWindowController } from '../core/window/PopupWindowController';
import { SettingsStore } from '../core/settings/SettingsStore';
import { StatusBarService } from '../core/statusbar/StatusBarService';
import { ClipboardHistoryStore } from '../services/ClipboardHistoryStore';

const DOMAIN = 0x0000;
const CURRENT_COLOR_MODE = 'currentColorMode';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate(CURRENT_COLOR_MODE, this.context.config.colorMode);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    AppStorage.setOrCreate(CURRENT_COLOR_MODE, newConfig.colorMode);
    hilog.info(DOMAIN, 'testTag', 'Color mode updated: %{public}s', JSON.stringify(newConfig.colorMode));
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    AppStorage.setOrCreate('windowStage', windowStage);
    ImagePreviewWindowController.getInstance().setContext(this.context as common.UIAbilityContext);
    ImagePreviewWindowController.getInstance().setWindowStage(windowStage);
    PopupWindowController.getInstance().setContext(this.context as common.UIAbilityContext);
    PopupWindowController.getInstance().setWindowStage(windowStage);
    SettingsStore.getInstance().init(this.context).then(() => {
      const settings = SettingsStore.getInstance().getSettings();
      ClipboardHistoryStore.getInstance().setMaxHistoryItems(settings.maxHistoryItems);
      ClipboardHistoryStore.getInstance().setListeningEnabled(settings.isListeningEnabled);
      ClipboardHistoryStore.getInstance().setPlainTextPasteEnabled(settings.isPlainTextPasteEnabled);
      ClipboardHistoryStore.getInstance().setRecordLocalFilesEnabled(settings.isDebugModeEnabled &&
        settings.isRecordLocalFilesEnabled);
      PopupWindowController.getInstance().setHideOnBlurEnabled(settings.isHideOnBlurEnabled);
      if (settings.isDebugModeEnabled && settings.isStatusBarIconEnabled) {
        StatusBarService.getInstance().register(this.context as common.UIAbilityContext);
      } else {
        StatusBarService.getInstance().unregister();
      }
      HotkeyService.getInstance().configure(settings);
      HotkeyService.getInstance().register();
    });
    ClipboardHistoryStore.getInstance().init(this.context);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    HotkeyService.getInstance().unregister();
    StatusBarService.getInstance().unregister();
    ImagePreviewWindowController.getInstance().destroyPreview();
    PopupWindowController.getInstance().destroyPopup();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
