export const IMAGE_PLACEHOLDER_TOKEN = '[[CLIPCLAP_IMAGE]]';
const LEGACY_IMAGE_PLACEHOLDER_ZH = '[图片]';

export class PreviewTextSegment {
  id: string;
  text: string;
  isMarker: boolean;
  isImagePlaceholder: boolean;

  constructor(id: string, text: string, isMarker: boolean, isImagePlaceholder: boolean) {
    this.id = id;
    this.text = text;
    this.isMarker = isMarker;
    this.isImagePlaceholder = isImagePlaceholder;
  }
}

export class PreviewTextFormatter {
  static buildSegments(text: string): Array<PreviewTextSegment> {
    const segments: Array<PreviewTextSegment> = [];
    let buffer = '';
    let sequence = 0;
    for (let index = 0; index < text.length; index++) {
      if (PreviewTextFormatter.matchesImagePlaceholder(text, index)) {
        if (buffer.length > 0) {
          segments.push(new PreviewTextSegment(`text_${sequence}`, buffer, false, false));
          sequence += 1;
          buffer = '';
        }
        segments.push(new PreviewTextSegment(`image_${sequence}`, '', false, true));
        sequence += 1;
        index = PreviewTextFormatter.nextImagePlaceholderIndex(text, index);
        continue;
      }
      const char = text.charAt(index);
      if (char === '\t' || char === '\n') {
        if (buffer.length > 0) {
          segments.push(new PreviewTextSegment(`text_${sequence}`, buffer, false, false));
          sequence += 1;
          buffer = '';
        }
        const marker = char === '\t' ? '⇥' : '↵';
        segments.push(new PreviewTextSegment(`marker_${sequence}`, marker, true, false));
        sequence += 1;
      } else {
        buffer = `${buffer}${char}`;
      }
    }
    if (buffer.length > 0) {
      segments.push(new PreviewTextSegment(`text_${sequence}`, buffer, false, false));
    }
    if (segments.length === 0) {
      segments.push(new PreviewTextSegment('text_0', '', false, false));
    }
    return segments;
  }

  private static matchesImagePlaceholder(text: string, index: number): boolean {
    return text.substring(index, index + IMAGE_PLACEHOLDER_TOKEN.length) === IMAGE_PLACEHOLDER_TOKEN ||
      text.substring(index, index + LEGACY_IMAGE_PLACEHOLDER_ZH.length) === LEGACY_IMAGE_PLACEHOLDER_ZH;
  }

  private static nextImagePlaceholderIndex(text: string, index: number): number {
    if (text.substring(index, index + IMAGE_PLACEHOLDER_TOKEN.length) === IMAGE_PLACEHOLDER_TOKEN) {
      return index + IMAGE_PLACEHOLDER_TOKEN.length - 1;
    }
    return index + LEGACY_IMAGE_PLACEHOLDER_ZH.length - 1;
  }
}
