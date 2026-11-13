# Claude for Apple Watch（自制客户端）

一个独立运行的 watchOS 应用，直接调用 Claude API。不依赖 iPhone App，手表连 Wi-Fi 或蜂窝网络就能用。

## 功能

| 功能 | 说明 |
|---|---|
| 流式回复 | 文字边生成边显示，可以随时停止 |
| 语音输入 | 点输入框，用系统听写、随手写、手表键盘，或者在 iPhone 上弹出的键盘里输入/粘贴 |
| 朗读回复 | 每条回复都有 🔊 按钮；可以开启"自动朗读"，支持调语速，中文自动用中文语音 |
| 对话历史 | 本地保存，支持搜索、左滑删除；用 Haiku 自动生成标题 |
| 多模型 | Opus 5.5（默认）/ Sonnet 5.5 / Haiku 5.5 / Fable 5.2，对话中途可以切换 |
| 思考过程 | 可以展开查看 Claude 的思考摘要；思考深度分快速/标准/深入三档 |
| 联网搜索 | 自动搜索并列出引用的来源链接 |
| 自定义指令 | 类似手机版的"个人偏好" |
| 重新生成 / 重试 | 最后一条回复可以重新生成，失败可以重试 |
| 用量统计 | 每个对话和累计的 token 数、估算费用 |
| 被拒自动换模型 | 偶尔被安全分类器误拒时，服务器会自动换一个推荐模型重试 |
| 触感反馈 | 发送、完成、出错时手表会轻震 |
| 网络代理 | 支持 HTTP / SOCKS5 代理（可填用户名密码）、自定义 API 地址、Bearer 认证，带"测试连接"按钮 |

## 你需要准备

1. 一台 Mac，装好 Xcode 15 或更新版本
2. Apple Watch，系统 watchOS 10 或以上
3. Anthropic API Key：到 https://console.anthropic.com 注册、充值，然后创建 Key。
   注意：API 按用量付费，和 Claude.ai 的 Pro/Max 订阅是**两套独立的账单**，订阅额度不能用在这里。

## 编译安装

### 方法一：XcodeGen（推荐）

```bash
brew install xcodegen
```

```bash
cd ClaudeWatch
```

```bash
xcodegen generate
```

```bash
open ClaudeWatch.xcodeproj
```

### 方法二：手动新建项目

1. 在 Xcode 里选 File → New → Project → watchOS → App，Product Name 填 `Claude`，Interface 选 SwiftUI，选 **Watch-only App**。
2. 删掉自动生成的 `ContentView.swift` 和 `ClaudeApp.swift`。
3. 把本目录 `ClaudeWatch/` 下的 `App`、`Models`、`Services`、`Views` 四个文件夹拖进项目（勾选 Copy items if needed）。
4. 最低系统版本（Minimum Deployments）设为 watchOS 10.0。

### 装到手表上

1. iPhone 和手表都打开**开发者模式**：iPhone 在 设置 → 隐私与安全性 → 开发者模式；手表在 设置 → 隐私与安全性 → 开发者模式。
2. Xcode 里选中 target → Signing & Capabilities → Team 选你的 Apple ID（免费的也行），Bundle Identifier 改成一个独一无二的名字，比如 `com.你的名字.claudewatch`。
3. 顶部设备选你的 Apple Watch，按 ⌘R 运行。第一次连手表可能要等几分钟。
4. 免费 Apple ID 签的应用 **7 天后过期**，到时候用 Xcode 再运行一次就行；付费开发者账号（99 美元/年）签一次能用一年。

> 想要 `.ipa` 文件：用 Product → Archive 打包，再在 Organizer 里选 Distribute App → Development 导出。
> 导出的包只能装在你账号里登记过的设备上。

## 首次使用

打开 App → 点输入框 → iPhone 上会弹出"Apple Watch 键盘"通知 → 在手机上粘贴 API Key → 开始。
Key 存在手表的钥匙串里，不会写进代码。

## 网络与代理

在 设置 → 网络与代理 里配置。首次启动时，输入 Key 的页面下方也有入口。

- **API 地址**：默认是 `https://api.anthropic.com`。用自建网关时填网关地址，末尾带不带 `/v1` 都可以。
- **Bearer 认证**：有的网关只认 `Authorization: Bearer` 请求头，不认 `x-api-key`，这种情况打开这个开关。
- **代理**：支持 HTTP（CONNECT）和 SOCKS5，可以填用户名和密码。只有本 App 的请求走代理，不影响手表上的其他应用。用的是 watchOS 10 自带的 `proxyConfigurations` 接口。
- **测试连接**：调用 `/v1/models` 接口，不消耗 token，会显示能否连通和延迟。

注意：
- 代理服务器地址必须是手表能访问到的地址。手表连着 iPhone 上网时，填 `127.0.0.1` 是连不上 iPhone 上的代理 App 的，要填局域网 IP 或公网地址。
- 第三方中转服务能看到你的 API Key 和全部对话内容，只用你信任的服务。
- Anthropic 只在[支持的国家和地区](https://www.anthropic.com/supported-countries)提供服务。从不支持的地区通过代理使用，违反服务条款，账号可能被封。

## 和手机版的区别

- **没有图片和文件上传**：手表拍不了照，也选不了文件。
- **对话不和 claude.ai 同步**：走的是 API，所以看不到你在网页版、手机版里的对话，这里的对话也只存在手表上。
- **抬腕时间有限**：watchOS 会在你放下手腕后暂停 App，很长的回复可能会中断。建议用 Sonnet/Haiku，或者把思考深度设为"快速"，回复会快很多。
- **费用**：Opus 5.5 每百万 token 输入 4 美元、输出 20 美元；Haiku 5.5 只要 0.1/0.5 美元。日常问答一次通常不到 1 美分。

## 代码结构

```
ClaudeWatch/
├── App/ClaudeWatchApp.swift        入口
├── Models/
│   ├── JSONValue.swift              通用 JSON，原样保存 API 返回的内容块
│   ├── ClaudeModel.swift            模型列表、价格、思考深度
│   └── Conversation.swift           对话 / 消息 / 用量数据结构
├── Services/
│   ├── AnthropicClient.swift        HTTPS + SSE 流式解析
│   ├── ChatController.swift         发送、续写（pause_turn）、拒绝处理、标题生成
│   ├── ConversationStore.swift      本地持久化
│   ├── AppSettings.swift            设置与系统提示
│   ├── NetworkConfig.swift          API 地址与代理配置
│   ├── KeychainStore.swift          API Key / 代理密码存储
│   └── SpeechService.swift          朗读
└── Views/                           SwiftUI 界面
```

技术说明：

- Swift 没有官方 Anthropic SDK，所以直接用 `URLSession` 调用 `POST /v1/messages`（API 版本 `2026-10-21`），流式响应用 SSE 解析。
- 历史记录**只追加、不修改**，助手消息原样回传（包括思考块签名），这样上下文和提示缓存都保持有效。系统提示和工具列表在对话创建时固定；中途换模型时，不兼容的思考块由服务器丢弃（`prefix_mismatch_behavior: "drop_block"`），不会报错。
- 开启了自动提示缓存（`cache_control`），长对话会便宜很多。
