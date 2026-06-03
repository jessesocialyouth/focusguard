import Foundation

actor ClaudeClassifier {
    static let shared = ClaudeClassifier()

    private var apiKey: String { APIKeyStore.shared.apiKey }
    private let model = "claude-haiku-4-5-20251001"
    private var cache: [String: ClassificationResult] = [:]

    private init() {}

    func classify(context: ActivityContext, task: String) async -> ClassificationResult? {
        guard !apiKey.isEmpty else { return nil }
        guard UsageTracker.shared.isUnderLimit else { return nil }

        let cacheKey = makeCacheKey(context)
        if let cached = cache[cacheKey] { return cached }

        guard let result = await callAPI(task: task, context: context) else { return nil }

        cache[cacheKey] = result
        await MainActor.run { UsageTracker.shared.recordCall() }
        return result
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - API

    private func callAPI(task: String, context: ActivityContext) async -> ClassificationResult? {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let userMessage = buildUserMessage(task: task, context: context)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 10,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return parseResponse(data)
        } catch {
            return nil
        }
    }

    private func parseResponse(_ data: Data) -> ClassificationResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else { return nil }

        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on_task":           return .clearlyOnTask
        case "probably_on_task":  return .probablyOnTask
        case "uncertain":         return .uncertain
        case "probably_off_task": return .probablyOffTask
        case "off_task":          return .clearlyOffTask
        default:                  return nil
        }
    }

    // MARK: - Prompt

    private let systemPrompt = """
    You classify if a user's computer activity supports their stated task.
    Reply with exactly one label — nothing else:
    on_task | probably_on_task | uncertain | probably_off_task | off_task
    """

    private func buildUserMessage(task: String, context: ActivityContext) -> String {
        var parts = ["Task: \"\(task)\"", "App: \(context.appName)"]
        if let url = context.url { parts.append("URL: \(url)") }
        else if !context.windowTitle.isEmpty { parts.append("Window: \(context.windowTitle)") }
        return parts.joined(separator: "\n")
    }

    private func makeCacheKey(_ context: ActivityContext) -> String {
        "\(context.bundleID)|\(context.url ?? context.windowTitle)"
    }
}
