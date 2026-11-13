import SwiftUI

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var store
    @Environment(AgentHub.self) private var hub
    @State private var selection: UUID?
    @State private var showSettings = false
    @State private var pendingDelete: Session?
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                ForEach(store.sorted) { s in
                    SessionRow(session: s, running: hub.isRunning(s.id))
                        .tag(s.id)
                        .contextMenu {
                            Button("删除", systemImage: "trash", role: .destructive) { pendingDelete = s }
                        }
                        .swipeActions {
                            Button("删除", systemImage: "trash", role: .destructive) { pendingDelete = s }
                        }
                }
            }
            .navigationTitle("DeepSeek Harness")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newSession() } label: { Image(systemName: "square.and.pencil") }
                        .keyboardShortcut("n", modifiers: .command)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { showSettings = true } label: { Label("设置", systemImage: "gearshape") }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
            .overlay {
                if store.sessions.isEmpty {
                    ContentUnavailableView("还没有任务", systemImage: "terminal",
                                           description: Text("点右上角新建一个任务"))
                }
            }
        } detail: {
            if let id = selection, store.session(id) != nil {
                SessionView(sessionID: id)
                    .id(id)
            } else {
                WelcomeView(onNew: newSession, onSettings: { showSettings = true })
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .confirmationDialog("删除任务“\(pendingDelete?.title ?? "")”？",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("删除任务和工作区文件", role: .destructive) { delete(removeFiles: true) }
            Button("只删除任务，保留文件") { delete(removeFiles: false) }
        }
        .onAppear {
            if !settings.hasAPIKey { showSettings = true }
        }
    }

    private func newSession() {
        let s = store.create(settings: settings)
        selection = s.id
    }

    private func delete(removeFiles: Bool) {
        guard let s = pendingDelete else { return }
        hub.remove(s.id)
        if selection == s.id { selection = nil }
        store.delete(s.id, removeFiles: removeFiles)
        pendingDelete = nil
    }
}

private struct SessionRow: View {
    let session: Session
    let running: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: running ? "circle.dotted" : "terminal")
                .foregroundStyle(running ? Color.deepBlue : .secondary)
                .symbolEffect(.pulse, isActive: running)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).lineLimit(1)
                HStack(spacing: 6) {
                    Text(session.updatedAt, format: .relative(presentation: .named))
                    Text(session.model == .pro ? "Pro" : "Flash")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WelcomeView: View {
    @Environment(AppSettings.self) private var settings
    let onNew: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(Color.deepBlue)
            Text("DeepSeek Harness").font(.largeTitle.bold())
            Text("让 DeepSeek 在独立的工作区里读写文件、运行 JavaScript、抓取网页，一步步完成任务。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)
            if settings.hasAPIKey {
                Button("新建任务", systemImage: "plus", action: onNew)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Button("填写 API Key", systemImage: "key", action: onSettings)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding()
    }
}
