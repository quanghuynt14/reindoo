import AVFoundation
import ReindooCore

/// Lit un mot à voix haute, avec les voix du système : rien à télécharger.
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        // « Ambiant » : le bouton silencieux du téléphone coupe la voix, et la
        // musique en cours continue.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func say(_ word: String, in language: Language) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        let voice: String = switch language {
        case .french: "fr-FR"
        case .english: "en-US"
        }
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
