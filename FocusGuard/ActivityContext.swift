import Foundation

struct ActivityContext {
    let appName: String
    let bundleID: String
    let windowTitle: String
    let url: String?
    let timestamp: Date
    var elapsedInContext: TimeInterval
}

extension ActivityContext {
    var urlDomain: String? {
        guard let url,
              let host = URLComponents(string: url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var displayDetail: String {
        urlDomain ?? windowTitle
    }
}

enum ClassificationResult {
    case clearlyOnTask
    case probablyOnTask
    case uncertain
    case probablyOffTask
    case clearlyOffTask
}
