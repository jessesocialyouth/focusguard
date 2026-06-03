import Foundation

struct ActivityContext {
    let appName: String
    let bundleID: String
    let windowTitle: String
    let url: String?
    let timestamp: Date
    var elapsedInContext: TimeInterval
    var classification: ClassificationResult? = nil
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

import SwiftUI

extension ClassificationResult {
    var label: String {
        switch self {
        case .clearlyOnTask:    return "on task"
        case .probablyOnTask:   return "probably on task"
        case .uncertain:        return "uncertain"
        case .probablyOffTask:  return "probably off task"
        case .clearlyOffTask:   return "off task"
        }
    }

    var badgeColor: Color {
        switch self {
        case .clearlyOnTask:    return .green
        case .probablyOnTask:   return .mint
        case .uncertain:        return .yellow
        case .probablyOffTask:  return .orange
        case .clearlyOffTask:   return .red
        }
    }

    var isOffTask: Bool {
        self == .probablyOffTask || self == .clearlyOffTask
    }
}
