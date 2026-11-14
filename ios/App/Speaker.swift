import AVFoundation
import ReindooCore

/// Lit un mot à voix haute, avec les voix du système : rien à télécharger.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// `asked` : l'utilisateur a touché le bouton. Sa demande passe outre le
    /// bouton silencieux du téléphone, comme une vidéo qu'on lance. La lecture
    /// automatique, elle, se tait quand le téléphone est en silencieux.
    func say(_ word: String, in language: Language, asked: Bool = false) {
        synthesizer.stopSpeaking(at: .immediate)

        let session = AVAudioSession.sharedInstance()
        if asked {
            // La musique en cours baisse le temps du mot, puis reprend.
            try? session.setCategory(.playback, options: .duckOthers)
        } else {
            try? session.setCategory(.ambient)
        }
        try? session.setActive(true)

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

    /// Le mot est dit : on rend le son aux autres apps.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
