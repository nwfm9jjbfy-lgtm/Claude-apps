import SwiftUI

struct ConversationListView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ConversationStore.self) private var store
    @State private var path: [UUID] = []
    @State private var search = ""

    private var filtered: [Conversation] {
        let all = store.sorted.filter { !$0.messages.isEmpty }
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.messages.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Button {
                    newChat()
                } label: {
                    Label("新对话", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(Color.claudeOrange)
                }

                if filtered.isEmpty {
                    Text(search.isEmpty ? "还没有对话" : "没有找到")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(filtered) { c in
                    NavigationLink(value: c.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.title).font(.headline).lineLimit(1)
                            Text(c.preview).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            Text(c.updatedAt, format: .relative(presentation: .named))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.delete(c.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "搜索对话")
            .navigationTitle("Claude")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ChatView(conversationID: id)
            }
            .onChange(of: path) { _, newPath in
                // 退出时清理空的新对话
                store.pruneEmpty(except: newPath.last)
            }
        }
    }

    private func newChat() {
        let c = store.create(settings: settings)
        path.append(c.id)
    }
}
