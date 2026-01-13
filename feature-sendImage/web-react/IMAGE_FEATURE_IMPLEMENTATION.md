# 前端图片发送功能实现说明

## 概述

此功能实现了与iOS端相同的图片发送能力，允许用户在Web端发送图片URL给AI Agent。

## 实现的功能

### 1. 图片发送
- 用户可以在输入框中输入图片URL
- 点击"发送图片"按钮发送图片
- 支持三种状态：发送中、发送成功、发送失败
- 默认图片URL：`http://e.hiphotos.baidu.com/image/pic/item/a1ec08fa513d2697e542494057fbb2fb4316d81e.jpg`

### 2. 状态管理
- **发送中 (sending)**: 图片正在上传，显示蓝色文字"发送中..."
- **发送成功 (success)**: 收到服务器确认，显示绿色文字"发送成功"
- **发送失败 (failed)**: 发送失败或服务器返回错误，显示红色文字"发送失败"

### 3. UI展示
- 图片消息显示在对话列表中
- 用户头像显示为绿色圆形，标注"我"
- 图片尺寸：200px × 150px，圆角8px
- 图片加载失败时显示灰色占位符

## 代码修改

### 1. MainView.jsx

#### 新增状态
```javascript
const [imageMessages, setImageMessages] = useState({}) // 存储图片消息状态
```

#### 新增sendImage方法
```javascript
const sendImage = async () => {
  const imageUrl = inputText.trim()
  const uuid = `img-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  
  const message = {
    messageType: EChatMessageType.IMAGE,
    uuid: uuid,
    url: imageUrl
  }
  
  // 发送图片并更新状态
  await convoAIAPIRef.current.chat(String(agentUid.current), message)
}
```

#### 事件监听
- `MESSAGE_RECEIPT_UPDATED`: 监听图片上传成功回执
- `MESSAGE_ERROR`: 监听图片上传失败错误

#### UI组件
- `ImageMessageRow`: 新增图片消息展示组件
- `InputContainer`: 修改为图片输入模式，按钮文字改为"发送图片"
- `TranscriptScrollView`: 合并显示文本消息和图片消息

### 2. chat-view.css

新增样式：
```css
.transcript-content.image-content { /* 图片内容容器 */ }
.message-image { /* 图片样式 */ }
.image-status { /* 状态文字样式 */ }
.send-button.send-image-button { /* 发送按钮宽度调整 */ }
```

### 3. conversational-ai-api/utils/sub-render.ts

修复bug：
```typescript
// 修复前
const messageType = message?.resource_type === 'picture'

// 修复后
const messageType = messageObj?.resource_type === 'picture'
```

## 与iOS端的对应关系

| iOS 实现 | Web 实现 | 说明 |
|---------|---------|------|
| `sendImage(imageUrl:)` | `sendImage()` | 发送图片方法 |
| `ImageMessage` | `IChatMessageImage` | 图片消息类型 |
| `ImageMessageItem` | `imageMessages[uuid]` | 图片消息状态 |
| `ImageMessageStatus` | `'sending'\|'success'\|'failed'` | 图片状态枚举 |
| `onMessageReceiptUpdated` | `MESSAGE_RECEIPT_UPDATED` | 消息回执事件 |
| `TranscriptCell` | `ImageMessageRow` | 图片消息UI组件 |

## 消息流程

1. 用户输入图片URL，点击"发送图片"
2. 生成唯一UUID，创建图片消息对象
3. 通过RTM发送消息（customType: "image.upload"）
4. 本地状态更新为"发送中"
5. 服务器处理后返回message.info消息
6. 前端收到MESSAGE_RECEIPT_UPDATED事件
7. 根据UUID更新对应图片消息状态为"成功"
8. 如果发生错误，收到MESSAGE_ERROR事件，更新状态为"失败"

## 消息格式

### 发送的RTM消息
```json
{
  "uuid": "img-1234567890-abc123def",
  "image_url": "http://example.com/image.jpg",
  "image_base64": ""
}
```

### 服务器返回的回执（message.info）
```json
{
  "object": "message.info",
  "module": "context",
  "turn_id": 123,
  "message": "{\"uuid\":\"img-xxx\",\"resource_type\":\"picture\"}"
}
```

## 测试建议

1. 测试正常发送图片
2. 测试图片加载失败的情况
3. 测试网络错误的情况
4. 测试快速连续发送多张图片
5. 验证图片消息与文本消息的排序

## 已知限制

1. 目前只支持图片URL，不支持上传本地文件
2. 图片尺寸固定为200×150，不支持自适应
3. 没有图片预览功能
4. 没有图片格式验证

## 未来改进方向

1. 支持本地图片文件上传
2. 支持base64编码的图片
3. 添加图片预览功能
4. 支持图片压缩
5. 添加图片格式和大小验证
6. 支持图片点击放大查看

