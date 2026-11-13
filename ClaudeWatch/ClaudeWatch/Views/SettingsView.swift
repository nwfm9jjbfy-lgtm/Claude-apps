import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ConversationStore.self) private var store
    @State private var newKey = ""
    @State private var confirmDeleteAll = false

    var body: some View {
        @Bindable var s = settings
        List {
            Section("默认模型") {
                Picker("模型", selection: $s.defaultModel) {
                    ForEach(ClaudeModel.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                Picker("思考深度", selection: $s.effort) {
                    ForEach(Effort.allCases) { e in
                        Text(e.displayName).tag(e)
                    }
                }
            }

            Section {
                Toggle("联网搜索", isOn: $s.webSearch)
                Toggle("显示思考过程", isOn: $s.showThinking)
            } footer: {
                Text("联网搜索对新建的对话生效。")
            }

            Section("语音") {
                Toggle("自动朗读回复", isOn: $s.autoSpeak)
                VStack(alignment: .leading) {
                    Text("语速").font(.caption2)
                    Slider(value: $s.speechRate, in: 0.2...0.8, step: 0.1)
                }
                Toggle("触感反馈", isOn: $s.haptics)
            }

            Section {
                TextField("例如：叫我小明，回答尽量简短", text: $s.customInstructions, axis: .vertical)
            } header: {
                Text("自定义指令")
            } footer: {
                Text("对新建的对话生效。")
            }

            Section {
                NavigationLink {
                    NetworkSettingsView()
                } label: {
                    VStack(alignment: .leading) {
                        Text("网络与代理")
                        Text(settings.network.summary).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                SecureField("新的 API Key", text: $newKey)
                if !newKey.isEmpty {
                    Button("保存 Key") {
                        settings.apiKey = newKey
                        newKey = ""
                    }
                }
                Text("当前：…" + String(settings.apiKey.suffix(4)))
                    .font(.caption2).foregroundStyle(.secondary)
                Button("退出（删除 Key）", role: .destructive) {
                    settings.apiKey = ""
                }
            } header: {
                Text("API Key")
            }

            Section("数据") {
                let total = store.conversations.map(\.totalUsage).reduce(Usage(), +)
                LabeledContent("累计估算费用", value: String(format: "$%.3f", total.costUSD))
                Button("删除全部对话", role: .destructive) { confirmDeleteAll = true }
            }
        }
        .navigationTitle("设置")
        .confirmationDialog("删除全部对话？", isPresented: $confirmDeleteAll) {
            Button("删除", role: .destructive) { store.deleteAll() }
        }
    }
}
