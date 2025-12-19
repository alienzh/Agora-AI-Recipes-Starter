# Startup Guide 文档说明

> **主要目标用户：AI Agent**  
> 本文档说明 `STARTUP_GUIDE.md` 的用途和在 AI Agent 工作流程中的作用

---

## 📚 文档说明

### STARTUP_GUIDE.md

**主要用户**: AI Agent（项目生成器）  
**在 AI Agent 工作流程中的作用**: 多平台项目生成的主入口和流程指南  

**内容**:
- ✅ 项目元信息和核心功能映射
- ✅ 平台 SDK 支持检测流程
- ✅ 多平台适配规则和目录结构规范
- ✅ **核心开发流程**（RTC 版本和 RTC+RTM 版本）
- ✅ UI 组件规范（描述性，无代码）
- ✅ **Agora MCP 工具使用指南**
- ✅ 生成规则和验证规则
- ✅ Agent 使用说明

**AI Agent 使用方式**:
1. 读取项目元信息，确定要生成的项目类型和目标平台
2. 使用 MCP 工具查询平台 SDK 支持情况
3. 根据目录结构规范创建文件夹
4. 根据核心开发流程，使用 MCP 工具查询具体 API 实现
5. 根据生成规则验证生成结果

**重要特点**:
- **无代码示例**：所有实现细节通过 MCP 工具获取
- **流程导向**：专注于指导 AI Agent 的生成流程
- **多平台支持**：不局限于某个平台，支持 React Native、Flutter、Android、iOS、HarmonyOS、Web、Unity 等所有平台
- **动态 SDK 集成**：根据平台 SDK 支持情况，自动选择 RTC 或 RTC+RTM 方案

---

## 🎯 AI Agent 使用建议

### AI Agent 工作流程：

1. **项目生成阶段**：
   - 📖 读取 `STARTUP_GUIDE.md`
   - 🔍 使用 MCP 工具查询目标平台的 SDK 支持情况
   - 🎯 根据项目元信息确定项目类型和集成方案
   - 📁 根据目录结构规范创建文件夹
   - 📝 根据核心开发流程，使用 MCP 工具查询具体 API 实现

2. **代码实现阶段**：
   - 🔧 对于每个 API 调用，使用 MCP 工具查询具体实现方式
   - ✅ 确保生成的代码符合项目结构规范
   - ✅ 确保业务逻辑符合核心开发流程
   - ✅ 确保错误处理符合错误处理规范

3. **代码优化阶段**：
   - 📖 参考 `STARTUP_GUIDE.md` 的安全注意事项
   - ✅ 确保代码符合生产环境要求

### MCP 工具使用原则：

1. **所有 API 调用**：必须通过 MCP 工具查询确认
2. **所有事件格式**：必须通过 MCP 工具查询确认
3. **所有消息格式**：必须通过 MCP 工具查询确认
4. **不要假设**：不要假设 API 名称或参数格式，必须查询文档

---

## 👥 人类开发者使用说明

虽然本文档主要供 AI Agent 使用，但人类开发者也可以参考：

- **STARTUP_GUIDE.md**: 了解多平台项目生成流程和架构设计

---

## 📝 文档维护（针对 AI Agent）

### 文档更新原则：

- **STARTUP_GUIDE.md**: 
  - 当需要更新流程或生成规则时修改
  - 当需要添加新的平台支持时修改
  - 当项目结构发生变化时修改
  - 当 MCP 工具使用方式变化时修改

### 重要原则：

- **无代码原则**：文档不包含具体代码示例，只提供流程、规则和 MCP 工具使用指南
- **MCP 工具导向**：所有实现细节都通过 MCP 工具获取，确保使用最新的 API 文档
- **多平台通用**：文档适用于所有平台，不针对特定平台
- **动态集成**：根据平台 SDK 支持情况，动态选择 RTC 或 RTC+RTM 方案

---

## 🔧 Agora MCP 工具说明

### 工具列表

1. **search-docs**：搜索文档内容
   - 用途：查找特定 API 或功能的文档
   - 示例：`search-docs: "[平台] RTC joinChannel"`

2. **list-docs**：列出文档列表
   - 用途：查看所有可用文档
   - 示例：`list-docs: category="RTC SDK"`

3. **get-doc-content**：获取文档具体内容
   - 用途：获取详细文档内容
   - 示例：`get-doc-content: uri="doc/rtc/[平台]/joinChannel"`

### MCP 服务器

- **服务器地址**：`https://doc-mcp.shengwang.cn/mcp`
- **文档范围**：Agora RTC SDK、RTM SDK、Conversational AI API 等所有官方文档

### 使用原则

- **必须使用**：所有 API 调用、事件格式、消息格式都必须通过 MCP 工具查询
- **不要假设**：不要假设 API 名称或参数格式
- **查询最新**：始终查询最新的文档，不要依赖文档中的描述
- **平台特定**：查询时明确指定平台名称，如 "React Native RTC"、"Flutter RTM" 等

---

## 📚 支持的平台

| 平台 | RTC SDK | RTM SDK | 集成方案 |
|------|---------|---------|----------|
| React Native | ✅ | ❌ | RTC + RTC DataStream |
| Flutter | ✅ | ✅ | RTC + RTM |
| Android (Kotlin) | ✅ | ✅ | RTC + RTM |
| iOS (Swift) | ✅ | ✅ | RTC + RTM |
| HarmonyOS | ✅ | ❌ | RTC + RTC DataStream |
| Web | ✅ | ✅ | RTC + RTM |
| Unity | ✅ | ✅ | RTC + RTM |

**注意**：上表仅供参考，实际生成时必须通过 MCP 工具查询最新支持情况。

---

**最后更新**: 2025-12-03
