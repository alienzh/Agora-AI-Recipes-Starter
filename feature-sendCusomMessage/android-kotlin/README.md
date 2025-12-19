# Android Kotlin Send Custom Message Agent Starter

本示例展示如何在 Conversational AI 中集成 **发送自定义文本消息** 功能，实现通过文本输入框向 AI Agent 发送消息。

> **工程启动指引**：请先参考 [android-kotlin 工程 README](../../android-kotlin/README.md) 完成基础配置和环境搭建。

## Demo 效果

- 连接 Agent 后，底部显示文本输入框和发送按钮
- 支持通过键盘输入文本消息
- 点击键盘上的"发送"按钮或按 Enter 键发送消息
- 发送的消息会实时显示在转录列表中
- 键盘弹起时自动调整布局，确保输入框可见

---

## 1. 代码新增的调用

相比基础版本，发送自定义消息示例新增了以下主要代码：

### 新增方法

```kotlin
// Send text message to agent
fun sendTextMessage(message: String?) {
    if (_uiState.value.connectionState != ConnectionState.Connected) {
        Log.w(TAG, "Cannot send message: not connected to agent")
        return
    }

    val text = message?.trim()
    if (text.isNullOrEmpty()) {
        Log.w(TAG, "Cannot send message: message is empty")
        return
    }

    val chatMessage = TextMessage(
        priority = Priority.APPEND,
        responseInterruptable = true,
        text = text
    )

    conversationalAIAPI?.chat(
        agentUid.toString(),
        chatMessage
    ) { error: ConversationalAIAPIError? ->
        if (error != null) {
            Log.e(TAG, "Send message failed: ${error.message}")
            addStatusLog("Send message failed: ${error.message}")
        } else {
            Log.d(TAG, "Message sent successfully: $text")
            addStatusLog("Message sent successfully")
        }
    }
}
```

### UI 交互逻辑

```kotlin
// Send message from input field
private fun sendMessage() {
    mBinding?.etMessage?.let { editText ->
        val message = editText.text?.toString()
        if (!message.isNullOrBlank()) {
            viewModel.sendTextMessage(message)
            editText.text?.clear()
            // Hide keyboard after sending
            hideKeyboard(editText)
        }
    }
}

// Listen for keyboard enter key and send button
etMessage.setOnEditorActionListener { _, actionId, event ->
    if (actionId == EditorInfo.IME_ACTION_SEND ||
        (event != null && event.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN)
    ) {
        sendMessage()
        true
    } else {
        false
    }
}
```

---

## 2. API 调用说明

发送文本消息使用 Conversational AI API 的 `chat` 方法：

```kotlin
conversationalAIAPI?.chat(
    agentUid.toString(),
    TextMessage(
        priority = Priority.APPEND,        // 消息优先级：追加到队列
        responseInterruptable = true,       // 是否可中断 Agent 当前回复
        text = "Your message text"         // 消息文本内容
    )
) { error: ConversationalAIAPIError? ->
    // 处理发送结果
}
```

**参数说明**：
- `priority`：消息优先级，可选值：
  - `Priority.APPEND`：追加到队列末尾（默认）
  - `Priority.INTERRUPT`：中断当前回复，立即处理此消息
- `responseInterruptable`：是否允许中断 Agent 的当前回复
- `text`：要发送的文本消息内容

---

## 3. 项目结构变更

相比基础版本，发送自定义消息示例主要修改了以下文件：

```
feature-sendCusomMessage/android-kotlin/
├── app/src/main/java/io/agora/convoai/example/startup/
│   └── ui/
│       ├── AgentChatActivity.kt     # 新增输入框 UI 和发送逻辑
│       └── AgentChatViewModel.kt   # 新增 sendTextMessage 方法
├── app/src/main/res/layout/
│   └── activity_agent_chat.xml     # 新增文本输入框布局
└── README.md                        # 本文档
```

**主要修改说明**：
- `AgentChatViewModel.kt`：新增 `sendTextMessage()` 方法，调用 Conversational AI API 发送文本消息
- `AgentChatActivity.kt`：新增输入框 UI 交互逻辑，包括键盘处理、发送按钮监听等
- `activity_agent_chat.xml`：新增底部输入框容器和文本输入组件

---

## 4. 功能验证清单

- ✅ 连接 Agent 后显示文本输入框
- ✅ 键盘弹起时输入框可见（自动调整布局）
- ✅ 键盘发送按钮功能正常
- ✅ Enter 键发送功能正常
- ✅ 发送消息成功（查看日志区域的状态消息）
- ✅ 发送的消息显示在转录列表中
- ✅ Agent 能够接收并回复文本消息
- ✅ 发送后输入框自动清空
- ✅ 键盘自动隐藏

---

## 相关资源

### API 文档链接

- [Conversational AI Android 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/android/android-component/overview)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)

---
