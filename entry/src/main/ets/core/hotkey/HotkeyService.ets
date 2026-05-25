import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit';
import { inputConsumer } from '@kit.InputKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HotkeyConfig } from '../../model/HotkeyConfig';
import { AppSettings } from '../../model/AppSettings';
import { PopupWindowController } from '../window/PopupWindowController';
import { SettingsStore } from '../settings/SettingsStore';

const DOMAIN = 0x0000;
const TAG = 'ClipClapHotkey';

export class HotkeyService {
  private static instance: HotkeyService = new HotkeyService();
  private config: HotkeyConfig = new HotkeyConfig();
  private contexts: common.UIAbilityContext[] = [];
  private mainWindowAgent?: WantAgent;
  private isRegistered: boolean = false;
  private callback: (options: inputConsumer.HotkeyOptions) => void = () => {};

  static getInstance(): HotkeyService {
    return HotkeyService.instance;
  }

  getLabel(): string {
    return this.config.label;
  }

  setContext(context: common.UIAbilityContext): void {
    this.contexts = this.contexts.filter((candidate: common.UIAbilityContext) => candidate !== context);
    this.contexts.push(context);
    this.prepareMainWindowAgent(context);
  }

  clearContext(context: common.UIAbilityContext): void {
    this.contexts = this.contexts.filter((candidate: common.UIAbilityContext) => candidate !== context);
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
      this.openConfiguredWindow();
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

  private openConfiguredWindow(): void {
    const settings = SettingsStore.getInstance().getSettings();
    if (settings.isDebugModeEnabled && settings.isFloatingWindowPresentationEnabled) {
      PopupWindowController.getInstance().showPopup();
      return;
    }
    this.openMainWindow();
  }

  private openMainWindow(): void {
    const context = this.getStartContext();
    if (!context) {
      this.triggerMainWindowAgent();
      return;
    }
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: 'EntryAbility',
      moduleName: context.abilityInfo.moduleName,
      parameters: {
        source: 'hotkey'
      }
    };
    context.startAbility(want).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Failed to open main window. Cause: %{public}s', JSON.stringify(err));
      this.triggerMainWindowAgent();
    });
  }

  private getStartContext(): common.UIAbilityContext | undefined {
    if (this.contexts.length === 0) {
      return undefined;
    }
    return this.contexts[this.contexts.length - 1];
  }

  private prepareMainWindowAgent(context: common.UIAbilityContext): void {
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: 'EntryAbility',
      moduleName: context.abilityInfo.moduleName,
      parameters: {
        source: 'hotkeyAgent'
      }
    };
    wantAgent.getWantAgent({
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 1001,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }).then((agent: WantAgent) => {
      this.mainWindowAgent = agent;
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'Failed to prepare main window WantAgent. Cause: %{public}s', JSON.stringify(err));
    });
  }

  private triggerMainWindowAgent(): void {
    if (!this.mainWindowAgent) {
      hilog.error(DOMAIN, TAG, 'Cannot open main window because no valid context or WantAgent is ready.');
      return;
    }
    wantAgent.trigger(this.mainWindowAgent, { code: 0 }, (err: BusinessError) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Failed to trigger main window WantAgent. Cause: %{public}s', JSON.stringify(err));
      }
    });
  }
}
