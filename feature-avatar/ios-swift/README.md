# iOS Swift Avatar Agent Starter

本示例展示如何在 Conversational AI 中集成 **数字人 Avatar** 功能，实现带有虚拟形象的实时对话交互。

> **工程启动指引**：请先参考 [ios-swift 工程 README](../../ios-swift/README.md) 完成基础配置和环境搭建。

## Demo 效果

- 默认状态：右上角小窗口显示数字人
- 点击放大窗口，再次点击收起成小窗
- 数字人会根据 AI 回复实时做出表情和口型动作

---

## 1. 代码新增的调用

相比基础版本，Avatar 示例新增了以下主要代码：

### 新增属性

```swift
// Avatar UID 和 Token
private var avatarToken: String = ""
private let avatarUid = Int.random(in: 10000000...99999999)

// 远端视频视图
private let remoteView = UIView()
```

### 新增方法

```swift
// 生成 Avatar Token
private func generateAvatarToken() async throws {
    NetworkManager.shared.generateToken(channelName: channel, uid: "\(avatarUid)", types: [.rtc]) { token in
        self.avatarToken = token
    }
}

// 设置远端视频画布
private func setupRemoteVideo() {
    let videoCanvas = AgoraRtcVideoCanvas()
    videoCanvas.uid = UInt(avatarUid)
    videoCanvas.view = remoteView
    videoCanvas.renderMode = .fit
    rtcEngine.setupRemoteVideo(videoCanvas)
}
```

### 连接流程变更

```swift
// 原有步骤 1-5...
try await generateAgentToken()

// 新增步骤：生成 Avatar Token
try await generateAvatarToken()

// 启动 Agent
try await startAgent()
```

---

## 2. 请求新增的参数

启动 Agent 的请求体新增 `avatar` 参数：

```json
{
  "name": "channel_name",
  "pipeline_id": "your_pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "agent_uid",
    "remote_rtc_uids": ["user_uid"],  // ⚠️ Avatar 模式不支持 ["*"]
    "token": "agent_token",
    "avatar": {
      "params": {
        "agora_token": "avatar_token",
        "agora_uid": "avatar_uid"
      }
    }
  }
}
```

**注意事项**：
- `remote_rtc_uids`：启用 Avatar 时必须指定具体的用户 UID，不能使用通配符 `["*"]`
- `avatar.params.agora_uid`：Avatar 的 RTC UID，用于视频渲染
- `avatar.params.agora_token`：Avatar 加入频道的 Token

---

## 3. Pipeline 新增的配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，需要额外配置 Avatar 模块：

1. 进入 Pipeline 编辑页面
2. 打开`数字人设置`选项
3. 打开`启用数字人`
4. 配置
5. 保存并发布 Pipeline
