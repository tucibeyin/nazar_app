import Foundation

struct APIConfig {
    static let baseURL = "http://nazar.aracabak.com"

    static func nazarURL(hash: String) -> URL? {
        URL(string: "\(baseURL)/api/nazar/\(hash)")
    }

    static func audioURL(mp3Path: String) -> URL? {
        URL(string: "\(baseURL)\(mp3Path)")
    }
}
