import { common } from '@kit.AbilityKit';
import { preferences, relationalStore, unifiedDataChannel } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { IMAGE_PLACEHOLDER_TOKEN } from '../model/PreviewTextSegment';

const LEGACY_STORE_NAME = 'clipclap_history';
const RDB_STORE_NAME = 'clipclap_history.db';
const HISTORY_TABLE_NAME = 'history_items';
const ORDER_KEY = 'history_order';
const ITEM_KEY_PREFIX = 'item_';
const IMAGE_ASSET_DIR_NAME = 'clipclap_image_assets';
const IMAGE_ASSET_EXTENSION = 'png';
const IMAGE_ASSET_FORMAT = 'image/png';
const DEFAULT_MAX_HISTORY_ITEMS = 60;
const MAX_TEXT_LENGTH = 4000;
const MAX_RAW_PAYLOAD_LENGTH = 12000;
const PREVIEW_LENGTH = 160;
const PROGRAMMATIC_UPDATE_IGNORE_MS = 1200;
const IMAGE_PLACEHOLDER = IMAGE_PLACEHOLDER_TOKEN;
const HISTORY_DB_VERSION = 1;
const SQL_CREATE_HISTORY_TABLE =
  'CREATE TABLE IF NOT EXISTS history_items (' +
    'id TEXT PRIMARY KEY, ' +
    'created_at INTEGER NOT NULL, ' +
    'copied_at INTEGER NOT NULL, ' +
    'is_pinned INTEGER NOT NULL, ' +
    'snapshot TEXT NOT NULL' +
  ')';
const SQL_CREATE_HISTORY_SORT_INDEX =
  'CREATE INDEX IF NOT EXISTS idx_history_items_sort ON history_items(is_pinned DESC, copied_at DESC)';
const SQL_SELECT_HISTORY =
  'SELECT snapshot FROM history_items ORDER BY is_pinned DESC, copied_at DESC';
const SQL_DELETE_HISTORY = 'DELETE FROM history_items';
const RDB_STORE_CONFIG: relationalStore.StoreConfig = {
  name: RDB_STORE_NAME,
  securityLevel: relationalStore.SecurityLevel.S2
};

export enum ClipboardItemKind {
  TEXT = 'Text',
  LINK = 'Link',
  CODE = 'Code',
  HTML = 'HTML',
  IMAGE = 'Image',
  URI = 'URI',
  FILE = 'File',
  CUSTOM = 'Custom'
}

export enum ClipboardHistoryStatus {
  READY = 'Ready',
  EMPTY_CLIPBOARD = 'EmptyClipboard',
  TEXT_ONLY = 'TextOnly',
  RECORDED = 'Recorded',
  LOAD_EMPTY = 'LoadEmpty',
  LOAD_DONE = 'LoadDone',
  PERMISSION_DENIED = 'PermissionDenied',
  COPY_DONE = 'CopyDone',
  COPY_FAILED = 'CopyFailed',
  DELETE_DONE = 'DeleteDone',
  CLEAR_DONE = 'ClearDone',
  CLEAR_EMPTY = 'ClearEmpty',
  PIN_DONE = 'PinDone',
  UNPIN_DONE = 'UnpinDone'
}

export interface ClipboardItemSnapshot {
  id: string;
  text: string;
  preview: string;
  kind: string;
  createdAt: number;
  copiedAt: number;
  copyCount: number;
  isPinned: boolean;
  signature?: string;
  uri?: string;
  fileUris?: Array<string>;
  html?: string;
  mimeTypes?: Array<string>;
  recordCount?: number;
  hasImage?: boolean;
  imageWidth?: number;
  imageHeight?: number;
  imageFilePath?: string;
  imageFileUri?: string;
  remoteImageUrl?: string;
  rawPayload?: string;
}

class ClipboardCaptureResult {
  text: string = '';
  preview: string = '';
  kind: ClipboardItemKind = ClipboardItemKind.TEXT;
  signature: string = '';
  uri: string = '';
  fileUris: Array<string> = [];
  html: string = '';
  mimeTypes: Array<string> = [];
  recordCount: number = 0;
  hasImage: boolean = false;
  pixelMap: image.PixelMap | undefined = undefined;
  imageWidth: number = 0;
  imageHeight: number = 0;
  remoteImageUrl: string = '';
  rawPayload: string = '';

  isRecordable(): boolean {
    return this.signature.length > 0 && this.preview.length > 0;
  }
}

class ClipboardImageRawPayload {
  hasImage: boolean = false;
  width: number = 0;
  height: number = 0;
  remoteUrl: string = '';
}

class ClipboardRecordRawPayload {
  index: number = 0;
  isAvailable: boolean = true;
  mimeType: string = '';
  plainText: string = '';
  uri: string = '';
  fileUris: Array<string> = [];
  htmlText: string = '';
  pixelMap: string = '';
}

class ClipboardRawPayload {
  kind: string = '';
  signature: string = '';
  recordCount: number = 0;
  mimeTypes: Array<string> = [];
  mimeSummary: string = '';
  primaryMimeType: string = '';
  text: string = '';
  uri: string = '';
  fileUris: Array<string> = [];
  html: string = '';
  image: ClipboardImageRawPayload = new ClipboardImageRawPayload();
  records: Array<ClipboardRecordRawPayload> = [];
}

export class ClipboardItem {
  id: string;
  text: string;
  preview: string;
  kind: ClipboardItemKind;
  createdAt: number;
  copiedAt: number;
  copyCount: number;
  isPinned: boolean;
  signature: string;
  uri: string;
  fileUris: Array<string>;
  html: string;
  mimeTypes: Array<string>;
  recordCount: number;
  hasImage: boolean;
  pixelMap: image.PixelMap | undefined;
  imageWidth: number;
  imageHeight: number;
  imageFilePath: string;
  imageFileUri: string;
  remoteImageUrl: string;
  rawPayload: string;

  constructor(id: string, text: string, preview: string, kind: ClipboardItemKind, createdAt: number,
    signature: string) {
    this.id = id;
    this.text = text;
    this.preview = preview.length > 0 ? preview : ClipboardItem.buildPreview(text);
    this.kind = kind;
    this.createdAt = createdAt;
    this.copiedAt = createdAt;
    this.copyCount = 1;
    this.isPinned = false;
    this.signature = signature;
    this.uri = '';
    this.fileUris = [];
    this.html = '';
    this.mimeTypes = [];
    this.recordCount = 0;
    this.hasImage = false;
    this.pixelMap = undefined;
    this.imageWidth = 0;
    this.imageHeight = 0;
    this.imageFilePath = '';
    this.imageFileUri = '';
    this.remoteImageUrl = '';
    this.rawPayload = '';
  }

  static create(result: ClipboardCaptureResult, sequence: number): ClipboardItem {
    const now = Date.now();
    const item = new ClipboardItem(`clip_${now}_${sequence}`, result.text, result.preview, result.kind, now,
      result.signature);
    item.uri = result.uri;
    item.fileUris = result.fileUris.slice();
    item.html = result.html;
    item.mimeTypes = result.mimeTypes.slice();
    item.recordCount = result.recordCount;
    item.hasImage = result.hasImage;
    item.pixelMap = result.pixelMap;
    item.imageWidth = result.imageWidth;
    item.imageHeight = result.imageHeight;
    item.remoteImageUrl = result.remoteImageUrl;
    item.rawPayload = result.rawPayload;
    return item;
  }

  static fromSnapshot(snapshot: ClipboardItemSnapshot): ClipboardItem {
    const kind = ClipboardItem.kindFromString(snapshot.kind);
    let signature = snapshot.text;
    if (snapshot.signature !== undefined && snapshot.signature.length > 0) {
      signature = snapshot.signature;
    }
    const item = new ClipboardItem(snapshot.id, snapshot.text, snapshot.preview, kind, snapshot.createdAt, signature);
    item.preview = snapshot.preview.length > 0 ? snapshot.preview : ClipboardItem.buildPreview(snapshot.text);
    item.copiedAt = snapshot.copiedAt;
    item.copyCount = snapshot.copyCount;
    item.isPinned = snapshot.isPinned;
    if (snapshot.uri !== undefined) {
      item.uri = snapshot.uri;
    }
    if (snapshot.fileUris !== undefined) {
      item.fileUris = snapshot.fileUris.slice();
    }
    if (snapshot.html !== undefined) {
      item.html = snapshot.html;
    }
    if (snapshot.mimeTypes !== undefined) {
      item.mimeTypes = snapshot.mimeTypes.slice();
    }
    if (snapshot.recordCount !== undefined) {
      item.recordCount = snapshot.recordCount;
    }
    if (snapshot.hasImage !== undefined) {
      item.hasImage = snapshot.hasImage;
    }
    if (snapshot.imageWidth !== undefined) {
      item.imageWidth = snapshot.imageWidth;
    }
    if (snapshot.imageHeight !== undefined) {
      item.imageHeight = snapshot.imageHeight;
    }
    if (snapshot.imageFilePath !== undefined) {
      item.imageFilePath = snapshot.imageFilePath;
    }
    if (snapshot.imageFileUri !== undefined) {
      item.imageFileUri = snapshot.imageFileUri;
    }
    if (snapshot.remoteImageUrl !== undefined) {
      item.remoteImageUrl = snapshot.remoteImageUrl;
    }
    if (snapshot.rawPayload !== undefined) {
      item.rawPayload = snapshot.rawPayload;
    }
    return item;
  }

  toSnapshot(): ClipboardItemSnapshot {
    return {
      id: this.id,
      text: this.text,
      preview: this.preview,
      kind: this.kind,
      createdAt: this.createdAt,
      copiedAt: this.copiedAt,
      copyCount: this.copyCount,
      isPinned: this.isPinned,
      signature: this.signature,
      uri: this.uri,
      fileUris: this.fileUris.slice(),
      html: this.html,
      mimeTypes: this.mimeTypes.slice(),
      recordCount: this.recordCount,
      hasImage: this.hasImage,
      imageWidth: this.imageWidth,
      imageHeight: this.imageHeight,
      imageFilePath: this.imageFilePath,
      imageFileUri: this.imageFileUri,
      remoteImageUrl: this.remoteImageUrl,
      rawPayload: this.rawPayload
    };
  }

  static buildPreview(text: string): string {
    const value = text.trim();
    if (value.length <= PREVIEW_LENGTH) {
      return value;
    }
    return `${value.substring(0, PREVIEW_LENGTH)}...`;
  }

  private static kindFromString(kind: string): ClipboardItemKind {
    if (kind === ClipboardItemKind.LINK) {
      return ClipboardItemKind.LINK;
    }
    if (kind === ClipboardItemKind.CODE) {
      return ClipboardItemKind.CODE;
    }
    if (kind === ClipboardItemKind.HTML) {
      return ClipboardItemKind.HTML;
    }
    if (kind === ClipboardItemKind.IMAGE) {
      return ClipboardItemKind.IMAGE;
    }
    if (kind === ClipboardItemKind.URI) {
      return ClipboardItemKind.URI;
    }
    if (kind === ClipboardItemKind.FILE) {
      return ClipboardItemKind.FILE;
    }
    if (kind === ClipboardItemKind.CUSTOM) {
      return ClipboardItemKind.CUSTOM;
    }
    return ClipboardItemKind.TEXT;
  }
}

type HistoryChangeListener = (items: ClipboardItem[], status: ClipboardHistoryStatus) => void;

export class ClipboardHistoryStore {
  private static instance: ClipboardHistoryStore = new ClipboardHistoryStore();

  private board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
  private items: ClipboardItem[] = [];
  private listeners: HistoryChangeListener[] = [];
  private context?: common.UIAbilityContext;
  private rdbStore?: relationalStore.RdbStore;
  private legacyPrefs?: preferences.Preferences;
  private memoryPasteData: Map<string, pasteboard.PasteData> = new Map<string, pasteboard.PasteData>();
  private memoryUnifiedData: Map<string, unifiedDataChannel.UnifiedData> =
    new Map<string, unifiedDataChannel.UnifiedData>();
  private isInitialized: boolean = false;
  private isListeningEnabled: boolean = true;
  private isListening: boolean = false;
  private isReadingPasteboard: boolean = false;
  private status: ClipboardHistoryStatus = ClipboardHistoryStatus.READY;
  private lastWrittenSignature: string = '';
  private lastWrittenAt: number = 0;
  private ignoreUpdateUntil: number = 0;
  private updateCallback: () => void = () => {};
  private sequence: number = 0;
  private maxHistoryItems: number = DEFAULT_MAX_HISTORY_ITEMS;
  private isPlainTextPasteEnabled: boolean = false;
  private isRecordLocalFilesEnabled: boolean = false;
  private imageAssetDir: string = '';

  static getInstance(): ClipboardHistoryStore {
    return ClipboardHistoryStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.isInitialized) {
      this.notify();
      return;
    }

    try {
      this.context = context;
      this.imageAssetDir = `${context.filesDir}/${IMAGE_ASSET_DIR_NAME}`;
      this.rdbStore = await relationalStore.getRdbStore(context, RDB_STORE_CONFIG);
      await this.ensureSchema();
      await this.load();
      this.isInitialized = true;
      if (this.isListeningEnabled) {
        this.startListening();
      } else {
        this.stopListening();
      }
      this.notify();
      if (this.isListeningEnabled) {
        await this.captureCurrentClipboard();
      }
    } catch (err) {
      this.status = ClipboardHistoryStatus.LOAD_EMPTY;
      this.notify();
    }
  }

  dispose(): void {
    this.stopListening();
    this.listeners = [];
  }

  subscribe(listener: HistoryChangeListener): () => void {
    this.listeners.push(listener);
    listener(this.items.slice(), this.status);
    return () => {
      this.listeners = this.listeners.filter((candidate: HistoryChangeListener) => candidate !== listener);
    };
  }

  getItems(): ClipboardItem[] {
    return this.items.slice();
  }

  getItemById(id: string): ClipboardItem | undefined {
    const index = this.items.findIndex((item: ClipboardItem) => item.id === id);
    if (index < 0) {
      return undefined;
    }
    return this.items[index];
  }

  setMaxHistoryItems(value: number): void {
    this.maxHistoryItems = value;
    this.trimToCapacity();
    this.notify();
    this.save();
  }

  setPlainTextPasteEnabled(isEnabled: boolean): void {
    this.isPlainTextPasteEnabled = isEnabled;
  }

  setRecordLocalFilesEnabled(isEnabled: boolean): void {
    this.isRecordLocalFilesEnabled = isEnabled;
  }

  setListeningEnabled(isEnabled: boolean): void {
    this.isListeningEnabled = isEnabled;
    if (!this.isInitialized) {
      return;
    }
    if (isEnabled) {
      this.startListening();
      this.captureCurrentClipboard();
      return;
    }
    this.stopListening();
  }

  async captureCurrentClipboard(): Promise<void> {
    if (this.isReadingPasteboard) {
      return;
    }
    if (this.shouldIgnoreProgrammaticUpdate()) {
      this.notify();
      return;
    }

    this.isReadingPasteboard = true;
    try {
      const hasData = await this.board.hasData();
      if (!hasData) {
        this.status = ClipboardHistoryStatus.EMPTY_CLIPBOARD;
        this.notify();
        return;
      }

      let data: pasteboard.PasteData | undefined = undefined;
      let result = new ClipboardCaptureResult();
      try {
        data = await this.board.getData();
        result = this.extractClipboard(data);
      } catch (err) {
        data = undefined;
      }
      const unifiedData = await this.safeGetUnifiedData();
      if (data === undefined && unifiedData === undefined) {
        throw new Error('Clipboard data is unavailable.');
      }
      if (unifiedData !== undefined) {
        this.enrichWithUnifiedData(result, unifiedData);
        if (data !== undefined) {
          this.assignRawPayload(result, data);
        }
      }
      if (!this.isRecordLocalFilesEnabled && result.fileUris.length > 0) {
        this.status = ClipboardHistoryStatus.TEXT_ONLY;
        this.notify();
        return;
      }
      if (!result.isRecordable()) {
        this.status = ClipboardHistoryStatus.TEXT_ONLY;
        this.notify();
        return;
      }

      if (this.isProgrammaticClipboardUpdate(result.signature)) {
        this.notify();
        return;
      }

      const itemId = this.addOrPromote(result);
      const item = this.getItemById(itemId);
      if (item !== undefined) {
        await this.ensureImageAsset(item);
      }
      if (data !== undefined) {
        this.memoryPasteData.set(itemId, data);
      }
      if (unifiedData !== undefined && result.fileUris.length > 0) {
        this.memoryUnifiedData.set(itemId, unifiedData);
      }
      await this.save();
      this.status = ClipboardHistoryStatus.RECORDED;
      this.notify();
    } catch (err) {
      this.status = ClipboardHistoryStatus.PERMISSION_DENIED;
      this.notify();
    } finally {
      this.isReadingPasteboard = false;
    }
  }

  async copyItem(item: ClipboardItem): Promise<boolean> {
    try {
      await this.restoreImagePixelMap(item);
      const unifiedData = this.memoryUnifiedData.get(item.id);
      if (!this.isPlainTextPasteEnabled && unifiedData !== undefined) {
        this.ignoreUpdateUntil = Date.now() + PROGRAMMATIC_UPDATE_IGNORE_MS;
        await this.board.setUnifiedData(unifiedData);
        this.lastWrittenSignature = item.signature;
        this.lastWrittenAt = Date.now();
        this.promoteItem(item.id);
        this.status = ClipboardHistoryStatus.COPY_DONE;
        this.notify();
        await this.save();
        return true;
      }

      const pasteData = this.createWritablePasteDataForItem(item);
      if (pasteData === undefined) {
        this.status = ClipboardHistoryStatus.COPY_FAILED;
        this.notify();
        return false;
      }

      this.ignoreUpdateUntil = Date.now() + PROGRAMMATIC_UPDATE_IGNORE_MS;
      await this.board.setData(pasteData);
      this.memoryPasteData.set(item.id, pasteData);
      this.lastWrittenSignature = item.signature;
      this.lastWrittenAt = Date.now();
      this.promoteItem(item.id);
      this.status = ClipboardHistoryStatus.COPY_DONE;
      this.notify();
      await this.save();
      return true;
    } catch (err) {
      this.status = ClipboardHistoryStatus.COPY_FAILED;
      this.notify();
      return false;
    }
  }

  async copyRawPayload(rawPayload: string): Promise<void> {
    if (rawPayload.trim().length === 0) {
      this.status = ClipboardHistoryStatus.COPY_FAILED;
      this.notify();
      return;
    }

    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, rawPayload);
      this.ignoreUpdateUntil = Date.now() + PROGRAMMATIC_UPDATE_IGNORE_MS;
      await this.board.setData(pasteData);
      this.status = ClipboardHistoryStatus.COPY_DONE;
      this.notify();
    } catch (err) {
      this.status = ClipboardHistoryStatus.COPY_FAILED;
      this.notify();
    }
  }

  private createWritablePasteDataForItem(item: ClipboardItem): pasteboard.PasteData | undefined {
    if (this.isPlainTextPasteEnabled && this.canFallbackToPlainText(item)) {
      return this.createPlainTextPasteDataForItem(item);
    }

    const originalData = this.memoryPasteData.get(item.id);
    if (originalData !== undefined && (item.fileUris.length > 0 || (item.hasImage && (item.text.length > 0 ||
      item.html.length > 0 || item.uri.length > 0)))) {
      const clonedData = this.clonePasteData(originalData);
      if (clonedData !== undefined) {
        return clonedData;
      }
    }

    const freshData = this.createPasteDataForItem(item);
    if (freshData !== undefined) {
      return freshData;
    }

    if (this.canFallbackToPlainText(item)) {
      return this.createPlainTextPasteDataForItem(item);
    }

    return undefined;
  }

  private canFallbackToPlainText(item: ClipboardItem): boolean {
    if (item.kind === ClipboardItemKind.IMAGE) {
      return false;
    }
    if (item.kind === ClipboardItemKind.CUSTOM) {
      return false;
    }
    if (item.kind === ClipboardItemKind.FILE) {
      return item.fileUris.length === 0 && item.uri.length === 0;
    }
    return true;
  }

  async deleteItem(id: string): Promise<void> {
    const item = this.getItemById(id);
    if (item !== undefined) {
      this.deleteImageAsset(item);
    }
    this.items = this.items.filter((item: ClipboardItem) => item.id !== id);
    this.memoryPasteData.delete(id);
    this.memoryUnifiedData.delete(id);
    await this.save();
    this.status = ClipboardHistoryStatus.DELETE_DONE;
    this.notify();
  }

  async clearUnpinned(): Promise<void> {
    for (let index = 0; index < this.items.length; index++) {
      const item = this.items[index];
      if (!item.isPinned) {
        this.deleteImageAsset(item);
        this.memoryPasteData.delete(item.id);
        this.memoryUnifiedData.delete(item.id);
      }
    }
    this.items = this.items.filter((item: ClipboardItem) => item.isPinned);
    await this.save();
    this.status = this.items.length > 0 ? ClipboardHistoryStatus.CLEAR_DONE : ClipboardHistoryStatus.CLEAR_EMPTY;
    this.notify();
  }

  async togglePinned(id: string): Promise<void> {
    const index = this.items.findIndex((item: ClipboardItem) => item.id === id);
    if (index < 0) {
      return;
    }
    this.items[index].isPinned = !this.items[index].isPinned;
    const isPinned = this.items[index].isPinned;
    this.sortItems();
    await this.save();
    this.status = isPinned ? ClipboardHistoryStatus.PIN_DONE : ClipboardHistoryStatus.UNPIN_DONE;
    this.notify();
  }

  private startListening(): void {
    if (this.isListening) {
      return;
    }

    this.updateCallback = () => {
      this.captureCurrentClipboard();
    };
    try {
      this.board.on('update', this.updateCallback);
      this.isListening = true;
    } catch (err) {
      this.isListening = false;
    }
  }

  private stopListening(): void {
    if (!this.isListening) {
      return;
    }
    try {
      this.board.off('update', this.updateCallback);
    } catch (err) {
    } finally {
      this.isListening = false;
    }
  }

  private addOrPromote(result: ClipboardCaptureResult): string {
    const index = this.findDuplicateIndex(result);
    if (index >= 0) {
      const existing = this.items[index];
      existing.text = result.text;
      existing.preview = result.preview;
      existing.kind = result.kind;
      existing.signature = result.signature;
      existing.uri = result.uri;
      existing.fileUris = result.fileUris.slice();
      existing.html = result.html;
      existing.mimeTypes = result.mimeTypes.slice();
      existing.recordCount = result.recordCount;
      existing.hasImage = result.hasImage;
      existing.pixelMap = result.pixelMap;
      existing.imageWidth = result.imageWidth;
      existing.imageHeight = result.imageHeight;
      existing.remoteImageUrl = result.remoteImageUrl;
      existing.rawPayload = result.rawPayload;
      existing.copiedAt = Date.now();
      existing.copyCount += 1;
      this.sortItems();
      return existing.id;
    }

    this.sequence += 1;
    const item = ClipboardItem.create(result, this.sequence);
    this.items.push(item);
    this.sortItems();
    this.trimToCapacity();
    return item.id;
  }

  private findDuplicateIndex(result: ClipboardCaptureResult): number {
    return this.items.findIndex((item: ClipboardItem) => item.signature === result.signature);
  }

  private promoteItem(id: string): void {
    const index = this.items.findIndex((item: ClipboardItem) => item.id === id);
    if (index < 0) {
      return;
    }
    this.items[index].copiedAt = Date.now();
    this.items[index].copyCount += 1;
    this.sortItems();
  }

  private sortItems(): void {
    this.items.sort((left: ClipboardItem, right: ClipboardItem) => {
      if (left.isPinned !== right.isPinned) {
        return left.isPinned ? -1 : 1;
      }
      return right.copiedAt - left.copiedAt;
    });
  }

  private trimToCapacity(): void {
    if (this.items.length <= this.maxHistoryItems) {
      return;
    }

    const pinned = this.items.filter((item: ClipboardItem) => item.isPinned);
    let nextItems: ClipboardItem[] = [];
    if (pinned.length >= this.maxHistoryItems) {
      nextItems = pinned.slice(0, this.maxHistoryItems);
    } else {
      const recent = this.items.filter((item: ClipboardItem) => !item.isPinned).slice(0,
        this.maxHistoryItems - pinned.length);
      nextItems = pinned.concat(recent);
    }
    const keepIds = nextItems.map((item: ClipboardItem) => item.id);
    for (let index = 0; index < this.items.length; index++) {
      const item = this.items[index];
      if (keepIds.indexOf(item.id) < 0) {
        this.deleteImageAsset(item);
      }
    }
    this.items = nextItems;
    this.trimMemoryCache();
  }

  private trimMemoryCache(): void {
    const keepIds: Array<string> = [];
    for (let index = 0; index < this.items.length; index++) {
      keepIds.push(this.items[index].id);
    }
    this.memoryPasteData.forEach((data: pasteboard.PasteData, id: string) => {
      if (keepIds.indexOf(id) < 0) {
        this.memoryPasteData.delete(id);
      }
    });
    this.memoryUnifiedData.forEach((data: unifiedDataChannel.UnifiedData, id: string) => {
      if (keepIds.indexOf(id) < 0) {
        this.memoryUnifiedData.delete(id);
      }
    });
  }

  private extractClipboard(data: pasteboard.PasteData): ClipboardCaptureResult {
    const result = new ClipboardCaptureResult();
    result.mimeTypes = this.safeGetMimeTypes(data);
    result.recordCount = this.safeGetRecordCount(data);
    result.pixelMap = this.findFirstPixelMap(data, result.recordCount);
    result.hasImage = result.pixelMap !== undefined || this.safeHasType(data, pasteboard.MIMETYPE_PIXELMAP);

    if (this.isMixedContent(data, result)) {
      this.assignMixedResult(result, data);
      this.assignFileUris(result, data);
      this.assignRawPayload(result, data);
      return result;
    }
    if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_HTML)) {
      this.assignHtmlResult(result, this.safeGetPrimaryHtml(data));
      if (this.finishExtractedResult(result, data)) {
        return result;
      }
    }
    if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_PLAIN)) {
      this.assignTextResult(result, this.safeGetPrimaryText(data), data);
      if (this.finishExtractedResult(result, data)) {
        return result;
      }
    }
    if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_URI)) {
      this.assignUriResult(result, this.safeGetPrimaryUri(data));
      if (this.finishExtractedResult(result, data)) {
        return result;
      }
    }
    if (this.safeHasType(data, pasteboard.MIMETYPE_PIXELMAP)) {
      this.assignImageResult(result, data);
      this.assignRawPayload(result, data);
      return result;
    }
    this.assignFallbackTextResult(result, data);
    if (this.finishExtractedResult(result, data)) {
      return result;
    }
    if (result.mimeTypes.length > 0 || result.recordCount > 0) {
      this.assignCustomResult(result);
      this.assignFileUris(result, data);
      this.assignRawPayload(result, data);
    }
    return result;
  }

  private finishExtractedResult(result: ClipboardCaptureResult, data: pasteboard.PasteData): boolean {
    if (!result.isRecordable()) {
      return false;
    }
    this.assignFileUris(result, data);
    this.assignRawPayload(result, data);
    return true;
  }

  private assignTextResult(result: ClipboardCaptureResult, rawText: string, data: pasteboard.PasteData): void {
    const text = this.clampText(rawText);
    if (text.trim().length === 0) {
      return;
    }
    result.text = text;
    result.preview = ClipboardItem.buildPreview(text);
    result.kind = this.detectTextKind(data, text);
    result.signature = `text:${text}`;
  }

  private assignUnifiedTextResult(result: ClipboardCaptureResult, rawText: string): void {
    const text = this.clampText(rawText);
    if (text.trim().length === 0) {
      return;
    }
    result.text = text;
    result.preview = ClipboardItem.buildPreview(text);
    if (this.isLikelyLink(text)) {
      result.kind = ClipboardItemKind.LINK;
    } else if (this.isLikelyCode(text)) {
      result.kind = ClipboardItemKind.CODE;
    } else {
      result.kind = ClipboardItemKind.TEXT;
    }
    result.signature = `text:${text}`;
  }

  private assignUriResult(result: ClipboardCaptureResult, uri: string): void {
    const text = this.clampText(uri);
    if (text.trim().length === 0) {
      return;
    }
    result.text = text;
    result.uri = text;
    result.preview = ClipboardItem.buildPreview(text);
    result.kind = this.isFileUri(text) ? ClipboardItemKind.FILE : ClipboardItemKind.URI;
    result.signature = `uri:${text}`;
  }

  private assignFallbackTextResult(result: ClipboardCaptureResult, data: pasteboard.PasteData): void {
    const html = this.safeGetPrimaryHtml(data);
    if (html.trim().length > 0) {
      this.assignHtmlResult(result, html);
      return;
    }

    const uri = this.safeGetPrimaryUri(data);
    if (uri.trim().length > 0) {
      this.assignUriResult(result, uri);
      return;
    }

    this.assignTextResult(result, this.safeGetPrimaryText(data), data);
  }

  private assignFileUris(result: ClipboardCaptureResult, data: pasteboard.PasteData): void {
    const uris: Array<string> = [];
    this.addFileUriCandidate(uris, result.uri);
    this.addFileUriCandidate(uris, this.safeGetPrimaryUri(data));

    for (let index = 0; index < result.recordCount; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      this.addFileUriCandidate(uris, record.uri);
      this.addFileUriCandidate(uris, this.safeRecordPlainText(record));
    }

    if (result.kind === ClipboardItemKind.URI || result.kind === ClipboardItemKind.TEXT) {
      const textUris = this.extractUriLines(result.text);
      for (let index = 0; index < textUris.length; index++) {
        this.addFileUriCandidate(uris, textUris[index]);
      }
    }

    if (uris.length === 0) {
      return;
    }

    result.fileUris = uris;
    result.kind = ClipboardItemKind.FILE;
    result.uri = uris[0];
    result.text = uris.join('\n');
    result.preview = this.buildFilePreview(uris);
    result.signature = `files:${uris.join('|')}`;
  }

  private assignHtmlResult(result: ClipboardCaptureResult, html: string): void {
    if (html.trim().length === 0) {
      return;
    }
    const text = this.clampText(this.stripHtmlForPreview(html));
    result.text = text;
    result.html = this.clampText(html);
    result.remoteImageUrl = this.extractFirstRemoteImageUrl(result.html);
    if (result.remoteImageUrl.length > 0) {
      result.hasImage = true;
    }
    result.preview = text.length > 0 ? ClipboardItem.buildPreview(text) : 'HTML 内容';
    result.kind = ClipboardItemKind.HTML;
    result.signature = this.buildHtmlSignature(html, result);
  }

  private assignMixedResult(result: ClipboardCaptureResult, data: pasteboard.PasteData): void {
    if (result.pixelMap === undefined) {
      result.pixelMap = this.findFirstPixelMap(data, result.recordCount);
    }
    if (result.pixelMap !== undefined) {
      this.assignImageSize(result, result.pixelMap);
    }

    if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_HTML)) {
      const rawHtml = this.safeGetPrimaryHtml(data);
      result.html = this.clampText(rawHtml);
      result.text = this.clampText(this.stripHtmlForPreview(rawHtml));
      result.remoteImageUrl = this.extractFirstRemoteImageUrl(rawHtml);
      result.kind = ClipboardItemKind.HTML;
      result.preview = this.buildMixedPreview(data, result);
      result.signature = this.buildMixedSignature(result, rawHtml);
      return;
    } else if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_URI)) {
      result.uri = this.clampText(this.safeGetPrimaryUri(data));
      result.text = result.uri;
      result.kind = this.isFileUri(result.uri) ? ClipboardItemKind.FILE : ClipboardItemKind.URI;
    } else {
      result.text = this.clampText(this.safeGetPrimaryText(data));
      result.kind = this.detectTextKind(data, result.text);
    }

    result.preview = this.buildMixedPreview(data, result);
    result.signature = this.buildMixedSignature(result, '');
  }

  private assignImageResult(result: ClipboardCaptureResult, data: pasteboard.PasteData): void {
    if (result.pixelMap === undefined) {
      result.pixelMap = this.findFirstPixelMap(data, result.recordCount);
    }
    if (result.pixelMap !== undefined) {
      this.assignImageSize(result, result.pixelMap);
    }
    result.text = '';
    result.preview = this.buildImagePreview(result);
    result.kind = ClipboardItemKind.IMAGE;
    result.signature = this.buildImageSignature(result);
  }

  private assignCustomResult(result: ClipboardCaptureResult): void {
    const summary = this.mimeSummary(result.mimeTypes);
    result.text = '';
    result.preview = summary.length > 0 ? `自定义内容: ${summary}` : '自定义剪贴板内容';
    result.kind = ClipboardItemKind.CUSTOM;
    result.signature = `custom:${summary}:${result.recordCount}:${Date.now()}`;
  }

  private async safeGetUnifiedData(): Promise<unifiedDataChannel.UnifiedData | undefined> {
    try {
      return await this.board.getUnifiedData();
    } catch (err) {
      return undefined;
    }
  }

  private enrichWithUnifiedData(result: ClipboardCaptureResult, data: unifiedDataChannel.UnifiedData): void {
    const uris = result.fileUris.slice();
    const types = this.safeGetUnifiedDataTypes(data);
    if (result.mimeTypes.length === 0 && types.length > 0) {
      result.mimeTypes = types;
    }
    let records: Array<unifiedDataChannel.UnifiedRecord> = [];
    try {
      records = data.getRecords();
    } catch (err) {
      records = [];
    }
    if (result.recordCount === 0 && records.length > 0) {
      result.recordCount = records.length;
    }

    for (let index = 0; index < records.length; index++) {
      if (!result.isRecordable()) {
        this.assignUnifiedRecordContent(result, records[index]);
      }
      this.addUnifiedRecordFileUri(uris, records[index]);
    }

    if (uris.length === 0) {
      return;
    }

    result.fileUris = uris;
    result.kind = ClipboardItemKind.FILE;
    result.uri = uris[0];
    result.text = uris.join('\n');
    result.preview = this.buildFilePreview(uris);
    result.signature = `files:${uris.join('|')}`;
  }

  private safeGetUnifiedDataTypes(data: unifiedDataChannel.UnifiedData): Array<string> {
    try {
      return data.getTypes();
    } catch (err) {
      return [];
    }
  }

  private assignUnifiedRecordContent(result: ClipboardCaptureResult, record: unifiedDataChannel.UnifiedRecord): void {
    if (record instanceof unifiedDataChannel.HTML) {
      this.assignHtmlResult(result, record.htmlContent);
      return;
    }
    if (record instanceof unifiedDataChannel.Hyperlink) {
      this.assignUriResult(result, record.url);
      return;
    }
    if (record instanceof unifiedDataChannel.PlainText) {
      this.assignUnifiedTextResult(result, record.textContent);
      return;
    }

    try {
      const value = record.getValue();
      if (typeof value === 'string') {
        this.assignUnifiedTextResult(result, value);
      }
    } catch (err) {
    }
  }

  private addUnifiedRecordFileUri(uris: Array<string>, record: unifiedDataChannel.UnifiedRecord): void {
    let recordType = '';
    try {
      recordType = record.getType().toLowerCase();
    } catch (err) {
      recordType = '';
    }
    if (this.isUnifiedFileType(recordType)) {
      try {
        const value = record.getValue();
        if (typeof value === 'string') {
          this.addFileUriCandidate(uris, value);
        }
      } catch (err) {
      }
    }
    if (record instanceof unifiedDataChannel.Image) {
      this.addFileUriCandidate(uris, record.imageUri);
    }
    if (record instanceof unifiedDataChannel.Video) {
      this.addFileUriCandidate(uris, record.videoUri);
    }
    if (record instanceof unifiedDataChannel.Audio) {
      this.addFileUriCandidate(uris, record.audioUri);
    }
    if (record instanceof unifiedDataChannel.Folder) {
      this.addFileUriCandidate(uris, record.folderUri);
    }
    if (record instanceof unifiedDataChannel.File) {
      this.addFileUriCandidate(uris, record.uri);
    }
  }

  private isUnifiedFileType(recordType: string): boolean {
    return recordType.indexOf('file') >= 0 || recordType.indexOf('folder') >= 0 || recordType.indexOf('image') >= 0 ||
      recordType.indexOf('video') >= 0 || recordType.indexOf('audio') >= 0;
  }

  private isMixedContent(data: pasteboard.PasteData, result: ClipboardCaptureResult): boolean {
    if (!result.hasImage) {
      return false;
    }
    return this.safeHasType(data, pasteboard.MIMETYPE_TEXT_PLAIN) ||
      this.safeHasType(data, pasteboard.MIMETYPE_TEXT_HTML) ||
      this.safeHasType(data, pasteboard.MIMETYPE_TEXT_URI);
  }

  private buildMixedPreview(data: pasteboard.PasteData, result: ClipboardCaptureResult): string {
    let preview = '';
    const count = result.recordCount;
    for (let index = 0; index < count; index++) {
      preview = `${preview}${this.recordPreviewText(data, index)}`;
    }
    if (preview.trim().length === 0) {
      if (result.text.length > 0) {
        preview = `${result.text} ${IMAGE_PLACEHOLDER}`;
      } else {
        preview = IMAGE_PLACEHOLDER;
      }
    }
    return ClipboardItem.buildPreview(preview);
  }

  private recordPreviewText(data: pasteboard.PasteData, index: number): string {
    try {
      const record = data.getRecord(index);
      if (this.safeGetRecordPixelMap(record) !== undefined) {
        return ` ${IMAGE_PLACEHOLDER} `;
      }
      if (record.plainText.length > 0) {
        return record.plainText;
      }
      if (record.htmlText.length > 0) {
        return this.stripHtmlForPreview(record.htmlText);
      }
      if (record.uri.length > 0) {
        return record.uri;
      }
      const plainText = this.safeRecordPlainText(record);
      if (plainText.length > 0) {
        return plainText;
      }
      return '';
    } catch (err) {
      return '';
    }
  }

  private buildMixedSignature(result: ClipboardCaptureResult, rawHtml: string): string {
    const summary = this.mimeSummary(result.mimeTypes);
    const imageSignature = this.buildImageSignature(result);
    const remoteSignature = result.remoteImageUrl.length > 0 ? result.remoteImageUrl : 'no-remote-image';
    if (result.html.length > 0) {
      const htmlHash = rawHtml.length > 0 ? this.buildStringHash(rawHtml) : this.buildStringHash(result.html);
      return `mixed-html:${htmlHash}:${result.text}:${summary}:${imageSignature}:${remoteSignature}`;
    }
    if (result.uri.length > 0) {
      return `mixed-uri:${result.uri}:${summary}:${imageSignature}:${remoteSignature}`;
    }
    return `mixed-text:${result.text}:${summary}:${imageSignature}:${remoteSignature}`;
  }

  private buildHtmlSignature(rawHtml: string, result: ClipboardCaptureResult): string {
    const htmlHash = this.buildStringHash(rawHtml);
    return `html:${htmlHash}:${result.text}:${result.remoteImageUrl}`;
  }

  private buildStringHash(text: string): string {
    let hash = 5381;
    let step = 1;
    if (text.length > 65536) {
      step = Math.floor(text.length / 65536);
    }
    for (let index = 0; index < text.length; index += step) {
      hash = (hash * 33 + text.charCodeAt(index)) % 2147483647;
    }
    if (text.length > 0) {
      hash = (hash * 33 + text.charCodeAt(text.length - 1)) % 2147483647;
    }
    return `${text.length}:${hash}`;
  }

  private assignRawPayload(result: ClipboardCaptureResult, data: pasteboard.PasteData): void {
    const payload = new ClipboardRawPayload();
    payload.kind = result.kind;
    payload.signature = result.signature;
    payload.recordCount = result.recordCount;
    payload.mimeTypes = result.mimeTypes.slice();
    payload.mimeSummary = this.mimeSummary(result.mimeTypes);
    payload.primaryMimeType = this.safeGetPrimaryMimeType(data);
    payload.text = this.clampRawField(result.text);
    payload.uri = this.clampRawField(result.uri);
    payload.fileUris = result.fileUris.slice();
    payload.html = this.clampRawField(result.html);
    payload.image.hasImage = result.hasImage;
    payload.image.width = result.imageWidth;
    payload.image.height = result.imageHeight;
    payload.image.remoteUrl = result.remoteImageUrl;
    for (let index = 0; index < result.recordCount; index++) {
      payload.records.push(this.buildRecordPayload(data, index));
    }
    result.rawPayload = JSON.stringify(payload, null, 2);
  }

  private buildRecordPayload(data: pasteboard.PasteData, index: number): ClipboardRecordRawPayload {
    const payload = new ClipboardRecordRawPayload();
    payload.index = index;
    try {
      const record = data.getRecord(index);
      payload.mimeType = record.mimeType;
      const plainText = this.safeRecordPlainText(record);
      if (plainText.length > 0) {
        payload.plainText = this.clampRawField(plainText);
      }
      if (record.uri.length > 0) {
        payload.uri = this.clampRawField(record.uri);
      }
      if (record.htmlText.length > 0) {
        payload.htmlText = this.clampRawField(record.htmlText);
      }
      if (this.safeGetRecordPixelMap(record) !== undefined) {
        payload.pixelMap = this.recordPixelMapText(record);
      }
    } catch (err) {
      payload.isAvailable = false;
    }
    return payload;
  }

  private safeRecordPlainText(record: pasteboard.PasteDataRecord): string {
    try {
      return this.clampRawPayload(record.toPlainText());
    } catch (err) {
      return '';
    }
  }

  private recordPixelMapText(record: pasteboard.PasteDataRecord): string {
    try {
      const pixelMap = record.pixelMap;
      const info = pixelMap.getImageInfoSync();
      return `${info.size.width} x ${info.size.height}`;
    } catch (err) {
      return '<unavailable>';
    }
  }

  private detectTextKind(data: pasteboard.PasteData, text: string): ClipboardItemKind {
    if (this.safeHasType(data, pasteboard.MIMETYPE_TEXT_HTML)) {
      return ClipboardItemKind.HTML;
    }
    if (this.isLikelyLink(text)) {
      return ClipboardItemKind.LINK;
    }
    if (this.isLikelyCode(text)) {
      return ClipboardItemKind.CODE;
    }
    return ClipboardItemKind.TEXT;
  }

  private createPasteDataForItem(item: ClipboardItem): pasteboard.PasteData | undefined {
    if (item.hasImage && item.pixelMap !== undefined && (item.text.length > 0 || item.html.length > 0 ||
      item.uri.length > 0)) {
      return this.createMixedPasteDataForItem(item);
    }
    if (item.kind === ClipboardItemKind.HTML && item.html.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_HTML, item.html);
    }
    if ((item.kind === ClipboardItemKind.URI || item.kind === ClipboardItemKind.FILE) && item.uri.length > 0) {
      if (item.fileUris.length > 1) {
        return this.createFilePasteDataForItem(item);
      }
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_URI, item.uri);
    }
    if (item.kind === ClipboardItemKind.IMAGE && item.pixelMap !== undefined) {
      return pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, item.pixelMap);
    }
    if (item.text.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.text);
    }
    return undefined;
  }

  private createFilePasteDataForItem(item: ClipboardItem): pasteboard.PasteData | undefined {
    if (item.fileUris.length === 0) {
      return undefined;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_URI, item.fileUris[0]);
    for (let index = 1; index < item.fileUris.length; index++) {
      data.addRecord(pasteboard.MIMETYPE_TEXT_URI, item.fileUris[index]);
    }
    return data;
  }

  private createMixedPasteDataForItem(item: ClipboardItem): pasteboard.PasteData | undefined {
    if (item.pixelMap === undefined) {
      return undefined;
    }

    let data: pasteboard.PasteData | undefined = undefined;
    if (item.html.length > 0) {
      data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_HTML, item.html);
      if (item.text.length > 0) {
        data.addRecord(pasteboard.MIMETYPE_TEXT_PLAIN, item.text);
      }
    } else if (item.uri.length > 0) {
      data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_URI, item.uri);
    } else if (item.text.length > 0) {
      data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.text);
    }

    if (data === undefined) {
      return pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, item.pixelMap);
    }
    data.addRecord(pasteboard.MIMETYPE_PIXELMAP, item.pixelMap);
    return data;
  }

  private clonePasteData(data: pasteboard.PasteData): pasteboard.PasteData | undefined {
    const count = this.safeGetRecordCount(data);
    let clonedData: pasteboard.PasteData | undefined = undefined;
    for (let index = 0; index < count; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      if (clonedData === undefined) {
        clonedData = this.createPasteDataFromRecord(record);
      } else {
        this.addRecordToPasteData(clonedData, record);
      }
    }
    return clonedData;
  }

  private createPasteDataFromRecord(record: pasteboard.PasteDataRecord): pasteboard.PasteData | undefined {
    const pixelMap = this.safeGetRecordPixelMap(record);
    if (pixelMap !== undefined) {
      return pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, pixelMap);
    }
    if (record.htmlText.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_HTML, record.htmlText);
    }
    if (record.plainText.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, record.plainText);
    }
    if (record.uri.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_URI, record.uri);
    }
    return undefined;
  }

  private addRecordToPasteData(data: pasteboard.PasteData, record: pasteboard.PasteDataRecord): void {
    const pixelMap = this.safeGetRecordPixelMap(record);
    if (pixelMap !== undefined) {
      data.addRecord(pasteboard.MIMETYPE_PIXELMAP, pixelMap);
      return;
    }
    if (record.htmlText.length > 0) {
      data.addRecord(pasteboard.MIMETYPE_TEXT_HTML, record.htmlText);
      return;
    }
    if (record.plainText.length > 0) {
      data.addRecord(pasteboard.MIMETYPE_TEXT_PLAIN, record.plainText);
      return;
    }
    if (record.uri.length > 0) {
      data.addRecord(pasteboard.MIMETYPE_TEXT_URI, record.uri);
    }
  }

  private createPlainTextPasteDataForItem(item: ClipboardItem): pasteboard.PasteData | undefined {
    if (item.text.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.text);
    }
    if (item.uri.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.uri);
    }
    if (item.preview.length > 0) {
      return pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.preview);
    }
    return undefined;
  }

  private safeGetPrimaryPixelMap(data: pasteboard.PasteData): image.PixelMap | undefined {
    try {
      return data.getPrimaryPixelMap();
    } catch (err) {
      return undefined;
    }
  }

  private findFirstPixelMap(data: pasteboard.PasteData, recordCount: number): image.PixelMap | undefined {
    for (let index = 0; index < recordCount; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      const pixelMap = this.safeGetRecordPixelMap(record);
      if (pixelMap !== undefined) {
        return pixelMap;
      }
    }
    return this.safeGetPrimaryPixelMap(data);
  }

  private safeGetRecord(data: pasteboard.PasteData, index: number): pasteboard.PasteDataRecord | undefined {
    try {
      return data.getRecord(index);
    } catch (err) {
      return undefined;
    }
  }

  private safeGetRecordPixelMap(record: pasteboard.PasteDataRecord): image.PixelMap | undefined {
    try {
      return record.pixelMap;
    } catch (err) {
      return undefined;
    }
  }

  private safeHasType(data: pasteboard.PasteData, mimeType: string): boolean {
    try {
      return data.hasType(mimeType);
    } catch (err) {
      return false;
    }
  }

  private safeGetPrimaryText(data: pasteboard.PasteData): string {
    try {
      const text = data.getPrimaryText();
      if (text.length > 0) {
        return text;
      }
    } catch (err) {
    }
    return this.findFirstRecordText(data);
  }

  private safeGetPrimaryHtml(data: pasteboard.PasteData): string {
    try {
      const html = data.getPrimaryHtml();
      if (html.length > 0) {
        return html;
      }
    } catch (err) {
    }
    return this.findFirstRecordHtml(data);
  }

  private safeGetPrimaryUri(data: pasteboard.PasteData): string {
    try {
      const uri = data.getPrimaryUri();
      if (uri.length > 0) {
        return uri;
      }
    } catch (err) {
    }
    return this.findFirstRecordUri(data);
  }

  private findFirstRecordText(data: pasteboard.PasteData): string {
    const count = this.safeGetRecordCount(data);
    for (let index = 0; index < count; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      try {
        if (record.plainText.length > 0) {
          return record.plainText;
        }
      } catch (err) {
      }
      const plainText = this.safeRecordPlainText(record);
      if (plainText.length > 0) {
        return plainText;
      }
    }
    return '';
  }

  private findFirstRecordHtml(data: pasteboard.PasteData): string {
    const count = this.safeGetRecordCount(data);
    for (let index = 0; index < count; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      try {
        if (record.htmlText.length > 0) {
          return record.htmlText;
        }
      } catch (err) {
      }
    }
    return '';
  }

  private findFirstRecordUri(data: pasteboard.PasteData): string {
    const count = this.safeGetRecordCount(data);
    for (let index = 0; index < count; index++) {
      const record = this.safeGetRecord(data, index);
      if (record === undefined) {
        continue;
      }
      try {
        if (record.uri.length > 0) {
          return record.uri;
        }
      } catch (err) {
      }
    }
    return '';
  }

  private assignImageSize(result: ClipboardCaptureResult, pixelMap: image.PixelMap): void {
    try {
      const info = pixelMap.getImageInfoSync();
      result.imageWidth = info.size.width;
      result.imageHeight = info.size.height;
    } catch (err) {
      result.imageWidth = 0;
      result.imageHeight = 0;
    }
  }

  private buildImagePreview(result: ClipboardCaptureResult): string {
    if (result.imageWidth > 0 && result.imageHeight > 0) {
      return `图片内容 · ${result.imageWidth} x ${result.imageHeight}`;
    }
    return '图片内容';
  }

  private buildImageSignature(result: ClipboardCaptureResult): string {
    const summary = this.mimeSummary(result.mimeTypes);
    if (result.pixelMap === undefined) {
      return `image:${summary}:${result.recordCount}:${result.imageWidth}x${result.imageHeight}:no-pixelmap:${Date.now()}`;
    }
    const pixelMap = result.pixelMap;
    const byteCount = this.safeGetPixelBytesNumber(pixelMap);
    const rowBytes = this.safeGetBytesNumberPerRow(pixelMap);
    const density = this.safeGetDensity(pixelMap);
    const pixelFormat = this.safeGetPixelFormat(pixelMap);
    const hash = this.safeBuildPixelHash(pixelMap, byteCount);
    if (!this.isReliableImageHash(hash)) {
      return `image:${summary}:${result.recordCount}:${result.imageWidth}x${result.imageHeight}:${byteCount}:${rowBytes}:${density}:${pixelFormat}:${hash}:${Date.now()}`;
    }
    return `image:${summary}:${result.recordCount}:${result.imageWidth}x${result.imageHeight}:${byteCount}:${rowBytes}:${density}:${pixelFormat}:${hash}`;
  }

  private isReliableImageHash(hash: string): boolean {
    return hash !== 'no-bytes' && hash !== 'hash-failed';
  }

  private async ensureImageAsset(item: ClipboardItem): Promise<void> {
    if (item.pixelMap === undefined || this.imageAssetDir.length === 0) {
      return;
    }
    if (item.imageFilePath.length > 0 && this.safeFileExists(item.imageFilePath)) {
      item.imageFileUri = this.imageUriFromPath(item.imageFilePath);
      return;
    }

    this.ensureImageAssetDir();
    const path = this.imageAssetPathForItem(item);
    const packer = image.createImagePacker();
    let fd = -1;
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE);
      fd = file.fd;
      await packer.packToFile(item.pixelMap, fd, {
        format: IMAGE_ASSET_FORMAT,
        quality: 100
      });
      item.imageFilePath = path;
      item.imageFileUri = this.imageUriFromPath(path);
    } catch (err) {
      this.deleteImageAssetPath(path);
    } finally {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd);
        } catch (err) {
        }
      }
      try {
        await packer.release();
      } catch (err) {
      }
    }
  }

  private async restoreImagePixelMap(item: ClipboardItem): Promise<void> {
    if (item.pixelMap !== undefined || item.kind !== ClipboardItemKind.IMAGE) {
      return;
    }
    const sourcePath = item.imageFilePath.length > 0 ? item.imageFilePath : item.imageFileUri;
    if (sourcePath.length === 0) {
      return;
    }

    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(sourcePath);
      item.pixelMap = await source.createPixelMap();
      item.hasImage = true;
      this.assignImageSizeFromPixelMap(item);
    } catch (err) {
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (err) {
        }
      }
    }
  }

  private assignImageSizeFromPixelMap(item: ClipboardItem): void {
    if (item.pixelMap === undefined || (item.imageWidth > 0 && item.imageHeight > 0)) {
      return;
    }
    try {
      const info = item.pixelMap.getImageInfoSync();
      item.imageWidth = info.size.width;
      item.imageHeight = info.size.height;
    } catch (err) {
    }
  }

  private normalizeLoadedImageAsset(item: ClipboardItem): void {
    if (item.imageFilePath.length > 0 && this.safeFileExists(item.imageFilePath)) {
      item.imageFileUri = this.imageUriFromPath(item.imageFilePath);
      return;
    }
    if (item.imageFilePath.length > 0) {
      item.imageFilePath = '';
    }
  }

  private ensureImageAssetDir(): void {
    if (this.imageAssetDir.length === 0 || this.safeFileExists(this.imageAssetDir)) {
      return;
    }
    try {
      fileIo.mkdirSync(this.imageAssetDir, true);
    } catch (err) {
    }
  }

  private imageAssetPathForItem(item: ClipboardItem): string {
    return `${this.imageAssetDir}/${item.id}.${IMAGE_ASSET_EXTENSION}`;
  }

  private imageUriFromPath(path: string): string {
    try {
      return fileUri.getUriFromPath(path);
    } catch (err) {
      return path;
    }
  }

  private safeFileExists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fileIo.accessSync(path);
    } catch (err) {
      return false;
    }
  }

  private deleteImageAsset(item: ClipboardItem): void {
    this.deleteImageAssetPath(item.imageFilePath);
    item.imageFilePath = '';
    item.imageFileUri = '';
  }

  private deleteImageAssetPath(path: string): void {
    if (!this.safeFileExists(path)) {
      return;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (err) {
    }
  }

  private safeGetPixelBytesNumber(pixelMap: image.PixelMap): number {
    try {
      return pixelMap.getPixelBytesNumber();
    } catch (err) {
      return 0;
    }
  }

  private safeGetBytesNumberPerRow(pixelMap: image.PixelMap): number {
    try {
      return pixelMap.getBytesNumberPerRow();
    } catch (err) {
      return 0;
    }
  }

  private safeGetDensity(pixelMap: image.PixelMap): number {
    try {
      return pixelMap.getDensity();
    } catch (err) {
      return 0;
    }
  }

  private safeGetPixelFormat(pixelMap: image.PixelMap): number {
    try {
      const info = pixelMap.getImageInfoSync();
      return info.pixelFormat;
    } catch (err) {
      return 0;
    }
  }

  private safeBuildPixelHash(pixelMap: image.PixelMap, byteCount: number): string {
    if (byteCount <= 0) {
      return 'no-bytes';
    }
    try {
      const buffer = new ArrayBuffer(byteCount);
      pixelMap.readPixelsToBufferSync(buffer);
      const bytes = new Uint8Array(buffer);
      let hash = 5381;
      let step = 1;
      if (bytes.length > 32768) {
        step = Math.floor(bytes.length / 32768);
      }
      for (let index = 0; index < bytes.length; index += step) {
        hash = (hash * 33 + bytes[index]) % 2147483647;
      }
      if (bytes.length > 0) {
        hash = (hash * 33 + bytes[bytes.length - 1]) % 2147483647;
      }
      return `${hash}`;
    } catch (err) {
      return 'hash-failed';
    }
  }

  private safeGetMimeTypes(data: pasteboard.PasteData): Array<string> {
    try {
      return data.getMimeTypes();
    } catch (err) {
      return [];
    }
  }

  private safeGetRecordCount(data: pasteboard.PasteData): number {
    try {
      return data.getRecordCount();
    } catch (err) {
      return 0;
    }
  }

  private safeGetPrimaryMimeType(data: pasteboard.PasteData): string {
    try {
      return data.getPrimaryMimeType();
    } catch (err) {
      return '';
    }
  }

  private mimeSummary(types: Array<string>): string {
    if (types.length === 0) {
      return '';
    }

    let summary = types[0];
    const limit = types.length > 3 ? 3 : types.length;
    for (let index = 1; index < limit; index++) {
      summary = `${summary}, ${types[index]}`;
    }
    if (types.length > limit) {
      summary = `${summary} +${types.length - limit}`;
    }
    return summary;
  }

  private isLikelyLink(text: string): boolean {
    const value = text.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://') || value.startsWith('file://');
  }

  private isFileUri(text: string): boolean {
    const value = text.trim().toLowerCase();
    if (value.startsWith('file://') || value.startsWith('content://') || value.startsWith('datashare://') ||
      value.startsWith('docs://')) {
      return true;
    }
    if (this.isWebUri(value)) {
      return false;
    }
    return value.indexOf('://') > 0 && value.indexOf('mailto:') !== 0 && value.indexOf('tel:') !== 0;
  }

  private isWebUri(text: string): boolean {
    return text.startsWith('http://') || text.startsWith('https://');
  }

  private addFileUriCandidate(uris: Array<string>, value: string): void {
    const trimmed = value.trim();
    if (trimmed.length === 0 || !this.isFileUri(trimmed)) {
      return;
    }
    if (uris.indexOf(trimmed) < 0) {
      uris.push(trimmed);
    }
  }

  private extractUriLines(text: string): Array<string> {
    const lines = text.split('\n');
    const uris: Array<string> = [];
    for (let index = 0; index < lines.length; index++) {
      const value = lines[index].trim();
      if (value.length > 0 && value.indexOf('://') > 0) {
        uris.push(value);
      }
    }
    return uris;
  }

  private buildFilePreview(uris: Array<string>): string {
    if (uris.length === 1) {
      return this.fileNameFromUri(uris[0]);
    }
    return `${uris.length} 个文件 · ${this.fileNameFromUri(uris[0])}`;
  }

  private fileNameFromUri(value: string): string {
    const withoutQuery = value.split('?')[0].split('#')[0];
    const parts = withoutQuery.split('/');
    const name = parts.length > 0 ? parts[parts.length - 1] : value;
    try {
      return decodeURIComponent(name.length > 0 ? name : value);
    } catch (err) {
      return name.length > 0 ? name : value;
    }
  }

  private isLikelyCode(text: string): boolean {
    const value = text.trim();
    return value.indexOf('\n') >= 0 &&
      (value.indexOf('{') >= 0 || value.indexOf('=>') >= 0 || value.indexOf('function ') >= 0 ||
        value.indexOf('class ') >= 0 || value.indexOf('import ') >= 0);
  }

  private stripHtml(html: string): string {
    const previewHtml = this.stripOfficeXmlHtml(html);
    return previewHtml.replace(/<style[\s\S]*?<\/style>/gi, '')
      .replace(/<script[\s\S]*?<\/script>/g, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private stripHtmlForPreview(html: string): string {
    const previewHtml = this.stripOfficeXmlHtml(html);
    return previewHtml.replace(/<img[\s\S]*?>/gi, ` ${IMAGE_PLACEHOLDER} `)
      .replace(/<style[\s\S]*?<\/style>/gi, '')
      .replace(/<script[\s\S]*?<\/script>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private stripOfficeXmlHtml(html: string): string {
    return html.replace(/<\?xml[\s\S]*?\?>/gi, ' ')
      .replace(/<!--\[if[\s\S]*?<!\[endif\]-->/gi, ' ')
      .replace(/<xml[\s\S]*?<\/xml>/gi, ' ')
      .replace(/<(w|o|v|m):[A-Za-z0-9_:-]+[\s\S]*?<\/\1:[A-Za-z0-9_:-]+>/gi, ' ')
      .replace(/<\/?(w|o|v|m):[^>]*>/gi, ' ');
  }

  private extractFirstRemoteImageUrl(html: string): string {
    const quotedMatch = /<img[\s\S]*?\ssrc\s*=\s*["']([^"']+)["'][\s\S]*?>/i.exec(html);
    if (quotedMatch !== null && quotedMatch.length > 1) {
      const quotedUrl = this.normalizeRemoteImageUrl(quotedMatch[1]);
      if (quotedUrl.length > 0) {
        return quotedUrl;
      }
    }

    const unquotedMatch = /<img[\s\S]*?\ssrc\s*=\s*([^\s>]+)[\s\S]*?>/i.exec(html);
    if (unquotedMatch !== null && unquotedMatch.length > 1) {
      return this.normalizeRemoteImageUrl(unquotedMatch[1]);
    }
    return '';
  }

  private normalizeRemoteImageUrl(url: string): string {
    const value = url.trim().replace(/&amp;/g, '&');
    const lowerValue = value.toLowerCase();
    if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
      return value;
    }
    return '';
  }

  private clampText(text: string): string {
    if (text.length <= MAX_TEXT_LENGTH) {
      return text;
    }
    return text.substring(0, MAX_TEXT_LENGTH);
  }

  private clampRawPayload(text: string): string {
    if (text.length <= MAX_RAW_PAYLOAD_LENGTH) {
      return text;
    }
    return `${text.substring(0, MAX_RAW_PAYLOAD_LENGTH)}...`;
  }

  private clampRawField(text: string): string {
    return this.clampRawPayload(text);
  }

  private shouldIgnoreProgrammaticUpdate(): boolean {
    if (Date.now() <= this.ignoreUpdateUntil) {
      return true;
    }
    return false;
  }

  private isProgrammaticClipboardUpdate(signature: string): boolean {
    if (this.lastWrittenSignature.length === 0) {
      return false;
    }
    const elapsed = Date.now() - this.lastWrittenAt;
    if (elapsed <= PROGRAMMATIC_UPDATE_IGNORE_MS && signature === this.lastWrittenSignature) {
      this.lastWrittenSignature = '';
      this.lastWrittenAt = 0;
      return true;
    }
    return false;
  }

  private async ensureSchema(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    try {
      await this.rdbStore.execute(SQL_CREATE_HISTORY_TABLE);
      await this.rdbStore.execute(SQL_CREATE_HISTORY_SORT_INDEX);
      if (this.rdbStore.version < HISTORY_DB_VERSION) {
        this.rdbStore.version = HISTORY_DB_VERSION;
      }
    } catch (err) {
      throw new Error('Failed to prepare history database.');
    }
  }

  private async load(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    const loaded = await this.loadFromRdb();
    if (loaded.length > 0) {
      this.items = loaded;
      this.sortItems();
      this.status = ClipboardHistoryStatus.LOAD_DONE;
      return;
    }

    const legacyItems = await this.loadLegacyPreferences();
    if (legacyItems.length > 0) {
      this.items = legacyItems;
      this.sortItems();
      await this.save();
      await this.clearLegacyPreferences();
      this.status = ClipboardHistoryStatus.LOAD_DONE;
      return;
    }

    this.items = [];
    this.status = ClipboardHistoryStatus.LOAD_EMPTY;
  }

  private async loadFromRdb(): Promise<ClipboardItem[]> {
    const loaded: ClipboardItem[] = [];
    if (!this.rdbStore) {
      return loaded;
    }

    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await this.rdbStore.querySql(SQL_SELECT_HISTORY);
      while (resultSet.goToNextRow()) {
        const snapshotText = resultSet.getString(resultSet.getColumnIndex('snapshot'));
        const item = this.itemFromSnapshotText(snapshotText);
        if (item !== undefined) {
          loaded.push(item);
        }
      }
    } catch (err) {
      return [];
    } finally {
      if (resultSet !== undefined) {
        try {
          resultSet.close();
        } catch (err) {
        }
      }
    }
    return loaded;
  }

  private async loadLegacyPreferences(): Promise<ClipboardItem[]> {
    if (this.context === undefined) {
      return [];
    }

    if (!this.legacyPrefs) {
      try {
        this.legacyPrefs = await preferences.getPreferences(this.context, LEGACY_STORE_NAME);
      } catch (err) {
        return [];
      }
    }

    if (!this.legacyPrefs) {
      return [];
    }

    let orderValue: preferences.ValueType = [] as Array<string>;
    try {
      orderValue = await this.legacyPrefs.get(ORDER_KEY, [] as Array<string>);
    } catch (err) {
      return [];
    }
    const order = orderValue as Array<string>;
    const loaded: ClipboardItem[] = [];

    for (let index = 0; index < order.length; index++) {
      const id = order[index];
      let rawValue: preferences.ValueType = '';
      try {
        rawValue = await this.legacyPrefs.get(`${ITEM_KEY_PREFIX}${id}`, '');
      } catch (err) {
        continue;
      }
      if (typeof rawValue === 'string') {
        const item = this.itemFromSnapshotText(rawValue);
        if (item !== undefined) {
          loaded.push(item);
        }
      }
    }
    return loaded;
  }

  private async save(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    const buckets: Array<relationalStore.ValuesBucket> = [];

    for (let index = 0; index < this.items.length; index++) {
      const item = this.items[index];
      buckets.push({
        id: item.id,
        created_at: item.createdAt,
        copied_at: item.copiedAt,
        is_pinned: item.isPinned ? 1 : 0,
        snapshot: JSON.stringify(item.toSnapshot())
      });
    }

    try {
      await this.rdbStore.execute(SQL_DELETE_HISTORY);
      if (buckets.length > 0) {
        await this.rdbStore.batchInsert(HISTORY_TABLE_NAME, buckets);
      }
    } catch (err) {
      return;
    }
  }

  private itemFromSnapshotText(rawValue: string): ClipboardItem | undefined {
    if (rawValue.length === 0) {
      return undefined;
    }
    try {
      const snapshot = JSON.parse(rawValue) as ClipboardItemSnapshot;
      if (snapshot.preview.length === 0 && snapshot.text.length === 0) {
        return undefined;
      }
      const item = ClipboardItem.fromSnapshot(snapshot);
      this.normalizeLoadedImageAsset(item);
      return item;
    } catch (err) {
      return undefined;
    }
  }

  private async clearLegacyPreferences(): Promise<void> {
    if (!this.legacyPrefs) {
      return;
    }

    let orderValue: preferences.ValueType = [] as Array<string>;
    try {
      orderValue = await this.legacyPrefs.get(ORDER_KEY, [] as Array<string>);
    } catch (err) {
      orderValue = [] as Array<string>;
    }
    const order = orderValue as Array<string>;
    for (let index = 0; index < order.length; index++) {
      try {
        await this.legacyPrefs.delete(`${ITEM_KEY_PREFIX}${order[index]}`);
      } catch (err) {
      }
    }
    try {
      await this.legacyPrefs.delete(ORDER_KEY);
      await this.legacyPrefs.flush();
    } catch (err) {
    }
  }

  private notify(): void {
    const snapshot = this.items.slice();
    this.listeners.forEach((listener: HistoryChangeListener) => {
      listener(snapshot, this.status);
    });
  }
}
