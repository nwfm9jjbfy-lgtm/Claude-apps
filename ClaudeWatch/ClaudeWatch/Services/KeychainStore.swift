import Foundation
import Security

/// API Key 存在钥匙串里，不写进代码或普通文件。
enum KeychainStore {
    private static let service = "com.example.claudewatch"
    static let apiKeyAccount = "anthropic-api-key"
    static let proxyPasswordAccount = "proxy-password"

    static func load(_ account: String = KeychainStore.apiKeyAccount) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String, account: String = KeychainStore.apiKeyAccount) -> Bool {
        delete(account)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String = KeychainStore.apiKeyAccount) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
