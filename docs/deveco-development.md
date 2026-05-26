# DevEco 开发、编译、调试指南

本文整理 ClipClap 在 DevEco Studio 和命令行下的常用开发、编译、测试、安装和调试方法。项目是 HarmonyOS Stage 模型应用，主模块为 `entry`，产品为 `default`，当前工程配置使用 HarmonyOS `6.0.2` 模型。

## 1. 工程信息

- 工程根目录：`/Users/takuenn/Workspace/DevEco/ClipClap`
- Bundle Name：`moe.kiwi.clipclap`
- 主模块：`entry`
- Target：`entry@default`
- Product：`default`
- Hvigor Wrapper：`./hvigorw`
- 根构建配置：`build-profile.json5`
- 模块构建配置：`entry/build-profile.json5`
- 模块清单：`entry/src/main/module.json5`
- 本地单元测试入口：`entry/src/test/List.test.ets`
- 设备测试入口：`entry/src/ohosTest/ets/test/List.test.ets`

当前仓库包含一个自定义 `hvigorw` 包装脚本。它会按以下顺序寻找 DevEco/Hvigor：

1. `DEVECO_TOOLS_HOME` 下的 `hvigor/bin/hvigorw`
2. 项目或环境中的 Hvigor Node 脚本
3. `CMD_PATH` 下的 Hvigor
4. PATH 中的 `hvigorw` 或 `hvigor`
5. macOS 默认路径 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`

## 2. 环境准备

### 2.1 推荐环境

- DevEco Studio：已安装并完成 HarmonyOS SDK 下载。
- Node.js：使用 DevEco Studio 自带 Node 或本机 Node 均可。
- ohpm：用于依赖安装。
- hdc：用于设备连接、安装、日志和调试辅助。

本机常见路径如下：

```bash
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export DEVECO_TOOLS_HOME=$DEVECO_HOME/tools
export DEVECO_SDK_HOME=$DEVECO_HOME/sdk
export HDC_PATH=$DEVECO_SDK_HOME/default/openharmony/toolchains/hdc
export OHPM_PATH=$DEVECO_TOOLS_HOME/ohpm/bin/ohpm
```

如果希望直接使用 `ohpm` 和 `hdc` 命令，可以临时加入 PATH：

```bash
export PATH="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH"
export PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"
```

验证工具版本：

```bash
./hvigorw --version
ohpm --version
hdc -v
```

当前本机验证到的版本：

- Hvigor：`6.22.7`
- ohpm：`6.0.1`
- hdc：`3.2.0c`

### 2.2 安装依赖

根目录执行：

```bash
ohpm install
```

如果 `ohpm` 不在 PATH 中，使用 DevEco 自带路径：

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
```

依赖会写入 `oh_modules`，锁文件为 `oh-package-lock.json5`。

## 3. DevEco Studio 开发方法

### 3.1 打开工程

1. 启动 DevEco Studio。
2. 选择 `Open`。
3. 打开工程根目录 `/Users/takuenn/Workspace/DevEco/ClipClap`。
4. 等待 Sync、Indexing、ohpm install 和 SDK 检查完成。

如果打开后依赖或构建插件异常，优先执行：

- `File > Sync and Refresh Project`
- `Build > Clean Project`
- `Build > Rebuild Project`

### 3.2 选择运行配置

常用运行配置：

- Module：`entry`
- Product：`default`
- Build Mode：`debug`
- Device：HarmonyOS PC / 2in1 设备或模拟器

此项目 `entry/src/main/module.json5` 的 `deviceTypes` 当前为 `2in1`，调试设备需要匹配目标设备类型。

### 3.3 在 IDE 中运行

常用入口：

- `Run`：构建、安装并启动应用。
- `Debug`：构建、安装、启动并附加 ArkTS 调试器。
- `Build > Make Project`：仅构建当前工程。
- `Build > Build Hap(s)/APP(s)`：生成安装包。

调试时可在 `.ets` 文件中设置断点。与剪贴板、窗口、状态栏、快捷键相关的能力通常需要真机或目标 PC/2in1 环境验证，Preview 无法完整覆盖。

## 4. 命令行构建

以下命令均在工程根目录执行。

### 4.1 查看帮助和任务

```bash
./hvigorw --help
./hvigorw tasks --mode module -p module=entry@default -p product=default --no-daemon
./hvigorw taskTree --mode module -p module=entry@default -p product=default --no-daemon
```

当前任务树里和本项目最相关的任务包括：

- `:entry:assembleHap`：构建 HAP。
- `:entry:test`：运行本地单元测试。
- `:entry:UnitTestBuild`：构建本地单元测试产物。
- `:entry:onDeviceTest`：设备测试相关任务。
- `:entry:PreviewBuild`：ArkUI Preview 构建。
- `:entry:HotReloadBuild`：热重载构建。
- `:entry:compileNative`：原生构建任务，当前项目一般用不到。

### 4.2 Debug HAP 构建

推荐命令：

```bash
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

如果需要更详细日志：

```bash
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --info --stacktrace --no-daemon
```

如果没有使用仓库的 `hvigorw`，可以直接调用 DevEco Studio 内置 Hvigor：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module -p module=entry@default -p product=default --no-daemon
```

### 4.3 Release HAP 构建

Release 构建使用 `release` 构建模式：

```bash
./hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=release --no-daemon
```

如果 DevEco/Hvigor 环境不识别 `buildMode` 属性，可改在 DevEco Studio 的 Build Variants 或构建配置中选择 `release` 后构建。

注意：

- `build-profile.json5` 中的签名配置通常包含本机证书、Profile、密码和绝对路径。
- 不要把个人签名材料、密码、Profile 或本机绝对路径提交到共享仓库。
- 真机安装或发布前，需要在 DevEco Studio 中配置有效签名。

### 4.4 清理和停止守护进程

停止当前项目 Hvigor daemon：

```bash
./hvigorw --stop-daemon
```

停止所有 Hvigor daemon：

```bash
./hvigorw --stop-daemon-all
```

查看 daemon 状态：

```bash
./hvigorw --status-daemon
```

清理 Hvigor 缓存和未引用包：

```bash
./hvigorw prune
```

DevEco Studio 中也可以使用：

- `Build > Clean Project`
- `Build > Rebuild Project`

## 5. 测试

### 5.1 本地单元测试

本项目本地测试位于：

- `entry/src/test/AppSettings.test.ets`
- `entry/src/test/HotkeyConfig.test.ets`
- `entry/src/test/PreviewTextFormatter.test.ets`
- `entry/src/test/List.test.ets`

命令行运行：

```bash
./hvigorw test --mode module -p module=entry@default -p product=default --no-daemon
```

只构建单元测试产物：

```bash
./hvigorw UnitTestBuild --mode module -p module=entry@default -p product=default --no-daemon
```

### 5.2 设备测试

设备测试入口位于：

- `entry/src/ohosTest/ets/test/Ability.test.ets`
- `entry/src/ohosTest/ets/test/List.test.ets`

在 DevEco Studio 中推荐使用 `Run OhosTest` 或测试面板运行。命令行可先查看任务：

```bash
./hvigorw taskTree --mode module -p module=entry@default -p product=default --no-daemon
```

设备测试相关任务：

```bash
./hvigorw onDeviceTest --mode module -p module=entry@default -p product=default --no-daemon
```

设备测试依赖已连接设备、签名、测试框架和目标设备能力，失败时优先看 DevEco Test 面板与 `hdc hilog`。

## 6. 安装、启动和卸载

### 6.1 检查设备连接

```bash
hdc list targets
```

如果 `hdc` 不在 PATH 中：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
```

常见处理：

- 设备需要开启开发者模式。
- USB 调试或网络调试需要授权。
- 多设备连接时，需要指定目标设备。

指定设备：

```bash
hdc -t <target-id> list targets
```

### 6.2 安装 HAP

构建完成后，先查找产物：

```bash
find entry/build -name "*.hap"
```

安装：

```bash
hdc install <path-to-hap>
```

多设备时：

```bash
hdc -t <target-id> install <path-to-hap>
```

如果签名、权限或版本冲突导致安装失败，先卸载旧包后重装：

```bash
hdc uninstall moe.kiwi.clipclap
hdc install <path-to-hap>
```

### 6.3 启动应用

使用 bundle 和 ability 启动：

```bash
hdc shell aa start -a EntryAbility -b moe.kiwi.clipclap
```

如果需要启动设置窗口，使用 `SettingsAbility`：

```bash
hdc shell aa start -a SettingsAbility -b moe.kiwi.clipclap
```

多设备时：

```bash
hdc -t <target-id> shell aa start -a EntryAbility -b moe.kiwi.clipclap
```

### 6.4 停止或卸载

强制停止应用：

```bash
hdc shell aa force-stop moe.kiwi.clipclap
```

卸载：

```bash
hdc uninstall moe.kiwi.clipclap
```

## 7. 日志和调试

### 7.1 查看日志

实时日志：

```bash
hdc hilog
```

保存日志：

```bash
hdc hilog > hilog.log
```

按关键字过滤：

```bash
hdc hilog | grep -i clipclap
hdc hilog | grep -E "EntryAbility|SettingsAbility|PopupWindow|Hotkey|Clipboard|StatusBar"
```

项目中常见日志 tag 包括：

- `testTag`
- `SettingsAbility`
- `HotkeyService`
- `PopupWindowController`
- `ImagePreviewWindowController`
- `StatusBarService`

### 7.2 DevEco Debug

推荐流程：

1. 使用 DevEco Studio 打开工程。
2. 连接 HarmonyOS PC / 2in1 设备。
3. 选择 `entry` 运行配置。
4. 点击 `Debug`。
5. 在 `.ets` 文件中设置断点。
6. 通过应用 UI、快捷键或状态栏入口触发对应代码路径。

适合断点调试的文件：

- 主窗口生命周期：`entry/src/main/ets/entryability/EntryAbility.ets`
- 设置窗口生命周期：`entry/src/main/ets/entryability/SettingsAbility.ets`
- 剪贴板历史：`entry/src/main/ets/services/ClipboardHistoryStore.ets`
- 快捷键：`entry/src/main/ets/core/hotkey/HotkeyService.ets`
- 弹窗：`entry/src/main/ets/core/window/PopupWindowController.ets`
- 图片预览：`entry/src/main/ets/core/window/ImagePreviewWindowController.ets`
- 状态栏：`entry/src/main/ets/core/statusbar/StatusBarService.ets`

### 7.3 ArkUI Preview

DevEco Studio 中可对页面组件使用 Preview，适合快速检查布局。命令行构建 Preview：

```bash
./hvigorw PreviewBuild --mode module -p module=entry@default -p product=default --no-daemon
```

限制：

- Preview 不能完整验证剪贴板权限、全局快捷键、悬浮窗、状态栏入口、设备权限弹窗。
- 这类能力需要真机或目标系统环境验证。

### 7.4 热重载

DevEco Studio 的 Hot Reload 适合 UI 调整。命令行任务：

```bash
./hvigorw HotReloadBuild --mode module -p module=entry@default -p product=default --no-daemon
```

实际开发中建议优先使用 IDE 的 Hot Reload 按钮，因为它会处理设备连接和会话状态。

## 8. 签名和权限

### 8.1 签名配置

构建配置入口：

- `build-profile.json5`

签名配置通常包含：

- `certpath`
- `keyAlias`
- `keyPassword`
- `profile`
- `storeFile`
- `storePassword`
- `signAlg`

处理原则：

- 本机调试签名可以留在本地工作区。
- 不要提交个人证书、Profile、密码和本机绝对路径。
- 发布签名应通过 DevEco Studio、CI Secret 或安全的本地配置管理。
- 如果需要提交公共构建配置，使用不含签名材料的模板，例如 `build-profile.ci.json5`。

### 8.2 权限

当前 `entry/src/main/module.json5` 声明：

- `ohos.permission.READ_PASTEBOARD`
- `ohos.permission.INTERNET`

权限验证重点：

- 首次运行时检查剪贴板读取授权弹窗。
- 关闭权限后验证降级提示。
- 远程图片预览依赖 `INTERNET`。
- 若后续恢复悬浮窗权限，`SYSTEM_FLOAT_WINDOW` 属于受限能力，需要 Profile 授权和安装验证。

## 9. 常见问题

### 9.1 `Unable to locate hvigorw`

原因：`./hvigorw` 没找到 DevEco/Hvigor。

处理：

```bash
export DEVECO_TOOLS_HOME=/Applications/DevEco-Studio.app/Contents/tools
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
./hvigorw --version
```

确认 DevEco Studio 已安装，且路径存在：

```bash
ls /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
```

### 9.2 `ohpm: command not found`

使用 DevEco 自带 ohpm：

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
```

或加入 PATH：

```bash
export PATH="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH"
```

### 9.3 `hdc: command not found`

使用 DevEco SDK 自带 hdc：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
```

或加入 PATH：

```bash
export PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"
```

### 9.4 安装失败

常见原因：

- 设备未授权。
- 设备类型不匹配。
- 签名 Profile 不包含当前设备。
- Bundle 已安装但签名不同。
- 目标 SDK 或兼容 SDK 与设备系统不匹配。
- 使用了受限权限但 Profile 未授权。

处理顺序：

```bash
hdc list targets
hdc uninstall moe.kiwi.clipclap
hdc install <path-to-hap>
hdc hilog
```

### 9.5 构建异常但 IDE 可以运行

常见原因是命令行缺少 DevEco 环境变量或 PATH。建议先设置：

```bash
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export DEVECO_TOOLS_HOME=$DEVECO_HOME/tools
export DEVECO_SDK_HOME=$DEVECO_HOME/sdk
export PATH="$DEVECO_TOOLS_HOME/ohpm/bin:$DEVECO_SDK_HOME/default/openharmony/toolchains:$PATH"
```

再执行：

```bash
ohpm install
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --info --stacktrace --no-daemon
```

### 9.6 快捷键、剪贴板、状态栏行为不符合预期

这类问题优先用真机或目标 PC/2in1 环境验证。排查顺序：

1. 确认 `READ_PASTEBOARD` 权限已授权。
2. 确认应用未被系统限制后台能力。
3. 查看 `HotkeyService`、`ClipboardHistoryStore`、`StatusBarService` 相关日志。
4. 在 DevEco Studio Debug 中对相关服务类打断点。
5. 检查设置页中调试模式、状态栏图标、剪贴板监听等开关状态。

## 10. 推荐日常流程

### 10.1 日常开发

```bash
ohpm install
./hvigorw test --mode module -p module=entry@default -p product=default --no-daemon
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

随后在 DevEco Studio 中 Debug 到设备，验证真实权限和窗口行为。

### 10.2 提交前检查

```bash
./hvigorw test --mode module -p module=entry@default -p product=default --no-daemon
./hvigorw assembleHap --mode module -p module=entry@default -p product=default --info --stacktrace --no-daemon
git status --short
```

提交前重点检查：

- 不提交本机签名文件、Profile、密码。
- 不提交无关构建产物。
- 不提交设备日志或临时调试文件。
- 多语言资源改动保持 key 一致。
- 涉及剪贴板、快捷键、窗口、状态栏的修改需要真机验证。

