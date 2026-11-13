import Foundation
import Observation

/// 会话列表，保存在 Application Support/sessions.json（工作区文件在 Documents 里）
@Observable
final class SessionStore {
    var sessions: [Session] = []
    @ObservationIgnored private var workspaces: [UUID: Workspace] = [:]
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }()

    init() { load() }

    var sorted: [Session] { sessions.sorted { $0.updatedAt > $1.updatedAt } }

    func session(_ id: UUID) -> Session? { sessions.first { $0.id == id } }

    func workspace(for id: UUID) -> Workspace? {
        if let w = workspaces[id] { return w }
        guard let s = session(id) else { return nil }
        let w = Workspace(folder: s.workspaceFolder)
        workspaces[id] = w
        return w
    }

    func create(settings: AppSettings) -> Session {
        let s = Session(model: settings.defaultModel, systemPrompt: settings.makeSystemPrompt())
        sessions.append(s)
        scheduleSave()
        return s
    }

    func update(_ id: UUID, _ change: (inout Session) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[i])
        scheduleSave()
    }

    func delete(_ id: UUID, removeFiles: Bool) {
        if removeFiles { workspace(for: id)?.removeAll() }
        workspaces[id] = nil
        sessions.removeAll { $0.id == id }
        scheduleSave()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        sessions = (try? dec.decode([Session].self, from: data)) ?? []
        // 上次运行中途被杀掉：清理空的占位回复，补齐缺失的工具结果，保证历史合法
        for i in sessions.indices {
            sessions[i].messages = Self.repair(sessions[i].messages)
        }
    }

    /// 去掉空的 assistant 占位消息；给没有结果的 tool_call 补一个"已中断"结果
    static func repair(_ msgs: [JSONValue]) -> [JSONValue] {
        var out: [JSONValue] = []
        var pending: [String] = []
        func flushPending() {
            for id in pending {
                out.append(["role": "tool", "tool_call_id": .string(id), "content": "Interrupted: the app was closed before this tool ran."])
            }
            pending = []
        }
        for m in msgs {
            let role = m["role"]?.string
            if role == "tool" {
                pending.removeAll { $0 == m["tool_call_id"]?.string }
                out.append(m)
                continue
            }
            flushPending()
            if role == "assistant",
               (m["content"]?.string ?? "").isEmpty,
               (m["tool_calls"]?.array ?? []).isEmpty {
                continue
            }
            out.append(m)
            if role == "assistant" {
                pending = (m["tool_calls"]?.array ?? []).compactMap { $0["id"]?.string }
            }
        }
        flushPending()
        return out
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = sessions
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            if let data = try? enc.encode(snapshot) {
                try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
    }
}
