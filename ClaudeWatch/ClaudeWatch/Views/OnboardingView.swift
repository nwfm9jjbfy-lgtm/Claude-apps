import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var key = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.claudeOrange)
                Text("Claude").font(.title3.bold())
                Text("输入你的 Anthropic API Key 开始使用")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                SecureField("sk-ant-…", text: $key)

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }

                Button("开始") {
                    let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard k.count >= 20 else {
                        error = "Key 太短，检查是否完整"
                        return
                    }
                    settings.apiKey = k
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.isEmpty)

                NavigationLink {
                    NetworkSettingsView()
                } label: {
                    Label("网络与代理", systemImage: "network")
                }
                .font(.footnote)

                Text("提示：点输入框后，iPhone 上会弹出键盘通知，可以直接在手机上粘贴。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        }
    }
}
