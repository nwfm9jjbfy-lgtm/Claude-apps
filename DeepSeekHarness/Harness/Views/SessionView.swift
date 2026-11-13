import SwiftUI

/// 中间：对话 + 工具卡片；右侧检查器：计划和工作区文件
struct SessionView: View {
    let sessionID: UUID
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var store
    @Environment(AgentHub.self) private var hub
    @State private var draft = ""
    @Environment(\.horizontalSizeClass) private var sizeClass
    // iPad 默认展开右侧面板；iPhone 上它是弹出的面板，默认收起
    @State private var showInspector = false
    @FocusState private var inputFocused: Bool

    private var session: Session? { store.session(sessionID) }
    private var runner: AgentRunner { hub.runner(for: sessionID, store: store, settings: settings) }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            composer
        }
        .navigationTitle(session?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                modelPicker
                Button { showInspector.toggle() } label: {
                    Image(systemName: sizeClass == .regular ? "sidebar.right" : "folder")
                }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
        .inspector(isPresented: $showInspector) {
            if let ws = store.workspace(for: sessionID) {
                InspectorView(sessionID: sessionID, workspace: ws)
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
        }
        .onAppear {
            if sizeClass == .regular { showInspector = true }
            if session?.messages.isEmpty == true { inputFocused = true }
        }
    }

    // MARK: 对话

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let s = session {
                        if s.messages.isEmpty { emptyHint }
                        ForEach(Array(s.messages.enumerated()), id: \.offset) { i, m in
                            MessageView(message: m, allMessages: s.messages, runner: runner,
                                        isStreaming: runner.isRunning && i == s.messages.count - 1)
                        }
                    }
                    statusBar.id("bottom")
                }
                .padding(.horizontal, sizeClass == .regular ? 24 : 12)
                .padding(.vertical, 16)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session?.messages.last) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("交给它一个任务").font(.title2.bold())
            Text("比如：")
                .foregroundStyle(.secondary)
            ForEach(["写一个贪吃蛇小游戏 snake.html，可以直接在浏览器打开",
                     "抓取 https://news.ycombinator.com 首页，把前 10 条整理成表格存成 hn.md",
                     "把我导入的 data.csv 按月份汇总，结果写进 summary.md"], id: \.self) { ex in
                Button {
                    draft = ex
                    inputFocused = true
                } label: {
                    Label(ex, systemImage: "arrow.up.right").multilineTextAlignment(.leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 30)
    }

    @ViewBuilder private var statusBar: some View {
        if runner.isRunning {
            HStack(spacing: 8) {
                ProgressView()
                Text(runner.phase.isEmpty ? "运行中…" : runner.phase)
                Text("第 \(runner.step) 步").foregroundStyle(.tertiary)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        } else if let err = runner.lastError {
            VStack(alignment: .leading, spacing: 8) {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                if runner.canResume {
                    Button("继续", systemImage: "play.fill") { runner.resume() }
                        .buttonStyle(.bordered)
                }
            }
        } else if runner.canResume {
            Button("继续", systemImage: "play.fill") { runner.resume() }.buttonStyle(.bordered)
        }
    }

    // MARK: 输入框

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(runner.isRunning ? "运行中，可以先输入下一条…" : "描述任务，⌘↩ 发送",
                      text: $draft, axis: .vertical)
                .lineLimit(1...8)
                .textFieldStyle(.plain)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .focused($inputFocused)

            if runner.isRunning {
                Button(role: .destructive) { runner.stop() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 30))
                }
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button { submit() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !settings.hasAPIKey)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func submit() {
        guard !runner.isRunning else { return }
        runner.send(draft)
        draft = ""
    }

    private var modelPicker: some View {
        Menu {
            ForEach(DeepSeekModel.allCases) { m in
                Button {
                    store.update(sessionID) { $0.model = m }
                } label: {
                    if session?.model == m { Label(m.displayName, systemImage: "checkmark") }
                    else { Text(m.displayName) }
                }
            }
        } label: {
            Label(session?.model.displayName ?? "", systemImage: "cpu")
                .labelStyle(.titleAndIcon)
        }
    }
}
