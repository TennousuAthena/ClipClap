export class AppSettings {
  hotkeyLabel: string = 'Ctrl + Shift + V';
  hotkeyFinalKey: number = 2038;
  isHotkeyCtrlEnabled: boolean = true;
  isHotkeyShiftEnabled: boolean = true;
  isHotkeyAltEnabled: boolean = false;
  isHotkeyMetaEnabled: boolean = false;
  maxHistoryItems: number = 60;
  isListeningEnabled: boolean = true;
  isAutoPasteEnabled: boolean = false;
  isPlainTextPasteEnabled: boolean = false;
  isRemoteImagePreviewEnabled: boolean = false;
  isRecordLocalFilesEnabled: boolean = false;
  isStatusBarIconEnabled: boolean = false;
  isDebugModeEnabled: boolean = false;
  isFloatingWindowPresentationEnabled: boolean = false;
  isHideOnBlurEnabled: boolean = true;
  isAutoStartupEnabled: boolean = false;
  popupLeft: number = 260;
  popupTop: number = 90;
  popupWidth: number = 760;
  popupHeight: number = 860;

  static createDefault(): AppSettings {
    return new AppSettings();
  }
}
