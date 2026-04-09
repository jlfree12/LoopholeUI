import Foundation

struct SessionStore {
    private let rootURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.rootURL = appSupport.appendingPathComponent("LoopholeUI", isDirectory: true)
    }

    func loadSessions() -> [SessionRecord] {
        ensureFolder()
        let files = (try? FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: [])) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? decoder.decode(SessionRecord.self, from: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ session: SessionRecord) throws {
        ensureFolder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        try data.write(to: fileURL(for: session.id), options: .atomic)
    }

    private func fileURL(for id: String) -> URL {
        rootURL.appendingPathComponent("\(id).json")
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
    }
}
