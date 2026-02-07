import Foundation

@MainActor
class LocalJSONStore<T: Codable & Identifiable>: ObservableObject {
    @Published var items: [T] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    init(filename: String, seed: [T] = []) {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = base.appendingPathComponent(filename)
        self.items = seed
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([T].self, from: data)
            self.items = decoded
        } catch {
            // Keep seed
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Non-fatal; ignore
        }
    }
}
