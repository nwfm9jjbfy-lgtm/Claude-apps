import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var keyDraft = ""
    @State private var portText = ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section {
                    SecureField(settings.hasAPIKey ? "已保存（…\(settings.apiKey.suffix(4))），输入新 Key 替换" : "sk-…",
                                text: $keyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !keyDraft.isEmpty {
                        Button("保存 Key") {
                            settings.apiKey = keyDraft
                            keyDraft = ""
                        }
                    }
                    if settings.hasAPIKey {
                        Button("删除 Key", role: .destructive) { settings.apiKey = "" }
                    }
                } header: {
                    Text("DeepSeek API Key")
                } footer: {
                    Text("在 platform.deepseek.com 创建。Key 保存在 iPad 的钥匙串里。")
                }

                Section {
                    Picker("新任务默认模型", selection: $s.defaultModel) {
                        ForEach(DeepSeekModel.allCases) { m in
                            VStack(alignment: .leading) {
                                Text(m.displayName)
                                Text(m.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(m)
                        }
                    }
                    Picker("思考强度", selection: $s.effort) {
                        ForEach(ReasoningEffort.allCases) { e in Text(e.displayName).tag(e) }
                    }
                    Toggle("显示思考过程", isOn: $s.showReasoning)
                } header: {
                    Text("模型")
                }

                Section {
                    Picker("权限", selection: $s.permissionMode) {
                        ForEach(PermissionMode.allCases) { p in Text(p.displayName).tag(p) }
                    }
                    Stepper("每次最多 \(settings.maxSteps) 步", value: $s.maxSteps, in: 5...200, step: 5)
                } header: {
                    Text("Agent")
                } footer: {
                    Text("“改动前询问”：写入、修改、删除文件和运行代码前都要你点允许。读取文件、抓取网页不需要批准。所有操作都只发生在该任务的工作区里。")
                }

                Section {
                    TextField("例如：代码注释用中文；网页用深色主题", text: $s.customInstructions, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("自定义指令")
                } footer: {
                    Text("对新建的任务生效。")
                }

                Section {
                    TextField(NetworkConfig.defaultBaseURL, text: $s.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Picker("代理", selection: $s.proxyMode) {
                        ForEach(ProxyMode.allCases) { m in Text(m.displayName).tag(m) }
                    }
                    if settings.proxyMode != .off {
                        TextField("代理服务器地址", text: $s.proxyHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("端口", text: $portText)
                            .keyboardType(.numberPad)
                            .onChange(of: portText) { _, v in settings.proxyPort = Int(v.filter(\.isNumber)) ?? 0 }
                        TextField("用户名（可选）", text: $s.proxyUser)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("密码（可选）", text: $s.proxyPassword)
                        Toggle("抓取网页也走代理", isOn: $s.proxyForWebFetch)
                    }
                    Button {
                        runTest()
                    } label: {
                        HStack {
                            Text("测试连接")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing || !settings.hasAPIKey)
                    if let testResult {
                        Text(testResult).font(.callout).foregroundStyle(testOK ? .green : .orange)
                    }
                } header: {
                    Text("网络与代理")
                } footer: {
                    Text("当前：\(settings.network.summary)。代理只作用于本 App。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .onAppear { portText = settings.proxyPort > 0 ? String(settings.proxyPort) : "" }
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
