import Foundation

struct Usage: Codable, Hashable {
    var inputTokens = 0
    var outputTokens = 0
    var cacheReadTokens = 0
    var cacheWriteTokens = 0
    var costUSD = 0.0

    static func + (a: Usage, b: Usage) -> Usage {
        Usage(inputTokens: a.inputTokens + b.inputTokens,
              outputTokens: a.outputTokens + b.outputTokens,
              cacheReadTokens: a.cacheReadTokens + b.cacheReadTokens,
              cacheWriteTokens: a.cacheWriteTokens + b.cacheWriteTokens,
              costUSD: a.costUSD + b.costUSD)
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    enum Role: String, Codable { case user, assistant }

    var id = UUID()
    var role: Role
    /// 界面上显示的正文
    var text: String
    /// 思考过程摘要
    var thinking: String = ""
    /// 本轮用到的搜索关键词
    var searchQueries: [String] = []
    /// 引用的网页（标题，链接）
    var sources: [Source] = []
    /// API 返回的原始内容块，下一轮原样回传
    var rawContent: [JSONValue]? = nil
    /// 实际回答的模型（可能因自动回退而不同于所选模型）
    var servedModel: String? = nil
    var error: String? = nil
    /// 被拒绝或失败的一轮，不再发给 API
    var excluded = false
    var usage: Usage? = nil
    var date = Date()

    struct Source: Codable, Hashable {
        var title: String
        var url: String
    }
}

struct Conversation: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String = "新对话"
    var titleGenerated = false
    var createdAt = Date()
    var updatedAt = Date()
    var model: ClaudeModel
    /// 系统提示在对话创建时冻结，中途修改会让之前的思考块失效
    var systemPrompt: String
    /// 工具列表同理，创建时冻结
    var webSearch: Bool
    var messages: [ChatMessage] = []

    var totalUsage: Usage {
        messages.compactMap(\.usage).reduce(Usage(), +)
    }

    var preview: String {
        messages.last(where: { !$0.text.isEmpty })?.text ?? ""
    }
}
