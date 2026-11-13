import Foundation

/// 可选模型。价格单位：美元 / 百万 token。
enum ClaudeModel: String, CaseIterable, Codable, Identifiable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"
    case fable = "claude-fable-5-2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opus: return "Opus 5.5"
        case .sonnet: return "Sonnet 5.5"
        case .haiku: return "Haiku 5.5"
        case .fable: return "Fable 5.2"
        }
    }

    var subtitle: String {
        switch self {
        case .opus: return "默认 · 聪明全面"
        case .sonnet: return "更快 · 更省"
        case .haiku: return "最快 · 最便宜"
        case .fable: return "最强 · 最贵"
        }
    }

    var inputPrice: Double {
        switch self {
        case .opus: return 4
        case .sonnet: return 2
        case .haiku: return 0.10
        case .fable: return 8
        }
    }

    var outputPrice: Double {
        switch self {
        case .opus: return 20
        case .sonnet: return 10
        case .haiku: return 0.50
        case .fable: return 40
        }
    }

    var cacheReadPrice: Double {
        switch self {
        case .opus: return 0.20
        case .sonnet: return 0.10
        case .haiku: return 0.01
        case .fable: return 0.20
        }
    }

    /// 被安全分类器拒绝时，由服务器自动换模型重试（Haiku 5.5 不支持）。
    var supportsServerFallback: Bool { self != .haiku }

    /// 联网搜索工具版本（Haiku 5.5 用基础版）。
    var webSearchToolType: String {
        self == .haiku ? "web_search_20250305" : "web_search_20260209"
    }

    static func from(id: String?) -> ClaudeModel? {
        guard let id else { return nil }
        return ClaudeModel(rawValue: id)
    }
}

enum Effort: String, CaseIterable, Codable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .low: return "快速"
        case .medium: return "标准"
        case .high: return "深入"
        }
    }
}
