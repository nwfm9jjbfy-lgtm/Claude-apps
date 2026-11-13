import Foundation

/// Agent 可以调用的工具
enum ToolKind: String, CaseIterable {
    case listFiles = "list_files"
    case readFile = "read_file"
    case writeFile = "write_file"
    case editFile = "edit_file"
    case deleteFile = "delete_file"
    case runJavaScript = "run_javascript"
    case fetchURL = "fetch_url"
    case updatePlan = "update_plan"

    /// 会改动文件或执行代码的工具，在"改动前询问"模式下需要用户批准
    var needsApproval: Bool {
        switch self {
        case .writeFile, .editFile, .deleteFile, .runJavaScript: return true
        default: return false
        }
    }

    var icon: String {
        switch self {
        case .listFiles: return "folder"
        case .readFile: return "doc.text"
        case .writeFile: return "square.and.pencil"
        case .editFile: return "pencil.line"
        case .deleteFile: return "trash"
        case .runJavaScript: return "curlybraces"
        case .fetchURL: return "globe"
        case .updatePlan: return "checklist"
        }
    }

    var label: String {
        switch self {
        case .listFiles: return "列出文件"
        case .readFile: return "读取文件"
        case .writeFile: return "写入文件"
        case .editFile: return "修改文件"
        case .deleteFile: return "删除文件"
        case .runJavaScript: return "运行 JavaScript"
        case .fetchURL: return "抓取网页"
        case .updatePlan: return "更新计划"
        }
    }
}

enum Tools {
    /// 工具结果的长度上限，超出时明确告诉模型被截断了
    static let maxResultChars = 60_000

    static var definitions: JSONValue {
        .array([
            fn("list_files", "List files and folders in the workspace (recursive). Directories end with '/'.",
               ["path": str("Folder path relative to the workspace root. Use \".\" for the root.")],
               required: ["path"]),
            fn("read_file", "Read a UTF-8 text file from the workspace. Returns numbered lines. Use offset/limit for large files.",
               ["path": str("File path relative to the workspace root."),
                "offset": int("1-based line number to start from. Use 1 to start at the top."),
                "limit": int("Maximum number of lines to return. Use 2000 by default.")],
               required: ["path", "offset", "limit"]),
            fn("write_file", "Create or overwrite a text file in the workspace. Parent folders are created automatically.",
               ["path": str("File path relative to the workspace root."),
                "content": str("The full file content.")],
               required: ["path", "content"]),
            fn("edit_file", "Replace an exact snippet in a file. old_string must appear exactly once in the file; include enough surrounding context to make it unique.",
               ["path": str("File path relative to the workspace root."),
                "old_string": str("Exact text to replace, copied from the file."),
                "new_string": str("Replacement text.")],
               required: ["path", "old_string", "new_string"]),
            fn("delete_file", "Delete a file or folder in the workspace.",
               ["path": str("Path relative to the workspace root.")],
               required: ["path"]),
            fn("run_javascript", "Run JavaScript in JavaScriptCore and return console output and the value of the last expression. No DOM, no network, no Node APIs. Available helpers: readFile(path) -> string, writeFile(path, text) -> bool, listFiles(path) -> string[]. Time limit 20 seconds.",
               ["code": str("JavaScript source to run.")],
               required: ["code"]),
            fn("fetch_url", "Download a web page or API endpoint over HTTP(S) and return it as text (HTML is converted to readable text with link URLs in brackets).",
               ["url": str("Absolute http(s) URL.")],
               required: ["url"]),
            fn("update_plan", "Replace the task checklist shown to the user. Call it at the start of a multi-step task and whenever a step's status changes.",
               ["items": [
                    "type": "array",
                    "description": "The full checklist, in order.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "content": str("Short description of the step."),
                            "status": ["type": "string", "enum": ["pending", "in_progress", "completed"],
                                       "description": "Step status."],
                        ],
                        "required": ["content", "status"],
                        "additionalProperties": false,
                    ],
               ]],
               required: ["items"]),
        ])
    }

    private static func fn(_ name: String, _ desc: String, _ props: [String: JSONValue], required: [String]) -> JSONValue {
        [
            "type": "function",
            "function": [
                "name": .string(name),
                "description": .string(desc),
                "parameters": [
                    "type": "object",
                    "properties": .object(props),
                    "required": .array(required.map { .string($0) }),
                    "additionalProperties": false,
                ],
            ],
        ]
    }

    private static func str(_ d: String) -> JSONValue { ["type": "string", "description": .string(d)] }
    private static func int(_ d: String) -> JSONValue { ["type": "integer", "description": .string(d)] }

    /// 卡片上显示的一行摘要
    static func summary(name: String, args: JSONValue?) -> String {
        guard let kind = ToolKind(rawValue: name) else { return name }
        switch kind {
        case .listFiles, .readFile, .writeFile, .editFile, .deleteFile:
            return args?["path"]?.string ?? ""
        case .runJavaScript:
            let code = args?["code"]?.string ?? ""
            return code.split(separator: "\n").first.map(String.init) ?? ""
        case .fetchURL:
            return args?["url"]?.string ?? ""
        case .updatePlan:
            return "\(args?["items"]?.array?.count ?? 0) 项"
        }
    }

    struct Outcome {
        var output: String
        var isError = false
        var plan: [PlanItem]? = nil
    }

    static func execute(name: String, args: JSONValue?, workspace: Workspace, network: NetworkConfig) async -> Outcome {
        guard let kind = ToolKind(rawValue: name) else {
            return Outcome(output: "Error: unknown tool \(name)", isError: true)
        }
        guard let args, args.object != nil else {
            return Outcome(output: "Error: tool arguments were not valid JSON. Call the tool again with a JSON object.", isError: true)
        }
        do {
            switch kind {
            case .listFiles:
                let items = try workspace.list(args["path"]?.string ?? ".")
                if items.isEmpty { return Outcome(output: "(empty)") }
                let lines = items.map { e in
                    e.isDirectory ? e.path + "/" : "\(e.path)  (\(e.size) bytes)"
                }
                return Outcome(output: lines.joined(separator: "\n"))

            case .readFile:
                let path = args["path"]?.string ?? ""
                let text = try workspace.read(path)
                let all = text.components(separatedBy: "\n")
                let offset = max(1, args["offset"]?.int ?? 1)
                let limit = max(1, args["limit"]?.int ?? 2000)
                guard offset <= max(all.count, 1) else {
                    return Outcome(output: "Error: offset \(offset) is past the end of the file (\(all.count) lines).", isError: true)
                }
                let end = min(all.count, offset - 1 + limit)
                var out = (offset - 1..<end).map { "\($0 + 1)\t\(all[$0])" }.joined(separator: "\n")
                if end < all.count { out += "\n[\(all.count - end) more lines. Call read_file with offset \(end + 1) to continue.]" }
                if text.isEmpty { out = "(empty file)" }
                return Outcome(output: out)

            case .writeFile:
                let path = args["path"]?.string ?? ""
                let content = args["content"]?.string ?? ""
                try workspace.write(path, content)
                return Outcome(output: "Wrote \(content.utf8.count) bytes to \(path).")

            case .editFile:
                let path = args["path"]?.string ?? ""
                let old = args["old_string"]?.string ?? ""
                let new = args["new_string"]?.string ?? ""
                guard !old.isEmpty else { return Outcome(output: "Error: old_string is empty.", isError: true) }
                let text = try workspace.read(path)
                let count = text.components(separatedBy: old).count - 1
                if count == 0 {
                    return Outcome(output: "Error: old_string was not found in \(path). Read the file again and copy the text exactly.", isError: true)
                }
                if count > 1 {
                    return Outcome(output: "Error: old_string appears \(count) times in \(path). Include more context so it is unique.", isError: true)
                }
                try workspace.write(path, text.replacingOccurrences(of: old, with: new))
                return Outcome(output: "Edited \(path).")

            case .deleteFile:
                let path = args["path"]?.string ?? ""
                try workspace.delete(path)
                return Outcome(output: "Deleted \(path).")

            case .runJavaScript:
                let r = await JSRunner.run(args["code"]?.string ?? "", workspace: workspace)
                return Outcome(output: cap(r.output), isError: r.isError)

            case .fetchURL:
                let text = try await WebFetcher.fetch(args["url"]?.string ?? "", network: network)
                return Outcome(output: cap(text))

            case .updatePlan:
                let items = (args["items"]?.array ?? []).compactMap { i -> PlanItem? in
                    guard let c = i["content"]?.string else { return nil }
                    return PlanItem(content: c, status: i["status"]?.string ?? "pending")
                }
                return Outcome(output: "Plan updated (\(items.count) items).", plan: items)
            }
        } catch {
            return Outcome(output: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    static func cap(_ s: String) -> String {
        guard s.count > maxResultChars else { return s }
        return String(s.prefix(maxResultChars))
            + "\n\n[Output truncated: \(s.count - maxResultChars) more characters were not shown.]"
    }
}
