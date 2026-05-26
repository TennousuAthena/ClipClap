import { describe, expect, it } from '@ohos/hypium';
import { IMAGE_PLACEHOLDER_TOKEN, PreviewTextFormatter } from '../main/ets/model/PreviewTextSegment';

export default function previewTextFormatterTest() {
  describe('PreviewTextFormatter', () => {
    it('buildSegments_returnsEmptyTextSegmentForEmptyInput', 0, () => {
      const segments = PreviewTextFormatter.buildSegments('');

      expect(segments.length).assertEqual(1);
      expect(segments[0].id).assertEqual('text_0');
      expect(segments[0].text).assertEqual('');
      expect(segments[0].isMarker).assertFalse();
      expect(segments[0].isImagePlaceholder).assertFalse();
    });

    it('buildSegments_replacesNewlineAndTabWithMarkers', 0, () => {
      const segments = PreviewTextFormatter.buildSegments('a\nb\tc');

      expect(segments.length).assertEqual(5);
      expect(segments[0].text).assertEqual('a');
      expect(segments[1].text).assertEqual('↵');
      expect(segments[1].isMarker).assertTrue();
      expect(segments[2].text).assertEqual('b');
      expect(segments[3].text).assertEqual('⇥');
      expect(segments[3].isMarker).assertTrue();
      expect(segments[4].text).assertEqual('c');
    });

    it('buildSegments_detectsCurrentImagePlaceholderToken', 0, () => {
      const segments = PreviewTextFormatter.buildSegments(`before ${IMAGE_PLACEHOLDER_TOKEN} after`);

      expect(segments.length).assertEqual(3);
      expect(segments[0].text).assertEqual('before ');
      expect(segments[1].isImagePlaceholder).assertTrue();
      expect(segments[1].text).assertEqual('');
      expect(segments[2].text).assertEqual(' after');
    });

    it('buildSegments_detectsLegacyChineseImagePlaceholder', 0, () => {
      const segments = PreviewTextFormatter.buildSegments('prefix [图片] suffix');

      expect(segments.length).assertEqual(3);
      expect(segments[0].text).assertEqual('prefix ');
      expect(segments[1].isImagePlaceholder).assertTrue();
      expect(segments[2].text).assertEqual(' suffix');
    });
  });
}
