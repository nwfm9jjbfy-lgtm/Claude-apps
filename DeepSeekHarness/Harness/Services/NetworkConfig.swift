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

/// API 地址 + HTTP / SOCKS5 代理（iPadOS 17 的 proxyConfigurations）
struct NetworkConfig {
    static let defaultBaseURL = "https://api.deepseek.com"

    var baseURL = defaultBaseURL
    var proxyMode: ProxyMode = .off
    var proxyHost = ""
    var proxyPort = 0
    var proxyUser = ""
    var proxyPassword = ""
    /// 代理是否也用于 fetch_url 工具
    var proxyForWebFetch = true

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
            throw HarnessError("API 地址格式不对：\(baseURL)")
        }
        return u
    }

    var proxyEnabled: Bool {
        proxyMode != .off && !proxyHost.isEmpty && (1...65535).contains(proxyPort)
    }

    func makeSession(forWebFetch: Bool = false, timeout: TimeInterval = 600) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = 3600
        if proxyEnabled, !(forWebFetch && !proxyForWebFetch),
           let port = NWEndpoint.Port(rawValue: UInt16(proxyPort)) {
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(proxyHost), port: port)
            var proxy: ProxyConfiguration
            switch proxyMode {
            case .http: proxy = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
            case .socks5: proxy = ProxyConfiguration(socksv5Proxy: endpoint)
            case .off: return URLSession(configuration: config)
            }
            if !proxyUser.isEmpty { proxy.applyCredential(username: proxyUser, password: proxyPassword) }
            config.proxyConfigurations = [proxy]
        }
        return URLSession(configuration: config)
    }

    var summary: String {
        var parts: [String] = []
        if normalizedBase != Self.defaultBaseURL { parts.append(URL(string: normalizedBase)?.host ?? normalizedBase) }
        if proxyEnabled { parts.append("\(proxyMode.displayName) \(proxyHost):\(proxyPort)") }
        return parts.isEmpty ? "直连官方 API" : parts.joined(separator: " · ")
    }
}

struct HarnessError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
