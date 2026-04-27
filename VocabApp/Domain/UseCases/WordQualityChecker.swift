import Foundation

enum WordField: CaseIterable, Equatable {
    case definitions, phonetic, audioURL, examples
    case synonyms, antonyms, etymology, contextualNote
}

struct WordQualityChecker {

    func score(_ word: WordEntity) -> Int {
        WordField.allCases.count - missingFields(word).count
    }

    func isComplete(_ word: WordEntity) -> Bool {
        missingFields(word).isEmpty
    }

    func missingFields(_ word: WordEntity) -> [WordField] {
        var missing: [WordField] = []
        if word.definitions.count < 2  { missing.append(.definitions) }
        if word.phonetic == nil        { missing.append(.phonetic) }
        if word.audioURL == nil        { missing.append(.audioURL) }
        if word.examples.count < 2    { missing.append(.examples) }
        if word.synonyms.count < 3    { missing.append(.synonyms) }
        if word.antonyms.isEmpty      { missing.append(.antonyms) }
        if word.etymology == nil      { missing.append(.etymology) }
        if word.contextualNote == nil { missing.append(.contextualNote) }
        return missing
    }
}
