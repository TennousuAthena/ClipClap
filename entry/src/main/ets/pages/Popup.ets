import { common, Want } from '@kit.AbilityKit';
import { KeyCode, pointer } from '@kit.InputKit';
import { ClipboardHistoryStatus, ClipboardHistoryStore, ClipboardItem } from '../services/ClipboardHistoryStore';
import { AutoPasteService } from '../core/hotkey/AutoPasteService';
import { ImagePreviewWindowController } from '../core/window/ImagePreviewWindowController';
import { PopupWindowController } from '../core/window/PopupWindowController';
import { SettingsStore } from '../core/settings/SettingsStore';
import { AppSettings } from '../model/AppSettings';
import { PreviewTextFormatter, PreviewTextSegment } from '../model/PreviewTextSegment';

const POPUP_SEARCH_INPUT_ID = 'popup_search_input';
const POPUP_MONO_FONT = 'JetBrains Mono';
const TEXT_PREVIEW_LENGTH_THRESHOLD = 180;
const RESIZE_HANDLE_SIZE = 18;
const SETTINGS_ABILITY_NAME = 'SettingsAbility';

@Entry
@Component
struct Popup {
  private historyStore: ClipboardHistoryStore = ClipboardHistoryStore.getInstance();
  private settingsStore: SettingsStore = SettingsStore.getInstance();
  private unsubscribe: () => void = () => {};
  private listScroller: Scroller = new Scroller();

  @State private items: ClipboardItem[] = [];
  @State private searchText: string = '';
  @State private status: ClipboardHistoryStatus = ClipboardHistoryStatus.READY;
  @State private settings: AppSettings = AppSettings.createDefault();
  @State private isCtrlPressed: boolean = false;
  @State private selectedIndex: number = 0;
  @State private isResizing: boolean = false;
  @State private isPreviewFocusActive: boolean = false;
  @State private hoveredPreviewItemId: string = '';
  private resizeStartX: number = 0;
  private resizeStartY: number = 0;
  private resizeStartWidth: number = 0;
  private resizeStartHeight: number = 0;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.settings = this.settingsStore.getSettings();
    this.historyStore.init(context);
    this.unsubscribe = this.historyStore.subscribe((items: ClipboardItem[], status: ClipboardHistoryStatus) => {
      this.items = items;
      this.status = status;
      this.normalizeSelectedIndex();
    });
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus(POPUP_SEARCH_INPUT_ID);
    }, 80);
  }

  aboutToDisappear(): void {
    this.unsubscribe();
    ImagePreviewWindowController.getInstance().hidePreview();
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.app_title'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.app_text_muted'))
      }
      .width('100%')
      .height(20)
      .margin({ bottom: 8 })
      .onHover((isHover: boolean) => {
        if (isHover) {
          cursorControl.setCursor(pointer.PointerStyle.MOVE);
        } else {
          cursorControl.restoreDefault();
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          if (this.isFloatingWindowMode()) {
            PopupWindowController.getInstance().startMoving();
          }
        }
      })

      Row() {
        TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
          .id(POPUP_SEARCH_INPUT_ID)
          .defaultFocus(true)
          .height(42)
          .layoutWeight(1)
          .backgroundColor($r('app.color.app_surface_subtle'))
          .borderRadius(8)
          .onChange((value: string) => {
            this.searchText = value;
            this.selectedIndex = 0;
            this.updateImagePreview();
          })
          .onFocus(() => {
            this.isPreviewFocusActive = true;
            this.updateImagePreview();
          })
          .onBlur(() => {
            this.isPreviewFocusActive = false;
            ImagePreviewWindowController.getInstance().hidePreview();
          })
          .onKeyEvent((event: KeyEvent) => {
            return this.handleKeyEvent(event);
          })
        Button() {
          this.ButtonLabel($r('sys.symbol.gearshape'), $r('app.string.action_open_settings'),
            $r('app.color.app_text_secondary'))
        }
          .height(42)
          .margin({ left: 10 })
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.openSettingsWindow();
          })
        Button() {
          this.ButtonLabel($r('sys.symbol.xmark'), $r('app.string.action_close'), $r('app.color.app_text_secondary'))
        }
          .height(42)
          .margin({ left: 10 })
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.closePopupSurface();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.filteredItems().length === 0) {
        Column() {
          Text($r('app.string.empty_title'))
            .fontSize(18)
            .fontColor($r('app.color.app_text_primary'))
          Text(this.statusText())
            .fontSize(13)
            .fontColor($r('app.color.app_text_secondary'))
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4, scroller: this.listScroller }) {
          ForEach(this.filteredItems(), (item: ClipboardItem, index: number) => {
            ListItem() {
              this.PopupItem(item, index)
            }
          }, (item: ClipboardItem) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ right: 14, bottom: 8 })
        .scrollBar(BarState.On)
      }

      Row() {
        Blank()
          .layoutWeight(1)
        if (this.isFloatingWindowMode()) {
          Column() {
          }
            .width(RESIZE_HANDLE_SIZE)
            .height(RESIZE_HANDLE_SIZE)
            .border({ width: { right: 2, bottom: 2 }, color: $r('app.color.app_text_muted') })
            .onHover((isHover: boolean) => {
              if (isHover) {
                cursorControl.setCursor(pointer.PointerStyle.SOUTH_EAST);
              } else {
                cursorControl.restoreDefault();
              }
            })
            .onTouch((event: TouchEvent) => {
              this.handleResizeTouch(event);
            })
        }
      }
      .width('100%')
      .height(RESIZE_HANDLE_SIZE)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 8 })
    .backgroundColor($r('app.color.app_surface'))
    .focusable(true)
    .onFocus(() => {
      this.isPreviewFocusActive = true;
      this.updateImagePreview();
    })
    .onBlur(() => {
      this.isPreviewFocusActive = false;
      ImagePreviewWindowController.getInstance().hidePreview();
    })
    .onKeyEvent((event: KeyEvent) => {
      return this.handleKeyEvent(event);
    })
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
  private PopupItem(item: ClipboardItem, index: number) {
    Row() {
      Column() {
        this.PreviewContent(item)
      }
      .layoutWeight(1)

      if (index < 9) {
        Text(this.shortcutText(index))
          .width(58)
          .height(28)
          .fontSize(12)
          .fontColor($r('app.color.app_text_muted'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.app_surface'))
          .borderRadius(6)
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 10, top: 8, bottom: 8 })
    .backgroundColor(this.isSelected(index) ? $r('app.color.app_accent_soft') : $r('app.color.app_surface_subtle'))
    .borderRadius(8)
    .border({ width: this.isSelected(index) ? 1 : 0, color: $r('app.color.app_accent') })
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.selectedIndex = index;
        this.hoveredPreviewItemId = item.id;
        this.updateImagePreview();
        cursorControl.setCursor(pointer.PointerStyle.HAND_POINTING);
      } else {
        if (this.hoveredPreviewItemId === item.id) {
          this.hoveredPreviewItemId = '';
          ImagePreviewWindowController.getInstance().hidePreview();
        }
        cursorControl.restoreDefault();
      }
    })
    .onClick(() => {
      this.selectItem(item);
    })
  }

  @Builder
  private PreviewContent(item: ClipboardItem) {
    if (this.isImageOnlyItem(item)) {
      Row() {
        if (item.pixelMap !== undefined) {
          Image(item.pixelMap)
            .width(74)
            .height(56)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.app_surface'))
            .borderRadius(7)
        } else {
          Image(item.imageFileUri)
            .width(74)
            .height(56)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.app_surface'))
            .borderRadius(7)
        }
        Column() {
          this.PreviewText(item.preview, 13, 18, this.isSelectedItem(item) ? 5 : 2)
          Text(this.mediaMetaText(item))
            .fontSize(11)
            .fontColor($r('app.color.app_text_muted'))
            .lineHeight(16)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .margin({ left: 9 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 7 })
    } else if (this.isMediaKind(item.kind)) {
      Column() {
        this.PreviewText(this.detailedPreview(item), 13, 18, this.isSelectedItem(item) ? 5 : 2)
        Text(this.mediaMetaText(item))
          .fontSize(11)
          .fontColor($r('app.color.app_text_muted'))
          .lineHeight(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 4 })
      }
      .width('100%')
    } else {
      this.PreviewText(this.detailedPreview(item), 14, 20, this.isSelectedItem(item) ? 7 : 3)
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
            .fontFamily(POPUP_MONO_FONT)
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

  private filteredItems(): ClipboardItem[] {
    const query = this.searchText.trim().toLowerCase();
    if (query.length === 0) {
      return this.items;
    }
    return this.items.filter((item: ClipboardItem) => {
      return this.itemSearchText(item).indexOf(query) >= 0;
    });
  }

  private statusText(): Resource {
    if (this.status === ClipboardHistoryStatus.PERMISSION_DENIED) {
      return $r('app.string.status_permission_denied');
    }
    if (this.status === ClipboardHistoryStatus.EMPTY_CLIPBOARD) {
      return $r('app.string.status_empty_clipboard');
    }
    if (this.status === ClipboardHistoryStatus.TEXT_ONLY) {
      return $r('app.string.status_text_only');
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

  private handleKeyEvent(event: KeyEvent): boolean {
    if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
      this.isCtrlPressed = event.type === KeyType.Down;
      return false;
    }
    if (event.type !== KeyType.Down) {
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.closePopupSurface();
      return true;
    }
    if (this.isPreviousKey(event.keyCode)) {
      this.moveSelection(-1);
      return true;
    }
    if (this.isNextKey(event.keyCode)) {
      this.moveSelection(1);
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER ||
      event.keyCode === KeyCode.KEYCODE_DPAD_CENTER) {
      this.selectSelectedItem();
      return true;
    }
    if (this.isCtrlShortcutActive(event)) {
      const index = this.shortcutIndex(event.keyCode);
      if (index >= 0) {
        const items = this.filteredItems();
        if (index < items.length) {
          this.selectItem(items[index]);
          return true;
        }
      }
    }
    return false;
  }

  private handleResizeTouch(event: TouchEvent): void {
    if (!this.isFloatingWindowMode()) {
      return;
    }
    const point = this.resizeTouchPoint(event);
    if (point === undefined) {
      return;
    }

    if (event.type === TouchType.Down) {
      const size = PopupWindowController.getInstance().getCurrentSize();
      this.isResizing = true;
      this.resizeStartX = point.displayX;
      this.resizeStartY = point.displayY;
      this.resizeStartWidth = size[0];
      this.resizeStartHeight = size[1];
      event.stopPropagation();
      return;
    }

    if (!this.isResizing) {
      return;
    }

    if (event.type === TouchType.Move) {
      PopupWindowController.getInstance().resizeByDrag(this.resizeStartWidth, this.resizeStartHeight,
        point.displayX - this.resizeStartX, point.displayY - this.resizeStartY);
      event.stopPropagation();
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.isResizing = false;
      PopupWindowController.getInstance().saveCurrentRect();
      this.settings = this.settingsStore.getSettings();
      event.stopPropagation();
    }
  }

  private resizeTouchPoint(event: TouchEvent): TouchObject | undefined {
    if (event.touches.length > 0) {
      return event.touches[0];
    }
    if (event.changedTouches.length > 0) {
      return event.changedTouches[0];
    }
    return undefined;
  }

  private isCtrlShortcutActive(event: KeyEvent): boolean {
    if (this.isCtrlPressed) {
      return true;
    }
    if (event.getModifierKeyState !== undefined) {
      try {
        return event.getModifierKeyState(['Ctrl']);
      } catch (err) {
        return false;
      }
    }
    return false;
  }

  private shortcutIndex(keyCode: number): number {
    if (keyCode >= KeyCode.KEYCODE_1 && keyCode <= KeyCode.KEYCODE_9) {
      return keyCode - KeyCode.KEYCODE_1;
    }
    return -1;
  }

  private shortcutText(index: number): string {
    if (index >= 0 && index < 9) {
      return `Ctrl+${index + 1}`;
    }
    return '';
  }

  private detailedPreview(item: ClipboardItem): string {
    if (item.text.length > 0) {
      return item.text;
    }
    if (item.uri.length > 0) {
      return item.uri;
    }
    return item.preview;
  }

  private isSelected(index: number): boolean {
    return index === this.selectedIndex;
  }

  private isSelectedItem(item: ClipboardItem): boolean {
    const items = this.filteredItems();
    if (this.selectedIndex < 0 || this.selectedIndex >= items.length) {
      return false;
    }
    return items[this.selectedIndex].id === item.id;
  }

  private normalizeSelectedIndex(): void {
    const items = this.filteredItems();
    if (items.length === 0) {
      this.selectedIndex = 0;
      return;
    }
    if (this.selectedIndex < 0) {
      this.selectedIndex = 0;
      return;
    }
    if (this.selectedIndex >= items.length) {
      this.selectedIndex = items.length - 1;
    }
    this.updateImagePreview();
  }

  private moveSelection(delta: number): void {
    const items = this.filteredItems();
    if (items.length === 0) {
      this.selectedIndex = 0;
      return;
    }
    let nextIndex = this.selectedIndex + delta;
    if (nextIndex < 0) {
      nextIndex = 0;
    }
    if (nextIndex >= items.length) {
      nextIndex = items.length - 1;
    }
    this.selectedIndex = nextIndex;
    this.listScroller.scrollToIndex(this.selectedIndex, true, ScrollAlign.AUTO);
    this.updateImagePreview();
  }

  private selectSelectedItem(): void {
    const items = this.filteredItems();
    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
      this.selectItem(items[this.selectedIndex]);
    }
  }

  private selectItem(item: ClipboardItem): void {
    this.historyStore.copyItem(item).then((isCopied: boolean) => {
      this.closePopupSurface().then(() => {
        if (isCopied && this.settings.isDebugModeEnabled && this.settings.isAutoPasteEnabled) {
          AutoPasteService.getInstance().pasteAfterDelay();
        }
      });
    });
  }

  private isFloatingWindowMode(): boolean {
    return this.settings.isDebugModeEnabled && this.settings.isFloatingWindowPresentationEnabled;
  }

  private async closePopupSurface(): Promise<void> {
    if (this.isFloatingWindowMode()) {
      await PopupWindowController.getInstance().hidePopup();
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await context.moveAbilityToBackground();
    } catch (err) {
      try {
        await context.terminateSelf();
      } catch (terminateErr) {
      }
    }
  }

  private openSettingsWindow(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: SETTINGS_ABILITY_NAME,
      moduleName: context.abilityInfo.moduleName,
      parameters: {
        source: 'popup'
      }
    };
    context.startAbility(want).catch(() => {
    });
  }

  private updateImagePreview(): void {
    const items = this.filteredItems();
    if (this.selectedIndex < 0 || this.selectedIndex >= items.length) {
      ImagePreviewWindowController.getInstance().hidePreview();
      return;
    }
    const item = items[this.selectedIndex];
    if (!this.isPreviewFocusActive || this.hoveredPreviewItemId !== item.id) {
      ImagePreviewWindowController.getInstance().hidePreview();
      return;
    }
    if (this.hasLocalImagePreview(item) || this.canPreviewRemoteImage(item) || this.shouldShowTextPreview(item)) {
      ImagePreviewWindowController.getInstance().showPreview(item.id);
    } else {
      ImagePreviewWindowController.getInstance().hidePreview();
    }
  }

  private canPreviewRemoteImage(item: ClipboardItem): boolean {
    return this.settings.isRemoteImagePreviewEnabled && item.remoteImageUrl.length > 0;
  }

  private shouldShowTextPreview(item: ClipboardItem): boolean {
    if (this.hasLocalImagePreview(item) || this.canPreviewRemoteImage(item)) {
      return false;
    }
    const text = this.detailedPreview(item);
    return text.length > TEXT_PREVIEW_LENGTH_THRESHOLD || text.indexOf('\n') >= 0 || text.indexOf('\t') >= 0;
  }

  private isPreviousKey(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_DPAD_UP || keyCode === KeyCode.KEYCODE_DPAD_LEFT;
  }

  private isNextKey(keyCode: number): boolean {
    return keyCode === KeyCode.KEYCODE_DPAD_DOWN || keyCode === KeyCode.KEYCODE_DPAD_RIGHT;
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
}
