import Foundation

struct SessionStore {
    let folderURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.folderURL = appSupport.appendingPathComponent("LoopholeUI", isDirectory: true)
    }

    func loadSessions() -> [SessionRecord] {
        ensureFolder()
        let files = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])) ?? []
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
        folderURL.appendingPathComponent("\(id).json")
    }

    func delete(id: String) throws {
        let fileURL = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    }
}
