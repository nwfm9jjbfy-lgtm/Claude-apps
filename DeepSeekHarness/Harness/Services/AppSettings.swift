import Foundation
import Observation

@Observable
final class AppSettings {
    private let d = UserDefaults.standard

    var apiKey: String {
        didSet {
            let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if k.isEmpty { KeychainStore.delete() } else { KeychainStore.save(k) }
        }
    }
    var defaultModel: DeepSeekModel { didSet { d.set(defaultModel.rawValue, forKey: "model") } }
    var effort: ReasoningEffort { didSet { d.set(effort.rawValue, forKey: "effort") } }
    var permissionMode: PermissionMode { didSet { d.set(permissionMode.rawValue, forKey: "permission") } }
    var maxSteps: Int { didSet { d.set(maxSteps, forKey: "maxSteps") } }
    var customInstructions: String { didSet { d.set(customInstructions, forKey: "custom") } }
    var showReasoning: Bool { didSet { d.set(showReasoning, forKey: "showReasoning") } }

    var baseURL: String { didSet { d.set(baseURL, forKey: "baseURL") } }
    var proxyMode: ProxyMode { didSet { d.set(proxyMode.rawValue, forKey: "proxyMode") } }
    var proxyHost: String { didSet { d.set(proxyHost, forKey: "proxyHost") } }
    var proxyPort: Int { didSet { d.set(proxyPort, forKey: "proxyPort") } }
    var proxyUser: String { didSet { d.set(proxyUser, forKey: "proxyUser") } }
    var proxyForWebFetch: Bool { didSet { d.set(proxyForWebFetch, forKey: "proxyForWebFetch") } }
    var proxyPassword: String {
        didSet {
            if proxyPassword.isEmpty { KeychainStore.delete(KeychainStore.proxyPasswordAccount) }
            else { KeychainStore.save(proxyPassword, account: KeychainStore.proxyPasswordAccount) }
        }
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var network: NetworkConfig {
        NetworkConfig(baseURL: baseURL, proxyMode: proxyMode,
                      proxyHost: proxyHost.trimmingCharacters(in: .whitespaces), proxyPort: proxyPort,
                      proxyUser: proxyUser, proxyPassword: proxyPassword, proxyForWebFetch: proxyForWebFetch)
    }

    func makeClient() -> DeepSeekClient {
        DeepSeekClient(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines), network: network)
    }

    init() {
        apiKey = KeychainStore.load() ?? ""
        defaultModel = DeepSeekModel(rawValue: d.string(forKey: "model") ?? "") ?? .flash
        effort = ReasoningEffort(rawValue: d.string(forKey: "effort") ?? "") ?? .high
        permissionMode = PermissionMode(rawValue: d.string(forKey: "permission") ?? "") ?? .ask
        maxSteps = d.object(forKey: "maxSteps") as? Int ?? 40
        customInstructions = d.string(forKey: "custom") ?? ""
        showReasoning = d.object(forKey: "showReasoning") as? Bool ?? true
        baseURL = d.string(forKey: "baseURL") ?? NetworkConfig.defaultBaseURL
        proxyMode = ProxyMode(rawValue: d.string(forKey: "proxyMode") ?? "") ?? .off
        proxyHost = d.string(forKey: "proxyHost") ?? ""
        proxyPort = d.integer(forKey: "proxyPort")
        proxyUser = d.string(forKey: "proxyUser") ?? ""
        proxyForWebFetch = d.object(forKey: "proxyForWebFetch") as? Bool ?? true
        proxyPassword = KeychainStore.load(KeychainStore.proxyPasswordAccount) ?? ""
    }

    /// 新会话的系统提示（创建时冻结）
    func makeSystemPrompt() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var s = """
        You are an autonomous agent running inside "DeepSeek Harness", an iPad app. You complete the user's task \
        by working step by step with the tools provided, then report back.

        Environment:
        - You have a private workspace folder. All file paths are relative to the workspace root ("." is the root). \
        You cannot access anything outside it. The user can see the workspace in the app's file panel and in the iPad Files app.
        - run_javascript executes JavaScript in JavaScriptCore (no DOM, no Node.js, no network, no npm). \
        Use it for calculations, data processing and verifying logic. It can read and write workspace files \
        through readFile(path), writeFile(path, text) and listFiles(path). Print results with console.log.
        - fetch_url downloads a web page or API response as text. There is no search engine; fetch a known URL \
        (for example a documentation page or a search results page) when you need information from the web.
        - There is no shell, no Python and no compiler.

        How to work:
        - For anything beyond a quick question, first call update_plan with a short checklist, and keep it updated \
        as you finish each step.
        - Read files before editing them. Prefer edit_file for small changes and write_file for new files or rewrites.
        - Verify your work when you can (re-read the file, run a check in run_javascript).
        - If a tool call is denied by the user, do not retry the same action; adjust or ask the user.
        - Keep your messages to the user brief. When finished, summarize what you did and which files you created or changed.
        - Reply in the language the user writes in.

        Today's date is \(df.string(from: Date())).
        """
        let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { s += "\n\nUser's custom instructions:\n\(custom)" }
        return s
    }
}
