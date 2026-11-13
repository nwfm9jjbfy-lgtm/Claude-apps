import SwiftUI

struct NetworkSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var portText = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        @Bindable var s = settings
        List {
            Section {
                TextField("https://api.anthropic.com", text: $s.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("Bearer 认证", isOn: $s.useBearerAuth)
                if settings.network.normalizedBase != NetworkConfig.defaultBaseURL {
                    Button("恢复官方地址") { settings.baseURL = NetworkConfig.defaultBaseURL }
                }
            } header: {
                Text("API 地址")
            } footer: {
                Text("用自建网关或兼容 Anthropic 接口的中转地址时修改。注意：中转服务能看到你的 Key 和全部对话内容。")
            }

            Section {
                Picker("类型", selection: $s.proxyMode) {
                    ForEach(ProxyMode.allCases) { m in Text(m.displayName).tag(m) }
                }
                if settings.proxyMode != .off {
                    TextField("服务器地址", text: $s.proxyHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("端口", text: $portText)
                        .onChange(of: portText) { _, v in
                            settings.proxyPort = Int(v.filter(\.isNumber)) ?? 0
                        }
                    TextField("用户名（可选）", text: $s.proxyUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码（可选）", text: $s.proxyPassword)
                }
            } header: {
                Text("代理")
            } footer: {
                Text("只作用于本 App 的 API 请求。需要 watchOS 10 或更新版本。")
            }

            Section {
                Button {
                    runTest()
                } label: {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        if testing { ProgressView().frame(width: 18, height: 18) }
                    }
                }
                .disabled(testing || !settings.hasAPIKey)

                if let testResult {
                    Text(testResult)
                        .font(.footnote)
                        .foregroundStyle(testOK ? .green : .orange)
                }
                if !settings.hasAPIKey {
                    Text("先填 API Key 才能测试").font(.caption2).foregroundStyle(.secondary)
                }
            } footer: {
                Text("当前：\(settings.network.summary)")
            }
        }
        .navigationTitle("网络与代理")
        .onAppear {
            portText = settings.proxyPort > 0 ? String(settings.proxyPort) : ""
        }
    }

    private func runTest() {
        testing = true
        testResult = nil
        let client = settings.makeClient()
        Task {
            do {
                testResult = try await client.testConnection()
                testOK = true
            } catch {
                testResult = error.localizedDescription
                testOK = false
            }
            testing = false
        }
    }
}
