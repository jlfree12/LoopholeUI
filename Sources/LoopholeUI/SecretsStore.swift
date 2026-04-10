import Foundation
import Security

enum SecretsStore {
    private static let service = "LoopholeUI"
    private static let anthropicAccount = "anthropic_api_key"
    private static let openAIAccount = "openai_api_key"

    static func saveAnthropicKey(_ value: String) {
        save(value, account: anthropicAccount)
    }

    static func loadAnthropicKey() -> String {
        load(account: anthropicAccount)
    }

    static func saveOpenAIKey(_ value: String) {
        save(value, account: openAIAccount)
    }

    static func loadOpenAIKey() -> String {
        load(account: openAIAccount)
    }

    private static func save(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty else { return }

        var payload = query
        payload[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(payload as CFDictionary, nil)
    }

    private static func load(account: String) -> String {
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
