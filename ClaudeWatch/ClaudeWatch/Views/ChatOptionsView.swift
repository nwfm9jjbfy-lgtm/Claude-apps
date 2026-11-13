import SwiftUI

/// 对话内的选项：切换模型、重新生成、用量
struct ChatOptionsView: View {
    let controller: ChatController
    @Environment(ConversationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let c = store.conversation(controller.conversationID) {
            List {
                Section("模型") {
                    ForEach(ClaudeModel.allCases) { m in
                        Button {
                            controller.switchModel(m)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(m.displayName)
                                    Text(m.subtitle).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if c.model == m {
                                    Image(systemName: "checkmark").foregroundStyle(Color.claudeOrange)
                                }
                            }
                        }
                    }
                }

                if c.messages.last?.role == .assistant, !controller.isStreaming {
                    Button {
                        controller.regenerate()
                        dismiss()
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                    }
                }

                Section("本对话") {
                    LabeledContent("联网搜索", value: c.webSearch ? "开" : "关")
                    let u = c.totalUsage
                    LabeledContent("输入", value: Self.tokens(u.inputTokens + u.cacheReadTokens + u.cacheWriteTokens))
                    LabeledContent("输出", value: Self.tokens(u.outputTokens))
                    LabeledContent("估算费用", value: String(format: "$%.4f", u.costUSD))
                }

                Button(role: .destructive) {
                    controller.stop()
                    store.delete(c.id)
                    dismiss()
                } label: {
                    Label("删除对话", systemImage: "trash")
                }
            }
            .navigationTitle("选项")
        }
    }

    static func tokens(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}
