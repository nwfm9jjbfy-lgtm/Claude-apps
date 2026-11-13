import SwiftUI

struct ChatView: View {
    let conversationID: UUID
    @Environment(AppSettings.self) private var settings
    @Environment(ConversationStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @State private var controller: ChatController?
    @State private var draft = ""
    @State private var showOptions = false

    private var conversation: Conversation? { store.conversation(conversationID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let c = conversation {
                        if c.messages.isEmpty {
                            EmptyChatHint(model: c.model)
                        }
                        ForEach(Array(c.messages.enumerated()), id: \.element.id) { i, m in
                            MessageRow(message: m,
                                       isLast: i == c.messages.count - 1,
                                       isStreaming: (controller?.isStreaming ?? false) && i == c.messages.count - 1,
                                       isSearching: controller?.isSearching ?? false,
                                       onRetry: { controller?.regenerate() })
                                .id(m.id)
                        }
                    }

                    ComposeField(draft: $draft, disabled: controller?.isStreaming ?? false) {
                        controller?.send(draft)
                        draft = ""
                    }
                    .id("bottom")
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: conversation?.messages.last?.text) { _, _ in
                if controller?.isStreaming == true, let id = conversation?.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: conversation?.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        .navigationTitle(conversation?.title ?? "对话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showOptions = true } label: { Image(systemName: "ellipsis") }
            }
            if controller?.isStreaming == true {
                ToolbarItem(placement: .bottomBar) {
                    Button { controller?.stop() } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                    .tint(.red)
                }
            }
        }
        .sheet(isPresented: $showOptions) {
            if let controller {
                ChatOptionsView(controller: controller)
            }
        }
        .onAppear {
            if controller == nil {
                controller = ChatController(conversationID: conversationID, store: store,
                                            settings: settings, speech: speech)
            }
        }
        .onDisappear { speech.stop() }
    }
}

private struct EmptyChatHint: View {
    let model: ClaudeModel
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkle").font(.title2).foregroundStyle(Color.claudeOrange)
            Text("有什么可以帮你？").font(.headline)
            Text(model.displayName).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// 点一下会弹出系统输入面板：听写、随手写、键盘或 iPhone 键盘
private struct ComposeField: View {
    @Binding var draft: String
    let disabled: Bool
    let onSend: () -> Void

    var body: some View {
        TextField("说点什么…", text: $draft)
            .submitLabel(.send)
            .onSubmit {
                guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                onSend()
            }
            .disabled(disabled)
            .padding(.top, 4)
    }
}
