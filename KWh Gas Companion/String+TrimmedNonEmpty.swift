import Foundation

extension String {
    /// Trim whitespace/newlines; return nil if empty after trimming.
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

extension Optional where Wrapped == String {
    /// Trim whitespace/newlines; return nil if empty after trimming.
    var trimmedNonEmpty: String? {
        switch self {
        case .none: return nil
        case .some(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    }
}
