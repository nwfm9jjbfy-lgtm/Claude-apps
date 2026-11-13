import Foundation

struct TokenUsage: Codable, Hashable {
    var cacheHit = 0
    var cacheMiss = 0
    var output = 0
    var reasoning = 0
    var costUSD = 0.0

    static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(cacheHit: a.cacheHit + b.cacheHit, cacheMiss: a.cacheMiss + b.cacheMiss,
                   output: a.output + b.output, reasoning: a.reasoning + b.reasoning,
                   costUSD: a.costUSD + b.costUSD)
    }
}

struct PlanItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var content: String
    var status: String // pending / in_progress / completed
}

/// 一个 Agent 会话。messages 按 OpenAI Chat Completions 格式原样保存，
/// 包括 reasoning_content（带工具的请求必须全部回传）。
struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var title = "新任务"
    var createdAt = Date()
    var updatedAt = Date()
    var model: DeepSeekModel
    /// 创建时冻结，保持前缀稳定，命中 DeepSeek 的硬盘缓存
    var systemPrompt: String
    var messages: [JSONValue] = []
    var usage = TokenUsage()
    var plan: [PlanItem] = []

    var workspaceFolder: String { "任务-" + id.uuidString.prefix(8) }

    var firstUserText: String? {
        messages.first { $0["role"]?.string == "user" }?["content"]?.string
    }
}
