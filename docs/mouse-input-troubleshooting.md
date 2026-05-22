# Mouse Input Troubleshooting

## 背景

GestureFlow 在实现鼠标手势时，先后遇到过两类高频且影响很大的问题：

1. 轨迹绘制位置和真实鼠标位置对不上。
2. 使用右键手势后，macOS 触发角失效，甚至出现必须再点一次右键后左键/系统交互才恢复的现象。

这份文档沉淀两类问题的根因、最终解决方案，以及后续开发时必须遵守的约束。

## 问题一：轨迹和鼠标位置对不上

### 现象

- 轨迹整体相对鼠标热点发生偏移。
- `y` 方向偶尔反向，或者在不同窗口状态下表现不一致。
- 多屏环境下，主屏和副屏的偏移规律不同。
- 识别提示位置也会跟着出现跨屏偏移。

### 根因

根因不是 `GestureOverlayView` 的绘制逻辑，而是屏幕坐标转换链路在不同层做了重复或错误的换算。

历史问题主要集中在两点：

1. 在 `MouseEventTap` 层使用“联合桌面 frame”手工翻转 `y`。
2. Overlay 层没有完全收敛到 AppKit 官方的屏幕坐标转换 API。

#### 错误模式

- 使用所有屏幕 union 后的 `desktopFrame` 做统一 `y` 翻转。
- 在多屏环境中，副屏 `minY` / `maxY` 会污染主屏点位。
- 在 `EventTap` 和 Overlay 两层同时做推导，导致局部修正一处、另一处继续放大误差。

这会让轨迹偏移表现为：

- 在主屏看起来“整体高一点/低一点”。
- 在副屏或窗口状态变化时，误差突然放大。
- 同一个点在日志里看似合理，但进入 Overlay 后变成错误的局部坐标。

### 解决方案

#### 1. `MouseEventTap` 只负责把 Quartz 点转换成正确的 AppKit 屏幕点

在 [MouseEventTap.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/EventTap/MouseEventTap.swift) 中：

- 先找到“包含当前点的屏幕 frame”，而不是用联合桌面 frame。
- 再基于该屏幕单独翻转 `y`：

```swift
let screenFrame = screenFramesProvider().first(where: { $0.contains(quartzPoint) }) ?? desktopFrameProvider()
let appKitY = screenFrame.maxY + screenFrame.minY - quartzPoint.y
```

关键点：

- 必须按“所在屏幕”翻转 `y`。
- 不能再用 `desktopFrame` 的整体 `minY/maxY` 去推导主屏点位。

#### 2. Overlay 统一使用 AppKit 官方转换 API

在 [GestureOverlayCoordinateConverter.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/Overlay/GestureOverlayCoordinateConverter.swift) 中，统一通过：

```swift
let windowPoint = panel.convertFromScreen(screenRect).origin
let localPoint = view.convert(windowPoint, from: nil)
```

以及：

```swift
let windowRect = panel.convertFromScreen(rect)
return view.convert(windowRect, from: nil)
```

这让以下逻辑完全收敛到一个地方：

- 全局屏幕点 -> Overlay window 坐标
- 全局屏幕 rect -> Overlay view 坐标

#### 3. `GestureEngine` 不再做人为热点偏移

在 [GestureEngine.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/Engine/GestureEngine.swift) 中，当前 `displayPoint(for:)` 直接返回原始点：

```swift
private func displayPoint(for point: GesturePoint) -> GesturePoint {
    point
}
```

原因：

- 热点偏移如果夹在事件采集层和 overlay 层之间，会让排查变得非常困难。
- 当前目标是先保证“屏幕点 -> 局部点” 1:1 正确，再考虑视觉微调。

### 防回归规则

- 坐标转换必须集中在 `GestureOverlayCoordinateConverter`。
- `MouseEventTap` 不允许再引入基于联合桌面 frame 的统一 `y` 翻转公式。
- 不要在 `GestureEngine`、`GestureOverlayWindow`、`GestureOverlayView` 中各自追加额外的手工偏移修正。
- 多屏环境下优先验证“按所在屏幕翻转 `y`”而不是继续微调常量偏移。

## 问题二：触发角失效，右键/左键状态异常

### 现象

- 开启手势后，macOS 触发角失效。
- 停止 GestureFlow 后，触发角仍然不恢复。
- 使用一次右键手势后，必须再点一次右键，左键或系统交互才恢复正常。
- 右键长按超时、右键回放、手势取消等边界场景下，问题更容易出现。

### 根因

根因是右键物理事件被 `EventTap` 吞掉后，系统内部“按钮仍处于按下态”，但没有收到对称的 `rightMouseUp`。

具体来说，问题由三类错误叠加导致：

#### 1. 手势成功或超时回放时，吞掉了真实 `rightMouseUp`

一旦我们返回 `.suppressEvent`，底层应用和系统都收不到这次物理抬起事件。

如果没有主动补发一个系统级的 `rightMouseUp`，就会出现：

- 系统仍认为右键处于 pressed 状态。
- 触发角、后续左键、上下文菜单行为异常。

#### 2. 只回放 synthetic click，不先释放 held button state

在“右键长按超时后首次移动立刻触发普通右键点击”的链路里，单纯发 synthetic `rightMouseDown/rightMouseUp` 并不稳定。

因为当时真实物理右键仍处于 held 状态，系统可能不会正确接受这次 synthetic click。

所以正确顺序必须是：

1. 先补一个 synthetic `rightMouseUp`
2. 再回放一次普通 synthetic 右键点击

#### 3. 抑制尾状态跨序列泄漏

在 [MouseEventTap.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/EventTap/MouseEventTap.swift) 中，`suppressRightMouseSequenceUntilUp` 用来吞掉 timeout replay 后剩余的物理 `dragged/up`。

如果这个状态泄漏到下一轮新的 `rightMouseDown`，就会导致：

- 新一轮 `dragged` 一开始就被提前吞掉。
- 根本进不了“超时后首次移动立即回放右键点击”的逻辑。
- 表现为红点出现后拖很远，也没有触发普通右键点击。

### 解决方案

#### 1. 为被吞掉的右键序列补发系统级 `rightMouseUp`

在 [MouseEventTap.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/EventTap/MouseEventTap.swift) 中，通过 `mouseButtonResetter` / `releaseMouseButtonIfNeeded(...)` 主动恢复系统按钮状态。

这条规则适用于：

- 手势识别成功后
- `stop()` 清理时
- 右键长按超时并准备回放普通右键点击前

#### 2. Timeout replay 采用“先 release，再 click”

当前 timeout 后首次移动走的是：

```swift
private func replaySyntheticRightClickDuringHeldSequence(at point: GesturePoint) {
    let reset = PendingMouseButtonReset(trigger: .rightMouse, point: point)
    releaseMouseButtonIfNeeded(reset)
    syntheticClickPoster(.rightMouse, point)
}
```

这解决了“红点出现后移动，但普通右键点击没有真正生效”的问题。

#### 3. 每轮新的 `rightMouseDown` 必须清掉旧的 suppress 尾状态

在 `beginPendingRightClick(at:)` 中，新的物理右键序列开始时显式执行：

```swift
suppressRightMouseSequenceUntilUp = false
```

这解决了“上一轮 replay 的 suppress 尾巴污染下一轮交互”的问题。

#### 4. 合成事件必须带标记，避免自我递归拦截

合成事件统一打上：

```swift
event.setIntegerValueField(.eventSourceUserData, value: syntheticEventSignature)
```

并在 `handle(type:event:)` 中直接放行：

```swift
if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventSignature {
    return .passEvent
}
```

否则会出现：

- 自己回放的 `rightMouseDown/up` 又被自己拦截
- 状态机再次进入 pending / suppress
- 右键状态和系统状态进一步失衡

### 防回归规则

- 任何被吞掉的右键序列，都必须考虑“系统按钮状态如何恢复”。
- Timeout replay 不能只发 synthetic click，必须先释放 held button state。
- `suppressRightMouseSequenceUntilUp` 这类状态位必须在新的物理交互起点上显式重置。
- `stop()` 不是简单停掉 tap；它还必须清理 pending/marker/button-reset 等残留状态。
- 所有 synthetic mouse events 都必须带签名，防止递归拦截。

## 推荐排查顺序

后续如果再遇到类似问题，建议优先按下面顺序排查：

1. 先看点位是不是在 `MouseEventTap` 层就已经错了。
2. 再看 Overlay 是否统一走了 `GestureOverlayCoordinateConverter`。
3. 如果是右键/触发角异常，先检查是否漏发了 `rightMouseUp` 恢复。
4. 如果问题出现在 timeout/replay 边界场景，检查 suppress 状态是否跨序列泄漏。
5. 最后再考虑视觉层面的偏移微调，不要一上来就改常量。

## 相关文件

- [MouseEventTap.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/EventTap/MouseEventTap.swift)
- [GestureOverlayCoordinateConverter.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/Overlay/GestureOverlayCoordinateConverter.swift)
- [GestureOverlayWindow.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift)
- [GestureEngine.swift](file:///Users/bytedance/Projects/GestureFlow/Sources/GestureFlowApp/Engine/GestureEngine.swift)
- [MouseEventTapTests.swift](file:///Users/bytedance/Projects/GestureFlow/Tests/GestureFlowAppTests/MouseEventTapTests.swift)
