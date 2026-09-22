# App icon

GestureFlow 使用 Icon Composer 原生 `.icon` 资源。主体是一笔连续、不对称的开放手势轨迹，通过斜向滑动与回转表达 GestureFlow；不使用字母 G 的圆环和水平横杠，采用自适应纯色背景、圆头等宽轨迹，不在素材内烘焙纹理、霓虹、高光或阴影。

| 外观 | Release | Debug |
| --- | --- | --- |
| Light / Default | ![Release Light](assets/app-icon.png) | ![Debug Light](assets/app-icon-debug.png) |
| Dark | ![Release Dark](assets/app-icon-dark.png) | ![Debug Dark](assets/app-icon-debug-dark.png) |

Light 使用浅灰蓝背景 `#EDF3F8` 和深青蓝轨迹 `#087FAD`；Dark 使用深蓝背景 `#122333` 和亮青蓝轨迹 `#55D9F2`。配色通过两个图层的 `fill-specializations` 定义，可在 Icon Composer 的 Default / Dark 中分别编辑；不是把明暗图层叠在一起。Debug 标记在两种外观下保持琥珀色。

## 图层

两个资源包均使用 1024 × 1024 SVG 画布，缩放为 1，偏移为 0。`icon.json` 中组顺序由前到后：

- `Foreground · Debug`：仅 Debug 包包含，琥珀色代码符号标记，独立于主体。
- `Foreground · Gesture`：透明底青蓝色开放手势轨迹，`Gesture.svg`。
- `Background · Adaptive`：铺满画布、按外观切换颜色的背景，`Background.svg`。背景不预裁圆角，外轮廓交由系统处理。

背景层关闭 Glass；当前 Release 主体启用 Glass，Debug 主体及标记关闭 Glass。各组阴影为 0，并关闭半透明。系统生成的材质和外缘效果不烘焙进 SVG。Release / Debug 的背景和主体 SVG 应保持一致。

## 编辑与工程集成

直接用 Icon Composer 打开 `Resources/AppIcon.icon` 或 `Resources/AppIconDebug.icon`，即可分别选择和编辑各组。无需把图层合并成 PNG，也无需导入 Assets.xcassets。

Xcode 工程已将两个 `.icon` 包加入 Resources；Release 的 `ASSETCATALOG_COMPILER_APPICON_NAME` 为 `AppIcon`，Debug 为 `AppIconDebug`。发布打包脚本使用该 Xcode 工程，自动编译图标。

## 验证

分别通过 Xcode `actool` 编译两个图标，输出 `Assets.car`、`.icns` 和图标信息 plist。下列命令验证 Release，将 `--app-icon` 改成 `AppIconDebug` 并更换输出目录即可验证 Debug：

```sh
mkdir -p /tmp/gestureflow-icon-check
xcrun actool Resources/AppIcon.icon Resources/AppIconDebug.icon \
  --compile /tmp/gestureflow-icon-check \
  --platform macosx --minimum-deployment-target 13.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/gestureflow-icon-check/info.plist \
  --output-format human-readable-text
```

上方 Light 预览来自实际编译的 `.icns`；Dark 预览由临时副本将 Dark 颜色设为默认后编译导出。原始资源沿用已在 Icon Composer 中确认的原生 Default / Dark 外观配置。新主体已检查 256 px 和 32 px 编译预览，并确认 Debug 标记不遮挡轨迹。整条轨迹保持 88 px 等宽。左侧上行轨迹略向左上方展开（1024 画布约 14–18 px），内侧回转轨迹保持原位，轻微增加两段轨迹之间的留白。主体使用闭合填充轮廓，避免 SVG 描边在兼容图标编译时应用填充覆盖产生异常。当前改动仅涉及图标资源，未执行完整应用构建。

参考：[Apple — Creating your app icon using Icon Composer](https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer)。
