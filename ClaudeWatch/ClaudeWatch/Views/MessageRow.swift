import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    let isLast: Bool
    let isStreaming: Bool
    let isSearching: Bool
    let onRetry: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(SpeechService.self) private var speech
    @State private var showThinking = false

    var body: some View {
        switch message.role {
        case .user: userBubble
        case .assistant: assistantBody
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 18)
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.claudeOrange.opacity(message.excluded ? 0.12 : 0.28),
                            in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var assistantBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if settings.showThinking, !message.thinking.isEmpty {
                Button {
                    withAnimation { showThinking.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                        Text(isStreaming && message.text.isEmpty ? "思考中…" : "思考过程")
                        Spacer()
                        Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showThinking {
                    Text(message.thinking)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(.secondary.opacity(0.4)).frame(width: 2)
                        }
                }
            }

            ForEach(message.searchQueries, id: \.self) { q in
                Label(q, systemImage: "magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let error = message.error {
                VStack(alignment: .leading, spacing: 4) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    if isLast {
                        Button("重试", action: onRetry).font(.footnote)
                    }
                }
            } else if message.text.isEmpty && isStreaming {
                HStack(spacing: 6) {
                    ProgressView().frame(width: 18, height: 18)
                    Text(isSearching ? "正在搜索…" : "思考中…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text(Markdown.render(message.text))
                    .font(.body)
            }

            if !message.sources.isEmpty, !isStreaming {
                VStack(alignment: .leading, spacing: 2) {
                    Text("来源").font(.caption2.bold()).foregroundStyle(.secondary)
                    ForEach(message.sources.prefix(5), id: \.url) { s in
                        if let url = URL(string: s.url) {
                            Link(destination: url) {
                                Text(s.title).font(.caption2).lineLimit(1)
                            }
                        }
                    }
                }
            }

            if !isStreaming, message.error == nil, !message.text.isEmpty {
                HStack(spacing: 14) {
                    Button {
                        speech.toggle(message.text, id: message.id, rate: settings.speechRate)
                    } label: {
                        Image(systemName: speech.speakingID == message.id ? "stop.circle" : "speaker.wave.2")
                    }
                    if isLast {
                        Button(action: onRetry) { Image(systemName: "arrow.clockwise") }
                    }
                    Spacer()
                    if let served = message.servedModel, let m = ClaudeModel.from(id: served) {
                        Text(m.displayName).font(.system(size: 10)).foregroundStyle(.tertiary)
                    } else if let served = message.servedModel {
                        Text(served).font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
                .font(.footnote)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Markdown {
    /// 小屏幕上的简化 Markdown：标题变粗体，列表符号变圆点，行内格式交给系统解析
    static func render(_ s: String) -> AttributedString {
        var t = s
        t = t.replacingOccurrences(of: "(?m)^#{1,6}\\s+(.+)$", with: "**$1**", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?m)^(\\s*)[-*+]\\s+", with: "$1• ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?m)^```.*$", with: "", options: .regularExpression)
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: t, options: opts)) ?? AttributedString(s)
    }
}
