import Foundation
import Observation

enum ToolStatus: Equatable {
    case waitingApproval
    case running
    case done
    case failed
    case denied
}

/// 运行一个会话的 Agent 循环：请求模型 → 执行工具 → 把结果交回模型 → 直到模型给出最终回答。
@MainActor
@Observable
final class AgentRunner {
    let sessionID: UUID
    private let store: SessionStore
    private let settings: AppSettings

    var isRunning = false
    var phase = ""
    var lastError: String?
    var toolStatus: [String: ToolStatus] = [:]
    var step = 0

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var approvals: [String: CheckedContinuation<Bool, Never>] = [:]

    init(sessionID: UUID, store: SessionStore, settings: AppSettings) {
        self.sessionID = sessionID
        self.store = store
        self.settings = settings
    }

    private var session: Session? { store.session(sessionID) }

    // MARK: 用户操作

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isRunning else { return }
        store.update(sessionID) {
            $0.messages.append(["role": "user", "content": .string(text)])
            $0.updatedAt = Date()
        }
        start()
    }

    /// 出错后继续（历史以 user 或 tool 消息结尾时）
    func resume() {
        guard !isRunning, let last = session?.messages.last,
              ["user", "tool"].contains(last["role"]?.string ?? "") else { return }
        start()
    }

    var canResume: Bool {
        guard !isRunning, let r = session?.messages.last?["role"]?.string else { return false }
        return r == "user" || r == "tool"
    }

    func stop() {
        task?.cancel()
        for (_, c) in approvals { c.resume(returning: false) }
        approvals.removeAll()
    }

    func decide(_ callID: String, allow: Bool) {
        approvals.removeValue(forKey: callID)?.resume(returning: allow)
    }

    // MARK: 循环

    private func start() {
        lastError = nil
        isRunning = true
        task = Task { [weak self] in
            await self?.loop()
            guard let self else { return }
            self.isRunning = false
            self.phase = ""
            await self.generateTitleIfNeeded()
        }
    }

    private func loop() async {
        guard let ws = store.workspace(for: sessionID) else { return }
        let maxSteps = max(1, settings.maxSteps)
        step = 0

        while step < maxSteps {
            step += 1
            if Task.isCancelled { return }

            // 1. 请求模型
            guard let finished = await callModel() else { return } // 出错或取消
            guard !finished.calls.isEmpty else {
                if finished.finishReason == "length" {
                    lastError = "回复达到长度上限被截断，可以让它继续"
                }
                return
            }

            // 2. 依次执行工具
            for call in finished.calls {
                if Task.isCancelled {
                    appendToolResult(call.id, "Cancelled by the user before this tool ran.")
                    continue
                }
                await runTool(call, workspace: ws)
            }
            if Task.isCancelled { return }
        }
        lastError = "已达到 \(maxSteps) 步上限，自动暂停。点“继续”让它接着做。"
        // 让下一次“继续”合法：历史以 tool 消息结尾
    }

    private struct Call { let id: String; let name: String; let args: JSONValue? }
    private struct Finished { let calls: [Call]; let finishReason: String? }

    private func callModel() async -> Finished? {
        guard let s = session else { return nil }
        phase = "思考中…"
        let client = settings.makeClient()
        let body = makeBody(s)
        let placeholderIndex = s.messages.count
        store.update(sessionID) { $0.messages.append(["role": "assistant", "content": "", "reasoning_content": ""]) }

        do {
            let result = try await client.stream(body, model: s.model) { [weak self] snap in
                guard let self else { return }
                self.phase = !snap.toolCalls.isEmpty ? "准备调用工具…" : (snap.content.isEmpty ? "思考中…" : "回复中…")
                self.store.update(self.sessionID) { sess in
                    guard placeholderIndex < sess.messages.count else { return }
                    var m: [String: JSONValue] = [
                        "role": "assistant",
                        "content": .string(snap.content),
                        "reasoning_content": .string(snap.reasoning),
                    ]
                    if !snap.toolCalls.isEmpty { m["tool_calls"] = .array(snap.toolCalls) }
                    sess.messages[placeholderIndex] = .object(m)
                }
            }
            store.update(sessionID) { sess in
                if placeholderIndex < sess.messages.count { sess.messages[placeholderIndex] = result.message }
                sess.usage = sess.usage + result.usage
                sess.updatedAt = Date()
            }
            let calls = (result.message["tool_calls"]?.array ?? []).map { tc in
                Call(id: tc["id"]?.string ?? "",
                     name: tc["function"]?["name"]?.string ?? "",
                     args: JSONValue.parse(tc["function"]?["arguments"]?.string ?? ""))
            }
            return Finished(calls: calls, finishReason: result.finishReason)
        } catch {
            // 取消或出错：不完整的工具调用不能留在历史里
            let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
            store.update(sessionID) { sess in
                guard placeholderIndex < sess.messages.count else { return }
                let partial = sess.messages[placeholderIndex]["content"]?.string ?? ""
                if cancelled, !partial.isEmpty {
                    sess.messages[placeholderIndex] = [
                        "role": "assistant",
                        "content": .string(partial + "\n\n（已停止）"),
                        "reasoning_content": sess.messages[placeholderIndex]["reasoning_content"] ?? "",
                    ]
                } else {
                    sess.messages.remove(at: placeholderIndex)
                }
            }
            if !cancelled { lastError = error.localizedDescription }
            return nil
        }
    }

    private func makeBody(_ s: Session) -> JSONValue {
        var msgs: [JSONValue] = [["role": "system", "content": .string(s.systemPrompt)]]
        msgs += s.messages
        var body: [String: JSONValue] = [
            "model": .string(s.model.rawValue),
            "messages": .array(msgs),
            "tools": Tools.definitions,
            "stream": true,
            "stream_options": ["include_usage": true],
            "max_tokens": 65536,
        ]
        if settings.effort == .off {
            body["thinking"] = ["type": "disabled"]
        } else {
            body["thinking"] = ["type": "enabled"]
            body["reasoning_effort"] = .string(settings.effort.rawValue)
        }
        return .object(body)
    }

    private func runTool(_ call: Call, workspace: Workspace) async {
        let kind = ToolKind(rawValue: call.name)
        if kind?.needsApproval == true, settings.permissionMode == .ask {
            toolStatus[call.id] = .waitingApproval
            phase = "等待你批准…"
            let allowed = await withCheckedContinuation { c in approvals[call.id] = c }
            guard allowed else {
                toolStatus[call.id] = .denied
                appendToolResult(call.id, Task.isCancelled
                                 ? "Cancelled by the user."
                                 : "The user denied this action. Do not retry it; continue another way or ask the user.")
                return
            }
        }
        toolStatus[call.id] = .running
        phase = "\(kind?.label ?? call.name)…"
        let outcome = await Tools.execute(name: call.name, args: call.args, workspace: workspace,
                                          network: settings.network)
        if let plan = outcome.plan {
            store.update(sessionID) { $0.plan = plan }
        }
        toolStatus[call.id] = outcome.isError ? .failed : .done
        appendToolResult(call.id, outcome.output)
    }

    private func appendToolResult(_ id: String, _ content: String) {
        store.update(sessionID) {
            $0.messages.append(["role": "tool", "tool_call_id": .string(id), "content": .string(content)])
        }
    }

    // MARK: 标题

    private func generateTitleIfNeeded() async {
        guard let s = session, s.title == "新任务", let first = s.firstUserText else { return }
        let fallback = String(first.prefix(20))
        let body: JSONValue = [
            "model": "deepseek-flash",
            "thinking": ["type": "disabled"],
            "max_tokens": 40,
            "messages": [
                ["role": "user", "content": .string("给下面这个任务起一个不超过 12 个字的标题，用任务的语言，只输出标题：\n\n\(first.prefix(2000))")],
            ],
        ]
        var title = fallback
        if let res = try? await settings.makeClient().complete(body),
           let t = res["choices"]?.array?.first?["message"]?["content"]?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"“”「」《》#*"))),
           !t.isEmpty, t.count <= 40 {
            title = t
        }
        store.update(sessionID) { $0.title = title }
    }
}

/// 每个会话一个 Runner，切换会话时后台任务继续跑
@MainActor
@Observable
final class AgentHub {
    @ObservationIgnored private var runners: [UUID: AgentRunner] = [:]

    func runner(for id: UUID, store: SessionStore, settings: AppSettings) -> AgentRunner {
        if let r = runners[id] { return r }
        let r = AgentRunner(sessionID: id, store: store, settings: settings)
        runners[id] = r
        return r
    }

    func remove(_ id: UUID) {
        runners[id]?.stop()
        runners[id] = nil
    }

    func isRunning(_ id: UUID) -> Bool { runners[id]?.isRunning ?? false }
}
