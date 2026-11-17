import Foundation

/// Reads and writes the save file. In-memory for tests and `--uitesting`.
final class ProfileStorage {
    private let url: URL?
    private var memory: Data?

    private init(url: URL?) { self.url = url }

    static func inMemory() -> ProfileStorage { ProfileStorage(url: nil) }

    static func onDisk(fileName: String = "cluck-crossing-save.json") throws -> ProfileStorage {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return ProfileStorage(url: folder.appendingPathComponent(fileName))
    }

    func load() -> PlayerProfile? {
        let data: Data?
        if let url { data = try? Data(contentsOf: url) } else { data = memory }
        guard let data else { return nil }
        return try? JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    func save(_ profile: PlayerProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        if let url {
            try? data.write(to: url, options: .atomic)
        } else {
            memory = data
        }
    }
}
