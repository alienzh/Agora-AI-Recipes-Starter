# Web React

一个基于 React 和 Vite 的前端项目。

## 开始使用

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

### 构建生产版本

```bash
npm run build
```

### 预览生产构建

```bash
npm run preview
```

## 环境变量配置

1. 复制 `.env.example` 文件为 `.env`：

```bash
cp .env.example .env
```

2. 在 `.env` 文件中填写相应的配置值：

```
VITE_AG_APP_ID=your_app_id
VITE_AG_APP_CERTIFICATE=your_certificate
VITE_AG_BASIC_AUTH_KEY=your_auth_key
VITE_AG_BASIC_AUTH_SECRET=your_auth_secret
VITE_AG_PIPELINE_ID=your_pipeline_id
```

3. 在代码中使用环境变量：

```javascript
import { env } from "./config/env";

// 使用配置
const appId = env.AG_APP_ID;
```

**注意**: Vite 要求环境变量必须以 `VITE_` 开头才能暴露给客户端代码。

## 项目结构

```
web-react/
├── src/
│   ├── config/
│   │   └── env.js       # 环境变量配置
│   ├── App.jsx          # 主应用组件
│   ├── App.css          # 应用样式
│   ├── main.jsx         # 入口文件
│   └── index.css        # 全局样式
├── .env.example         # 环境变量示例文件
├── index.html           # HTML 模板
├── vite.config.js       # Vite 配置
└── package.json         # 项目配置
```
