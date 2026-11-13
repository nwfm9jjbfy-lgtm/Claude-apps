import Foundation
import Observation

@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { KeychainStore.delete() } else { KeychainStore.save(trimmed) }
        }
    }
    var defaultModel: ClaudeModel { didSet { defaults.set(defaultModel.rawValue, forKey: "model") } }
    var effort: Effort { didSet { defaults.set(effort.rawValue, forKey: "effort") } }
    var webSearch: Bool { didSet { defaults.set(webSearch, forKey: "webSearch") } }
    var showThinking: Bool { didSet { defaults.set(showThinking, forKey: "showThinking") } }
    var autoSpeak: Bool { didSet { defaults.set(autoSpeak, forKey: "autoSpeak") } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    var customInstructions: String { didSet { defaults.set(customInstructions, forKey: "customInstructions") } }
    var speechRate: Double { didSet { defaults.set(speechRate, forKey: "speechRate") } }

    // 网络 / 代理
    var baseURL: String { didSet { defaults.set(baseURL, forKey: "baseURL") } }
    var useBearerAuth: Bool { didSet { defaults.set(useBearerAuth, forKey: "useBearerAuth") } }
    var proxyMode: ProxyMode { didSet { defaults.set(proxyMode.rawValue, forKey: "proxyMode") } }
    var proxyHost: String { didSet { defaults.set(proxyHost, forKey: "proxyHost") } }
    var proxyPort: Int { didSet { defaults.set(proxyPort, forKey: "proxyPort") } }
    var proxyUser: String { didSet { defaults.set(proxyUser, forKey: "proxyUser") } }
    var proxyPassword: String {
        didSet {
            if proxyPassword.isEmpty { KeychainStore.delete(KeychainStore.proxyPasswordAccount) }
            else { KeychainStore.save(proxyPassword, account: KeychainStore.proxyPasswordAccount) }
        }
    }

    var network: NetworkConfig {
        NetworkConfig(baseURL: baseURL, useBearerAuth: useBearerAuth, proxyMode: proxyMode,
                      proxyHost: proxyHost.trimmingCharacters(in: .whitespaces), proxyPort: proxyPort,
                      proxyUser: proxyUser, proxyPassword: proxyPassword)
    }

    func makeClient() -> AnthropicClient {
        AnthropicClient(apiKey: apiKey, network: network)
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init() {
        apiKey = KeychainStore.load() ?? ""
        defaultModel = ClaudeModel.from(id: defaults.string(forKey: "model")) ?? .opus
        effort = Effort(rawValue: defaults.string(forKey: "effort") ?? "") ?? .medium
        webSearch = defaults.object(forKey: "webSearch") as? Bool ?? true
        showThinking = defaults.object(forKey: "showThinking") as? Bool ?? true
        autoSpeak = defaults.object(forKey: "autoSpeak") as? Bool ?? false
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        customInstructions = defaults.string(forKey: "customInstructions") ?? ""
        speechRate = defaults.object(forKey: "speechRate") as? Double ?? 0.5
        baseURL = defaults.string(forKey: "baseURL") ?? NetworkConfig.defaultBaseURL
        useBearerAuth = defaults.bool(forKey: "useBearerAuth")
        proxyMode = ProxyMode(rawValue: defaults.string(forKey: "proxyMode") ?? "") ?? .off
        proxyHost = defaults.string(forKey: "proxyHost") ?? ""
        proxyPort = defaults.integer(forKey: "proxyPort")
        proxyUser = defaults.string(forKey: "proxyUser") ?? ""
        proxyPassword = KeychainStore.load(KeychainStore.proxyPasswordAccount) ?? ""
    }

    /// 新对话的系统提示（创建时冻结）
    func makeSystemPrompt() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy年M月d日 EEEE"
        var s = """
        You are Claude, made by Anthropic, chatting with the user through an app on their Apple Watch. \
        The screen is tiny and the user may be reading at a glance or listening via text-to-speech. \
        Lead with the answer. Keep replies short and scannable: brief paragraphs or short lists, \
        no tables, no wide code blocks, and no headings unless the user asks for detail. \
        If the user asks for something long, give a compact version and offer to expand. \
        Reply in the language the user writes in. Voice input may contain transcription errors; \
        infer the intended meaning. Today's date is \(df.string(from: Date())).
        """
        let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            s += "\n\nThe user's custom instructions:\n\(custom)"
        }
        return s
    }
}
