import SwiftUI

/// 轻量 Markdown：代码块、标题、列表、引用和行内格式
struct MarkdownView: View {
    let text: String

    private enum Block: Hashable {
        case code(lang: String, body: String)
        case heading(level: Int, text: String)
        case paragraph(String)
        case quote(String)
        case rule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.parse(text).enumerated()), id: \.offset) { _, b in
                switch b {
                case .code(let lang, let body):
                    CodeBlock(text: body, title: lang.isEmpty ? nil : lang)
                case .heading(let level, let t):
                    Text(Self.inline(t))
                        .font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                        .padding(.top, 4)
                case .paragraph(let t):
                    Text(Self.inline(t)).textSelection(.enabled)
                case .quote(let t):
                    Text(Self.inline(t))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) { Rectangle().fill(.tertiary).frame(width: 3) }
                case .rule:
                    Divider()
                }
            }
        }
    }

    private static func inline(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }

    private static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var para: [String] = []
        var quote: [String] = []
        var inCode = false
        var codeLang = ""
        var code: [String] = []

        func flush() {
            if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: "\n"))); para = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))); quote = [] }
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(lang: codeLang, body: code.joined(separator: "\n")))
                    code = []; inCode = false
                } else {
                    flush()
                    inCode = true
                    codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if inCode { code.append(line); continue }

            if trimmed.isEmpty { flush(); continue }
            if trimmed == "---" || trimmed == "***" { flush(); blocks.append(.rule); continue }
            if let m = trimmed.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
                flush()
                blocks.append(.heading(level: m.1.count, text: String(m.2)))
                continue
            }
            if trimmed.hasPrefix(">") {
                if !para.isEmpty { flush() }
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            // 列表项：把 - / * 换成圆点，保留缩进
            if let m = line.firstMatch(of: /^(\s*)[-*+]\s+(.*)$/) {
                para.append(String(m.1) + "• " + String(m.2))
                continue
            }
            para.append(line)
        }
        if inCode { blocks.append(.code(lang: codeLang, body: code.joined(separator: "\n"))) }
        flush()
        return blocks
    }
}
