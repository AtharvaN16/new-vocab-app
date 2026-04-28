import Foundation

struct DailyWordsUseCase {
    private static let wordsPerDay = 10

    private static let curatedWords: [String] = {
        guard let url = Bundle.main.url(forResource: "curated_words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return words
    }()

    func wordsForToday() -> [String] {
        let today = Calendar.current.startOfDay(for: Date())
        let defaults = UserDefaults.standard
        let cacheKey = "dailyWords_v2"
        let dateKey = "dailyWordsDate_v2"

        if let cached = defaults.stringArray(forKey: cacheKey),
           let cachedDate = defaults.object(forKey: dateKey) as? Date,
           Calendar.current.isDate(cachedDate, inSameDayAs: today) {
            return cached
        }

        let words = Self.curatedWords
        guard words.count >= Self.wordsPerDay else { return Array(words) }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: today) ?? 1
        let year = Calendar.current.component(.year, from: today)
        let seed = year * 1000 + dayOfYear
        
        var generator = SeededGenerator(seed: UInt64(seed))
        let selection = Array(words.shuffled(using: &generator).prefix(Self.wordsPerDay))

        defaults.set(selection, forKey: cacheKey)
        defaults.set(today, forKey: dateKey)
        return selection
    }
}

/// A simple LCG for deterministic shuffling
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
