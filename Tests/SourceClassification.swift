import Foundation
@main struct ClassificationChecks {
    static func main() {
        let cases: [(String, ClipSource?)] = [
            ("https://www.linkedin.com/in/example", .linkedin),
            ("https://lnkd.in/example", .linkedin),
            ("https://web.whatsapp.com", .whatsapp),
            ("https://wa.me/123", .whatsapp),
            ("https://m.facebook.com/post/123", .facebook),
            ("https://fb.watch/example", .facebook),
            ("https://www.instagram.com/example", .instagram),
            ("https://linkedin.com.evil.example", nil),
            ("https://fakewhatsapp.com", nil),
            ("linkedin metni", nil),
            ("file://facebook.com", nil)
        ]
        for (value, expected) in cases { precondition(ClipSource.fromURL(value) == expected, value) }
        precondition(ClipSource.fromBundle("net.whatsapp.WhatsApp") == .whatsapp)
        precondition(ClipSource.fromBundle("com.apple.Safari") == nil)
        var checks = cases.count + 2
        for source in ClipSource.allCases {
            for domain in source.domains {
                for host in [domain, "www." + domain, "m." + domain] {
                    precondition(ClipSource.fromURL("https://" + host + "/example") == source, host)
                    checks += 1
                }
                precondition(ClipSource.fromURL("https://" + domain + ".evil.example/path") == nil)
                precondition(ClipSource.fromURL("https://fake" + domain.replacingOccurrences(of: ".", with: "") + ".example/path") == nil)
                checks += 2
            }
        }
        precondition(ClipSource.fromBundle("com.hnc.Discord") == .discord)
        precondition(ClipSource.fromBundle("ru.keepcoder.Telegram") == .telegram)
        checks += 2
        print("\(checks) kaynak sınıflandırma kontrolü geçti; \(ClipSource.allCases.count) kaynak destekleniyor.")
    }
}
