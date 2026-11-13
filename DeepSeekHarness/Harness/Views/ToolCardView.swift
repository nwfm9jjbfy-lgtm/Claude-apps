import SwiftUI

struct ToolCardView: View {
    let call: JSONValue
    let result: String?
    let status: ToolStatus?
    let onDecide: (Bool) -> Void

    @State private var expanded = false

    private var name: String { call["function"]?["name"]?.string ?? "" }
    private var argsText: String { call["function"]?["arguments"]?.string ?? "" }
    private var args: JSONValue? { JSONValue.parse(argsText) }
    private var kind: ToolKind? { ToolKind(rawValue: name) }

    private var effectiveStatus: ToolStatus {
        if let status { return status }
        guard let result else { return .running }
        if result.hasPrefix("The user denied") { return .denied }
        if result.hasPrefix("Error") || result.hasPrefix("Cancelled") || result.hasPrefix("Interrupted") { return .failed }
        return .done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if effectiveStatus == .waitingApproval { approvalBar }
            if expanded { details }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor.opacity(0.5), lineWidth: 1))
        .onAppear { if effectiveStatus == .waitingApproval { expanded = true } }
        .onChange(of: effectiveStatus) { _, s in if s == .waitingApproval { expanded = true } }
    }

    private var header: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind?.icon ?? "wrench")
                    .frame(width: 22)
                    .foregroundStyle(Color.deepBlue)
                Text(kind?.label ?? name).fontWeight(.medium)
                Text(Tools.summary(name: name, args: args))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                statusIcon
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var statusIcon: some View {
        switch effectiveStatus {
        case .running: ProgressView().controlSize(.small)
        case .waitingApproval: Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .denied: Image(systemName: "nosign").foregroundStyle(.secondary)
        }
    }

    private var borderColor: Color {
        switch effectiveStatus {
        case .waitingApproval: return .orange
        case .failed: return .red
        default: return .gray
        }
    }

    private var approvalBar: some View {
        HStack {
            Text("允许执行这个操作吗？").font(.callout)
            Spacer()
            Button("拒绝", role: .destructive) { onDecide(false) }
                .buttonStyle(.bordered)
            Button("允许") { onDecide(true) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            switch kind {
            case .writeFile:
                CodeBlock(text: args?["content"]?.string ?? argsText, title: args?["path"]?.string)
            case .editFile:
                CodeBlock(text: args?["old_string"]?.string ?? "", title: "替换前", tint: .red)
                CodeBlock(text: args?["new_string"]?.string ?? "", title: "替换后", tint: .green)
            case .runJavaScript:
                CodeBlock(text: args?["code"]?.string ?? argsText, title: "JavaScript")
            case .updatePlan:
                EmptyView()
            default:
                if args == nil, !argsText.isEmpty { CodeBlock(text: argsText, title: "参数") }
            }
            if let result, kind != .updatePlan {
                CodeBlock(text: result, title: "结果", maxLines: 40)
            }
        }
        .padding([.horizontal, .bottom], 12)
    }
}

struct CodeBlock: View {
    let text: String
    var title: String? = nil
    var tint: Color = .clear
    var maxLines: Int? = nil

    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let title { Text(title).font(.caption.bold()).foregroundStyle(.secondary) }
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: { Image(systemName: "doc.on.doc") }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            let lines = text.components(separatedBy: "\n")
            let limited = (maxLines != nil && !showAll && lines.count > maxLines!)
            ScrollView(.horizontal) {
                Text(limited ? lines.prefix(maxLines!).joined(separator: "\n") : text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint == .clear ? Color.black.opacity(0.06) : tint.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8))
            if limited {
                Button("显示全部 \(lines.count) 行") { showAll = true }.font(.caption)
            }
        }
    }
}
