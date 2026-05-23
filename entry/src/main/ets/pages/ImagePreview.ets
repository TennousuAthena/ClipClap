import { ClipboardHistoryStore, ClipboardItem } from '../services/ClipboardHistoryStore';
import { SettingsStore } from '../core/settings/SettingsStore';
import { AppSettings } from '../model/AppSettings';
import { PreviewTextFormatter, PreviewTextSegment } from '../model/PreviewTextSegment';

const IMAGE_PREVIEW_ITEM_ID = 'previewImageItemId';
const IMAGE_PREVIEW_MONO_FONT = 'JetBrains Mono';

@Entry
@Component
struct ImagePreview {
  private historyStore: ClipboardHistoryStore = ClipboardHistoryStore.getInstance();
  private settingsStore: SettingsStore = SettingsStore.getInstance();

  @State private item: ClipboardItem | undefined = undefined;
  @State private settings: AppSettings = AppSettings.createDefault();

  aboutToAppear(): void {
    this.settings = this.settingsStore.getSettings();
    const itemId = AppStorage.get<string>(IMAGE_PREVIEW_ITEM_ID);
    if (itemId !== undefined) {
      this.item = this.historyStore.getItemById(itemId);
    }
  }

  build() {
    Column() {
      if (this.item !== undefined && this.item.pixelMap !== undefined) {
        Image(this.item.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else if (this.canShowLocalPreview()) {
        Image(this.localImageSource())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else if (this.canShowRemotePreview()) {
        Image(this.remoteImageSource())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else if (this.canShowTextPreview()) {
        Scroll() {
          Text() {
            ForEach(PreviewTextFormatter.buildSegments(this.previewText()), (segment: PreviewTextSegment) => {
              if (segment.isImagePlaceholder) {
                Span($r('app.string.image_placeholder'))
              } else if (segment.isMarker) {
                Span(segment.text)
                  .fontFamily(IMAGE_PREVIEW_MONO_FONT)
              } else {
                Span(segment.text)
              }
            }, (segment: PreviewTextSegment) => segment.id)
          }
          .fontSize(14)
          .fontColor($r('app.color.app_text_primary'))
          .lineHeight(22)
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
      } else {
        Text($r('app.string.image_preview_unavailable'))
          .fontSize(14)
          .fontColor($r('app.color.app_text_secondary'))
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.app_surface'))
  }

  private canShowRemotePreview(): boolean {
    return this.settings.isRemoteImagePreviewEnabled && this.item !== undefined &&
      this.item.remoteImageUrl.length > 0;
  }

  private canShowLocalPreview(): boolean {
    return this.item !== undefined && this.item.imageFileUri.length > 0;
  }

  private canShowTextPreview(): boolean {
    return this.item !== undefined && this.previewText().length > 0;
  }

  private remoteImageSource(): string {
    if (this.item === undefined) {
      return '';
    }
    return this.item.remoteImageUrl;
  }

  private localImageSource(): string {
    if (this.item === undefined) {
      return '';
    }
    return this.item.imageFileUri;
  }

  private previewText(): string {
    if (this.item === undefined) {
      return '';
    }
    if (this.item.text.length > 0) {
      return this.item.text;
    }
    if (this.item.uri.length > 0) {
      return this.item.uri;
    }
    return this.item.preview;
  }
}
