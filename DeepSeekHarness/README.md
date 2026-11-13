# DeepSeek Harness（iPad 版 Agent）

一个运行在 iPad 上的 AI 智能体工作台。你描述任务，DeepSeek 自己制定计划、调用工具，一步步完成：读写文件、运行 JavaScript、抓取网页。所有操作都限制在这个任务自己的工作区文件夹里。

## 界面

```
┌──────────────┬────────────────────────────────┬──────────────────┐
│ 任务列表      │  对话                           │ 计划              │
│              │  ├ 你的任务                     │  ✓ 读取数据        │
│ ● 贪吃蛇游戏  │  ├ 思考过程（可折叠）            │  ◌ 生成报告        │
│   数据汇总    │  ├ [写入文件 snake.html] ✓      │                  │
│   …          │  ├ [运行 JavaScript]  ✋ 允许？  │ 工作区文件         │
│              │  └ 总结                         │  snake.html       │
│ ⚙ 设置       │  [输入框…                  ⬆]  │ 用量 / 费用        │
└──────────────┴────────────────────────────────┴──────────────────┘
```

## 功能

| 功能 | 说明 |
|---|---|
| Agent 循环 | 模型调用工具，再根据结果继续，直到完成任务；可以随时停止，出错或达到步数上限后可以"继续" |
| 8 个工具 | `list_files` `read_file` `write_file` `edit_file` `delete_file` `run_javascript` `fetch_url` `update_plan` |
| 权限审批 | "改动前询问"模式下，写入、修改、删除文件和运行代码之前，卡片上会出现 允许 / 拒绝 按钮；也可以切换成全部自动 |
| 工作区 | 每个任务一个文件夹，在右侧面板和"文件"App 里都能看到；可以导入你自己的文件，可以分享导出 |
| 文件预览 | 点文件用系统快速查看打开，HTML、图片、PDF、文本都能看。Agent 写的网页可以直接预览 |
| 任务计划 | Agent 会把任务拆成清单，并随进度更新 |
| 思考过程 | 实时显示 DeepSeek 的推理内容；思考强度可以选 关闭 / 低 / 高 / 最高 |
| 两个模型 | `deepseek-flash`（默认，快且便宜）和 `deepseek-v4-pro`（更强），每个任务中途可以切换 |
| 用量统计 | 缓存命中 / 未命中 / 输出 token 数，按高峰和非高峰价格估算费用 |
| 网络代理 | HTTP / SOCKS5 代理（可填账号密码）、自定义 API 地址、测试连接 |
| 键盘快捷键 | ⌘N 新任务，⌘↩ 发送，⌘. 停止，⇧⌘↩ 允许，⌘, 设置 |

## 编译安装

需要：一台装了 Xcode 15 或更新版本的 Mac，系统为 iPadOS 17 以上的 iPad，以及 DeepSeek API Key（在 platform.deepseek.com 创建并充值）。

```bash
brew install xcodegen
```

```bash
cd DeepSeekHarness && xcodegen generate && open DeepSeekHarness.xcodeproj
```

然后在 Signing & Capabilities 里选你的 Team，并把 Bundle Identifier 改成你自己的。iPad 打开开发者模式（设置 → 隐私与安全性 → 开发者模式）后，选中 iPad，按 ⌘R 运行。免费 Apple ID 签名的 App 7 天后过期，到时候重新运行一次即可。

没有 XcodeGen 的话：新建一个 iOS App 项目（SwiftUI，设备选 iPad），删掉自动生成的两个 Swift 文件，把 `Harness/` 下的 `App`、`Models`、`Services`、`Views` 拖进去；最低版本设为 iOS 17；在 Info 里加上 `UIFileSharingEnabled` 和 `LSSupportsOpeningDocumentsInPlace`，两个都设为 YES。

## 工具说明和限制

- **没有终端、Python 或编译器**。iOS 不允许 App 运行任意程序，所以代码执行用的是系统自带的 JavaScriptCore。它可以做计算、处理数据，也可以通过 `readFile` / `writeFile` / `listFiles` 读写工作区；没有 DOM、网络和 Node.js API，单次运行限时 20 秒。
- **没有搜索引擎**。`fetch_url` 只能抓取已知网址，HTML 会转成纯文本，链接地址保留在方括号里，方便继续抓取。
- **工具输出超过 6 万字符会截断**，截断时会明确告诉模型。读大文件时模型会用 `offset` / `limit` 分段读取。
- **切到后台后可能中断**：iPadOS 会暂停后台 App，长任务建议留在前台。中断后点"继续"就能接着做。

## 技术说明

- 接口是 DeepSeek 官方的 Chat Completions（OpenAI 格式），地址 `https://api.deepseek.com`，流式 SSE 输出。
- 思考模式下使用工具时，DeepSeek 要求**每一轮的 `reasoning_content` 都原样传回**，否则会返回 400。所以 App 按原始格式保存全部消息，并完整回传。
- 系统提示在任务创建时固定，消息只追加不修改，这样请求前缀保持稳定，能命中 DeepSeek 的缓存（命中部分价格低很多）。
- App 被杀掉后重新打开时，会自动修复不完整的历史：没有结果的工具调用会补上"已中断"的结果，保证下次请求合法。

```
Harness/
├── App/HarnessApp.swift
├── Models/        JSONValue · Session · DeepSeekModel（价格、思考强度、权限模式）
├── Services/
│   ├── DeepSeekClient.swift   流式请求、tool_calls 拼接、用量
│   ├── AgentRunner.swift      Agent 循环、审批、停止 / 继续、标题生成
│   ├── Tools.swift            工具定义与执行
│   ├── Workspace.swift        工作区文件操作（路径不能越界）
│   ├── JSRunner.swift         JavaScriptCore 沙盒
│   ├── WebFetcher.swift       网页抓取、HTML 转文本
│   ├── SessionStore.swift     持久化与历史修复
│   ├── NetworkConfig.swift    API 地址与代理
│   ├── AppSettings.swift      设置与系统提示
│   └── KeychainStore.swift
└── Views/         Root · Session · Message · ToolCard · Markdown · Inspector · Settings
```
