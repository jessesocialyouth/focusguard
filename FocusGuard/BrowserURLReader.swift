import AppKit
import ApplicationServices

struct BrowserURLReader {

    private static let supportedBundles: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
    ]

    static func isBrowser(bundleID: String) -> Bool {
        supportedBundles.contains(bundleID)
    }

    static func readURL(from app: NSRunningApplication) -> String? {
        guard isBrowser(bundleID: app.bundleIdentifier ?? "") else { return nil }
        guard AXIsProcessTrusted() else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }

        return findURLField(in: windowRef as! AXUIElement, depth: 0)
    }

    // Depth-limited AX tree search for the address bar
    private static func findURLField(in element: AXUIElement, depth: Int) -> String? {
        guard depth < 8 else { return nil }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)

        if roleRef as? String == (kAXTextFieldRole as String) {
            var descRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            let desc = (descRef as? String ?? "").lowercased()

            if desc.contains("address") || desc.contains("url") || desc.contains("location") || desc.contains("search") {
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                   let value = valueRef as? String, !value.isEmpty {
                    return value
                }
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            if let url = findURLField(in: child, depth: depth + 1) {
                return url
            }
        }
        return nil
    }
}
