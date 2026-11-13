import SwiftUI
import QuickLook
import UniformTypeIdentifiers

/// 右侧面板：任务计划 + 工作区文件
struct InspectorView: View {
    let sessionID: UUID
    let workspace: Workspace
    @Environment(SessionStore.self) private var store
    @State private var files: [FileEntry] = []
    @State private var preview: URL?
    @State private var importing = false
    @State private var importError: String?

    private var session: Session? { store.session(sessionID) }

    var body: some View {
        List {
            if let plan = session?.plan, !plan.isEmpty {
                Section("计划") {
                    ForEach(plan) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon(item.status))
                                .foregroundStyle(item.status == "completed" ? .green :
                                                 item.status == "in_progress" ? Color.deepBlue : .secondary)
                            Text(item.content)
                                .strikethrough(item.status == "completed")
                                .foregroundStyle(item.status == "completed" ? .secondary : .primary)
                        }
                        .font(.callout)
                    }
                }
            }

            Section {
                if files.isEmpty {
                    Text("工作区是空的").foregroundStyle(.secondary)
                }
                ForEach(files) { f in
                    Button {
                        if !f.isDirectory, let url = try? workspace.resolve(f.path) { preview = url }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: f.isDirectory ? "folder.fill" : fileIcon(f.name))
                                .foregroundStyle(f.isDirectory ? Color.deepBlue : .secondary)
                            Text(f.name).lineLimit(1)
                            Spacer()
                            if !f.isDirectory {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(f.size), countStyle: .file))
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.leading, CGFloat(f.depth) * 16)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let url = try? workspace.resolve(f.path) {
                            ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") }
                        }
                        Button("删除", systemImage: "trash", role: .destructive) {
                            try? workspace.delete(f.path)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("工作区文件")
                    Spacer()
                    Button { importing = true } label: { Image(systemName: "plus") }
                    ShareLink(item: workspace.root) { Image(systemName: "square.and.arrow.up") }
                }
            } footer: {
                Text("也可以在“文件”App → 我的 iPad → DS Harness → \(session?.workspaceFolder ?? "") 里查看")
            }

            if let u = session?.usage {
                Section("用量") {
                    LabeledContent("输入（缓存命中）", value: fmt(u.cacheHit))
                    LabeledContent("输入（未命中）", value: fmt(u.cacheMiss))
                    LabeledContent("输出", value: fmt(u.output))
                    LabeledContent("其中思考", value: fmt(u.reasoning))
                    LabeledContent("估算费用", value: String(format: "$%.4f", u.costUSD))
                }
            }
        }
        .listStyle(.insetGrouped)
        .quickLookPreview($preview, in: files.filter { !$0.isDirectory }.compactMap { try? workspace.resolve($0.path) })
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for u in urls {
                    do { _ = try workspace.importFile(from: u) } catch { importError = error.localizedDescription }
                }
            case .failure(let e):
                importError = e.localizedDescription
            }
        }
        .alert("导入失败", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("好") {}
        } message: { Text(importError ?? "") }
        .onAppear(perform: reload)
        .onChange(of: workspace.revision) { _, _ in reload() }
        .refreshable { reload() }
    }

    private func reload() {
        files = (try? workspace.list(".")) ?? []
    }

    private func icon(_ status: String) -> String {
        switch status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "circle.dotted.circle"
        default: return "circle"
        }
    }

    private func fileIcon(_ name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "html", "htm": return "globe"
        case "js", "ts", "json", "swift", "py", "css": return "chevron.left.forwardslash.chevron.right"
        case "md", "txt": return "doc.text"
        case "csv", "xlsx": return "tablecells"
        case "png", "jpg", "jpeg", "gif", "svg", "heic": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.2fM", Double(n) / 1e6)
            : n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}
