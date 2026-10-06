# 性能优化记录

## 2026-09：手势链路与内存峰值

### 背景

手势链路的热点都在主线程上，而且大多运行在 CGEvent tap 的回调里：

- 右/中键的每个事件都会同步经过 `MouseEventTap` → `GestureEngine` → 识别 / 匹配 → 浮层更新。
- 松手时，识别、匹配、激活目标 App、发送快捷键也在同一个回调里完成。

tap 回调没有返回之前，系统的鼠标事件会一直被挡住；回调太慢时，macOS 还会直接停用 tap（`tapDisabledByTimeout`）。这次 review 围绕这条链路展开，同时排查了线上进程 772 MB 的内存峰值。

测量方式：临时基准测试直接调用仓库里的真实代码（测完即删），机器为 Apple Silicon、macOS 27.0、Xcode 27。**CPU 数据以 release 构建为准**：debug 构建里 Swift 循环要慢几十倍，review 初稿里"实时识别 1000 点 62 ms、2000 点 212 ms"就是 debug 数据，release 下只有 1.2 ms 和 3.7 ms。

### 结论速览

| 问题 | 改动 | 效果（release） |
| --- | --- | --- |
| 松手投递阻塞 tap 回调 | 投递延后到回调返回之后；激活改为异步等待 | 回调不再等待 LaunchServices（本机 12–73 ms）和最长 0.5 s 的空转 |
| AX 调用没有超时 | 全局 AX 超时 0.25 s | App 卡死时最多阻塞 0.25 s，而不是系统默认的数秒 |
| 每次右键按下都解析目标 | 目标改为懒解析，右键变成手势时才解析 | 普通右键按下：约 3.7 ms → 0.0007 ms |
| 实时识别随手势变长 | 增量识别器 | 2000 个采样的一次手势：3.73 ms → 0.017 ms |
| 轨迹绘制随手势变长 | 只描边重绘区域附近的线段 | 2000 个点时单次重绘：0.36 ms → 约 0.05 ms，不再随长度增长 |

另外确认了一个**不需要优化**的点：反馈卡片的 `show()` 虽然每个采样都会调用，但内容不变时只要约 0.01 ms。

### 1. 松手投递阻塞 tap 回调

#### 根因

`finishConsumedGesture` 在 tap 回调里同步调用 `onGestureEnded`，引擎随即执行 `ActionExecutor`，之后才补发右键抬起。目标 App 不在前台时（"光标下的 App"模式的常见情况），投递过程是：

1. 发起一次直接激活，然后马上读 `NSWorkspace.frontmostApplication` 判断是否已激活。这个值要等主 run loop 转一圈才会更新，此时读到的必然还是旧值。
2. 因此一定会走到第二次激活，再调用 `NSWorkspace.openApplication`，并在主线程上 `RunLoop.run` 空转，最长 0.5 s，等待它完成。
3. 之后 `AXTargetWindowRaiser` 对目标 App 的每个窗口再做 2–4 次 AX 往返，才发送快捷键。

后果：反馈卡片和补发的右键抬起都被推迟；这段时间里右键和中键事件都被 tap 挡住；目标 App 响应慢时可能触发 `tapDisabledByTimeout`。本机实测一次 `openApplication` 往返就要 12–73 ms。

#### 改动

- `GestureEngine` 新增 `scheduleGestureCompletion`（默认 `DispatchQueue.main.async`）。回调里只同步记录并清理手势状态（包括按下时解析出的目标），识别、匹配、投递和浮层结果都在回调返回之后执行。tap 因此能立刻补发右键抬起，快捷键也总是在按键释放之后才发送。
- `ActionExecutor` 新增 `TargetActivationWaiting` 依赖，生产实现是 `WorkspaceActivationWaiter`：
  - 监听 `NSWorkspace.didActivateApplicationNotification`，按 pid、bundle id 或 helper 与父 App 的对应关系匹配目标，收到后再置前窗口、发送快捷键；
  - 最长等待 0.5 s，与原来的上限一致，超时后照常投递；
  - 如果实际会被激活的那个 App 已经在前台（系统不会再发激活通知），立即投递，避免白等 0.5 s。
- `NSProcessActivator` 仍会同时发起直接激活和 LaunchServices 激活，但不再等待任何一个。原因是 macOS 14+ 的直接激活是协作式的，后台 agent 发起的请求可能被拒绝（见提交 `61f7d50`）。去掉了重复的第二次激活和 run loop 空转。
- 目标或其 helper 已在前台时，行为不变，立即投递。
- 激活之后发送快捷键若失败（只有创建 CGEvent 失败这一种情况，实际几乎不会发生），错误无法再抛给引擎，改为打印日志。

### 2. Accessibility 调用没有超时

仓库里原先没有任何地方调用 `AXUIElementSetMessagingTimeout`。"光标下的 App"模式下，AX 命中测试运行在 tap 回调里；如果光标下的 App 卡死，它会一直阻塞到系统默认超时（数秒），右键跟着卡住，tap 也会被停用。

改动：新增 `AccessibilityMessaging.applyTimeout()`，通过 system-wide 元素把全进程的 AX 超时设为 0.25 s，在 AX 命中测试和窗口置前之前调用。正常情况下 AX 命中测试只需约 2 ms。超时后，命中测试会退回到窗口栈的结果，窗口置前则直接跳过。

### 3. 每次右键按下都解析目标

"光标下的 App"模式下，每次右键按下（包括只想打开右键菜单的普通点击）都会在 tap 回调里同步完成：逐层查询窗口栈（本机栈深 3，约 0.06 ms）、拉取全部屏幕窗口信息（11 个窗口，约 0.23 ms）、`NSRunningApplication` 查询，以及一次系统级 AX 命中测试。合计约 2–4 ms，还会让光标下的 App 响应一次 AX 请求。

改动：

- 新增 `GestureActivation`：目标在第一次访问时才解析，之后复用。
- `GestureActivationGate.gestureActivation(at:)` 在忽略列表为空时返回懒解析的对象；忽略列表不为空时仍在按下时解析，因为要靠 bundle id 当场决定是否放行。
- `MouseEventTap` 只在右键待定状态升级为手势时读取目标，此时浮层还没出现。中键手势在按下时就开始，所以仍在按下时解析。

效果：普通右键的按下开销从约 3.7 ms 降到 0.0007 ms，目标解析只在真正的手势里发生。

没有做的：review 里还提议只查询按下点所在的几个窗口（`CGWindowListCreateDescriptionFromArray`），取代拉取全部窗口。解析改为只在手势时发生后，这一项每个手势只能再省约 0.2 ms，却要手工复刻 `.excludeDesktopElements` 的桌面窗口过滤规则，风险不值得。

### 4. 单个采样的开销随手势长度增长

#### 实时识别

原先每来一个采样，都会对全部点重跑一遍 `GestureRecognizer.recognize`，一次手势的总开销与点数的平方成正比。

识别算法是：贪心丢弃离上一个保留点不到 8 pt 的点，累加路径长度，再把相邻相同方向合并成 token。这个过程对前缀稳定，可以逐点增量计算。新增的 `IncrementalGestureRecognizer`（GestureFlowCore）每个点 O(1)，累加顺序与原算法一致，结果逐位相同；有随机路径的逐前缀对比测试保证。引擎的实时反馈改用它；松手时的最终识别仍用批量识别，只算一次。

| 采样数 | 修复前（每次手势） | 修复后 |
| --- | --- | --- |
| 500 | 0.44 ms | 0.006 ms |
| 1000 | 1.16 ms | 0.009 ms |
| 2000 | 3.73 ms | 0.017 ms |

#### 轨迹绘制

原先每次局部重绘都会重建整条路径，并在脏区域的裁剪下完整描边两遍（外描边 + 轨迹色），开销随点数线性增长。

改动：`GestureOverlayView.makeTrailPath(intersecting:)` 只保留"描边范围（半线宽 + 2 pt 抗锯齿余量）能碰到脏区域"的线段。轨迹使用圆头和圆角连接，描边等于各线段胶囊形状的并集，所以跳过碰不到脏区域的线段，不会改变脏区域内的任何像素；有逐像素对比测试保证。筛选只做标量比较，数组先拷贝到局部变量，循环在 release 下可以忽略不计。

| 轨迹点数 | 修复前（单次重绘） | 修复后 |
| --- | --- | --- |
| 500 | 0.17 ms | 0.04 ms |
| 1000 | 0.24 ms | 0.06 ms |
| 2000 | 0.36 ms | 0.05 ms |

#### Core Graphics 的子路径长度问题

实现过程中发现：同一次 stroke 里的半透明重叠通常只着色一次，但**单条子路径超过约 256 段后，相隔较远的线段交叉处会重复着色**。本机用 alpha 0.5 描一条两段交叉的子路径：两条交叉线各 120 段（整条子路径约 241 段）时交叉处 alpha 为 128，各 140 段（约 281 段）时为 192，各 1000 段时为 240；把两条线拆成两条子路径，则始终是 128。

这会带来两个问题：

- 原实现下，长的半透明轨迹交叉处会比短轨迹更深；默认的不透明轨迹看不出区别。
- 分段描边后，交叉处的颜色会取决于脏区域怎样切分轨迹，重绘时可能出现接缝。

因此现在每条子路径最多 128 段，段与段之间用圆头衔接，几何上与圆角连接完全等价。所有重绘都按并集着色，交叉处始终只着色一次。

### 内存峰值排查

#### 线上进程快照

对正在运行的 0.3.0（已运行 2 天 5 小时）用 `footprint`、`vmmap`、`heap`、`leaks` 检查：

- footprint 77.8 MB，**生命周期峰值 772.3 MB**。
- 存活的堆分配共 34.9 MB；另有 19.7 MB（37%）是碎片，即已释放但与存活对象共用页面、还不回系统的空间。物理内存里只有约 11 MB，其余约 44 MB 已被系统压缩或换出。
- `leaks` 只报告约 20 KB，全部来自系统 XPC 连接（`LNDaemonApplicationInterface`）的循环引用，与 GestureFlow 代码无关。
- 只有 1 个 `NSPanel` / `GestureOverlayView` / `GestureFeedbackCardView`（当时是单屏），说明屏幕变化后重建浮层不会泄漏。
- 最大的一项是 20.9 MB 没有类型信息的缓冲区。进程启动时没有开启 MallocStackLogging，无法归因。

注意：这些工具扫描期间会暂停目标进程（`heap` 约 8 s），手势 tap 也会一起暂停。

#### 受控测试

新增的 `MemoryFootprintProbeTests` 默认跳过，用下面的命令运行：

```sh
GESTUREFLOW_MEMORY_PROBE=1 swift test --filter MemoryFootprintProbeTests
```

它会在屏幕上显示真实的浮层和设置窗口，并打印各阶段的 footprint 和峰值。建议两个测试分开跑，这样每个阶段的峰值互不干扰。单块 1728×1117@2x 屏幕上的结果（一个整屏 RGBA 缓冲约 29.5 MB）：

| 阶段 | footprint |
| --- | --- |
| 浮层创建完、未显示 | 20 MB |
| 第一次手势开始，轨迹为空 | 72 MB |
| 画完轨迹（每 8 个采样强制重绘一次） | 328 MB，约 10 个整屏缓冲 |
| 之后的手势 | 维持在约 328 MB；开启液态玻璃只多约 2–3 MB |
| 空闲 5 s 后 | 94 MB |

| 阶段 | footprint |
| --- | --- |
| 设置窗口打开前 | 6 MB |
| 通用页 | 40 MB |
| 高级页 | 186 MB（单这一页 +146 MB） |
| 手势页 / 关于页 | 198 MB / 202 MB，峰值 209 MB |
| 关闭窗口后空闲 5 s | 68 MB |

#### 结论

- 峰值的主要来源是**全屏、由 CPU 绘制的浮层图层**：频繁局部重绘时会累积多份整屏大小的后备缓冲，每块 2x 屏幕临时多占约 300 MB，空闲一段时间后才部分释放。外接 4K 屏加内建屏两块叠加约 620 MB，基本能解释 772 MB 的峰值。
- 设置窗口会带来约 200 MB 的临时峰值，主要来自高级页，关闭后大部分会释放。
- 以上都与这次的 CPU 优化无关；浮层的内存问题在 0.3.0 里就存在。

### 后续待办

- 浮层轨迹改用矢量图层（`CAShapeLayer`），或只覆盖轨迹范围的绘制图层，避免整屏后备缓冲。这是降低内存峰值最有效的方式。
- 用 Instruments（Allocations / VM Tracker）定位设置高级页的 +146 MB。
- 需要归因那 20.9 MB 无类型缓冲区时，用 MallocStackLogging 启动进程后再抓取。
- 跨 App 的激活和快捷键投递无法自动测试：自动测试会切走当前应用。改动后需要手动验证：在"光标下的 App"模式下对后台窗口画手势，确认目标窗口被置前、快捷键生效。

### 防回归规则

- tap 回调里不要做慢操作，也不要空转 run loop。激活、LaunchServices、AX 这类可能阻塞的调用必须放到回调返回之后（CLAUDE.md "Do NOT" 第 10 条）。
- 不要在调用 `activate()` 之后立刻同步判断是否已经激活：`NSWorkspace.frontmostApplication`、`NSRunningApplication.isActive` 这类属性要等主 run loop 转一圈才会更新。需要等待时，监听激活通知并设置超时。
- 新增 AX 调用前先调用 `AccessibilityMessaging.applyTimeout()`。
- 普通右键不应触发目标解析：在右键升级为手势之前，不要访问 `GestureActivation.target`。
- 每个采样的工作量不能随手势长度增长：实时识别用 `IncrementalGestureRecognizer`，不要对全部点重新识别；浮层绘制只处理脏区域附近的内容。
- 轨迹子路径保持在 128 段以内（`GestureOverlayView.maximumSegmentsPerSubpath`），否则半透明交叉处的颜色会随脏区域切分而变化。
- 性能数据以 release 构建为准（`swift test -c release -Xswiftc -enable-testing`）。

### 测试

新增测试：

- `GestureActivationGateTests`：忽略列表为空时，直到第一次访问才解析目标，且只解析一次。
- `MouseEventTapTests`：普通右键不解析目标；拖动升级为手势时只解析一次，并把目标传给 `onGestureBegan`。
- `GestureEngineTests`：投递要等调度的完成回调执行；使用的是松手时捕获的目标，即使下一个手势已经开始。
- `ActionExecutorTests`：
  - 激活前不置前窗口、不发送快捷键；
  - 目标已在前台时直接发送；
  - `WorkspaceActivationWaiter` 收到目标激活通知时只投递一次、忽略其他 App、超时后照常投递。
- `GestureRecognizerTests`：随机路径（屏幕 / 视图两种坐标系）下，增量识别与批量识别逐前缀完全一致。
- `GestureOverlayWindowTests`：半透明、自交叉、超过 256 段的轨迹，局部重绘与全量重绘的像素一致。
- `MemoryFootprintProbeTests`：可选运行的内存诊断，见上文。

验证结果：`swift test` 共 303 个测试全部通过（2 个诊断测试跳过）；`xcodebuild test` 通过。

### 相关文件

- [GestureEngine.swift](../Sources/GestureFlowApp/Engine/GestureEngine.swift)
- [ActionExecutor.swift](../Sources/GestureFlowApp/Actions/ActionExecutor.swift)
- [MouseEventTap.swift](../Sources/GestureFlowApp/EventTap/MouseEventTap.swift)
- [GestureActivationGate.swift](../Sources/GestureFlowApp/Target/GestureActivationGate.swift)
- [GestureTargetApplicationResolver.swift](../Sources/GestureFlowApp/Target/GestureTargetApplicationResolver.swift)
- [GestureOverlayView.swift](../Sources/GestureFlowApp/Overlay/GestureOverlayView.swift)
- [GestureRecognizer.swift](../Sources/GestureFlowCore/Recognition/GestureRecognizer.swift)
- [MemoryFootprintProbeTests.swift](../Tests/GestureFlowAppTests/MemoryFootprintProbeTests.swift)
