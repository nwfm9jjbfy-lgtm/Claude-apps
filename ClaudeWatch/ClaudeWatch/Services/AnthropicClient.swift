import Foundation

struct AnthropicError: LocalizedError {
    let message: String
    var retryable = true
    var errorDescription: String? { message }
}

/// 流式过程中给界面的实时快照
struct StreamSnapshot {
    var text = ""
    var thinking = ""
    var searchQueries: [String] = []
    var isSearching = false
    var model: String?
}

struct StreamResult {
    var content: [JSONValue]
    var stopReason: String?
    var model: String?
    var usage: Usage
}

/// 直接用 HTTPS 调用 Claude Messages API（Swift 没有官方 SDK）。
final class AnthropicClient {
    static let apiVersion = "2026-10-21"

    let apiKey: String
    let network: NetworkConfig
    private let session: URLSession

    init(apiKey: String, network: NetworkConfig = NetworkConfig()) {
        self.apiKey = apiKey
        self.network = network
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 900
        config.waitsForConnectivity = !network.proxyEnabled
        network.apply(to: config)
        self.session = URLSession(configuration: config)
    }

    private func authorize(_ req: inout URLRequest) {
        req.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if network.useBearerAuth {
            // 部分中转网关要求 Authorization: Bearer
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        } else {
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
    }

    private func makeRequest(body: JSONValue, betas: [String]) throws -> URLRequest {
        var req = URLRequest(url: try network.url("/v1/messages"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        authorize(&req)
        if !betas.isEmpty {
            req.setValue(betas.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    // MARK: 测试连接（列出模型，不消耗 token）

    func testConnection() async throws -> String {
        var req = URLRequest(url: try network.url("/v1/models?limit=1"))
        req.timeoutInterval = 20
        authorize(&req)
        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as URLError {
            throw AnthropicError(message: Self.describe(e))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.httpError(status: status, data: data) }
        return String(format: "连接成功 · %.0f ms", Date().timeIntervalSince(start) * 1000)
    }

    static func describe(_ e: URLError) -> String {
        switch e.code {
        case .timedOut: return "连接超时，检查网络或代理"
        case .cannotFindHost, .dnsLookupFailed: return "找不到服务器，检查 API 地址或代理地址"
        case .cannotConnectToHost: return "连不上服务器或代理，检查地址和端口"
        case .notConnectedToInternet: return "手表没有联网"
        case .secureConnectionFailed, .serverCertificateUntrusted: return "TLS 握手失败，检查代理或 API 地址"
        case .userAuthenticationRequired: return "代理需要用户名和密码"
        default: return "网络错误：\(e.localizedDescription)"
        }
    }

    // MARK: 非流式（用于生成标题）

    func send(body: JSONValue, betas: [String] = []) async throws -> JSONValue {
        let req = try makeRequest(body: body, betas: betas)
        let (data, response) = try await session.data(for: req)

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.httpError(status: status, data: data) }
        guard let json = JSONValue.parse(data) else {
            throw AnthropicError(message: "无法解析服务器响应")
        }
        return json
    }

    // MARK: 流式

    func stream(body: JSONValue,
                betas: [String],
                pricing: ClaudeModel,
                onUpdate: @escaping @MainActor (StreamSnapshot) -> Void) async throws -> StreamResult {
        let req = try makeRequest(body: body, betas: betas)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: req)
        } catch let e as URLError where e.code != .cancelled {
            throw AnthropicError(message: Self.describe(e))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            var data = Data()
            for try await b in bytes { data.append(b) }
            throw Self.httpError(status: status, data: data)
        }

        var acc = StreamAccumulator()
        var lastPush = Date.distantPast

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let event = JSONValue.parse(payload) else { continue }
            try acc.handle(event)

            // 限制界面刷新频率，省电
            if Date().timeIntervalSince(lastPush) > 0.12 {
                lastPush = Date()
                let snap = acc.snapshot
                await onUpdate(snap)
            }
        }
        await onUpdate(acc.snapshot)

        return StreamResult(content: acc.finalContent(),
                            stopReason: acc.stopReason,
                            model: acc.model,
                            usage: acc.usage(pricing: ClaudeModel.from(id: acc.model) ?? pricing))
    }

    static func httpError(status: Int, data: Data) -> AnthropicError {
        let json = JSONValue.parse(data)
        let apiMessage = json?["error"]?["message"]?.string
        let type = json?["error"]?["type"]?.string
        switch status {
        case 401: return AnthropicError(message: "API Key 无效，请到设置里检查", retryable: false)
        case 403: return AnthropicError(message: "没有权限：\(apiMessage ?? "账号无法使用该模型")", retryable: false)
        case 404: return AnthropicError(message: "找不到模型：\(apiMessage ?? "")", retryable: false)
        case 407: return AnthropicError(message: "代理认证失败，检查代理用户名和密码", retryable: false)
        case 413: return AnthropicError(message: "对话太长了，请开个新对话", retryable: false)
        case 429: return AnthropicError(message: "请求太频繁或额度不足，稍后再试")
        case 400:
            if type == "invalid_request_error", apiMessage?.contains("credit balance") == true {
                return AnthropicError(message: "账户余额不足，请到 Console 充值", retryable: false)
            }
            return AnthropicError(message: "请求错误：\(apiMessage ?? "未知")", retryable: false)
        case 500...599: return AnthropicError(message: "服务器繁忙（\(status)），请重试")
        default: return AnthropicError(message: apiMessage ?? "网络错误（\(status)）")
        }
    }
}

/// 把 SSE 事件拼成完整的内容块
private struct StreamAccumulator {
    var blocks: [Int: [String: JSONValue]] = [:]
    var partialJSON: [Int: String] = [:]
    var stopReason: String?
    var model: String?
    var inputTokens = 0
    var outputTokens = 0
    var cacheRead = 0
    var cacheWrite = 0
    var snapshot = StreamSnapshot()

    mutating func handle(_ event: JSONValue) throws {
        switch event["type"]?.string {
        case "message_start":
            let msg = event["message"]
            model = msg?["model"]?.string
            snapshot.model = model
            readUsage(msg?["usage"])

        case "content_block_start":
            guard let idx = event["index"]?.int,
                  let block = event["content_block"]?.object else { return }
            blocks[idx] = block
            if block["type"]?.string == "server_tool_use" {
                snapshot.isSearching = true
            }
            if block["type"]?.string == "web_search_tool_result" {
                snapshot.isSearching = false
            }

        case "content_block_delta":
            guard let idx = event["index"]?.int, let delta = event["delta"],
                  var block = blocks[idx] else { return }
            switch delta["type"]?.string {
            case "text_delta":
                let t = delta["text"]?.string ?? ""
                block["text"] = .string((block["text"]?.string ?? "") + t)
                snapshot.text += t
            case "thinking_delta":
                let t = delta["thinking"]?.string ?? ""
                block["thinking"] = .string((block["thinking"]?.string ?? "") + t)
                snapshot.thinking += t
            case "signature_delta":
                block["signature"] = .string((block["signature"]?.string ?? "") + (delta["signature"]?.string ?? ""))
            case "input_json_delta":
                partialJSON[idx, default: ""] += delta["partial_json"]?.string ?? ""
            case "citations_delta":
                if let c = delta["citation"] {
                    var list = block["citations"]?.array ?? []
                    list.append(c)
                    block["citations"] = .array(list)
                }
            default: break
            }
            blocks[idx] = block

        case "content_block_stop":
            guard let idx = event["index"]?.int, var block = blocks[idx] else { return }
            if let raw = partialJSON[idx] {
                block["input"] = raw.isEmpty ? .object([:]) : (JSONValue.parse(raw) ?? .object([:]))
                partialJSON[idx] = nil
                blocks[idx] = block
            }
            if block["type"]?.string == "server_tool_use",
               let q = block["input"]?["query"]?.string {
                snapshot.searchQueries.append(q)
            }

        case "message_delta":
            if let r = event["delta"]?["stop_reason"]?.string { stopReason = r }
            readUsage(event["usage"])

        case "error":
            let msg = event["error"]?["message"]?.string ?? "流式传输中断"
            let type = event["error"]?["type"]?.string
            throw AnthropicError(message: type == "overloaded_error" ? "服务器繁忙，请重试" : msg)

        default:
            break // ping 等
        }
    }

    mutating func readUsage(_ u: JSONValue?) {
        guard let u else { return }
        if let v = u["input_tokens"]?.int { inputTokens = v }
        if let v = u["output_tokens"]?.int { outputTokens = v }
        if let v = u["cache_read_input_tokens"]?.int { cacheRead = v }
        if let v = u["cache_creation_input_tokens"]?.int { cacheWrite = v }
    }

    func usage(pricing m: ClaudeModel) -> Usage {
        let cost = (Double(inputTokens) * m.inputPrice
                    + Double(cacheWrite) * m.inputPrice * 1.25
                    + Double(cacheRead) * m.cacheReadPrice
                    + Double(outputTokens) * m.outputPrice) / 1_000_000
        return Usage(inputTokens: inputTokens, outputTokens: outputTokens,
                     cacheReadTokens: cacheRead, cacheWriteTokens: cacheWrite, costUSD: cost)
    }

    /// 整理成可以原样回传的内容块
    func finalContent() -> [JSONValue] {
        var out: [JSONValue] = []
        for idx in blocks.keys.sorted() {
            guard var b = blocks[idx] else { continue }
            if b["type"]?.string == "text" {
                // 空文本块会被 API 拒绝
                if (b["text"]?.string ?? "").isEmpty { continue }
                if let c = b["citations"], c.isNull || (c.array?.isEmpty ?? false) {
                    b["citations"] = nil
                }
            }
            out.append(.object(b))
        }
        return Self.sanitizeAfterFallback(out)
    }

    /// 中途自动回退后：最后一个 fallback 块之前的 thinking / tool_use、
    /// 以及没有配对结果的 server_tool_use 不能再回传；fallback 块本身保留原位。
    static func sanitizeAfterFallback(_ content: [JSONValue]) -> [JSONValue] {
        guard let last = content.lastIndex(where: { $0["type"]?.string == "fallback" }) else {
            return content
        }
        let resultIDs = Set(content.compactMap { b -> String? in
            guard let t = b["type"]?.string, t.hasSuffix("_tool_result") else { return nil }
            return b["tool_use_id"]?.string
        })
        return content.enumerated().compactMap { (i: Int, b: JSONValue) -> JSONValue? in
            guard i < last else { return b }
            switch b["type"]?.string {
            case "thinking", "redacted_thinking", "tool_use":
                return nil
            case "server_tool_use":
                return resultIDs.contains(b["id"]?.string ?? "") ? b : nil
            default:
                return b
            }
        }
    }
}
