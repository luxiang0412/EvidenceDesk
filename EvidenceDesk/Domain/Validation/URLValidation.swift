import Foundation

enum URLValidationError: Error, LocalizedError, Equatable {
    case empty
    case invalidScheme(String)
    case malformed

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Please enter a URL."
        case .invalidScheme(let scheme):
            return "Only http and https links are supported (got “\(scheme)”)."
        case .malformed:
            return "That doesn’t look like a valid web address."
        }
    }
}

/// Validates web source URLs. Only `http` and `https` are accepted; schemes
/// such as `file:`, `javascript:` and `data:` are rejected.
enum URLValidation {
    static func validate(_ raw: String) -> Result<URL, URLValidationError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        // Detect an explicit scheme (including "javascript:"/"data:") before
        // any normalisation so unsafe schemes are rejected, not accidentally
        // re-interpreted as http hosts.
        let hasExplicitScheme = trimmed.contains("://")
            || (trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.\\-]*:", options: .regularExpression) != nil)
        let candidate = hasExplicitScheme ? trimmed : "http://\(trimmed)"

        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased() else {
            return .failure(.malformed)
        }
        guard scheme == "http" || scheme == "https" else {
            return .failure(.invalidScheme(scheme))
        }
        guard url.host != nil else { return .failure(.malformed) }
        return .success(url)
    }
}