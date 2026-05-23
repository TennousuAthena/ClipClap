import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppSettings } from '../../model/AppSettings';

const SETTINGS_STORE_NAME = 'clipclap_settings';
const KEY_MAX_HISTORY = 'max_history_items';
const KEY_LISTENING = 'listening_enabled';
const KEY_AUTO_PASTE = 'auto_paste_enabled';
const KEY_PLAIN_TEXT_PASTE = 'plain_text_paste_enabled';
const KEY_REMOTE_IMAGE_PREVIEW = 'remote_image_preview_enabled';
const KEY_RECORD_LOCAL_FILES = 'record_local_files_enabled';
const KEY_STATUS_BAR_ICON = 'status_bar_icon_enabled';
const KEY_HOTKEY_LABEL = 'hotkey_label';
const KEY_HOTKEY_FINAL_KEY = 'hotkey_final_key';
const KEY_HOTKEY_CTRL = 'hotkey_ctrl_enabled';
const KEY_HOTKEY_SHIFT = 'hotkey_shift_enabled';
const KEY_HOTKEY_ALT = 'hotkey_alt_enabled';
const KEY_HOTKEY_META = 'hotkey_meta_enabled';
const KEY_DEBUG_MODE = 'debug_mode_enabled';
const KEY_HIDE_ON_BLUR = 'hide_on_blur_enabled';
const KEY_AUTO_STARTUP = 'auto_startup_enabled';
const KEY_POPUP_LEFT = 'popup_left';
const KEY_POPUP_TOP = 'popup_top';
const KEY_POPUP_WIDTH = 'popup_width';
const KEY_POPUP_HEIGHT = 'popup_height';
const MIN_HISTORY_ITEMS = 10;
const MAX_HISTORY_ITEMS = 300;
const MIN_POPUP_LEFT = 0;
const MIN_POPUP_TOP = 0;
export const MIN_POPUP_WIDTH = 760;
export const MIN_POPUP_HEIGHT = 860;

export class SettingsStore {
  private static instance: SettingsStore = new SettingsStore();
  private prefs?: preferences.Preferences;
  private settings: AppSettings = AppSettings.createDefault();

  static getInstance(): SettingsStore {
    return SettingsStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, SETTINGS_STORE_NAME);
      await this.load();
    } catch (err) {
      this.settings = AppSettings.createDefault();
    }
  }

  getSettings(): AppSettings {
    const copy = new AppSettings();
    copy.hotkeyLabel = this.settings.hotkeyLabel;
    copy.hotkeyFinalKey = this.settings.hotkeyFinalKey;
    copy.isHotkeyCtrlEnabled = this.settings.isHotkeyCtrlEnabled;
    copy.isHotkeyShiftEnabled = this.settings.isHotkeyShiftEnabled;
    copy.isHotkeyAltEnabled = this.settings.isHotkeyAltEnabled;
    copy.isHotkeyMetaEnabled = this.settings.isHotkeyMetaEnabled;
    copy.maxHistoryItems = this.settings.maxHistoryItems;
    copy.isListeningEnabled = this.settings.isListeningEnabled;
    copy.isAutoPasteEnabled = this.settings.isAutoPasteEnabled;
    copy.isPlainTextPasteEnabled = this.settings.isPlainTextPasteEnabled;
    copy.isRemoteImagePreviewEnabled = this.settings.isRemoteImagePreviewEnabled;
    copy.isRecordLocalFilesEnabled = this.settings.isRecordLocalFilesEnabled;
    copy.isStatusBarIconEnabled = this.settings.isStatusBarIconEnabled;
    copy.isDebugModeEnabled = this.settings.isDebugModeEnabled;
    copy.isHideOnBlurEnabled = this.settings.isHideOnBlurEnabled;
    copy.isAutoStartupEnabled = this.settings.isAutoStartupEnabled;
    copy.popupLeft = this.settings.popupLeft;
    copy.popupTop = this.settings.popupTop;
    copy.popupWidth = this.settings.popupWidth;
    copy.popupHeight = this.settings.popupHeight;
    return copy;
  }

  async setListeningEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isListeningEnabled = isEnabled;
    await this.save();
  }

  async setAutoPasteEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isAutoPasteEnabled = isEnabled;
    await this.save();
  }

  async setPlainTextPasteEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isPlainTextPasteEnabled = isEnabled;
    await this.save();
  }

  async setRemoteImagePreviewEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isRemoteImagePreviewEnabled = isEnabled;
    await this.save();
  }

  async setRecordLocalFilesEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isRecordLocalFilesEnabled = isEnabled;
    await this.save();
  }

  async setStatusBarIconEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isStatusBarIconEnabled = isEnabled;
    await this.save();
  }

  async setDebugModeEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isDebugModeEnabled = isEnabled;
    await this.save();
  }

  async setHideOnBlurEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isHideOnBlurEnabled = isEnabled;
    await this.save();
  }

  async setAutoStartupEnabled(isEnabled: boolean): Promise<void> {
    this.settings.isAutoStartupEnabled = isEnabled;
    await this.save();
  }

  async setMaxHistoryItems(value: number): Promise<void> {
    this.settings.maxHistoryItems = this.normalizeHistoryCapacity(value);
    await this.save();
  }

  async setPopupWindowPosition(left: number, top: number): Promise<void> {
    this.settings.popupLeft = this.normalizePopupLeft(left);
    this.settings.popupTop = this.normalizePopupTop(top);
    await this.save();
  }

  async setPopupWindowRect(left: number, top: number, width: number, height: number): Promise<void> {
    this.settings.popupLeft = this.normalizePopupLeft(left);
    this.settings.popupTop = this.normalizePopupTop(top);
    this.settings.popupWidth = this.normalizePopupWidth(width);
    this.settings.popupHeight = this.normalizePopupHeight(height);
    await this.save();
  }

  async setHotkey(ctrlEnabled: boolean, shiftEnabled: boolean, altEnabled: boolean, metaEnabled: boolean,
    finalKey: number, label: string): Promise<void> {
    this.settings.isHotkeyCtrlEnabled = ctrlEnabled;
    this.settings.isHotkeyShiftEnabled = shiftEnabled;
    this.settings.isHotkeyAltEnabled = altEnabled;
    this.settings.isHotkeyMetaEnabled = false;
    this.settings.hotkeyFinalKey = finalKey;
    this.settings.hotkeyLabel = label;
    await this.save();
  }

  private async load(): Promise<void> {
    if (!this.prefs) {
      return;
    }

    let maxHistory: preferences.ValueType = this.settings.maxHistoryItems;
    let listening: preferences.ValueType = this.settings.isListeningEnabled;
    let autoPaste: preferences.ValueType = this.settings.isAutoPasteEnabled;
    let plainTextPaste: preferences.ValueType = this.settings.isPlainTextPasteEnabled;
    let remoteImagePreview: preferences.ValueType = this.settings.isRemoteImagePreviewEnabled;
    let recordLocalFiles: preferences.ValueType = this.settings.isRecordLocalFilesEnabled;
    let statusBarIcon: preferences.ValueType = this.settings.isStatusBarIconEnabled;
    let hotkeyLabel: preferences.ValueType = this.settings.hotkeyLabel;
    let hotkeyFinalKey: preferences.ValueType = this.settings.hotkeyFinalKey;
    let hotkeyCtrl: preferences.ValueType = this.settings.isHotkeyCtrlEnabled;
    let hotkeyShift: preferences.ValueType = this.settings.isHotkeyShiftEnabled;
    let hotkeyAlt: preferences.ValueType = this.settings.isHotkeyAltEnabled;
    let debugMode: preferences.ValueType = this.settings.isDebugModeEnabled;
    let hideOnBlur: preferences.ValueType = this.settings.isHideOnBlurEnabled;
    let autoStartup: preferences.ValueType = this.settings.isAutoStartupEnabled;
    let popupLeft: preferences.ValueType = this.settings.popupLeft;
    let popupTop: preferences.ValueType = this.settings.popupTop;
    let popupWidth: preferences.ValueType = this.settings.popupWidth;
    let popupHeight: preferences.ValueType = this.settings.popupHeight;

    try {
      maxHistory = await this.prefs.get(KEY_MAX_HISTORY, this.settings.maxHistoryItems);
      listening = await this.prefs.get(KEY_LISTENING, this.settings.isListeningEnabled);
      autoPaste = await this.prefs.get(KEY_AUTO_PASTE, this.settings.isAutoPasteEnabled);
      plainTextPaste = await this.prefs.get(KEY_PLAIN_TEXT_PASTE, this.settings.isPlainTextPasteEnabled);
      remoteImagePreview = await this.prefs.get(KEY_REMOTE_IMAGE_PREVIEW,
        this.settings.isRemoteImagePreviewEnabled);
      recordLocalFiles = await this.prefs.get(KEY_RECORD_LOCAL_FILES, this.settings.isRecordLocalFilesEnabled);
      statusBarIcon = await this.prefs.get(KEY_STATUS_BAR_ICON, this.settings.isStatusBarIconEnabled);
      hotkeyLabel = await this.prefs.get(KEY_HOTKEY_LABEL, this.settings.hotkeyLabel);
      hotkeyFinalKey = await this.prefs.get(KEY_HOTKEY_FINAL_KEY, this.settings.hotkeyFinalKey);
      hotkeyCtrl = await this.prefs.get(KEY_HOTKEY_CTRL, this.settings.isHotkeyCtrlEnabled);
      hotkeyShift = await this.prefs.get(KEY_HOTKEY_SHIFT, this.settings.isHotkeyShiftEnabled);
      hotkeyAlt = await this.prefs.get(KEY_HOTKEY_ALT, this.settings.isHotkeyAltEnabled);
      debugMode = await this.prefs.get(KEY_DEBUG_MODE, this.settings.isDebugModeEnabled);
      hideOnBlur = await this.prefs.get(KEY_HIDE_ON_BLUR, this.settings.isHideOnBlurEnabled);
      autoStartup = await this.prefs.get(KEY_AUTO_STARTUP, this.settings.isAutoStartupEnabled);
      popupLeft = await this.prefs.get(KEY_POPUP_LEFT, this.settings.popupLeft);
      popupTop = await this.prefs.get(KEY_POPUP_TOP, this.settings.popupTop);
      popupWidth = await this.prefs.get(KEY_POPUP_WIDTH, this.settings.popupWidth);
      popupHeight = await this.prefs.get(KEY_POPUP_HEIGHT, this.settings.popupHeight);
    } catch (err) {
      return;
    }

    if (typeof maxHistory === 'number') {
      this.settings.maxHistoryItems = this.normalizeHistoryCapacity(maxHistory);
    }
    if (typeof listening === 'boolean') {
      this.settings.isListeningEnabled = listening;
    }
    if (typeof autoPaste === 'boolean') {
      this.settings.isAutoPasteEnabled = autoPaste;
    }
    if (typeof plainTextPaste === 'boolean') {
      this.settings.isPlainTextPasteEnabled = plainTextPaste;
    }
    if (typeof remoteImagePreview === 'boolean') {
      this.settings.isRemoteImagePreviewEnabled = remoteImagePreview;
    }
    if (typeof recordLocalFiles === 'boolean') {
      this.settings.isRecordLocalFilesEnabled = recordLocalFiles;
    }
    if (typeof statusBarIcon === 'boolean') {
      this.settings.isStatusBarIconEnabled = statusBarIcon;
    }
    if (typeof hotkeyLabel === 'string') {
      this.settings.hotkeyLabel = hotkeyLabel;
    }
    if (typeof hotkeyFinalKey === 'number') {
      this.settings.hotkeyFinalKey = hotkeyFinalKey;
    }
    if (typeof hotkeyCtrl === 'boolean') {
      this.settings.isHotkeyCtrlEnabled = hotkeyCtrl;
    }
    if (typeof hotkeyShift === 'boolean') {
      this.settings.isHotkeyShiftEnabled = hotkeyShift;
    }
    if (typeof hotkeyAlt === 'boolean') {
      this.settings.isHotkeyAltEnabled = hotkeyAlt;
    }
    this.settings.isHotkeyMetaEnabled = false;
    if (typeof debugMode === 'boolean') {
      this.settings.isDebugModeEnabled = debugMode;
    }
    if (typeof hideOnBlur === 'boolean') {
      this.settings.isHideOnBlurEnabled = hideOnBlur;
    }
    if (typeof autoStartup === 'boolean') {
      this.settings.isAutoStartupEnabled = autoStartup;
    }
    if (typeof popupLeft === 'number') {
      this.settings.popupLeft = this.normalizePopupLeft(popupLeft);
    }
    if (typeof popupTop === 'number') {
      this.settings.popupTop = this.normalizePopupTop(popupTop);
    }
    if (typeof popupWidth === 'number') {
      this.settings.popupWidth = this.normalizePopupWidth(popupWidth);
    }
    if (typeof popupHeight === 'number') {
      this.settings.popupHeight = this.normalizePopupHeight(popupHeight);
    }
    if (!this.settings.isDebugModeEnabled) {
      this.settings.isAutoPasteEnabled = false;
    }
    this.settings.hotkeyLabel = this.buildHotkeyLabel();
  }

  private async save(): Promise<void> {
    if (!this.prefs) {
      return;
    }

    try {
      await this.prefs.put(KEY_MAX_HISTORY, this.settings.maxHistoryItems);
      await this.prefs.put(KEY_LISTENING, this.settings.isListeningEnabled);
      await this.prefs.put(KEY_AUTO_PASTE, this.settings.isAutoPasteEnabled);
      await this.prefs.put(KEY_PLAIN_TEXT_PASTE, this.settings.isPlainTextPasteEnabled);
      await this.prefs.put(KEY_REMOTE_IMAGE_PREVIEW, this.settings.isRemoteImagePreviewEnabled);
      await this.prefs.put(KEY_RECORD_LOCAL_FILES, this.settings.isRecordLocalFilesEnabled);
      await this.prefs.put(KEY_STATUS_BAR_ICON, this.settings.isStatusBarIconEnabled);
      await this.prefs.put(KEY_HOTKEY_LABEL, this.settings.hotkeyLabel);
      await this.prefs.put(KEY_HOTKEY_FINAL_KEY, this.settings.hotkeyFinalKey);
      await this.prefs.put(KEY_HOTKEY_CTRL, this.settings.isHotkeyCtrlEnabled);
      await this.prefs.put(KEY_HOTKEY_SHIFT, this.settings.isHotkeyShiftEnabled);
      await this.prefs.put(KEY_HOTKEY_ALT, this.settings.isHotkeyAltEnabled);
      await this.prefs.put(KEY_HOTKEY_META, this.settings.isHotkeyMetaEnabled);
      await this.prefs.put(KEY_DEBUG_MODE, this.settings.isDebugModeEnabled);
      await this.prefs.put(KEY_HIDE_ON_BLUR, this.settings.isHideOnBlurEnabled);
      await this.prefs.put(KEY_AUTO_STARTUP, this.settings.isAutoStartupEnabled);
      await this.prefs.put(KEY_POPUP_LEFT, this.settings.popupLeft);
      await this.prefs.put(KEY_POPUP_TOP, this.settings.popupTop);
      await this.prefs.put(KEY_POPUP_WIDTH, this.settings.popupWidth);
      await this.prefs.put(KEY_POPUP_HEIGHT, this.settings.popupHeight);
      await this.prefs.flush();
    } catch (err) {
      return;
    }
  }

  private normalizeHistoryCapacity(value: number): number {
    if (value < MIN_HISTORY_ITEMS) {
      return MIN_HISTORY_ITEMS;
    }
    if (value > MAX_HISTORY_ITEMS) {
      return MAX_HISTORY_ITEMS;
    }
    return Math.floor(value);
  }

  private normalizePopupLeft(value: number): number {
    if (value < MIN_POPUP_LEFT) {
      return MIN_POPUP_LEFT;
    }
    return Math.floor(value);
  }

  private normalizePopupTop(value: number): number {
    if (value < MIN_POPUP_TOP) {
      return MIN_POPUP_TOP;
    }
    return Math.floor(value);
  }

  private normalizePopupWidth(value: number): number {
    if (value < MIN_POPUP_WIDTH) {
      return MIN_POPUP_WIDTH;
    }
    return Math.floor(value);
  }

  private normalizePopupHeight(value: number): number {
    if (value < MIN_POPUP_HEIGHT) {
      return MIN_POPUP_HEIGHT;
    }
    return Math.floor(value);
  }

  private buildHotkeyLabel(): string {
    let label = '';
    if (this.settings.isHotkeyCtrlEnabled) {
      label = 'Ctrl';
    }
    if (this.settings.isHotkeyShiftEnabled) {
      label = label.length > 0 ? `${label} + Shift` : 'Shift';
    }
    if (this.settings.isHotkeyAltEnabled) {
      label = label.length > 0 ? `${label} + Alt` : 'Alt';
    }
    const keyText = this.hotkeyFinalKeyText(this.settings.hotkeyFinalKey);
    return label.length > 0 ? `${label} + ${keyText}` : keyText;
  }

  private hotkeyFinalKeyText(finalKey: number): string {
    if (finalKey === 2050) {
      return 'Space';
    }
    if (finalKey === 2070) {
      return 'Esc';
    }
    if (finalKey >= 2017 && finalKey <= 2042) {
      return String.fromCharCode(65 + finalKey - 2017);
    }
    return 'V';
  }
}
