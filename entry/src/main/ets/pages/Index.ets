import { common, Want } from '@kit.AbilityKit';
import { KeyCode, pointer } from '@kit.InputKit';
import { ClipboardHistoryStatus, ClipboardHistoryStore, ClipboardItem } from '../services/ClipboardHistoryStore';
import { PermissionService } from '../core/permission/PermissionService';
import { SettingsStore } from '../core/settings/SettingsStore';
import { PopupWindowController } from '../core/window/PopupWindowController';
import { StatusBarService } from '../core/statusbar/StatusBarService';
import { HotkeyService } from '../core/hotkey/HotkeyService';
import { AutoPasteService } from '../core/hotkey/AutoPasteService';
import { AppSettings } from '../model/AppSettings';
import { PreviewTextFormatter, PreviewTextSegment } from '../model/PreviewTextSegment';

const NAV_HISTORY = 'history';
const NAV_SETTINGS = 'settings';
const NAV_DEVELOPER = 'developer';
const NAV_ABOUT = 'about';
const SETTING_LISTENING = 'listening';
const SETTING_AUTO_PASTE = 'autoPaste';
const SETTING_PLAIN_TEXT_PASTE = 'plainTextPaste';
const SETTING_REMOTE_IMAGE_PREVIEW = 'remoteImagePreview';
const SETTING_RECORD_LOCAL_FILES = 'recordLocalFiles';
const SETTING_STATUS_BAR_ICON = 'statusBarIcon';
const SETTING_DEBUG_MODE = 'debugMode';
const SETTING_FLOATING_WINDOW_PRESENTATION = 'floatingWindowPresentation';
const SETTING_HIDE_ON_BLUR = 'hideOnBlur';
const SETTING_AUTO_STARTUP = 'autoStartup';
const VERSION_UNLOCK_TAPS = 5;
const MIN_HISTORY_CAPACITY = 10;
const MAX_HISTORY_CAPACITY = 300;
const ACTION_MANAGE_APPLICATIONS_SETTINGS = 'ohos.settings.manage.applications';
const ACTION_APPLICATION_DETAILS_SETTINGS = 'ohos.settings.application.details';
const SETTINGS_BUNDLE_NAME = 'com.huawei.hmos.settings';
const SETTINGS_ABILITY_NAME = 'com.huawei.hmos.settings.MainAbility';
const APP_BUNDLE_NAME = 'moe.kiwi.clipclap';
const PREVIEW_MONO_FONT = 'JetBrains Mono';

@Entry
@Component
struct Index {
  private historyStore: ClipboardHistoryStore = ClipboardHistoryStore.getInstance();
  private settingsStore: SettingsStore = SettingsStore.getInstance();
  private permissionService: PermissionService = new PermissionService();
  private unsubscribe: () => void = () => {};

  @State private activeNav: string = NAV_HISTORY;
  @State private items: ClipboardItem[] = [];
  @State private searchText: string = '';
  @State private status: ClipboardHistoryStatus = ClipboardHistoryStatus.READY;
  @State private settings: AppSettings = AppSettings.createDefault();
  @State private isReadPasteboardGranted: boolean = false;
  @State private isDebugSwitchVisible: boolean = false;
  @State private versionTapCount: number = 0;
  @State private isVersionLinePressed: boolean = false;
  @State private isAutoStartupAllowed: boolean = false;
  @State private isHotkeyRestartHintVisible: boolean = false;
  @State private capacityInputText: string = MIN_HISTORY_CAPACITY.toString();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.settingsStore.init(context).then(() => {
      this.settings = this.settingsStore.getSettings();
      this.capacityInputText = this.settings.maxHistoryItems.toString();
      this.isDebugSwitchVisible = this.settings.isDebugModeEnabled;
      this.historyStore.setMaxHistoryItems(this.settings.maxHistoryItems);
      this.historyStore.setListeningEnabled(this.settings.isListeningEnabled);
      this.historyStore.setPlainTextPasteEnabled(this.settings.isPlainTextPasteEnabled);
      this.historyStore.setRecordLocalFilesEnabled(this.isRecordLocalFilesActive());
      PopupWindowController.getInstance().setHideOnBlurEnabled(this.settings.isHideOnBlurEnabled);
      this.configureStatusBarIcon(context);
      HotkeyService.getInstance().configure(this.settings);
    });
    this.historyStore.init(context).then(() => {
      this.items = this.historyStore.getItems();
    });
    this.unsubscribe = this.historyStore.subscribe((items: ClipboardItem[], status: ClipboardHistoryStatus) => {
      this.items = items;
      this.status = status;
    });
    this.refreshPermissionStatus();
    this.refreshAutoStartupStatus();
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  build() {
    Row() {
      this.Sidebar()
      Column() {
        this.TopBar()
        if (this.activeNav === NAV_HISTORY) {
          this.HistoryView()
        } else if (this.activeNav === NAV_SETTINGS) {
          this.SettingsView()
        } else if (this.activeNav === NAV_DEVELOPER) {
          this.DeveloperView()
        } else {
          this.AboutView()
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('app.color.app_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  private Sidebar() {
    Column() {
      Column() {
        Text($r('app.string.app_title'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.app_text_primary'))
        Text($r('app.string.app_subtitle'))
          .fontSize(13)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .margin({ bottom: 28 })

      this.NavButton(NAV_HISTORY, $r('app.string.nav_history'), $r('sys.symbol.list_bullet'))
      this.NavButton(NAV_SETTINGS, $r('app.string.nav_settings'), $r('sys.symbol.gearshape'))
      if (this.isDebugSwitchVisible) {
        this.NavButton(NAV_DEVELOPER, $r('app.string.nav_developer'), $r('sys.symbol.laboratories'))
      }
      this.NavButton(NAV_ABOUT, $r('app.string.nav_about'), $r('sys.symbol.info_circle'))

      Blank()

      Text(this.statusText())
        .fontSize(12)
        .fontColor($r('app.color.app_text_muted'))
        .lineHeight(18)
        .width('100%')
    }
    .width(220)
    .height('100%')
    .padding({ left: 22, right: 18, top: 28, bottom: 22 })
    .backgroundColor($r('app.color.app_sidebar_background'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private NavButton(key: string, label: Resource, symbol: Resource) {
    Button() {
      this.NavButtonLabel(symbol, label,
        this.activeNav === key ? $r('app.color.app_accent') : $r('app.color.app_text_secondary'))
    }
    .width('100%')
    .height(42)
    .margin({ bottom: 8 })
    .backgroundColor(this.activeNav === key ? $r('app.color.app_accent_soft') : Color.Transparent)
    .borderRadius(8)
    .padding(0)
    .onClick(() => {
      this.activeNav = key;
    })
  }

  @Builder
  private NavButtonLabel(symbol: Resource, label: Resource, color: ResourceColor) {
    Row() {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(22)
          .width(22)
          .height(22)
          .fontColor([color])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(34)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Text(label)
        .layoutWeight(1)
        .fontSize(16)
        .fontColor(color)
        .textAlign(TextAlign.Start)
        .margin({ left: 8 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 32, right: 18 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ButtonLabel(symbol: Resource, label: Resource | string, color: ResourceColor, iconSize: number = 20) {
    Row() {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(iconSize)
          .width(iconSize)
          .height(iconSize)
          .fontColor([color])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Text(label)
        .fontSize(16)
        .fontColor(color)
        .textAlign(TextAlign.Start)
        .constraintSize({ minWidth: 32 })
        .margin({ left: 8 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 10, right: 12 })
  }

  @Builder
  private ButtonIcon(symbol: Resource, color: ResourceColor, iconSize: number = 20) {
    SymbolGlyph(symbol)
      .fontSize(iconSize)
      .width(iconSize)
      .height(iconSize)
      .fontColor([color])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  private TopBar() {
    Row() {
      Column() {
        Text(this.pageTitle())
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_primary'))
        Text(this.pageSubtitle())
          .fontSize(13)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.settings.isDebugModeEnabled && this.settings.isFloatingWindowPresentationEnabled) {
        Button() {
          this.ButtonLabel($r('sys.symbol.rectangle_and_arrowshape_turn_up_right'),
            $r('app.string.action_open_popup'), $r('app.color.app_on_accent'))
        }
          .height(38)
          .backgroundColor($r('app.color.app_accent'))
          .borderRadius(8)
          .onClick(() => {
            PopupWindowController.getInstance().showPopup();
          })
      }
    }
    .width('100%')
    .padding({ left: 28, right: 28, top: 24, bottom: 18 })
    .backgroundColor($r('app.color.app_surface'))
    .border({ width: { bottom: 1 }, color: $r('app.color.app_border') })
  }

  @Builder
  private HistoryView() {
    Column() {
      Row() {
        TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
          .height(40)
          .layoutWeight(1)
          .backgroundColor($r('app.color.app_surface'))
          .borderRadius(8)
          .onChange((value: string) => {
            this.searchText = value;
          })

        Button() {
          this.ButtonLabel($r('sys.symbol.arrow_clockwise'), $r('app.string.action_refresh'),
            $r('app.color.app_text_primary'))
        }
          .height(40)
          .margin({ left: 12 })
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(8)
          .onClick(() => {
            this.historyStore.captureCurrentClipboard();
          })

        Button() {
          this.ButtonLabel($r('sys.symbol.clean'), $r('app.string.action_clear'),
            $r('app.color.app_on_accent'))
        }
          .height(40)
          .margin({ left: 8 })
          .backgroundColor($r('app.color.app_danger'))
          .borderRadius(8)
          .onClick(() => {
            this.confirmClearHistory();
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.filteredItems().length === 0) {
        this.EmptyState()
      } else {
        List({ space: 10 }) {
          ForEach(this.filteredItems(), (item: ClipboardItem) => {
            ListItem() {
              this.HistoryItem(item)
            }
          }, (item: ClipboardItem) => `${item.id}_${item.isPinned ? 'pinned' : 'unpinned'}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ bottom: 12 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(24)
  }

  @Builder
  private HistoryItem(item: ClipboardItem) {
    Column() {
      Column() {
        Row() {
          Text(this.kindText(item.kind))
            .fontSize(12)
            .fontColor($r('app.color.app_accent'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.app_accent_soft'))
            .borderRadius(6)
          Text(item.isPinned ? $r('app.string.filter_pinned') : '')
            .fontSize(12)
            .fontColor($r('app.color.app_text_muted'))
            .margin({ left: 8 })
          Blank()
          Text(this.formatTime(item.copiedAt))
            .fontSize(12)
            .fontColor($r('app.color.app_text_muted'))
        }
        .width('100%')

        this.PreviewContent(item, false)
        if (this.settings.isDebugModeEnabled && item.rawPayload.length > 0) {
          this.RawPayloadBlock(item)
        }
      }
      .width('100%')
      .onClick(() => {
        this.copyHistoryItem(item);
      })

      Row() {
        Button() {
          this.ButtonLabel($r('sys.symbol.square_on_square_fill'), $r('app.string.action_copy'),
            $r('app.color.app_on_accent'))
        }
          .height(40)
          .constraintSize({ minWidth: 86 })
          .backgroundColor($r('app.color.app_accent'))
          .borderRadius(7)
          .onClick(() => {
            this.copyHistoryItem(item);
          })
        Button() {
          this.ButtonLabel(item.isPinned ? $r('sys.symbol.pin_slash') : $r('sys.symbol.pin'),
            item.isPinned ? $r('app.string.action_unpin') : $r('app.string.action_pin'),
            $r('app.color.app_text_primary'))
        }
          .height(40)
          .constraintSize({ minWidth: 86 })
          .margin({ left: 8 })
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(7)
          .onClick(() => {
            this.historyStore.togglePinned(item.id);
          })
        Button() {
          this.ButtonLabel($r('sys.symbol.trash'), $r('app.string.action_delete'),
            $r('app.color.app_on_accent'))
        }
          .height(40)
          .constraintSize({ minWidth: 86 })
          .margin({ left: 8 })
          .backgroundColor($r('app.color.app_danger'))
          .borderRadius(7)
          .onClick(() => {
            this.historyStore.deleteItem(item.id);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
  }

  private copyHistoryItem(item: ClipboardItem): void {
    this.historyStore.copyItem(item).then((isCopied: boolean) => {
      if (isCopied && this.settings.isDebugModeEnabled && this.settings.isAutoPasteEnabled) {
        AutoPasteService.getInstance().pasteAfterDelay();
      }
    });
  }

  @Builder
  private PreviewContent(item: ClipboardItem, compact: boolean) {
    if (this.shouldPreviewRemoteImage(item)) {
      Row() {
        Image(item.remoteImageUrl)
          .width(compact ? 84 : 132)
          .height(compact ? 64 : 96)
          .objectFit(ImageFit.Contain)
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(7)
        Column() {
          this.PreviewText(item.preview, compact ? 13 : 15, compact ? 18 : 22, compact ? 2 : 3)
          Text(this.mediaMetaText(item))
            .fontSize(12)
            .fontColor($r('app.color.app_text_muted'))
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 10, bottom: 12 })
    } else if (this.isImageOnlyItem(item)) {
      Row() {
        if (item.pixelMap !== undefined) {
          Image(item.pixelMap)
            .width(compact ? 84 : 132)
            .height(compact ? 64 : 96)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.app_surface_subtle'))
            .borderRadius(7)
        } else {
          Image(item.imageFileUri)
            .width(compact ? 84 : 132)
            .height(compact ? 64 : 96)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.app_surface_subtle'))
            .borderRadius(7)
        }
        Column() {
          this.PreviewText(item.preview, compact ? 13 : 15, compact ? 18 : 22, 2)
          Text(this.mediaMetaText(item))
            .fontSize(12)
            .fontColor($r('app.color.app_text_muted'))
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 10, bottom: 12 })
    } else if (this.isMediaKind(item.kind)) {
      Row() {
        Column() {
          Text(this.mediaBadgeText(item.kind))
            .fontSize(12)
            .fontColor($r('app.color.app_text_secondary'))
            .fontWeight(FontWeight.Medium)
        }
        .width(compact ? 54 : 72)
        .height(compact ? 48 : 60)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.app_surface_subtle'))
        .borderRadius(7)
        .border({ width: 1, color: $r('app.color.app_border') })

        Column() {
          this.PreviewText(item.preview, compact ? 13 : 15, compact ? 18 : 22, compact ? 2 : 3)
          Text(this.mediaMetaText(item))
            .fontSize(12)
            .fontColor($r('app.color.app_text_muted'))
            .lineHeight(17)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 10, bottom: 12 })
    } else {
      Column() {
        this.PreviewText(item.preview, compact ? 14 : 15, compact ? 20 : 22, compact ? 2 : 3)
      }
      .width('100%')
        .margin({ top: 10, bottom: 12 })
    }
  }

  @Builder
  private PreviewText(text: string, fontSize: number, lineHeight: number, maxLines: number) {
    Text() {
      ForEach(PreviewTextFormatter.buildSegments(text), (segment: PreviewTextSegment) => {
        if (segment.isImagePlaceholder) {
          Span($r('app.string.image_placeholder'))
        } else if (segment.isMarker) {
          Span(segment.text)
            .fontFamily(PREVIEW_MONO_FONT)
        } else {
          Span(segment.text)
        }
      }, (segment: PreviewTextSegment) => segment.id)
    }
    .fontSize(fontSize)
    .fontColor($r('app.color.app_text_primary'))
    .lineHeight(lineHeight)
    .maxLines(maxLines)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
  }

  @Builder
  private RawPayloadBlock(item: ClipboardItem) {
    Column() {
      Row() {
        Text($r('app.string.debug_raw_payload'))
          .fontSize(12)
          .fontColor($r('app.color.app_text_muted'))
        Blank()
        Text($r('app.string.debug_raw_payload_copy_hint'))
          .fontSize(12)
          .fontColor($r('app.color.app_accent'))
      }
      .width('100%')
      .margin({ bottom: 6 })
      Text(item.rawPayload)
        .fontSize(12)
        .fontColor($r('app.color.app_text_secondary'))
        .fontFamily(PREVIEW_MONO_FONT)
        .lineHeight(17)
        .maxLines(12)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(10)
    .margin({ bottom: 12 })
    .backgroundColor($r('app.color.app_surface_subtle'))
    .borderRadius(7)
    .onHover((isHover: boolean) => {
      if (isHover) {
        cursorControl.setCursor(pointer.PointerStyle.HAND_POINTING);
      } else {
        cursorControl.restoreDefault();
      }
    })
    .onClick(() => {
      this.historyStore.copyRawPayload(item.rawPayload);
    })
  }

  @Builder
  private EmptyState() {
    Column() {
      Text($r('app.string.empty_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.app_text_primary'))
      Text($r('app.string.empty_body'))
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .lineHeight(21)
        .margin({ top: 8, bottom: 20 })
      Button() {
        this.ButtonLabel($r('sys.symbol.checkmark_circle'), $r('app.string.permission_action'),
          $r('app.color.app_on_accent'))
      }
        .height(40)
        .backgroundColor($r('app.color.app_accent'))
        .borderRadius(8)
        .onClick(() => {
          this.requestPermissionAndRefresh();
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
    .padding(32)
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
  }

  @Builder
  private SettingsView() {
    Scroll() {
      Column() {
        this.AboutLine()
        this.VersionLine()
        this.HotkeySettings()
        this.CapacitySettings()
        this.PermissionLine()
        this.ToggleLine($r('app.string.setting_listening'), $r('app.string.setting_listening_desc'),
          this.settings.isListeningEnabled, SETTING_LISTENING)
        this.ToggleLine($r('app.string.setting_plain_text_paste'), $r('app.string.setting_plain_text_paste_desc'),
          this.settings.isPlainTextPasteEnabled,
          SETTING_PLAIN_TEXT_PASTE)
        this.ToggleLine($r('app.string.setting_remote_image_preview'),
          $r('app.string.setting_remote_image_preview_desc'), this.settings.isRemoteImagePreviewEnabled,
          SETTING_REMOTE_IMAGE_PREVIEW)
        this.AutoStartupLine()
        this.ToggleLine($r('app.string.setting_hide_on_blur'), $r('app.string.setting_hide_on_blur_desc'),
          this.settings.isHideOnBlurEnabled, SETTING_HIDE_ON_BLUR)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ left: 24, right: 32, top: 24, bottom: 36 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.On)
  }

  @Builder
  private DeveloperView() {
    Scroll() {
      Column() {
        this.ToggleLine($r('app.string.setting_debug_mode'), $r('app.string.setting_debug_mode_desc'),
          this.settings.isDebugModeEnabled, SETTING_DEBUG_MODE)
        if (this.settings.isDebugModeEnabled) {
          this.ToggleLine($r('app.string.setting_record_local_files'),
            $r('app.string.setting_record_local_files_desc'), this.settings.isRecordLocalFilesEnabled,
            SETTING_RECORD_LOCAL_FILES)
          this.ToggleLine($r('app.string.setting_status_bar_icon'), $r('app.string.setting_status_bar_icon_desc'),
            this.settings.isStatusBarIconEnabled, SETTING_STATUS_BAR_ICON)
          this.ToggleLine($r('app.string.setting_floating_window_presentation'),
            $r('app.string.setting_floating_window_presentation_desc'),
            this.settings.isFloatingWindowPresentationEnabled, SETTING_FLOATING_WINDOW_PRESENTATION)
          this.ToggleLine($r('app.string.setting_auto_paste'), $r('app.string.setting_auto_paste_desc'),
            this.settings.isAutoPasteEnabled, SETTING_AUTO_PASTE)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ left: 24, right: 32, top: 24, bottom: 36 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.On)
  }

  @Builder
  private AboutLine() {
    Row() {
      this.SettingText($r('app.string.setting_about'), $r('app.string.setting_about_desc'))
      Blank()
      Text($r('app.string.app_title'))
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
    .onClick(() => {
      this.activeNav = NAV_ABOUT;
    })
  }

  @Builder
  private VersionLine() {
    Row() {
      this.SettingText($r('app.string.setting_version'), $r('app.string.setting_version_desc'))
      Blank()
      Text($r('app.string.about_version'))
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor(this.isVersionLinePressed ? $r('app.color.app_accent_soft') : $r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: this.isVersionLinePressed ? $r('app.color.app_accent') : $r('app.color.app_border') })
    .scale({ x: this.isVersionLinePressed ? 0.99 : 1, y: this.isVersionLinePressed ? 0.99 : 1 })
    .onTouch((event: TouchEvent) => {
      this.handleVersionLineTouch(event);
    })
    .onClick(() => {
      this.handleVersionTap();
    })
  }

  @Builder
  private HotkeySettings() {
    Column() {
      Row() {
        this.SettingText($r('app.string.setting_hotkey'), $r('app.string.setting_hotkey_desc'))
        Blank()
        Text(this.settings.hotkeyLabel)
          .fontSize(14)
          .fontColor($r('app.color.app_text_secondary'))
      }
      .width('100%')

      Row() {
        Toggle({ type: ToggleType.Checkbox, isOn: this.settings.isHotkeyCtrlEnabled })
          .onChange((isOn: boolean) => {
            this.updateHotkeyModifier('ctrl', isOn);
          })
        Text('Ctrl')
          .fontSize(13)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ left: 4, right: 14 })

        Toggle({ type: ToggleType.Checkbox, isOn: this.settings.isHotkeyShiftEnabled })
          .onChange((isOn: boolean) => {
            this.updateHotkeyModifier('shift', isOn);
          })
        Text('Shift')
          .fontSize(13)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ left: 4, right: 14 })

        Toggle({ type: ToggleType.Checkbox, isOn: this.settings.isHotkeyAltEnabled })
          .onChange((isOn: boolean) => {
            this.updateHotkeyModifier('alt', isOn);
          })
        Text('Alt')
          .fontSize(13)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ left: 4, right: 14 })

        Select(this.hotkeyOptions())
          .selected(this.hotkeySelectedIndex())
          .value(this.hotkeyFinalKeyText(this.settings.hotkeyFinalKey))
          .onSelect((index: number) => {
            this.updateHotkeyFinalKey(index);
          })
      }
      .width('100%')
      .margin({ top: 12 })

      if (this.isHotkeyRestartHintVisible) {
        Text($r('app.string.setting_hotkey_restart_hint'))
          .fontSize(12)
          .fontColor($r('app.color.app_warning_text'))
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
    .alignItems(HorizontalAlign.Start)
    .focusable(true)
    .onKeyEvent((event: KeyEvent) => {
      return this.handleHotkeyInput(event);
    })
  }

  @Builder
  private CapacitySettings() {
    Column() {
      Row() {
        this.SettingText($r('app.string.setting_capacity'), $r('app.string.setting_capacity_desc'))
        Blank()
        Text(this.settings.maxHistoryItems.toString())
          .fontSize(14)
          .fontColor($r('app.color.app_text_secondary'))
      }
      .width('100%')

      Row() {
        Button() {
          this.ButtonIcon($r('sys.symbol.minus'), $r('app.color.app_text_primary'))
        }
          .width(40)
          .height(36)
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(7)
          .onClick(() => {
            this.updateHistoryCapacity(this.settings.maxHistoryItems - 10);
          })
        TextInput({ text: this.capacityInputText })
          .layoutWeight(1)
          .height(32)
          .margin({ left: 12, right: 12 })
          .type(InputType.Number)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(7)
          .onChange((value: string) => {
            this.capacityInputText = this.normalizeCapacityInput(value);
          })
          .onSubmit(() => {
            this.commitHistoryCapacityInput();
          })
          .onBlur(() => {
            this.commitHistoryCapacityInput();
          })
        Button() {
          this.ButtonIcon($r('sys.symbol.plus'), $r('app.color.app_text_primary'))
        }
          .width(40)
          .height(36)
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(7)
          .onClick(() => {
            this.updateHistoryCapacity(this.settings.maxHistoryItems + 10);
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private PermissionLine() {
    Row() {
      this.SettingText($r('app.string.setting_clipboard_permission'), $r('app.string.setting_clipboard_permission_desc'))
      Blank()
      Button() {
        this.ButtonLabel(this.isReadPasteboardGranted ? $r('sys.symbol.checkmark_circle') :
          $r('sys.symbol.exclamationmark_circle'),
          this.isReadPasteboardGranted ? $r('app.string.permission_granted') : $r('app.string.permission_action'),
          this.isReadPasteboardGranted ? $r('app.color.app_text_secondary') : $r('app.color.app_on_accent'))
      }
        .height(34)
        .backgroundColor(this.isReadPasteboardGranted ? $r('app.color.app_surface_subtle') : $r('app.color.app_accent'))
        .borderRadius(7)
        .onClick(() => {
          if (!this.isReadPasteboardGranted) {
            this.requestPermissionAndRefresh();
          } else {
            this.refreshPermissionStatus();
          }
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
  }

  @Builder
  private AutoStartupLine() {
    Row() {
      this.SettingText($r('app.string.setting_auto_startup'), $r('app.string.setting_auto_startup_desc'))
      Blank()
      Text(this.isAutoStartupAllowed ? $r('app.string.auto_startup_enabled') : $r('app.string.auto_startup_unavailable'))
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.End)
        .margin({ right: 10 })
      Button() {
        this.ButtonLabel($r('sys.symbol.gearshape'), $r('app.string.action_open_settings'),
          $r('app.color.app_text_primary'))
      }
        .height(34)
        .backgroundColor($r('app.color.app_surface_subtle'))
        .borderRadius(7)
        .onClick(() => {
          this.openAutoStartupSettings();
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
    .onClick(() => {
      this.refreshAutoStartupStatus();
    })
  }

  @Builder
  private SettingLine(label: Resource, description: Resource, value: Resource | string) {
    Row() {
      this.SettingText(label, description)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.app_text_secondary'))
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
  }

  @Builder
  private ToggleLine(label: Resource, description: Resource, checked: boolean, key: string) {
    Row() {
      this.SettingText(label, description)
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .onChange((isOn: boolean) => {
          this.updateToggle(key, isOn);
        })
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 10 })
    .backgroundColor($r('app.color.app_surface'))
    .borderRadius(8)
    .border({ width: 1, color: $r('app.color.app_border') })
  }

  @Builder
  private SettingText(label: Resource, description: Resource) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.app_text_primary'))
      Text(description)
        .fontSize(12)
        .fontColor($r('app.color.app_text_muted'))
        .margin({ top: 4 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  private AboutView() {
    Scroll() {
      Column() {
        Text($r('app.string.app_title'))
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.app_text_primary'))
        Text($r('app.string.about_version'))
          .fontSize(15)
          .fontColor($r('app.color.app_text_secondary'))
          .margin({ top: 8, bottom: 24 })
        Text($r('app.string.about_body'))
          .fontSize(15)
          .lineHeight(23)
          .fontColor($r('app.color.app_text_secondary'))
          .width('100%')
        this.AboutLinks()
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 28, right: 28, top: 28, bottom: 40 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
  }

  @Builder
  private AboutLinks() {
    Column() {
      this.AboutLink($r('app.string.about_website'), 'https://clipclap.kiwi.moe')
      this.AboutLink($r('app.string.about_terms'), 'https://clipclap.kiwi.moe/terms')
      this.AboutLink($r('app.string.about_privacy'), 'https://clipclap.kiwi.moe/privacy')
      this.AboutLink($r('app.string.about_community'), 'https://clipclap.kiwi.moe/community')
      this.AboutLink($r('app.string.about_open_source'), 'https://github.com/tennousuathena/ClipClap')
    }
    .width('100%')
    .margin({ top: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private AboutLink(label: Resource, url: string) {
    Hyperlink(url, label)
      .color($r('app.color.app_accent'))
      .margin({ bottom: 12 })
  }

  private filteredItems(): ClipboardItem[] {
    const query = this.searchText.trim().toLowerCase();
    if (query.length === 0) {
      return this.items;
    }
    return this.items.filter((item: ClipboardItem) => {
      return this.itemSearchText(item).indexOf(query) >= 0;
    });
  }

  private requestPermissionAndRefresh(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.permissionService.requestReadPasteboard(context).then((isGranted: boolean) => {
      this.isReadPasteboardGranted = isGranted;
      if (isGranted) {
        this.historyStore.captureCurrentClipboard();
      }
    });
  }

  private confirmClearHistory(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.clear_history_confirm_title'),
      message: $r('app.string.clear_history_confirm_message'),
      alignment: DialogAlignment.Center,
      buttons: [
        {
          value: $r('app.string.action_clear'),
          action: () => {
            this.historyStore.clearAll();
          }
        },
        {
          value: $r('app.string.action_cancel'),
          action: () => {
          }
        }
      ],
      buttonDirection: DialogButtonDirection.HORIZONTAL,
      autoCancel: true,
      cancel: () => {
      }
    });
  }

  private updateToggle(key: string, isOn: boolean): void {
    if (key === SETTING_LISTENING) {
      this.settingsStore.setListeningEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        this.historyStore.setListeningEnabled(this.settings.isListeningEnabled);
      });
      return;
    }
    if (key === SETTING_DEBUG_MODE) {
      this.settingsStore.setDebugModeEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.configureStatusBarIcon(context);
        this.historyStore.setRecordLocalFilesEnabled(this.isRecordLocalFilesActive());
      });
      return;
    }
    if (key === SETTING_HIDE_ON_BLUR) {
      this.settingsStore.setHideOnBlurEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        PopupWindowController.getInstance().setHideOnBlurEnabled(this.settings.isHideOnBlurEnabled);
      });
      return;
    }
    if (key === SETTING_AUTO_STARTUP) {
      this.settingsStore.setAutoStartupEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
      });
      return;
    }
    if (key === SETTING_PLAIN_TEXT_PASTE) {
      this.settingsStore.setPlainTextPasteEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        this.historyStore.setPlainTextPasteEnabled(this.settings.isPlainTextPasteEnabled);
      });
      return;
    }
    if (key === SETTING_REMOTE_IMAGE_PREVIEW) {
      this.settingsStore.setRemoteImagePreviewEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
      });
      return;
    }
    if (key === SETTING_RECORD_LOCAL_FILES) {
      this.settingsStore.setRecordLocalFilesEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        this.historyStore.setRecordLocalFilesEnabled(this.isRecordLocalFilesActive());
      });
      return;
    }
    if (key === SETTING_STATUS_BAR_ICON) {
      this.settingsStore.setStatusBarIconEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.configureStatusBarIcon(context);
      });
      return;
    }
    if (key === SETTING_FLOATING_WINDOW_PRESENTATION) {
      this.settingsStore.setFloatingWindowPresentationEnabled(isOn).then(() => {
        this.settings = this.settingsStore.getSettings();
      });
      return;
    }
    this.settingsStore.setAutoPasteEnabled(isOn).then(() => {
      this.settings = this.settingsStore.getSettings();
    });
  }

  private handleVersionTap(): void {
    if (this.isDebugSwitchVisible) {
      return;
    }
    this.versionTapCount += 1;
    if (this.versionTapCount >= VERSION_UNLOCK_TAPS) {
      this.isDebugSwitchVisible = true;
      this.activeNav = NAV_DEVELOPER;
    }
  }

  private handleVersionLineTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseOut }, () => {
        this.isVersionLinePressed = true;
      });
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
        this.isVersionLinePressed = false;
      });
    }
  }

  private refreshPermissionStatus(): void {
    this.permissionService.isReadPasteboardGranted().then((isGranted: boolean) => {
      this.isReadPasteboardGranted = isGranted;
    });
  }

  private refreshAutoStartupStatus(): void {
    this.isAutoStartupAllowed = false;
  }

  private configureStatusBarIcon(context: common.UIAbilityContext): void {
    if (this.settings.isDebugModeEnabled && this.settings.isStatusBarIconEnabled) {
      StatusBarService.getInstance().register(context);
      return;
    }
    StatusBarService.getInstance().unregister();
  }

  private isRecordLocalFilesActive(): boolean {
    return this.settings.isDebugModeEnabled && this.settings.isRecordLocalFilesEnabled;
  }

  private openAutoStartupSettings(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      bundleName: SETTINGS_BUNDLE_NAME,
      abilityName: SETTINGS_ABILITY_NAME,
      parameters: {
        bundleName: APP_BUNDLE_NAME
      }
    };
    context.startAbility(want).catch(() => {
      this.openManageApplicationsSettings(context);
    });
  }

  private openManageApplicationsSettings(context: common.UIAbilityContext): void {
    const want: Want = {
      action: ACTION_MANAGE_APPLICATIONS_SETTINGS
    };
    context.startAbility(want).catch(() => {
      this.openApplicationDetailsSettings(context);
    });
  }

  private openApplicationDetailsSettings(context: common.UIAbilityContext): void {
    const want: Want = {
      action: ACTION_APPLICATION_DETAILS_SETTINGS,
      parameters: {
        bundleName: APP_BUNDLE_NAME
      }
    };
    context.startAbility(want).catch(() => {
    });
  }

  private updateHistoryCapacity(value: number): void {
    let nextValue = Math.floor(value / 10) * 10;
    if (nextValue < MIN_HISTORY_CAPACITY) {
      nextValue = MIN_HISTORY_CAPACITY;
    }
    if (nextValue > MAX_HISTORY_CAPACITY) {
      nextValue = MAX_HISTORY_CAPACITY;
    }
    this.settingsStore.setMaxHistoryItems(nextValue).then(() => {
      this.settings = this.settingsStore.getSettings();
      this.capacityInputText = this.settings.maxHistoryItems.toString();
      this.historyStore.setMaxHistoryItems(this.settings.maxHistoryItems);
    });
  }

  private normalizeCapacityInput(value: string): string {
    let result = '';
    for (let index = 0; index < value.length; index++) {
      const charCode = value.charCodeAt(index);
      if (charCode >= 48 && charCode <= 57) {
        result = `${result}${value.charAt(index)}`;
      }
    }
    return result;
  }

  private commitHistoryCapacityInput(): void {
    if (this.capacityInputText.length === 0) {
      this.capacityInputText = this.settings.maxHistoryItems.toString();
      return;
    }
    this.updateHistoryCapacity(Number.parseInt(this.capacityInputText));
  }

  private updateHotkeyModifier(key: string, isOn: boolean): void {
    let ctrl = this.settings.isHotkeyCtrlEnabled;
    let shift = this.settings.isHotkeyShiftEnabled;
    let alt = this.settings.isHotkeyAltEnabled;
    if (key === 'ctrl') {
      ctrl = isOn;
    } else if (key === 'shift') {
      shift = isOn;
    } else {
      alt = isOn;
    }
    if (this.hotkeyModifierCount(ctrl, shift, alt, false) > 2 ||
      this.hotkeyModifierCount(ctrl, shift, alt, false) === 0) {
      this.settings = this.settingsStore.getSettings();
      return;
    }
    this.saveHotkey(ctrl, shift, alt, false, this.settings.hotkeyFinalKey);
  }

  private updateHotkeyFinalKey(index: number): void {
    let finalKey = this.hotkeyFinalKeyFromIndex(index);
    this.saveHotkey(this.settings.isHotkeyCtrlEnabled, this.settings.isHotkeyShiftEnabled,
      this.settings.isHotkeyAltEnabled, false, finalKey);
  }

  private hotkeyFinalKeyFromIndex(index: number): number {
    if (index >= 0 && index < 26) {
      return KeyCode.KEYCODE_A + index;
    }
    if (index === 26) {
      return KeyCode.KEYCODE_SPACE;
    }
    if (index === 27) {
      return KeyCode.KEYCODE_ESCAPE;
    }
    return KeyCode.KEYCODE_V;
  }

  private saveHotkey(ctrl: boolean, shift: boolean, alt: boolean, meta: boolean, finalKey: number): void {
    const label = this.buildHotkeyLabel(ctrl, shift, alt, meta, finalKey);
    this.settingsStore.setHotkey(ctrl, shift, alt, meta, finalKey, label).then(() => {
      this.settings = this.settingsStore.getSettings();
      this.isHotkeyRestartHintVisible = true;
    });
  }

  private hotkeyModifierCount(ctrl: boolean, shift: boolean, alt: boolean, meta: boolean): number {
    let count = 0;
    if (ctrl) {
      count += 1;
    }
    if (shift) {
      count += 1;
    }
    if (alt) {
      count += 1;
    }
    if (meta) {
      count += 1;
    }
    return count;
  }

  private hotkeySelectedIndex(): number {
    if (this.settings.hotkeyFinalKey >= KeyCode.KEYCODE_A && this.settings.hotkeyFinalKey <= KeyCode.KEYCODE_Z) {
      return this.settings.hotkeyFinalKey - KeyCode.KEYCODE_A;
    }
    if (this.settings.hotkeyFinalKey === KeyCode.KEYCODE_SPACE) {
      return 26;
    }
    if (this.settings.hotkeyFinalKey === KeyCode.KEYCODE_ESCAPE) {
      return 27;
    }
    return KeyCode.KEYCODE_V - KeyCode.KEYCODE_A;
  }

  private buildHotkeyLabel(ctrl: boolean, shift: boolean, alt: boolean, meta: boolean, finalKey: number): string {
    let label = '';
    if (ctrl) {
      label = 'Ctrl';
    }
    if (shift) {
      label = label.length > 0 ? `${label} + Shift` : 'Shift';
    }
    if (alt) {
      label = label.length > 0 ? `${label} + Alt` : 'Alt';
    }
    const keyText = this.hotkeyFinalKeyText(finalKey);
    return label.length > 0 ? `${label} + ${keyText}` : keyText;
  }

  private hotkeyFinalKeyText(finalKey: number): string {
    if (finalKey >= KeyCode.KEYCODE_A && finalKey <= KeyCode.KEYCODE_Z) {
      return String.fromCharCode(65 + finalKey - KeyCode.KEYCODE_A);
    }
    if (finalKey === KeyCode.KEYCODE_SPACE) {
      return 'Space';
    }
    if (finalKey === KeyCode.KEYCODE_ESCAPE) {
      return 'Esc';
    }
    return 'V';
  }

  private handleHotkeyInput(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      return false;
    }
    if (event.keyCode >= KeyCode.KEYCODE_A && event.keyCode <= KeyCode.KEYCODE_Z) {
      this.saveHotkey(this.settings.isHotkeyCtrlEnabled, this.settings.isHotkeyShiftEnabled,
        this.settings.isHotkeyAltEnabled, false, event.keyCode);
      return true;
    }
    return false;
  }

  private hotkeyOptions(): Array<SelectOption> {
    const options: Array<SelectOption> = [];
    for (let index = 0; index < 26; index++) {
      options.push({ value: String.fromCharCode(65 + index) });
    }
    options.push({ value: 'Space' });
    options.push({ value: 'Esc' });
    return options;
  }

  private pageTitle(): Resource {
    if (this.activeNav === NAV_SETTINGS) {
      return $r('app.string.nav_settings');
    }
    if (this.activeNav === NAV_DEVELOPER) {
      return $r('app.string.nav_developer');
    }
    if (this.activeNav === NAV_ABOUT) {
      return $r('app.string.nav_about');
    }
    return $r('app.string.nav_history');
  }

  private pageSubtitle(): Resource {
    if (this.activeNav === NAV_SETTINGS) {
      return $r('app.string.settings_subtitle');
    }
    if (this.activeNav === NAV_DEVELOPER) {
      return $r('app.string.developer_subtitle');
    }
    if (this.activeNav === NAV_ABOUT) {
      return $r('app.string.about_subtitle');
    }
    return $r('app.string.history_subtitle');
  }

  private statusText(): Resource {
    if (this.status === ClipboardHistoryStatus.RECORDED) {
      return $r('app.string.status_recorded');
    }
    if (this.status === ClipboardHistoryStatus.PERMISSION_DENIED) {
      return $r('app.string.status_permission_denied');
    }
    if (this.status === ClipboardHistoryStatus.EMPTY_CLIPBOARD) {
      return $r('app.string.status_empty_clipboard');
    }
    if (this.status === ClipboardHistoryStatus.TEXT_ONLY) {
      return $r('app.string.status_text_only');
    }
    if (this.status === ClipboardHistoryStatus.COPY_DONE) {
      return $r('app.string.status_copy_done');
    }
    if (this.status === ClipboardHistoryStatus.COPY_FAILED) {
      return $r('app.string.status_copy_failed');
    }
    if (this.status === ClipboardHistoryStatus.LOAD_DONE) {
      return $r('app.string.status_load_done');
    }
    if (this.status === ClipboardHistoryStatus.LOAD_EMPTY) {
      return $r('app.string.status_load_empty');
    }
    return $r('app.string.status_ready');
  }

  private kindText(kind: string): Resource {
    if (kind === 'Link') {
      return $r('app.string.kind_link');
    }
    if (kind === 'Code') {
      return $r('app.string.kind_code');
    }
    if (kind === 'HTML') {
      return $r('app.string.kind_html');
    }
    if (kind === 'Image') {
      return $r('app.string.kind_image');
    }
    if (kind === 'URI') {
      return $r('app.string.kind_uri');
    }
    if (kind === 'File') {
      return $r('app.string.kind_file');
    }
    if (kind === 'Custom') {
      return $r('app.string.kind_custom');
    }
    return $r('app.string.kind_text');
  }

  private itemSearchText(item: ClipboardItem): string {
    return `${item.text} ${item.preview} ${item.uri} ${item.imageFileUri} ${item.remoteImageUrl} ${item.kind}`.toLowerCase();
  }

  private isMediaKind(kind: string): boolean {
    return kind === 'Image' || kind === 'URI' || kind === 'File' || kind === 'Custom';
  }

  private isImageOnlyItem(item: ClipboardItem): boolean {
    return this.hasLocalImagePreview(item) && item.text.length === 0 && item.html.length === 0 && item.uri.length === 0;
  }

  private hasLocalImagePreview(item: ClipboardItem): boolean {
    return item.pixelMap !== undefined || item.imageFileUri.length > 0;
  }

  private shouldPreviewRemoteImage(item: ClipboardItem): boolean {
    return this.settings.isRemoteImagePreviewEnabled && item.remoteImageUrl.length > 0;
  }

  private mediaBadgeText(kind: string): string {
    if (kind === 'Image') {
      return 'IMG';
    }
    if (kind === 'URI') {
      return 'URI';
    }
    if (kind === 'File') {
      return 'FILE';
    }
    return 'MIME';
  }

  private mediaMetaText(item: ClipboardItem): string {
    let meta = '';
    if (item.imageWidth > 0 && item.imageHeight > 0) {
      const resolutionText = `${item.imageWidth} x ${item.imageHeight}`;
      if (item.preview.indexOf(resolutionText) < 0) {
        meta = resolutionText;
      }
    }
    if (item.recordCount > 0) {
      meta = meta.length > 0 ? `${meta} · ${item.recordCount} 条记录` : `${item.recordCount} 条记录`;
    }
    const mimeText = this.mimeText(item);
    if (mimeText.length > 0) {
      meta = meta.length > 0 ? `${meta} · ${mimeText}` : mimeText;
    }
    if (meta.length > 0) {
      return meta;
    }
    return item.kind;
  }

  private mimeText(item: ClipboardItem): string {
    if (item.mimeTypes.length === 0) {
      return '';
    }
    let text = item.mimeTypes[0];
    const limit = item.mimeTypes.length > 2 ? 2 : item.mimeTypes.length;
    for (let index = 1; index < limit; index++) {
      text = `${text}, ${item.mimeTypes[index]}`;
    }
    if (item.mimeTypes.length > limit) {
      text = `${text} +${item.mimeTypes.length - limit}`;
    }
    return text;
  }

  private formatTime(time: number): string {
    const date = new Date(time);
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }
}
