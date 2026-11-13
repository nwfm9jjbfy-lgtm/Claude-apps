import Foundation

/// 流式过程中的实时快照
struct StreamSnapshot {
    var content = ""
    var reasoning = ""
    var toolCalls: [JSONValue] = []
}

struct StreamResult {
    /// 可以直接追加到 messages 的 assistant 消息
    var message: JSONValue
    var finishReason: String?
    var usage: TokenUsage
}

/// DeepSeek Chat Completions（OpenAI 格式）流式客户端
final class DeepSeekClient {
    let apiKey: String
    let network: NetworkConfig
    private let session: URLSession

    init(apiKey: String, network: NetworkConfig) {
        self.apiKey = apiKey
        self.network = network
        self.session = network.makeSession()
    }

    private func request(path: String) throws -> URLRequest {
        var req = URLRequest(url: try network.url(path))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    func testConnection() async throws -> String {
        var req = try request(path: "/models")
        req.timeoutInterval = 20
        let start = Date()
        let (data, resp) = try await mapNetworkErrors { try await self.session.data(for: req) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.httpError(status, data) }
        let ids = JSONValue.parse(data)?["data"]?.array?.compactMap { $0["id"]?.string } ?? []
        return String(format: "连接成功 · %.0f ms", Date().timeIntervalSince(start) * 1000)
            + (ids.isEmpty ? "" : "\n可用模型：" + ids.joined(separator: ", "))
    }

    /// 非流式小请求（生成标题用）
    func complete(_ body: JSONValue) async throws -> JSONValue {
        var req = try request(path: "/chat/completions")
        req.httpMethod = "POST"
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await mapNetworkErrors { try await self.session.data(for: req) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.httpError(status, data) }
        guard let json = JSONValue.parse(data) else { throw HarnessError("无法解析服务器响应") }
        return json
    }

    func stream(_ body: JSONValue, model: DeepSeekModel,
                onUpdate: @escaping @MainActor (StreamSnapshot) -> Void) async throws -> StreamResult {
        var req = try request(path: "/chat/completions")
        req.httpMethod = "POST"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)

        let (bytes, resp) = try await mapNetworkErrors { try await self.session.bytes(for: req) }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await b in bytes { data.append(b) }
            throw Self.httpError(status, data)
        }

        var content = ""
        var reasoning = ""
        var calls: [Int: (id: String, name: String, args: String)] = [:]
        var finish: String?
        var usage = TokenUsage()
        var lastPush = Date.distantPast

        func snapshot() -> StreamSnapshot {
            StreamSnapshot(content: content, reasoning: reasoning, toolCalls: Self.toolCallsJSON(calls))
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue } // 忽略 ": keep-alive"
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let chunk = JSONValue.parse(payload) else { continue }

            if let err = chunk["error"] {
                throw HarnessError("服务器错误：\(err["message"]?.string ?? "未知")")
            }
            if let u = chunk["usage"], !u.isNull {
                usage = Self.readUsage(u, model: model)
            }
            guard let choice = chunk["choices"]?.array?.first else { continue }
            let delta = choice["delta"]
            if let r = delta?["reasoning_content"]?.string { reasoning += r }
            if let c = delta?["content"]?.string { content += c }
            for tc in delta?["tool_calls"]?.array ?? [] {
                let i = tc["index"]?.int ?? 0
                var cur = calls[i] ?? (id: "", name: "", args: "")
                if let id = tc["id"]?.string, !id.isEmpty { cur.id = id }
                if let n = tc["function"]?["name"]?.string { cur.name += n }
                if let a = tc["function"]?["arguments"]?.string { cur.args += a }
                calls[i] = cur
            }
            if let f = choice["finish_reason"]?.string { finish = f }

            if Date().timeIntervalSince(lastPush) > 0.08 {
                lastPush = Date()
                let snap = snapshot()
                await onUpdate(snap)
            }
        }
        await onUpdate(snapshot())

        var msg: [String: JSONValue] = [
            "role": "assistant",
            "content": .string(content),
            // 带工具的会话里，之前所有轮次的 reasoning_content 都要回传
            "reasoning_content": .string(reasoning),
        ]
        let tcs = Self.toolCallsJSON(calls)
        if !tcs.isEmpty { msg["tool_calls"] = .array(tcs) }
        return StreamResult(message: .object(msg), finishReason: finish, usage: usage)
    }

    private static func toolCallsJSON(_ calls: [Int: (id: String, name: String, args: String)]) -> [JSONValue] {
        calls.keys.sorted().compactMap { i in
            guard let c = calls[i] else { return nil }
            return [
                "id": .string(c.id.isEmpty ? "call_\(i)" : c.id),
                "type": "function",
                "function": ["name": .string(c.name), "arguments": .string(c.args)],
            ]
        }
    }

    private static func readUsage(_ u: JSONValue, model: DeepSeekModel) -> TokenUsage {
        let prompt = u["prompt_tokens"]?.int ?? 0
        let hit = u["prompt_cache_hit_tokens"]?.int ?? 0
        let miss = u["prompt_cache_miss_tokens"]?.int ?? max(0, prompt - hit)
        let out = u["completion_tokens"]?.int ?? 0
        let reasoning = u["completion_tokens_details"]?["reasoning_tokens"]?.int ?? 0
        return TokenUsage(cacheHit: hit, cacheMiss: miss, output: out, reasoning: reasoning,
                          costUSD: model.cost(hit: hit, miss: miss, output: out))
    }

    private func mapNetworkErrors<T>(_ op: () async throws -> T) async throws -> T {
        do { return try await op() }
        catch let e as URLError where e.code != .cancelled { throw HarnessError(Self.describe(e)) }
    }

    static func describe(_ e: URLError) -> String {
        switch e.code {
        case .timedOut: return "连接超时，检查网络或代理"
        case .cannotFindHost, .dnsLookupFailed: return "找不到服务器，检查 API 地址或代理地址"
        case .cannotConnectToHost: return "连不上服务器或代理，检查地址和端口"
        case .notConnectedToInternet: return "iPad 没有联网"
        case .secureConnectionFailed, .serverCertificateUntrusted: return "TLS 握手失败，检查代理或 API 地址"
        case .networkConnectionLost: return "网络连接中断"
        default: return "网络错误：\(e.localizedDescription)"
        }
    }

    static func httpError(_ status: Int, _ data: Data) -> HarnessError {
        let msg = JSONValue.parse(data)?["error"]?["message"]?.string
        switch status {
        case 400: return HarnessError("请求格式错误：\(msg ?? "")")
        case 401: return HarnessError("API Key 无效，请到设置里检查")
        case 402: return HarnessError("账户余额不足，请到 DeepSeek 开放平台充值")
        case 407: return HarnessError("代理认证失败，检查代理用户名和密码")
        case 422: return HarnessError("参数错误：\(msg ?? "")")
        case 429: return HarnessError("请求太频繁，请稍后再试")
        case 500: return HarnessError("DeepSeek 服务器错误，请稍后重试")
        case 503: return HarnessError("DeepSeek 服务器繁忙，请稍后重试")
        default: return HarnessError(msg ?? "网络错误（\(status)）")
        }
    }
}
