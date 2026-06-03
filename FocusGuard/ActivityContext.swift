import Foundation

struct ActivityContext {
    let appName: String
    let bundleID: String
    let windowTitle: String
    let url: String?
    let timestamp: Date
    var elapsedInContext: TimeInterval
}

enum ClassificationResult {
    case clearlyOnTask
    case probablyOnTask
    case uncertain
    case probablyOffTask
    case clearlyOffTask
}
