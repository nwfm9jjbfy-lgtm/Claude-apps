import Foundation
import JavaScriptCore

/// 在 JavaScriptCore 里运行模型写的代码，可以读写工作区文件。
enum JSRunner {
    private static let queue = DispatchQueue(label: "js-runner", qos: .userInitiated)

    static func run(_ code: String, workspace: Workspace, timeout: TimeInterval = 20) async -> (output: String, isError: Bool) {
        await withCheckedContinuation { cont in
            let lock = NSLock()
            var finished = false
            func finish(_ r: (String, Bool)) {
                lock.lock(); defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                cont.resume(returning: r)
            }

            queue.async {
                let r = execute(code, workspace: workspace)
                finish(r)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(("超时：脚本运行超过 \(Int(timeout)) 秒（脚本可能仍在后台运行，请避免死循环）", true))
            }
        }
    }

    private static func execute(_ code: String, workspace: Workspace) -> (String, Bool) {
        guard let ctx = JSContext() else { return ("无法创建 JavaScript 环境", true) }
        var logs: [String] = []
        var thrown: String?

        ctx.exceptionHandler = { _, ex in
            let msg = ex?.toString() ?? "unknown error"
            let line = ex?.objectForKeyedSubscript("line")?.toString() ?? "?"
            thrown = "\(msg)（第 \(line) 行）"
        }

        let log: @convention(block) () -> Void = {
            let args = JSContext.currentArguments() as? [JSValue] ?? []
            logs.append(args.map(describe).joined(separator: " "))
        }
        let console = JSValue(newObjectIn: ctx)
        console?.setObject(log, forKeyedSubscript: "log" as NSString)
        console?.setObject(log, forKeyedSubscript: "info" as NSString)
        console?.setObject(log, forKeyedSubscript: "warn" as NSString)
        console?.setObject(log, forKeyedSubscript: "error" as NSString)
        ctx.setObject(console, forKeyedSubscript: "console" as NSString)

        let readFile: @convention(block) (String) -> Any = { path in
            do { return try workspace.read(path) } catch {
                JSContext.current()?.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: JSContext.current())
                return NSNull()
            }
        }
        let writeFile: @convention(block) (String, String) -> Bool = { path, text in
            do { try workspace.write(path, text); return true } catch {
                JSContext.current()?.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: JSContext.current())
                return false
            }
        }
        let listFiles: @convention(block) (String?) -> [String] = { path in
            // 不传参数时 JavaScriptCore 会传入 "undefined"
            let p = (path == nil || path == "undefined" || path == "null") ? "." : path!
            return (try? workspace.list(p).map { $0.isDirectory ? $0.path + "/" : $0.path }) ?? []
        }
        ctx.setObject(readFile, forKeyedSubscript: "readFile" as NSString)
        ctx.setObject(writeFile, forKeyedSubscript: "writeFile" as NSString)
        ctx.setObject(listFiles, forKeyedSubscript: "listFiles" as NSString)

        let result = ctx.evaluateScript(code)

        var out = logs.joined(separator: "\n")
        if let thrown {
            if !out.isEmpty { out += "\n" }
            return (out + "错误：" + thrown, true)
        }
        if let result, !result.isUndefined {
            if !out.isEmpty { out += "\n" }
            out += "=> " + describe(result)
        }
        return (out.isEmpty ? "（没有输出。用 console.log 打印结果）" : out, false)
    }

    private static func describe(_ v: JSValue) -> String {
        if v.isString { return v.toString() }
        if v.isObject, !v.isNull,
           let json = v.context.objectForKeyedSubscript("JSON")?
            .invokeMethod("stringify", withArguments: [v, NSNull(), 2]),
           json.isString {
            return json.toString()
        }
        return v.toString()
    }
}
