import Foundation
import Network

enum ProxyMode: String, CaseIterable, Codable, Identifiable {
    case off, http, socks5
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "不使用"
        case .http: return "HTTP / HTTPS"
        case .socks5: return "SOCKS5"
        }
    }
}

/// 网络设置：自定义 API 地址 + HTTP / SOCKS5 代理
struct NetworkConfig {
    static let defaultBaseURL = "https://api.anthropic.com"

    var baseURL: String = defaultBaseURL
    var useBearerAuth = false
    var proxyMode: ProxyMode = .off
    var proxyHost = ""
    var proxyPort = 0
    var proxyUser = ""
    var proxyPassword = ""

    /// 规范化后的地址，去掉末尾的 / 和 /v1
    var normalizedBase: String {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = Self.defaultBaseURL }
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/v1") { s.removeLast(3) }
        return s
    }

    func url(_ path: String) throws -> URL {
        guard let u = URL(string: normalizedBase + path), u.host != nil else {
            throw AnthropicError(message: "API 地址格式不对：\(baseURL)", retryable: false)
        }
        return u
    }

    var proxyEnabled: Bool {
        proxyMode != .off && !proxyHost.isEmpty && (1...65535).contains(proxyPort)
    }

    /// 用 watchOS 10 的 Network 框架代理配置（支持 HTTP CONNECT 和 SOCKS5，可带账号密码）
    func apply(to config: URLSessionConfiguration) {
        guard proxyEnabled, let port = NWEndpoint.Port(rawValue: UInt16(proxyPort)) else { return }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxyHost), port: port)
        var proxy: ProxyConfiguration
        switch proxyMode {
        case .http: proxy = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
        case .socks5: proxy = ProxyConfiguration(socksv5Proxy: endpoint)
        case .off: return
        }
        if !proxyUser.isEmpty {
            proxy.applyCredential(username: proxyUser, password: proxyPassword)
        }
        config.proxyConfigurations = [proxy]
    }

    var summary: String {
        var parts: [String] = []
        if normalizedBase != Self.defaultBaseURL {
            parts.append(URL(string: normalizedBase)?.host ?? normalizedBase)
        }
        if proxyEnabled { parts.append("\(proxyMode.displayName) \(proxyHost):\(proxyPort)") }
        return parts.isEmpty ? "直连" : parts.joined(separator: " · ")
    }
}
