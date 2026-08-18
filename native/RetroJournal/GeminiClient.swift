import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case badResponse(Int, String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key set yet — paste one into Secrets.swift."
        case .badResponse(let code, let message):
            return "Gemini error \(code): \(message)"
        case .emptyReply:
            return "Gemini returned no reply text."
        }
    }
}

struct GeminiClient {
    struct Turn {
        let isFromAI: Bool
        let text: String
    }

    struct ExtractedMemoryItem {
        let kind: MemoryItemKind
        let text: String
    }

    // "latest" alias so this doesn't rot again as Google renames underlying models.
    private let model = "gemini-flash-latest"

    private let systemPreamble = """
    You are Kit, a concise, warm, hands-free voice companion for someone in a session. \
    You remember everything said earlier in this conversation and refer back to it naturally. \
    Keep replies short — one or two sentences, spoken out loud. No lists, no markdown, no emoji.
    """

    private let summaryPreamble = """
    You are Kit, writing a short private journal summary of a voice conversation from someone's session. \
    Write 2-4 warm, first-person-plural-free sentences capturing what they talked about, noticed, or decided. \
    Write it like a diary entry, not a meeting recap. No lists, no markdown, no emoji.
    """

    func reply(to prompt: String, history: [Turn], relevantMemories: [String] = []) async throws -> String {
        var contents = history.map(Self.contentPart)
        contents.append(["role": "user", "parts": [["text": prompt]]])
        return try await generate(systemPreamble: composedSystemPreamble(relevantMemories: relevantMemories), contents: contents)
    }

    private func composedSystemPreamble(relevantMemories: [String]) -> String {
        guard !relevantMemories.isEmpty else { return systemPreamble }
        let bulleted = relevantMemories.map { "- \($0)" }.joined(separator: "\n")
        return systemPreamble + "\n\nThings you already know from past sessions — mention naturally only if actually relevant, don't force it in:\n" + bulleted
    }

    func summarize(history: [Turn]) async throws -> String {
        let transcript = history
            .map { "\($0.isFromAI ? "Kit" : "Me"): \($0.text)" }
            .joined(separator: "\n")
        let contents = [["role": "user", "parts": [["text": transcript]]]]
        return try await generate(systemPreamble: summaryPreamble, contents: contents)
    }

    private let extractionPreamble = """
    You extract structured items from a private voice journal transcript. Find concrete \
    shopping items, tasks or reminders, ideas, and people mentioned. Respond with strict JSON \
    only: an array of objects shaped like {"kind":"shopping|task|idea|person","text":"..."}. \
    Omit a category entirely if nothing fits it. Return [] if there is nothing worth extracting. \
    No prose, no markdown code fences, JSON array only.
    """

    /// Best-effort structured extraction from the same transcript summarize() already
    /// read. Callers must treat any thrown error or empty result as "nothing extracted",
    /// never as a reason to affect the session save itself.
    func extractMemoryItems(history: [Turn]) async throws -> [ExtractedMemoryItem] {
        let transcript = history
            .map { "\($0.isFromAI ? "Kit" : "Me"): \($0.text)" }
            .joined(separator: "\n")
        let contents = [["role": "user", "parts": [["text": transcript]]]]
        let raw = try await generate(systemPreamble: extractionPreamble, contents: contents)
        return Self.parseExtractedItems(raw)
    }

    private static func parseExtractedItems(_ raw: String) -> [ExtractedMemoryItem] {
        // Defensively strip ```json ... ``` fences in case the model wraps the array anyway.
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }

        return objects.compactMap { object -> ExtractedMemoryItem? in
            guard let kindString = object["kind"] as? String,
                  let kind = MemoryItemKind(rawValue: kindString),
                  let text = object["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            return ExtractedMemoryItem(kind: kind, text: text)
        }
    }

    private static func contentPart(_ turn: Turn) -> [String: Any] {
        ["role": turn.isFromAI ? "model" : "user", "parts": [["text": turn.text]]]
    }

    private func generate(systemPreamble: String, contents: [[String: Any]]) async throws -> String {
        guard !Secrets.geminiAPIKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.badResponse(-1, "Invalid URL")
        }

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPreamble]]
            ],
            "contents": contents
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.badResponse(-1, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GeminiError.badResponse(http.statusCode, message)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.emptyReply
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
