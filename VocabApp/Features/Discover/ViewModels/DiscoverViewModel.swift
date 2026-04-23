import Foundation
import SwiftUI
import Combine

@Observable
final class DiscoverViewModel {
    var searchText: String = ""
    var searchResult: WordEntity?
    var isLoading: Bool = false
    var errorMessage: String?
    var showDetail: Bool = false
    
    private let dictionaryRepository: DictionaryRepository
    private var searchTask: Task<Void, Never>?

    init(dictionaryRepository: DictionaryRepository) {
        self.dictionaryRepository = dictionaryRepository
    }

    func performSearch() {
        searchTask?.cancel()
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResult = nil
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task {
            do {
                let result = try await dictionaryRepository.lookup(word: query)
                if !Task.isCancelled {
                    self.searchResult = result
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Could not find definition for '\(query)'"
                    self.isLoading = false
                    self.searchResult = nil
                }
            }
        }
    }
}
