import Foundation

// MARK: - Entry

struct MerriamWebsterEntry: Decodable {
    let hwi: HeadwordInfo?
    let et: [[MWValue]]?

    struct HeadwordInfo: Decodable {
        let hw: String
        let prs: [Pronunciation]?

        struct Pronunciation: Decodable {
            let ipa: String?
            let sound: Sound?
            struct Sound: Decodable { let audio: String }
        }
    }
}

// M-W arrays contain mixed String / [String] values — MWValue decodes both.
enum MWValue: Decodable {
    case string(String)
    case nested([MWValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self)    { self = .string(s); return }
        if let a = try? c.decode([MWValue].self) { self = .nested(a); return }
        self = .string("")
    }

    var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
}

// MARK: - Audio URL helper

enum MerriamWebsterAudioURL {
    static func subdirectory(for filename: String) -> String {
        if filename.hasPrefix("bix") { return "bix" }
        if filename.hasPrefix("gg")  { return "gg" }
        if let first = filename.first, first.isNumber { return "number" }
        return String(filename.prefix(1))
    }

    static func build(filename: String) -> String {
        "https://media.merriam-webster.com/audio/prons/en/us/mp3/\(subdirectory(for: filename))/\(filename).mp3"
    }
}

// MARK: - Normalise

extension Array where Element == MerriamWebsterEntry {
    func normalize(word: String) -> WordEntity {
        guard let entry = first else {
            return WordEntity(word: word, sources: ["Merriam-Webster"])
        }
        let phonetic = entry.hwi?.prs?.first?.ipa
        let audioURL = entry.hwi?.prs?.first?.sound.map { MerriamWebsterAudioURL.build(filename: $0.audio) }
        let etymology: String? = entry.et?
            .compactMap { pair -> String? in
                guard pair.first?.stringValue == "text",
                      let text = pair.dropFirst().first?.stringValue else { return nil }
                return text.strippingMWMarkup()
            }
            .first

        return WordEntity(
            word: word,
            phonetic: phonetic,
            etymology: etymology,
            sources: ["Merriam-Webster"],
            audioURL: audioURL
        )
    }
}

private extension String {
    func strippingMWMarkup() -> String {
        replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
