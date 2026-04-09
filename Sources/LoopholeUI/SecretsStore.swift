import Foundation
import Security

enum SecretsStore {
    private static let service = "LoopholeUI"
    private static let account = "anthropic_api_key"

    static func saveAnthropicKey(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty else { return }

        var payload = query
        payload[kSecValueData as String] = data
        SecItemAdd(payload as CFDictionary, nil)
    }

    static func loadAnthropicKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }

        return key
    }
}
