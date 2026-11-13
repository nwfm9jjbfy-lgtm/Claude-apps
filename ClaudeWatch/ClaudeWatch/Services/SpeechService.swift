import AVFoundation
import Observation

/// 朗读回复（手表扬声器或蓝牙耳机）
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    var speakingID: UUID?

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ text: String, id: UUID, rate: Double) {
        if speakingID == id { stop(); return }
        speak(text, id: id, rate: rate)
    }

    func speak(_ text: String, id: UUID, rate: Double) {
        stop()
        let clean = Self.plainText(text)
        guard !clean.isEmpty else { return }
        let u = AVSpeechUtterance(string: clean)
        u.voice = AVSpeechSynthesisVoice(language: Self.languageCode(for: clean))
        // 0...1 映射到系统允许的语速范围
        let minR = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxR = Double(AVSpeechUtteranceMaximumSpeechRate)
        u.rate = Float(minR + (maxR - minR) * rate)
        speakingID = id
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        speakingID = nil
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingID = nil }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingID = nil }
    }

    /// 含中文就用中文语音，否则用系统语言
    static func languageCode(for text: String) -> String {
        if text.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) }) {
            return "zh-CN"
        }
        return AVSpeechSynthesisVoice.currentLanguageCode()
    }

    /// 去掉 Markdown 符号，读起来更自然
    static func plainText(_ md: String) -> String {
        var s = md
        s = s.replacingOccurrences(of: "```[\\s\\S]*?```", with: "（代码略）", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^#{1,6}\\s*", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\s*[-*+]\\s+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[*_`~>]", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
