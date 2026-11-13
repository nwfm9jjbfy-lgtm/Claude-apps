import Foundation
import Observation
import WatchKit

/// 管理一个对话的发送、流式接收、重试和标题生成。
@MainActor
@Observable
final class ChatController {
    let conversationID: UUID
    private let store: ConversationStore
    private let settings: AppSettings
    private let speech: SpeechService

    var isStreaming = false
    var isSearching = false
    private var task: Task<Void, Never>?

    init(conversationID: UUID, store: ConversationStore, settings: AppSettings, speech: SpeechService) {
        self.conversationID = conversationID
        self.store = store
        self.settings = settings
        self.speech = speech
    }

    var conversation: Conversation? { store.conversation(conversationID) }

    // MARK: 用户操作

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        speech.stop()
        let assistantID = UUID()
        store.update(conversationID) { c in
            // 上一轮失败还没重试就发新消息：把失败那轮排除在历史之外
            if let last = c.messages.last, last.role == .assistant, last.error != nil, !last.excluded {
                Self.excludeLastPair(&c)
            }
            c.messages.append(ChatMessage(role: .user, text: text))
            c.messages.append(ChatMessage(id: assistantID, role: .assistant, text: ""))
            c.updatedAt = Date()
        }
        haptic(.click)
        start(assistantID)
    }

    /// 重新生成最后一条回复（也用于失败后重试）
    func regenerate() {
        guard !isStreaming, let c = conversation,
              let last = c.messages.last, last.role == .assistant else { return }
        speech.stop()
        let newID = UUID()
        store.update(conversationID) { c in
            c.messages.removeLast()
            // 被拒绝的那轮也一并恢复用户消息
            if let i = c.messages.indices.last, c.messages[i].role == .user {
                c.messages[i].excluded = false
            }
            c.messages.append(ChatMessage(id: newID, role: .assistant, text: ""))
            c.updatedAt = Date()
        }
        start(newID)
    }

    func stop() {
        task?.cancel()
    }

    func switchModel(_ m: ClaudeModel) {
        store.update(conversationID) { $0.model = m }
    }

    // MARK: 生成

    private func start(_ assistantID: UUID) {
        isStreaming = true
        task = Task { [weak self] in
            await self?.generate(assistantID)
            self?.isStreaming = false
            self?.isSearching = false
        }
    }

    private func generate(_ assistantID: UUID) async {
        guard let conv = conversation,
              let idx = conv.messages.firstIndex(where: { $0.id == assistantID }) else { return }

        let client = settings.makeClient()
        let model = conv.model
        let history = Self.buildMessages(Array(conv.messages[..<idx]))
        var collected: [JSONValue] = []
        var usage = Usage()
        var stopReason: String?
        var servedModel: String?
        var prefixText = ""
        var prefixThinking = ""
        var queries: [String] = []

        do {
            // pause_turn：服务器端搜索循环暂停，原样回传继续，最多 5 次
            for _ in 0..<6 {
                var messages = history
                if !collected.isEmpty {
                    messages.append(["role": "assistant", "content": .array(collected)])
                }
                let (body, betas) = makeBody(conv: conv, model: model, messages: messages)
                let pt = prefixText, pth = prefixThinking, pq = queries
                let result = try await client.stream(body: body, betas: betas, pricing: model) { [weak self] snap in
                    guard let self else { return }
                    self.isSearching = snap.isSearching
                    self.store.update(self.conversationID) { c in
                        guard let i = c.messages.firstIndex(where: { $0.id == assistantID }) else { return }
                        c.messages[i].text = pt + snap.text
                        c.messages[i].thinking = pth + snap.thinking
                        c.messages[i].searchQueries = pq + snap.searchQueries
                        c.messages[i].servedModel = snap.model
                    }
                }
                collected += result.content
                usage = usage + result.usage
                stopReason = result.stopReason
                servedModel = result.model ?? servedModel
                prefixText = Self.text(of: collected)
                prefixThinking = Self.thinking(of: collected)
                queries = Self.queries(of: collected)
                if stopReason != "pause_turn" { break }
            }
        } catch is CancellationError {
            finishCancelled(assistantID)
            return
        } catch let e as URLError where e.code == .cancelled {
            finishCancelled(assistantID)
            return
        } catch {
            store.update(conversationID) { c in
                guard let i = c.messages.firstIndex(where: { $0.id == assistantID }) else { return }
                c.messages[i].error = error.localizedDescription
                c.messages[i].text = ""
                c.messages[i].thinking = ""
            }
            haptic(.failure)
            return
        }

        if stopReason == "refusal" {
            store.update(conversationID) { c in
                guard let i = c.messages.firstIndex(where: { $0.id == assistantID }) else { return }
                c.messages[i].text = ""
                c.messages[i].thinking = ""
                c.messages[i].usage = usage
                c.messages[i].error = "Claude 无法回答这个请求，可以换个说法试试。"
                Self.excludeLastPair(&c)
            }
            haptic(.failure)
            return
        }

        var finalText = Self.text(of: collected)
        if stopReason == "max_tokens" { finalText += "\n\n（回复太长，已截断）" }
        let sources = Self.sources(of: collected)
        let thinking = Self.thinking(of: collected)

        store.update(conversationID) { c in
            guard let i = c.messages.firstIndex(where: { $0.id == assistantID }) else { return }
            c.messages[i].rawContent = collected
            c.messages[i].text = finalText
            c.messages[i].thinking = thinking
            c.messages[i].searchQueries = Self.queries(of: collected)
            c.messages[i].sources = sources
            c.messages[i].servedModel = servedModel
            c.messages[i].usage = usage
            c.updatedAt = Date()
        }
        haptic(.success)

        if settings.autoSpeak {
            speech.speak(finalText, id: assistantID, rate: settings.speechRate)
        }
        await generateTitleIfNeeded()
    }

    private func finishCancelled(_ assistantID: UUID) {
        store.update(conversationID) { c in
            guard let i = c.messages.firstIndex(where: { $0.id == assistantID }) else { return }
            let partial = c.messages[i].text
            if partial.isEmpty {
                c.messages.remove(at: i)
                // 用户消息保留在界面上，但不再发给 API（没有回复）
                if let u = c.messages.indices.last, c.messages[u].role == .user {
                    c.messages[u].excluded = true
                }
            } else {
                // 只保留已生成的文字，作为一条普通回复
                c.messages[i].rawContent = [["type": "text", "text": .string(partial)]]
                c.messages[i].text = partial + " …"
            }
        }
    }

    private func makeBody(conv: Conversation, model: ClaudeModel, messages: [JSONValue]) -> (JSONValue, [String]) {
        var betas = ["thinking-binding-controls-2026-08-01"]
        var body: [String: JSONValue] = [
            "model": .string(model.rawValue),
            "max_tokens": 16000,
            "stream": true,
            "system": .string(conv.systemPrompt),
            "messages": .array(messages),
            "thinking": [
                "type": "adaptive",
                "display": .string(settings.showThinking ? "summarized" : "omitted"),
                // 切换模型等情况导致思考块不匹配时，丢弃而不是报错
                "block_binding": ["prefix_mismatch_behavior": "drop_block"],
            ],
            "output_config": ["effort": .string(settings.effort.rawValue)],
            // 自动提示缓存，长对话更省钱
            "cache_control": ["type": "ephemeral"],
        ]
        if conv.webSearch {
            body["tools"] = [[
                "type": .string(model.webSearchToolType),
                "name": "web_search",
                "max_uses": 5,
            ]]
        }
        if model.supportsServerFallback {
            // 被安全分类器误拒时，服务器自动换推荐模型重试
            betas.append("server-side-fallback-2026-07-01")
            body["fallbacks"] = "default"
        }
        return (.object(body), betas)
    }

    // MARK: 标题

    private func generateTitleIfNeeded() async {
        guard let c = conversation, !c.titleGenerated,
              let user = c.messages.first(where: { $0.role == .user }),
              let reply = c.messages.first(where: { $0.role == .assistant && !$0.text.isEmpty }) else { return }

        let fallbackTitle = String(user.text.prefix(16))
        let prompt = """
        用户：\(user.text.prefix(1500))

        助手：\(reply.text.prefix(1500))

        为上面这段对话写一个简短标题：中文不超过12个字，英文不超过6个单词，用用户的语言。只输出标题本身，不要引号和标点。
        """
        let body: JSONValue = [
            "model": "claude-haiku-5-5",
            "max_tokens": 1024,
            "output_config": ["effort": "low"],
            "messages": [["role": "user", "content": .string(prompt)]],
        ]
        var title = fallbackTitle
        if let res = try? await settings.makeClient().send(body: body),
           res["stop_reason"]?.string != "refusal" {
            let t = Self.text(of: res["content"]?.array ?? [])
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"“”「」《》")))
            if !t.isEmpty, t.count <= 40 { title = t }
        }
        store.update(conversationID) { c in
            c.title = title
            c.titleGenerated = true
        }
    }

    // MARK: 工具函数

    private static func excludeLastPair(_ c: inout Conversation) {
        guard let a = c.messages.indices.last else { return }
        c.messages[a].excluded = true
        if a > 0, c.messages[a - 1].role == .user { c.messages[a - 1].excluded = true }
    }

    /// 历史记录只追加不修改：用户消息发纯文本，助手消息发 API 返回的原始内容块
    static func buildMessages(_ msgs: [ChatMessage]) -> [JSONValue] {
        msgs.compactMap { (m: ChatMessage) -> JSONValue? in
            guard !m.excluded else { return nil }
            switch m.role {
            case .user:
                return ["role": "user", "content": .string(m.text)]
            case .assistant:
                guard let raw = m.rawContent, !raw.isEmpty else { return nil }
                return ["role": "assistant", "content": .array(raw)]
            }
        }
    }

    static func text(of blocks: [JSONValue]) -> String {
        blocks.filter { $0["type"]?.string == "text" }
            .compactMap { $0["text"]?.string }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func thinking(of blocks: [JSONValue]) -> String {
        blocks.filter { $0["type"]?.string == "thinking" }
            .compactMap { $0["thinking"]?.string }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    static func queries(of blocks: [JSONValue]) -> [String] {
        blocks.filter { $0["type"]?.string == "server_tool_use" }
            .compactMap { $0["input"]?["query"]?.string }
    }

    static func sources(of blocks: [JSONValue]) -> [ChatMessage.Source] {
        var seen = Set<String>()
        var out: [ChatMessage.Source] = []
        for b in blocks where b["type"]?.string == "text" {
            for c in b["citations"]?.array ?? [] {
                guard let url = c["url"]?.string, !seen.contains(url) else { continue }
                seen.insert(url)
                out.append(.init(title: c["title"]?.string ?? url, url: url))
            }
        }
        return out
    }

    private func haptic(_ type: WKHapticType) {
        guard settings.haptics else { return }
        WKInterfaceDevice.current().play(type)
    }
}
