# Android Kotlin Vision Agent Starter

本示例展示如何在 Conversational AI 中集成 **视觉理解 Vision** 功能，实现 AI 对本地摄像头画面的实时理解和分析。

> **工程启动指引**：请先参考 [android-kotlin 工程 README](../../android-kotlin/README.md) 完成基础配置和环境搭建。

## 权限要求

Vision 功能需要**摄像头权限**，在 `AndroidManifest.xml` 中配置：

```xml
<uses-permission android:name="android.permission.CAMERA" />

<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
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

```kotlin
// 本地视频视图
private var localVideoView: View? = null
private var isLocalViewExpanded: Boolean = false
private var isCameraOn: Boolean = true
```

### 新增方法

```kotlin
// 设置本地视频预览
fun setupLocalVideo(view: View)

// 切换摄像头开关
fun toggleVideo()

// 切换本地视频视图大小（展开/收起）
private fun toggleLocalViewSize()
```

### 连接流程变更

```kotlin
// joinRtcChannel 中启用摄像头发布
val channelOptions = ChannelMediaOptions().apply {
    publishCameraTrack = true   // 开启摄像头视频流
    autoSubscribeVideo = false  // 无需订阅远端视频
}
```

### UI 新增组件

在 `activity_agent_chat.xml` 中新增了视频开关按钮：

```xml
<!-- 本地视频预览窗口 -->
<com.google.android.material.card.MaterialCardView
    android:id="@+id/localVideoContainer"
    ...>
    <SurfaceView android:id="@+id/localVideoView" />
</com.google.android.material.card.MaterialCardView>

<!-- 视频开关按钮，放置在挂断按钮右侧 -->
<androidx.appcompat.widget.AppCompatImageButton
    android:id="@+id/btnVideo"
    app:srcCompat="@drawable/ic_video_on" />
```

---

## 2. Pipeline 新增的配置

未知
TODO：支持Vison功能的条件
