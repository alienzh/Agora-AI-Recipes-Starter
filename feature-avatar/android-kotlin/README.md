# Android Kotlin Avatar Agent Starter

本示例展示如何在 Conversational AI 中集成 **数字人 Avatar** 功能，实现带有虚拟形象的实时对话交互。

> **工程启动指引**：请先参考 [android-kotlin 工程 README](../../android-kotlin/README.md) 完成基础配置和环境搭建。

## Demo 效果

- 默认状态：右上角小窗口显示数字人
- 点击放大窗口，再次点击收起成小窗
- 数字人会根据 AI 回复实时做出表情和口型动作

---

## 1. 代码新增的调用

相比基础版本，Avatar 示例新增了以下主要代码：

### 新增属性

```kotlin
// Avatar UID and Token
private val avatarUid: Int = (10000000..99999999).random()
private var avatarToken: String? = null

// Avatar joined state
private val _avatarJoined = MutableStateFlow(false)
val avatarJoined: StateFlow<Boolean> = _avatarJoined.asStateFlow()
```

### 新增方法

```kotlin
// Generate Avatar Token
private suspend fun generateAvatarToken(): String? {
    val tokenResult = TokenGenerator.generateTokensAsync(
        channelName = channelName,
        uid = avatarUid.toString(),
        tokenTypes = arrayOf(AgoraTokenType.Rtc)
    )
    return tokenResult.fold(
        onSuccess = { token ->
            avatarToken = token
            token
        },
        onFailure = { exception ->
            null
        }
    )
}

// Setup remote video canvas for Avatar display
fun setupRemoteVideo(surfaceView: SurfaceView) {
    val videoCanvas = VideoCanvas(surfaceView, VideoCanvas.RENDER_MODE_FIT, avatarUid)
    rtcEngine?.setupRemoteVideo(videoCanvas)
}
```

### 连接流程变更

```kotlin
// 原有步骤 1-5...
val agentToken = generateAgentToken()

// 新增步骤：生成 Avatar Token
val avatarTokenValue = generateAvatarToken()

// 创建 Avatar 配置
val avatarConfig = AgentStarter.AvatarConfig(
    avatarUid = avatarUid.toString(),
    avatarToken = avatarTokenValue
)

// 启动 Agent（带 Avatar 参数）
AgentStarter.startAgentAsync(
    channelName = channelName,
    agentRtcUid = agentUid.toString(),
    token = agentToken,
    userUid = userId.toString(),
    avatarConfig = avatarConfig
)
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

## 3. UI 新增的功能

### 布局新增

```xml
<!-- Avatar Video Container (Small) - Top Right -->
<com.google.android.material.card.MaterialCardView
    android:id="@+id/cardAvatarSmall"
    android:layout_width="120dp"
    android:layout_height="160dp"
    android:visibility="gone">
    <FrameLayout android:id="@+id/avatarContainerSmall" />
</com.google.android.material.card.MaterialCardView>

<!-- Avatar Video Container (Full Screen) -->
<com.google.android.material.card.MaterialCardView
    android:id="@+id/cardAvatarFull"
    android:visibility="gone">
    <FrameLayout android:id="@+id/avatarContainerFull" />
</com.google.android.material.card.MaterialCardView>
```

### 交互逻辑

- 点击小窗口可放大至全屏
- 再次点击收起成小窗口
- Avatar 加入频道后自动显示视频

---

## 4. Pipeline 新增的配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，需要额外配置 Avatar 模块：

1. 进入 Pipeline 编辑页面
2. 打开`数字人设置`选项
3. 打开`启用数字人`
4. 配置
5. 保存并发布 Pipeline

---

## 5. 项目结构变更

相比基础版本，Avatar 示例主要修改了以下文件：

```
feature-avatar/android-kotlin/
├── app/src/main/java/io/agora/convoai/example/startup/
│   ├── api/
│   │   └── AgentStarter.kt          # 新增 AvatarConfig 和 avatar 参数支持
│   └── ui/
│       ├── AgentChatActivity.kt     # 新增 Avatar 视频显示和交互逻辑
│       └── AgentChatViewModel.kt    # 新增 avatarUid/avatarToken 和 setupRemoteVideo
├── app/src/main/res/layout/
│   └── activity_agent_chat.xml      # 新增 Avatar 视频容器
└── README.md                        # 本文档
```

---

## 6. 功能验证清单

- ✅ Avatar Token 生成成功（查看日志区域的状态消息）
- ✅ Avatar 加入频道成功（右上角显示数字人视频）
- ✅ 数字人口型同步正常（说话时嘴型同步）
- ✅ 小窗口/全屏切换正常（点击切换）
- ✅ 停止时正确清理 Avatar 视频
