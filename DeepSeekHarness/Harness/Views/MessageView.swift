import SwiftUI

/// 渲染一条 API 格式的消息。tool 消息不单独显示，结果嵌在对应的工具卡片里。
struct MessageView: View {
    let message: JSONValue
    let allMessages: [JSONValue]
    let runner: AgentRunner
    let isStreaming: Bool

    @Environment(AppSettings.self) private var settings
    @State private var showReasoning = false

    var body: some View {
        switch message["role"]?.string {
        case "user": userBubble
        case "assistant": assistant
        default: EmptyView()
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 80)
            Text(message["content"]?.string ?? "")
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.deepBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var assistant: some View {
        let reasoning = message["reasoning_content"]?.string ?? ""
        let content = message["content"]?.string ?? ""
        let calls = message["tool_calls"]?.array ?? []

        return VStack(alignment: .leading, spacing: 10) {
            if settings.showReasoning, !reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.snappy) { showReasoning.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                            Text(isStreaming && content.isEmpty && calls.isEmpty ? "思考中…" : "思考过程")
                            Text("\(reasoning.count) 字").foregroundStyle(.tertiary)
                            Image(systemName: showReasoning ? "chevron.up" : "chevron.down")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showReasoning || (isStreaming && content.isEmpty && calls.isEmpty) {
                        Text(showReasoning ? reasoning : String(reasoning.suffix(400)))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(.tertiary).frame(width: 2)
                            }
                    }
                }
            }

            if !content.isEmpty {
                MarkdownView(text: content)
            }

            ForEach(Array(calls.enumerated()), id: \.offset) { _, call in
                let id = call["id"]?.string ?? ""
                ToolCardView(call: call,
                             result: allMessages.first { $0["role"]?.string == "tool" && $0["tool_call_id"]?.string == id }?["content"]?.string,
                             status: runner.toolStatus[id],
                             onDecide: { runner.decide(id, allow: $0) })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
