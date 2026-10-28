import Foundation

/// Validate the entire final object; discard only a documented thinking envelope or one outer JSON fence.
/// Never search arbitrary prose for a JSON fragment or repair its values.
public enum ModelJSONPayload {
    public enum Failure: Error { case malformed }
    public static func finalObject(_ content: String, allowsThinkingEnvelope: Bool) throws -> Data {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let end = text.range(of: "</think>", options: .backwards) {
            guard allowsThinkingEnvelope else { throw Failure.malformed }
            text = String(text[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.contains("<think>"), !text.contains("</think>") else { throw Failure.malformed }
        if text.hasPrefix("```json\n") && text.hasSuffix("\n```") {
            text = String(text.dropFirst(8).dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard text.hasPrefix("{"), text.hasSuffix("}"), let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw Failure.malformed }
        return data
    }
}
