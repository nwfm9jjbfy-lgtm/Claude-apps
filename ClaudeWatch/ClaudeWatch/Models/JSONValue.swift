import Foundation

/// 任意 JSON 值。用来原样保存 API 返回的内容块（思考块、搜索结果、引用等），
/// 下一轮对话时原封不动地发回去，保证思考块签名有效。
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "无法解析的 JSON 值")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var string: String? { if case .string(let s) = self { return s }; return nil }
    var double: Double? { if case .number(let n) = self { return n }; return nil }
    var int: Int? { double.map { Int($0) } }
    var array: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    var isNull: Bool { if case .null = self { return true }; return false }

    static func parse(_ data: Data) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func parse(_ text: String) -> JSONValue? {
        parse(Data(text.utf8))
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral,
                     ExpressibleByIntegerLiteral, ExpressibleByDictionaryLiteral,
                     ExpressibleByArrayLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { $1 }))
    }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}
