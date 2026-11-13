import Foundation

/// fetch_url 工具：下载网页并转成纯文本
enum WebFetcher {
    static let maxBytes = 5_000_000

    static func fetch(_ urlString: String, network: NetworkConfig) async throws -> String {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw HarnessError("只支持 http/https 链接：\(urlString)")
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.setValue("Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/json,text/plain;q=0.9,*/*;q=0.5", forHTTPHeaderField: "Accept")

        let session = network.makeSession(forWebFetch: true, timeout: 30)
        let (bytes, resp) = try await session.bytes(for: req)
        let http = resp as? HTTPURLResponse
        var data = Data()
        for try await b in bytes {
            data.append(b)
            if data.count >= maxBytes { break }
        }
        let type = http?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let status = http?.statusCode ?? 0

        guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw HarnessError("无法解码响应（\(type)，\(data.count) 字节）")
        }
        let isHTML = type.contains("html") || raw.prefix(500).lowercased().contains("<html")
        let text = isHTML ? htmlToText(raw) : raw
        var header = "URL: \(http?.url?.absoluteString ?? urlString)\nStatus: \(status)\nContent-Type: \(type)\n"
        if data.count >= maxBytes { header += "（响应超过 5MB，只下载了前 5MB）\n" }
        return header + "\n" + text
    }

    static func htmlToText(_ html: String) -> String {
        var s = html
        let title = s.range(of: "<title[^>]*>([\\s\\S]*?)</title>", options: [.regularExpression, .caseInsensitive])
            .map { String(s[$0]) }
            .map { $0.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) }
        for tag in ["script", "style", "noscript", "svg", "head"] {
            s = s.replacingOccurrences(of: "<\(tag)[\\s\\S]*?</\(tag)>", with: " ",
                                       options: [.regularExpression, .caseInsensitive])
        }
        // 保留链接地址，方便模型继续抓取
        s = s.replacingOccurrences(of: "<a\\s[^>]*href=\"([^\"]+)\"[^>]*>([\\s\\S]*?)</a>", with: "$2 [$1]",
                                   options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<(br|/p|/div|/li|/tr|/h[1-6])[^>]*>", with: "\n",
                                   options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<li[^>]*>", with: "\n- ", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#x27;": "'"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n\\s*\\n+", with: "\n\n", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title { s = "Title: \(title.trimmingCharacters(in: .whitespacesAndNewlines))\n\n" + s }
        return s
    }
}
