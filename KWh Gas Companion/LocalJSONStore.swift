import Foundation

@MainActor
class LocalJSONStore<T: Codable & Identifiable>: ObservableObject {
    @Published var items: [T] = [] {
        didSet {
            guard !isHydrating else { return }
            save()
        }
    }

    private let fileURL: URL
    private var isHydrating = true

    init(filename: String, seed: [T] = []) {
        let base = (try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        self.fileURL = base.appendingPathComponent(filename)
        self.items = seed
        load()
    }

    func load() {
        isHydrating = true
        defer { isHydrating = false }

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
