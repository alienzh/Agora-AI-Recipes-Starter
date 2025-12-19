# Android Kotlin Send Image Message Agent Starter

本示例展示如何在 Conversational AI 中集成 **发送图片消息** 功能，实现通过图片 URL 向 AI Agent 发送图片消息。

> **重要提示**：使用图片消息功能需要确保 Agent 配置的 LLM 支持视觉理解（Vision）能力，能够理解和分析图片内容。如果 LLM 不支持视觉理解，图片消息可能无法被正确处理。

> **工程启动指引**：请先参考 [android-kotlin 工程 README](../../android-kotlin/README.md) 完成基础配置和环境搭建。

## Demo 效果

- 连接 Agent 后，底部显示图片 URL 输入框
- 输入框默认填充示例图片 URL，用户可以修改为自定义图片 URL
- 支持通过键盘输入图片 URL
- 点击键盘上的"发送"按钮或按 Enter 键发送消息
- 发送的图片会实时显示在转录列表中（使用 Glide 加载图片）
- 图片消息发送成功后，在 `onMessageReceiptUpdated` 回调中处理
- 图片消息发送失败时，在 `onMessageError` 回调中处理并显示错误提示

---

## 1. 代码新增的调用

相比基础版本，发送图片消息示例新增了以下主要代码：

### 新增方法

```kotlin
// Send image message to agent
fun sendImageMessage(
    uuid: String,
    imageUrl: String? = null,
    imageBase64: String? = null,
    completion: (error: ConversationalAIAPIError?) -> Unit
) {
    if (_uiState.value.connectionState != ConnectionState.Connected) {
        Log.w(TAG, "Cannot send image message: not connected to agent")
        completion.invoke(ConversationalAIAPIError.UnknownError("Please connect to agent first"))
        return
    }

    // Clear previous error for this uuid if exists
    val resourceError = _resourceError.value
    if ((resourceError is PictureError) && resourceError.uuid == uuid) {
        _resourceError.value = null
    }

    val imageMessage = ImageMessage(
        uuid = uuid,
        imageUrl = imageUrl,
        imageBase64 = imageBase64
    )

    conversationalAIAPI?.chat(agentUid.toString(), imageMessage) { error: ConversationalAIAPIError? ->
        if (error != null) {
            Log.e(TAG, "Send image message failed: ${error.message}")
            addStatusLog("Send image message failed: ${error.message}")
        } else {
            Log.d(TAG, "Image message sent successfully: uuid=$uuid")
            addStatusLog("Image message sent successfully")
        }
        completion.invoke(error)
    }
}
```

### 图片消息成功/失败回调处理

```kotlin
// Handle image message success in onMessageReceiptUpdated
override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
    if (receipt.type == ModuleType.Context && receipt.chatMessageType == ChatMessageType.Image) {
        // ... parse JSON and create PictureInfo
        _mediaInfoUpdate.value = pictureInfo
    }
}

// Handle image message error in onMessageError
override fun onMessageError(agentUserId: String, error: MessageError) {
    if (error.chatMessageType == ChatMessageType.Image) {
        // ... parse JSON and create PictureError
        _resourceError.value = pictureError
    }
}
```

---

## 2. API 调用说明

发送图片消息使用 Conversational AI API 的 `chat` 方法：

```kotlin
conversationalAIAPI?.chat(
    agentUid.toString(),
    ImageMessage(
        uuid = "img_123",                    // 图片消息的唯一标识符（必需）
        imageUrl = "https://example.com/image.jpg",  // 图片 URL（与 imageBase64 二选一）
        imageBase64 = null                   // Base64 编码的图片数据（与 imageUrl 二选一，限制 32KB）
    )
) { error: ConversationalAIAPIError? ->
    // 处理发送结果
}
```

**参数说明**：
- `uuid`：图片消息的唯一标识符（必需），用于追踪消息状态
- `imageUrl`：HTTP/HTTPS 图片 URL（推荐用于大图片）
- `imageBase64`：Base64 编码的图片数据（注意：总消息大小需小于 32KB，受 RTM 消息通道限制）

**重要提示**：
- **LLM 支持要求**：使用图片消息功能需要确保 Agent 配置的 LLM 支持视觉理解（Vision）能力，能够理解和分析图片内容。如果 LLM 不支持视觉理解，图片消息可能无法被正确处理
- 使用 `imageBase64` 时，确保总消息大小（包括 JSON 结构）小于 32KB
- 对于大图片，建议使用 `imageUrl` 方式
- 图片发送成功会在 `onMessageReceiptUpdated` 回调中返回 `PictureInfo`
- 图片发送失败会在 `onMessageError` 回调中返回 `PictureError`

---

## 3. 项目结构变更

相比基础版本，发送图片消息示例主要修改了以下文件：

```
feature-sendImage/android-kotlin/
├── app/src/main/java/io/agora/convoai/example/startup/
│   └── ui/
│       ├── AgentChatActivity.kt          # 新增图片 URL 输入框 UI、发送逻辑、图片显示逻辑
│       └── AgentChatViewModel.kt        # 新增 sendImageMessage、addImageMessageToTranscript 方法
│                                         # 新增 PictureInfo、PictureError 数据类
│                                         # 新增 onMessageReceiptUpdated、onMessageError 回调处理
├── app/src/main/res/layout/
│   ├── activity_agent_chat.xml          # 修改为图片 URL 输入框
│   └── item_transcript_user.xml        # 新增 ImageView，支持图片和文字分开显示
├── app/build.gradle.kts                 # 新增 Glide 依赖
├── gradle/libs.versions.toml            # 新增 Glide 版本定义
└── README.md                            # 本文档
```

**主要修改说明**：
- `AgentChatViewModel.kt`：新增 `sendImageMessage()` 方法，实现图片消息发送和回调处理
- `AgentChatActivity.kt`：修改输入框为图片 URL 输入，新增图片发送逻辑和状态观察，支持图片显示

---

## 4. 功能验证清单

- ✅ 连接 Agent 后显示图片 URL 输入框
- ✅ 输入框默认填充示例图片 URL
- ✅ 用户可以修改输入框中的图片 URL
- ✅ 键盘发送按钮功能正常
- ✅ Enter 键发送功能正常
- ✅ 发送图片成功（查看日志区域的状态消息）
- ✅ 发送的图片显示在转录列表中（使用 Glide 加载）
- ✅ 图片显示时隐藏状态文本（END/IN PROGRESS 等）
- ✅ Agent 能够接收并处理图片消息
- ✅ 图片发送失败时显示错误提示
- ✅ 图片消息直接添加到列表末尾（不按 turnId 排序）

---

## 5. 依赖说明

本示例新增了以下依赖：

```kotlin
// Glide for image loading
implementation(libs.glide)
```

在 `gradle/libs.versions.toml` 中定义：
```toml
glide = "4.16.0"
```

---

## 相关资源

### API 文档链接

- [Conversational AI Android 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/android/android-component/overview)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)

---
