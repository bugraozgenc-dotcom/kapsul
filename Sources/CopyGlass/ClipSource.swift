import Foundation

enum ClipSource: String, Codable, CaseIterable {
    case linkedin = "LinkedIn", whatsapp = "WhatsApp", facebook = "Facebook", instagram = "Instagram"
    case youtube = "YouTube", behance = "Behance", medium = "Medium", x = "X"
    case tiktok = "TikTok", reddit = "Reddit", pinterest = "Pinterest", github = "GitHub"
    case dribbble = "Dribbble", vimeo = "Vimeo", telegram = "Telegram", discord = "Discord"

    var assetName: String { rawValue.lowercased() }
    var colorHex: UInt32 {
        switch self {
        case .linkedin: return 0x0A66C2
        case .whatsapp: return 0x25D366
        case .facebook: return 0x0866FF
        case .instagram: return 0xE4405F
        case .youtube: return 0xFF0000
        case .behance: return 0x1769FF
        case .medium, .x, .tiktok, .github: return 0 // Use adaptive foreground for monochrome marks.
        case .reddit: return 0xFF4500
        case .pinterest: return 0xE60023
        case .dribbble: return 0xEA4C89
        case .vimeo: return 0x1AB7EA
        case .telegram: return 0x26A5E4
        case .discord: return 0x5865F2
        }
    }
    var domains: [String] {
        switch self {
        case .linkedin: return ["linkedin.com", "lnkd.in"]
        case .whatsapp: return ["whatsapp.com", "wa.me"]
        case .facebook: return ["facebook.com", "fb.com", "fb.watch", "fb.me", "messenger.com", "m.me"]
        case .instagram: return ["instagram.com", "instagr.am"]
        case .youtube: return ["youtube.com", "youtu.be", "youtube-nocookie.com"]
        case .behance: return ["behance.net"]
        case .medium: return ["medium.com"]
        case .x: return ["x.com", "twitter.com", "t.co"]
        case .tiktok: return ["tiktok.com"]
        case .reddit: return ["reddit.com", "redd.it"]
        case .pinterest: return ["pinterest.com", "pin.it"]
        case .github: return ["github.com", "gist.github.com"]
        case .dribbble: return ["dribbble.com"]
        case .vimeo: return ["vimeo.com"]
        case .telegram: return ["telegram.org", "t.me", "telegram.me"]
        case .discord: return ["discord.com", "discord.gg", "discordapp.com"]
        }
    }
    static func fromURL(_ value: String) -> ClipSource? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased() else { return nil }
        return allCases.first { source in source.domains.contains { host == $0 || host.hasSuffix("." + $0) } }
    }
    static func fromBundle(_ identifier: String?) -> ClipSource? {
        switch identifier?.lowercased() {
        case "net.whatsapp.whatsapp", "net.whatsapp.whatsapp.desktop": return .whatsapp
        case "com.linkedin.linkedin": return .linkedin
        case "com.facebook.archon", "com.facebook.messenger": return .facebook
        case "com.burbn.instagram": return .instagram
        case "ru.keepcoder.telegram", "org.telegram.desktop": return .telegram
        case "com.hnc.discord": return .discord
        case "com.github.githubclient": return .github
        default: return nil
        }
    }
}
