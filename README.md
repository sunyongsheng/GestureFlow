# GestureFlow

[English README](README.en.md)

GestureFlow 是一款原生 macOS 鼠标手势工具。按住鼠标按键绘制路径，即可在当前应用中触发快捷键或操作。

## 功能介绍

### 鼠标手势

- 使用**右键**或**中键**触发手势
- 支持单段或多段路径（上、下、左、右）

### 手势库

- **全局**手势适用于所有场景，也可为已注册应用配置**按应用**手势集
- 内置常用快捷键预设：后退/前进、复制/粘贴、查找、新建标签页、刷新、最小化、撤销/重做等
- 可为各应用**设置专属手势**
- 支持**自定义手势**：在画布上录制路径并绑定键盘快捷键

### 视觉反馈

- 绘制时显示实时**手势轨迹** overlay
- 可自定义轨迹颜色、宽度、透明度与描边
- 手势识别后可选择显示**反馈卡片**

### 高级调节

- 可调节移动阈值、按住超时与采样距离
- 将操作发送至**前台应用**或**鼠标下方应用**
- 可配置**忽略应用**列表，在指定应用中禁用手势

### 设置与配置

- 支持**登录时启动**及全局手势识别开关
- 支持**自定义配置目录**，便于在多台设备间同步设置（含 XDG `~/.config/gestureflow`）
- **多语言支持**

## 系统要求

- macOS 14.0 或更高版本
- Xcode 26 或更高版本
- Swift 5.9 工具链

## 项目结构

- `GestureFlowCore`：共享手势模型、识别、匹配、校验与配置存储
- `GestureFlowApp`：macOS 菜单栏应用、权限流程、事件监听、overlay、设置与动作执行

## 在 Xcode 中打开

打开标准 macOS 应用工程：

```bash
open GestureFlow.xcodeproj
```

首次 clone 后如需覆盖 Debug 签名（默认 ad-hoc，见 `Config/GestureFlowApp-Debug.xcconfig`），可创建本地配置：

```bash
Scripts/setup_local_xcconfig.sh
```

按 `Config/Local.xcconfig.example` 中的注释填入 `DEVELOPMENT_TEAM` 等项；`Config/Local.xcconfig` 不进仓库。

本地主要工作流：

- 在 Xcode 中运行 `GestureFlowApp` scheme
- 通过 Xcode 的 Test 操作运行测试
- 使用 `xcodebuild` 进行命令行验证

## 构建

使用 Xcode 构建应用：

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
```

## 运行

在 Xcode 中运行应用，或构建并启动打包后的 bundle：

```bash
Scripts/package_app.sh
open build/GestureFlow.app
```

首次启动时，macOS 会显示权限引导或提示授予**辅助功能**权限。应用需要该权限才能监听全局鼠标事件并触发操作。

## 构建 Release

发布包会用自签证书 **GestureFlow Self-Signed** 签名（便于辅助功能等权限在更新后延续）。证书只需配置一次：

```bash
# 生成 .p12 与 base64（默认密码 gestureflow，有效期约 10 年）
Scripts/generate-signing-cert.sh

# 导入登录钥匙串，供 package_app.sh / sign_app_bundle.sh 使用
security import ~/Desktop/gestureflow-signing.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -P gestureflow \
  -T /usr/bin/codesign

# 验证（自签身份可能不出现在 find-identity 列表中，以 dryrun 为准）
codesign -s "GestureFlow Self-Signed" -f --dryrun /bin/ls
```

请备份 `gestureflow-signing.p12`，并在后续版本中复用同一文件。

打包：

```bash
Scripts/package_app.sh              # build/GestureFlow.app
Scripts/package_release.sh 0.2.3    # dist/ 下的 zip、dmg 与校验和
```
