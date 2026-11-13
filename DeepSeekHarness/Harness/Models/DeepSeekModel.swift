import Foundation

/// DeepSeek 官方模型。价格：美元 / 百万 token（高峰价，非高峰时段减半）
enum DeepSeekModel: String, CaseIterable, Codable, Identifiable {
    case flash = "deepseek-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "DeepSeek Flash"
        case .pro: return "DeepSeek V4 Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .flash: return "快、便宜，日常任务首选"
        case .pro: return "更强，适合复杂任务"
        }
    }

    var peakCacheHit: Double { self == .flash ? 0.006 : 0.044 }
    var peakCacheMiss: Double { self == .flash ? 0.3 : 1.32 }
    var peakOutput: Double { self == .flash ? 1.2 : 3.96 }

    /// 高峰时段：周一到周五 UTC 01:00–04:00 和 06:00–10:00（官方另外排除中国法定节假日，这里不处理）
    static func isPeak(_ date: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let wd = cal.component(.weekday, from: date) // 1 = 周日
        guard (2...6).contains(wd) else { return false }
        let h = cal.component(.hour, from: date)
        return (1..<4).contains(h) || (6..<10).contains(h)
    }

    func cost(hit: Int, miss: Int, output: Int, at date: Date = Date()) -> Double {
        let factor = Self.isPeak(date) ? 1.0 : 0.5
        return (Double(hit) * peakCacheHit + Double(miss) * peakCacheMiss + Double(output) * peakOutput)
            * factor / 1_000_000
    }
}

enum ReasoningEffort: String, CaseIterable, Codable, Identifiable {
    case off, low, high, max
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "关闭思考"
        case .low: return "低"
        case .high: return "高（默认）"
        case .max: return "最高"
        }
    }
}

enum PermissionMode: String, CaseIterable, Codable, Identifiable {
    case ask, auto
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ask: return "改动前询问"
        case .auto: return "全部自动"
        }
    }
}
