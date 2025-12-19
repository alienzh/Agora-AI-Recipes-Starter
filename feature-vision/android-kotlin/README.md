# Android Kotlin Vision Demo

本示例是配合服务端视觉理解功能的**移动端效果演示 Demo**。

## 启动指引

### 1. 运行移动端 Demo

请先参考 [android-kotlin 工程 README](../../android-kotlin/README.md) 完成基础配置和环境搭建。

### 2. 启动服务端 Vision Agent

在运行移动端 Demo 之前，必须先启动服务端 Vision Agent 脚本

详细的服务端配置和使用方法，请参考 [服务端 README](../server-python/README.md)。

## Demo 效果

- 默认状态：右上角小窗口显示本地摄像头画面（后置摄像头）
- 点击放大窗口，再次点击收起成小窗
- 点击视频开关按钮（挂断按钮右侧）可开关摄像头和视频流
- AI 可以实时理解摄像头拍摄的内容并进行对话

## 注意事项

- 本 Demo 仅用于展示效果，服务端 Vision Agent 需要单独启动
