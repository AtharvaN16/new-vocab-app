import XCTest
@testable import VocabApp

final class WordAudioPlayerTests: XCTestCase {

    func test_initialState_notPlaying() {
        let player = WordAudioPlayer()
        XCTAssertFalse(player.isPlaying)
    }

    func test_toggle_nilURL_doesNotPlay() {
        let player = WordAudioPlayer()
        player.toggle(url: nil)
        XCTAssertFalse(player.isPlaying)
    }

    func test_stop_whenNotPlaying_staysNotPlaying() {
        let player = WordAudioPlayer()
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }

    func test_toggle_validURL_setsIsPlayingTrue() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        XCTAssertTrue(player.isPlaying)
    }

    func test_toggle_whenPlaying_setsIsPlayingFalse() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        XCTAssertFalse(player.isPlaying)
    }

    func test_stop_whenPlaying_setsIsPlayingFalse() {
        let player = WordAudioPlayer()
        player.toggle(url: "https://api.dictionaryapi.dev/media/pronunciations/en/ephemeral-us.mp3")
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }
}
