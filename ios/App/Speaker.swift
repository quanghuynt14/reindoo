import AVFoundation
import ReindooCore

/// Lit un mot à voix haute, avec les voix du système : rien à télécharger.
///
/// Tout se passe sur une file à part. Activer la session audio parle au
/// serveur du son et attend sa réponse ; chercher une voix la première fois
/// charge la liste des voix. Sur le fil principal, ces attentes figeaient le
/// reel à son ouverture et à chaque carte.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = Speaker()

    private let queue = DispatchQueue(label: "reindoo.speaker", qos: .userInitiated)
    // Tout ce qui suit ne se touche que sur `queue`.
    private let synthesizer = AVSpeechSynthesizer()
    private var voices: [Language: AVSpeechSynthesisVoice] = [:]
    private var category: AVAudioSession.Category?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Charge les voix d'avance, au lancement : la première carte n'attend pas.
    func warm() {
        queue.async {
            for language in Language.allCases { _ = self.voice(for: language) }
        }
    }

    /// `asked` : l'utilisateur a touché le bouton. Sa demande passe outre le
    /// bouton silencieux du téléphone, comme une vidéo qu'on lance. La lecture
    /// automatique, elle, se tait quand le téléphone est en silencieux.
    func say(_ word: String, in language: Language, asked: Bool = false) {
        queue.async { self.speak(word, in: language, asked: asked) }
    }

    func stop() {
        queue.async { self.synthesizer.stopSpeaking(at: .immediate) }
    }

    private func speak(_ word: String, in language: Language, asked: Bool) {
        synthesizer.stopSpeaking(at: .immediate)

        let session = AVAudioSession.sharedInstance()
        let wanted: AVAudioSession.Category = asked ? .playback : .ambient
        if category != wanted {
            // La musique en cours baisse le temps du mot, puis reprend.
            if asked {
                try? session.setCategory(.playback, options: .duckOthers)
            } else {
                try? session.setCategory(.ambient)
            }
            category = wanted
        }
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    private func voice(for language: Language) -> AVSpeechSynthesisVoice? {
        if let found = voices[language] { return found }
        let code: String = switch language {
        case .french: "fr-FR"
        case .english: "en-US"
        }
        let found = AVSpeechSynthesisVoice(language: code)
        voices[language] = found
        return found
    }

    /// Le mot est dit : on rend le son aux autres apps.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        queue.async {
            guard !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
