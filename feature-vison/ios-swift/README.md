# iOS Swift Vision Agent Starter

本示例展示如何在 Conversational AI 中集成 **视觉理解 Vision** 功能，实现 AI 对本地摄像头画面的实时理解和分析。

> **工程启动指引**：请先参考 [ios-swift 工程 README](../../ios-swift/README.md) 完成基础配置和环境搭建。

## Demo 效果

- 默认状态：右上角小窗口显示本地摄像头画面
- 点击放大窗口，再次点击收起成小窗
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
```

### 连接流程变更

```swift
// joinRTCChannel 中启用摄像头发布
let options = AgoraRtcChannelMediaOptions()
options.publishCameraTrack = true  // 开启摄像头视频流
options.autoSubscribeVideo = false  // 无需订阅远端视频
```

---

## 2. 请求新增的参数

Vision 功能**无需修改**启动 Agent 的请求参数，仅需在 Pipeline 中配置视觉理解模块。

请求体与基础版本相同：

```json
{
  "name": "channel_name",
  "pipeline_id": "your_pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "agent_uid",
    "remote_rtc_uids": ["*"],
    "token": "agent_token"
  }
}
```

---

## 3. Pipeline 新增的配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，需要配置视觉理解模块：

1. 进入 Pipeline 编辑页面
2. 打开`视觉设置`选项
3. 打开`启用视觉理解`
4. 配置视觉参数（如识别间隔、分辨率等）
5. 保存并发布 Pipeline
