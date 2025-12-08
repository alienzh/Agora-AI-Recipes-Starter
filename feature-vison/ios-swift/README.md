# iOS Swift Vision Agent Starter

本示例展示如何在 Conversational AI 中集成 **视觉理解 Vision** 功能，实现 AI 对本地摄像头画面的实时理解和分析。

> **工程启动指引**：请先参考 [ios-swift 工程 README](../../ios-swift/README.md) 完成基础配置和环境搭建。

## 权限要求

Vision 功能需要**摄像头权限**，在 `Info.plist` 中配置：

```xml
<key>NSCameraUsageDescription</key>
<string>App needs camera access for AI vision understanding</string>
```

## Demo 效果

- 默认状态：右上角小窗口显示本地摄像头画面
- 点击放大窗口，再次点击收起成小窗
- 点击视频开关按钮（挂断按钮右侧）可开关摄像头和视频流
- AI 可以实时理解摄像头拍摄的内容并进行对话

---

## 1. 代码新增的调用

相比基础版本，Vision 示例新增了以下主要代码：

### 新增属性

```swift
// 本地视频视图
private let localView = UIView()
private let localViewSmallSize = CGSize(width: 90, height: 120)
private var isLocalViewExpanded: Bool = false
private var isCameraOn: Bool = true
```

### 新增方法

```swift
// 设置本地视频预览
private func setupLocalVideo() {
    rtcEngine.startPreview()
    
    let videoCanvas = AgoraRtcVideoCanvas()
    videoCanvas.uid = 0  // 0 for local user
    videoCanvas.view = localView
    videoCanvas.renderMode = .hidden
    rtcEngine.setupLocalVideo(videoCanvas)
}

// 切换摄像头开关
@objc private func toggleVideo() {
    isCameraOn.toggle()
    if isCameraOn {
        rtcEngine?.startPreview()
        rtcEngine?.muteLocalVideoStream(false)
    } else {
        rtcEngine?.stopPreview()
        rtcEngine?.muteLocalVideoStream(true)
    }
}
```

### 连接流程变更

```swift
// joinRTCChannel 中启用摄像头发布
let options = AgoraRtcChannelMediaOptions()
options.publishCameraTrack = true  // 开启摄像头视频流
options.autoSubscribeVideo = false  // 无需订阅远端视频
```

### UI 新增组件

在 `ChatBackgroundView` 中新增了视频开关按钮：

```swift
let videoToggleButton = UIButton(type: .system)
// 放置在挂断按钮右侧
```

---

## 2. Pipeline 新增的配置

未知
TODO：支持Vison功能的条件

