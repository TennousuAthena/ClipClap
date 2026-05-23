import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';

const READ_PASTEBOARD_PERMISSION: Permissions = 'ohos.permission.READ_PASTEBOARD';
const GRANTED: number = 0;

export class PermissionService {
  async isReadPasteboardGranted(): Promise<boolean> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const manager = abilityAccessCtrl.createAtManager();
      return manager.checkAccessTokenSync(bundleInfo.appInfo.accessTokenId, READ_PASTEBOARD_PERMISSION) === GRANTED;
    } catch (err) {
      return false;
    }
  }

  async requestReadPasteboard(context: common.UIAbilityContext): Promise<boolean> {
    const manager = abilityAccessCtrl.createAtManager();
    try {
      const result = await manager.requestPermissionsFromUser(context, [READ_PASTEBOARD_PERMISSION]);
      if (result.authResults.length === 0) {
        return false;
      }
      return result.authResults[0] === GRANTED;
    } catch (err) {
      return false;
    }
  }
}
