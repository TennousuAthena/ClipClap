import appSettingsTest from './AppSettings.test';
import hotkeyConfigTest from './HotkeyConfig.test';
import previewTextFormatterTest from './PreviewTextFormatter.test';

export default function testsuite() {
  appSettingsTest();
  hotkeyConfigTest();
  previewTextFormatterTest();
}
