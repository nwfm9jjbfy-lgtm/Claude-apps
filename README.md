# 自制 AI 客户端

| 目录 | 内容 |
|---|---|
| `DeepSeekHarness/` | iPad 版 DeepSeek Agent 工作台 |
| `ClaudeWatch/` | Apple Watch 版 Claude 客户端 |

## 用 GitHub Actions 打包

每次推送到 `main` 分支都会自动编译。也可以在 Actions → 打包 → Run workflow 手动运行。

编译完成后，在这次运行页面底部的 **Artifacts** 里下载：

- `DeepSeekHarness-unsigned-ipa`：iPad 安装包（未签名）
- `ClaudeWatch-unsigned-app`：手表 App（未签名，主要用来确认代码能编译通过）

编译失败时会上传 `*-build-log`，里面有完整的报错。

## 安装未签名的 IPA

iOS 只能安装签过名的 App。下载的 IPA 需要用你自己的 Apple ID 签名后才能装：

1. 在电脑上安装 [Sideloadly](https://sideloadly.io)（Windows 和 Mac 都能用）。
2. 用数据线连接 iPad，把 IPA 拖进 Sideloadly，输入 Apple ID，点 Start。
3. iPad 上打开 设置 → 通用 → VPN与设备管理，信任你的开发者证书；再到 设置 → 隐私与安全性 → 开发者模式，打开开发者模式。

免费 Apple ID 签名的 App **7 天后过期**，过期后重新签一次就行，数据不会丢。同一个免费 Apple ID 最多同时装 3 个这类 App。

手表 App 是独立的 watchOS 应用，常见的签名工具对它支持不好，建议用 Mac 上的 Xcode 直接安装（见 `ClaudeWatch/README.md`）。
