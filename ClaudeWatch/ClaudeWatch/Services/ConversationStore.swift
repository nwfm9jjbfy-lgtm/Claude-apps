import Foundation
import Observation

/// 对话保存在手表本地（Application Support/conversations.json）。
@Observable
final class ConversationStore {
    var conversations: [Conversation] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("conversations.json")
    }()

    private var saveTask: Task<Void, Never>?

    init() { load() }

    var sorted: [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func conversation(_ id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func create(settings: AppSettings) -> Conversation {
        let c = Conversation(model: settings.defaultModel,
                             systemPrompt: settings.makeSystemPrompt(),
                             webSearch: settings.webSearch)
        conversations.append(c)
        return c
    }

    func update(_ id: UUID, _ change: (inout Conversation) -> Void) {
        guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[i])
        scheduleSave()
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        scheduleSave()
    }

    func deleteAll() {
        conversations.removeAll()
        scheduleSave()
    }

    /// 删掉没有任何消息的空对话
    func pruneEmpty(except keep: UUID? = nil) {
        let before = conversations.count
        conversations.removeAll { $0.messages.isEmpty && $0.id != keep }
        if conversations.count != before { scheduleSave() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        conversations = (try? decoder.decode([Conversation].self, from: data)) ?? []
        // 上次运行若在生成中被杀掉，清理残留的空回复
        for i in conversations.indices {
            conversations[i].messages.removeAll {
                $0.role == .assistant && $0.rawContent == nil && $0.error == nil && $0.text.isEmpty
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = conversations
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: [.atomic, .completeFileProtection])
            }
        }
    }
}
