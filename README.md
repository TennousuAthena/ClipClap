# ClipClap - HarmonyOS PC 剪贴板管理工具

ClipClap 是一个面向 **HarmonyOS 6.0 PC / 2in1** 的剪贴板历史管理工具，使用 **ArkTS** 和 Stage 模型开发。项目目标是参考 macOS 端 Maccy 的核心体验，在鸿蒙 PC 场景下提供剪贴板监听、历史记录、快捷唤起、搜索选择和复制回剪贴板能力。

> 当前 README 按 2026-05-23 工作区源码更新。

For Coding Agents: 鸿蒙应用开发请遵守 [harmonyos-default.md](harmonyos-default.md)。

---

## 项目概况

- 平台：HarmonyOS 6.0 PC / 2in1
- 语言：ArkTS
- 应用类型：剪贴板历史管理工具
- Bundle Name：`moe.kiwi.clipclap`
- AppScope 版本：`versionName: 0.1.0`
- 应用关于页版本资源：`0.1.0`
- 默认快捷键：`Ctrl + Shift + V`
- 默认历史容量：60 条，可在 10 到 300 条之间调整

当前项目已经从原始模板推进到可交互的剪贴板管理器骨架，核心闭环是：

```text
复制内容 -> 后台捕获 -> 记录历史 -> 快捷键/入口唤起弹窗 -> 搜索选择 -> 写回系统剪贴板
```

---

## 当前已实现

### 主界面

- `pages/Index.ets` 已实现主窗口 UI。
- 左侧导航包含历史记录、设置、关于三页。
- 历史页支持搜索、刷新当前剪贴板、复制、固定/取消固定、删除单条、清理未固定记录。
- 历史项展示内容类型、预览、MIME 摘要、复制次数、时间等信息。
- 调试模式下可以显示原始剪贴板负载 JSON，并支持复制原始负载。

### 剪贴板历史

- `ClipboardHistoryStore.ets` 已负责剪贴板捕获、历史管理、复制回写和持久化。
- 使用 `pasteboard.getSystemPasteboard()` 监听剪贴板更新，并在初始化时捕获当前剪贴板。
- 当前历史存储使用 `relationalStore`，历史项以 RDB 表保存，并保留旧 `preferences` 数据的一次性迁移路径。
- 已支持记录或识别以下类型：
  - 文本
  - 链接
  - 代码片段
  - HTML
  - URI
  - 文件 URI
  - 图片 / PixelMap
  - 自定义或混合 MIME 内容
- 图片会尝试保存为应用沙箱内 PNG 资源，便于历史恢复和预览。
- 支持重复内容识别，同签名内容会提升到顶部并增加复制次数。
- 支持置顶优先排序、容量裁剪、清理被删除图片资源。
- 写回剪贴板时会尽量保留原始 `PasteData` / `UnifiedData`，必要时降级为可写入的文本、HTML、URI 或 PixelMap。

### 快捷键和弹窗

- `HotkeyService.ets` 已使用 `inputConsumer.on('hotkeyChange')` 注册全局热键。
- 默认热键是 `Ctrl + Shift + V`，设置页支持调整 Ctrl / Shift / Alt 组合和最终按键。
- 修改快捷键后当前 UI 会提示重启应用后生效。
- `PopupWindowController.ets` 已实现剪贴板弹窗创建、显示、隐藏和销毁。
- 弹窗优先尝试 `WindowType.TYPE_FLOAT`，失败后降级为 `WindowStage.createSubWindowWithOptions`。
- 弹窗支持无装饰窗口、拖动、右下角拖拽调整大小、失焦隐藏，以及位置和尺寸持久化。
- `pages/Popup.ets` 支持搜索、鼠标选择、上下键移动、回车复制、Esc 关闭、`Ctrl+1` 到 `Ctrl+9` 快速选择。

### 图片预览

- `ImagePreviewWindowController.ets` 和 `pages/ImagePreview.ets` 已实现独立图片预览窗口。
- 选中图片、含图片的 HTML 或较长文本时，弹窗旁侧可显示预览。
- 支持本地图片资源预览。
- 远程图片预览由设置项控制，默认关闭。

### 设置

- `SettingsStore.ets` 已使用 `preferences` 保存设置。
- 当前设置项包括：
  - 快捷键
  - 历史容量
  - 剪贴板监听开关
  - 仅粘贴为纯文本
  - 远程图片预览
  - 记录本地文件
  - 系统托盘图标
  - 自动粘贴开关（仅调试模式显示，默认关闭）
  - 失去焦点后隐藏弹窗
  - 开机自启动入口
  - 调试模式
  - 弹窗位置和尺寸
- `PermissionService.ets` 已封装 `READ_PASTEBOARD` 权限检查和申请。
- “监听剪贴板”设置会实际注册或注销系统剪贴板更新监听。
- “自动粘贴”仅在调试模式中显示，默认关闭；开启后会在历史项复制成功、弹窗关闭后尝试发送 `Ctrl + V` 粘贴快捷键。
- 开机自启动当前是跳转系统设置入口，不是直接静默启用。

### 状态栏入口

- `StatusBarService.ets` 已接入 `@kit.DeskTopExtensionKit` 的 `statusBarManager`。
- 可注册状态栏图标，点击图标后调用 `PopupWindowController.showPopup()`。
- 当前该能力由“调试模式 + 系统托盘图标”两个开关共同控制，属于测试中能力。
- `StatusBarQuickAbility.ets` 已作为 `statusBarView` 扩展能力配置到 `module.json5`。

### 多语言和资源

- 已补充基础资源和多语言目录，包括：
  - `base`
  - `en_US`
  - `en_GB`
  - `zh_HK`
  - `zh_TW`
  - `ja_JP`
  - `fr_FR`
  - `de_DE`
  - `ru_RU`
  - `bo_CN`
- 已配置深色主题颜色资源。

---

## 当前权限

`entry/src/main/module.json5` 当前声明：

```text
ohos.permission.READ_PASTEBOARD
ohos.permission.SYSTEM_FLOAT_WINDOW
ohos.permission.INTERNET
```

说明：

- `READ_PASTEBOARD` 用于读取系统剪贴板并生成本地历史。
- `SYSTEM_FLOAT_WINDOW` 用于优先创建真正悬浮窗口；该权限属于受限权限，安装和运行依赖对应 AGC/Profile 授权。没有授权时需要移除该声明，或依赖子窗口降级路径。
- `INTERNET` 用于在用户开启远程图片预览时加载 HTML 内容中的网络图片。

---

## 工程结构

```text
entry/src/main/ets/
  entryability/
    EntryAbility.ets
  entrybackupability/
    EntryBackupAbility.ets
  statusbar/
    StatusBarQuickAbility.ets
  pages/
    Index.ets
    Popup.ets
    ImagePreview.ets
  services/
    ClipboardHistoryStore.ets
  core/
    hotkey/
      AutoPasteService.ets
      HotkeyService.ets
    permission/
      PermissionService.ets
    settings/
      SettingsStore.ets
    statusbar/
      StatusBarService.ets
    window/
      PopupWindowController.ets
      ImagePreviewWindowController.ets
  model/
    AppSettings.ets
    HotkeyConfig.ets
    PreviewTextSegment.ets
```

---

## 构建方式

推荐使用 DevEco Studio 打开项目并执行构建。开发、编译、测试、安装和调试命令见 [DevEco 开发、编译、调试指南](docs/deveco-development.md)。

命令行构建可参考：

```bash
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

当前仓库包含 `hvigorw` 包装脚本，它会优先查找本机 DevEco Studio / Hvigor 安装。需要真机安装或发布时，请在 DevEco Studio 中为本机生成签名配置，不要把个人证书、Profile、密码或本机绝对路径提交到共享仓库。

---

## 已知限制

- 自动粘贴当前仅作为调试功能，依赖 `sendKeyEvent` 发送 `Ctrl + V`，构建可通过，但 SDK 会提示该 API 面向测试目录；发布前仍需确认是否有正式可用的系统级输入模拟或辅助能力方案。
- 状态栏入口仍处于调试能力，默认需要先开启调试模式。
- 本地文件记录被调试模式额外保护，默认关闭。
- `SYSTEM_FLOAT_WINDOW` 是受限权限，当前声明适合有授权 Profile 的调试环境；普通环境需要重点验证安装表现。
- 当前版本号在 `AppScope/app.json5` 和关于页资源中保持为 `0.1.0`，后续发布流程仍应统一版本更新入口。
- 历史记录的图片资源在沙箱内保存，但跨版本迁移、异常恢复和空间清理策略还需要更多验证。

---

## 下一步优先级

1. 明确 `SYSTEM_FLOAT_WINDOW` 的发布策略：有授权时启用，普通构建可一键禁用。
2. 确认自动粘贴的正式 API 路线；如果 `sendKeyEvent` 不能用于发布构建，应改为辅助能力或在 UI 中标记实验状态。
3. 固化版本更新流程，避免 `versionName` 和关于页 `about_version` 再次分叉。
4. 为 `ClipboardHistoryStore` 增加重点单元测试，覆盖 RDB 迁移、去重、容量裁剪、置顶、删除、纯文本降级和多类型写回。
5. 验证状态栏入口在目标 PC / 2in1 设备上的兼容性和失败降级。

---

## 开发原则

- 优先保证应用可安装、可运行、权限风险可控。
- 受限权限相关能力必须保留降级路径。
- 剪贴板内容属于敏感数据，历史记录默认只保存在本地。
- 设置和历史数据分开管理，避免大量历史内容长期堆在普通设置项中。
- 自动粘贴、全局悬浮窗、文件历史和远程图片预览都必须以用户显式设置和平台权限为前提。
- ArkTS 代码需要兼顾严格模式、异常处理和可维护性。
