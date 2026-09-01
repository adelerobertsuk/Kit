import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case badResponse(Int, String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Gemini API key. Run Kit from Xcode, or paste the key into Secrets.swift."
        case .badResponse(_, let message):
            return message
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

    /// Tried in order. Bare model IDs — the REST path template adds the `models/`
    /// prefix itself, so these must never include it. Falls through to the next when
    /// one is retired (404), rejects the request (400), or is overloaded (500/503 —
    /// currently common on the newest flash models). `gemini-2.5-flash` and the whole
    /// 1.x line are retired for API keys created in 2026.
    private let models = ["gemini-3.7-flash", "gemini-3.5-flash-lite", "gemini-flash-latest"]

    /// Prints the real underlying failure to the Xcode console in debug builds —
    /// the friendly `errorMessage` shown in the app deliberately hides the detail,
    /// this is where you see the actual HTTP status and Google error body.
    private static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[GeminiClient] \(message())")
        #endif
    }

    // MARK: - Reply (Auto Cruise + Pursuit Mode)

    /// Voice rules appended to every spoken reply, whatever the seat.
    private static let voiceRules = """
    Rules for how you speak: 1 to 3 punchy sentences, always out loud — never markdown, \
    bullet points, headings, or emoji. Talk like a sharp friend keeping pace, not a \
    therapist or a support bot. Fast, tangential, stream-of-consciousness talk is just how \
    they think out loud — match that momentum, do not slow it down or tidy it up. Never \
    assume they are upset, anxious, stuck, or have a problem to solve unless they plainly \
    say so; riffing is not a cry for help. No corporate affirmations — never open with \
    "It sounds like you're feeling…", "That's completely valid…", "I hear you…", or \
    "It's understandable that…". Just answer like a person.
    """

    private func replyPreamble(for chair: Chair) -> String {
        let persona: String
        switch chair {
        case .auto:
            persona = """
            You are Kit in Auto Cruise. They are walking, pottering about, or working \
            through daily tasks — not on a run, so do not talk to them like they are \
            mid-sprint. Warm and upbeat: react to what they just said and keep them \
            moving through the day.
            """
        case .kit:
            persona = """
            You are Kit in Pursuit Mode — a sharp thinking partner while they move, \
            usually a run or a brisk walk. Help them work the idea out loud: reflect it \
            back, ask the one useful question, connect it to something they said earlier.
            """
        case .diane:
            // Diane never reaches here — she only writes it down — but keep this total.
            persona = "You are Kit."
        }
        return persona + "\n\n" + Self.voiceRules
    }

    private static func replyConfig(for chair: Chair) -> [String: Any] {
        switch chair {
        case .auto: return ["maxOutputTokens": 90, "temperature": 0.9]
        case .kit, .diane: return ["maxOutputTokens": 220, "temperature": 0.7]
        }
    }

    /// Auto Cruise must feel instant — a short leash, after which the caller drops to a
    /// canned native confirmation. Pursuit does real thinking, so it gets room.
    private static func replyTimeout(for chair: Chair) -> TimeInterval {
        switch chair {
        case .auto: return 10
        case .kit, .diane: return 30
        }
    }

    func reply(to prompt: String, history: [Turn], relevantMemories: [String] = [], chair: Chair) async throws -> String {
        var contents = history.map(Self.contentPart)
        contents.append(["role": "user", "parts": [["text": prompt]]])
        let preamble = composedPreamble(base: replyPreamble(for: chair), relevantMemories: relevantMemories)
        return try await generate(
            systemPreamble: preamble,
            contents: contents,
            generationConfig: Self.replyConfig(for: chair),
            timeout: Self.replyTimeout(for: chair)
        )
    }

    private func composedPreamble(base: String, relevantMemories: [String]) -> String {
        guard !relevantMemories.isEmpty else { return base }
        let bulleted = relevantMemories.map { "- \($0)" }.joined(separator: "\n")
        return base + "\n\nThings you already know from past sessions — mention naturally only if actually relevant, don't force it in:\n" + bulleted
    }

    // MARK: - Session summary (all seats)

    /// Applied to every session summary regardless of seat.
    private static let journalRules = """
    Write it as a plain private diary line, not a meeting recap: no lists, no markdown, no emoji. \
    Do not diagnose, dramatise, or read distress into it — if they were just thinking out loud, \
    say that plainly. No therapy language or affirmations.
    """

    private func summaryPreamble(for chair: Chair) -> String {
        let brief: String
        switch chair {
        case .diane:
            brief = """
            You are Kit, writing a short private journal summary of someone's Normal Cruise session — \
            quiet voice journaling, like morning pages. 2-4 warm sentences on what they felt, \
            noticed, or were turning over.
            """
        case .auto:
            brief = """
            You are Kit, writing a short private journal note from an Auto Cruise chat — \
            light back-and-forth on a walk. Two or three warm sentences on what came up.
            """
        case .kit:
            brief = """
            You are Kit, writing a private debrief of a Pursuit Mode session — active thinking \
            out loud on a walk or run. In 3-5 warm sentences: what they explored, what they \
            worked out, and any next step they named for themselves.
            """
        }
        return brief + "\n\n" + Self.journalRules
    }

    func summarize(history: [Turn], chair: Chair) async throws -> String {
        let transcript = history
            .map { "\($0.isFromAI ? "Kit" : "Me"): \($0.text)" }
            .joined(separator: "\n")
        let contents = [["role": "user", "parts": [["text": transcript]]]]
        return try await generate(systemPreamble: summaryPreamble(for: chair), contents: contents)
    }

    // MARK: - Structured extraction (Smart Kit)

    private let extractionPreamble = """
    You extract structured items from a private voice journal transcript. Find concrete \
    shopping items, tasks or reminders, people, reflective morning-page thoughts, running thoughts, \
    general ideas, and app ideas. Respond with strict JSON only: an array of objects shaped like \
    {"kind":"morningPages|runningThought|appIdea|reflection|shopping|task|idea|person","text":"..."}. \
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

    // MARK: - Transport

    private func generate(
        systemPreamble: String,
        contents: [[String: Any]],
        generationConfig: [String: Any]? = nil,
        timeout: TimeInterval = 45
    ) async throws -> String {
        let apiKey = Secrets.geminiAPIKey
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        var lastError: Error = GeminiError.emptyReply
        for model in models {
            do {
                return try await generateOnce(
                    model: model,
                    apiKey: apiKey,
                    systemPreamble: systemPreamble,
                    contents: contents,
                    generationConfig: generationConfig,
                    timeout: timeout
                )
            } catch GeminiError.badResponse(let status, let message)
                where status == 404 || status == 400 || status == 500 || status == 503 {
                Self.debugLog("model \(model) unusable (HTTP \(status)), trying next — \(message)")
                lastError = GeminiError.badResponse(status, message)
                continue
            } catch {
                Self.debugLog("\(model) failed: \(error.localizedDescription)")
                throw error
            }
        }
        throw lastError
    }

    private func generateOnce(
        model: String,
        apiKey: String,
        systemPreamble: String,
        contents: [[String: Any]],
        generationConfig: [String: Any]?,
        timeout: TimeInterval
    ) async throws -> String {
        // Bare model id — `models/` is part of the path template, never the id.
        // The key goes in BOTH the x-goog-api-key header and a ?key= query param:
        // AI Studio keys (incl. the newer AQ.* format) are accepted either way, and
        // sending both maximises compatibility while auth is being sorted out.
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw GeminiError.badResponse(-1, "Invalid URL")
        }

        var body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPreamble]]],
            "contents": contents
        ]
        if let generationConfig {
            body["generationConfig"] = generationConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Self.debugLog("transport error hitting \(model): \(error.localizedDescription)")
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            Self.debugLog("non-HTTP response: \(response)")
            throw GeminiError.badResponse(-1, "Kit could not reach Google. Your words are still saved.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8) ?? "<\(data.count) non-utf8 bytes>"
            let error = GeminiError.badResponse(http.statusCode, Self.friendlyGoogleError(from: data, status: http.statusCode))
            Self.debugLog("HTTP \(http.statusCode) from \(model): \(error.localizedDescription)\n\(rawBody)")
            throw error
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            Self.debugLog("HTTP 200 but unparseable body:\n\(String(data: data, encoding: .utf8) ?? "<binary>")")
            throw GeminiError.emptyReply
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func friendlyGoogleError(from data: Data, status: Int) -> String {
        let raw: String = {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            return String(data: data, encoding: .utf8) ?? ""
        }()

        let lowered = raw.lowercased()
        if status == 429 || lowered.contains("high demand") || lowered.contains("resource exhausted") || lowered.contains("quota") {
            return "Google is busy. Kit could not talk back. Your words are still saved. Try again in a moment."
        }
        if status == 400, lowered.contains("api key not valid") || lowered.contains("api_key_invalid") {
            return "Kit could not talk back. The Google key looks wrong. Your words are still saved."
        }
        if status == 404 {
            return "Kit could not talk back. That Gemini model wasn't found. Your words are still saved."
        }
        if status == 401 || status == 403 {
            return "Kit could not talk back. Check the Google key, then try again. Your words are still saved."
        }
        return "Kit could not talk back. Your words are still saved. Try again in a moment."
    }
}
