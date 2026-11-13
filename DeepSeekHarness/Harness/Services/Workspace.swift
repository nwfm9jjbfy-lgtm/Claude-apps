import Foundation
import Observation

struct FileEntry: Identifiable, Hashable {
    var id: String { path }
    let path: String      // 相对路径
    let name: String
    let isDirectory: Bool
    let size: Int
    let depth: Int
}

/// 每个会话一个工作区文件夹：Documents/<任务-xxxx>/
/// 所有路径都限制在这个文件夹里。
@Observable
final class Workspace {
    let root: URL
    /// 文件有变化时递增，界面据此刷新
    var revision = 0

    init(folder: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent(folder, isDirectory: true).standardizedFileURL
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func touch() {
        DispatchQueue.main.async { self.revision += 1 }
    }

    /// 把相对路径解析成工作区内的 URL，越界就报错
    func resolve(_ path: String) throws -> URL {
        var p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while p.hasPrefix("/") { p.removeFirst() }
        if p.hasPrefix("./") { p.removeFirst(2) }
        let url = (p.isEmpty || p == ".") ? root : root.appendingPathComponent(p).standardizedFileURL
        let rootPath = root.path
        guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else {
            throw HarnessError("路径超出工作区：\(path)")
        }
        return url
    }

    func relative(_ url: URL) -> String {
        let p = url.standardizedFileURL.path
        let r = root.path
        if p == r { return "." }
        return p.hasPrefix(r + "/") ? String(p.dropFirst(r.count + 1)) : p
    }

    // MARK: 文件操作

    func list(_ path: String, recursive: Bool = true, limit: Int = 500) throws -> [FileEntry] {
        let base = try resolve(path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: base.path, isDirectory: &isDir), isDir.boolValue else {
            throw HarnessError("不是文件夹：\(path)")
        }
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        var out: [FileEntry] = []
        let baseDepth = base.pathComponents.count
        if recursive {
            let en = FileManager.default.enumerator(at: base, includingPropertiesForKeys: keys,
                                                    options: [.skipsHiddenFiles])
            while let u = en?.nextObject() as? URL, out.count < limit {
                out.append(entry(u, depth: u.standardizedFileURL.pathComponents.count - baseDepth - 1))
            }
        } else {
            let items = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: keys,
                                                                    options: [.skipsHiddenFiles])
            out = items.prefix(limit).map { entry($0, depth: 0) }
        }
        return out.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func entry(_ u: URL, depth: Int) -> FileEntry {
        let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        return FileEntry(path: relative(u), name: u.lastPathComponent,
                         isDirectory: v?.isDirectory ?? false, size: v?.fileSize ?? 0, depth: max(0, depth))
    }

    func read(_ path: String) throws -> String {
        let url = try resolve(path)
        guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError("文件不存在：\(path)") }
        let data = try Data(contentsOf: url)
        guard let s = String(data: data, encoding: .utf8) else {
            throw HarnessError("不是 UTF-8 文本文件（\(data.count) 字节）：\(path)")
        }
        return s
    }

    func write(_ path: String, _ content: String) throws {
        let url = try resolve(path)
        guard url != root else { throw HarnessError("不能写入工作区根目录") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url, options: .atomic)
        touch()
    }

    func delete(_ path: String) throws {
        let url = try resolve(path)
        guard url != root else { throw HarnessError("不能删除工作区根目录") }
        guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError("文件不存在：\(path)") }
        try FileManager.default.removeItem(at: url)
        touch()
    }

    func importFile(from src: URL) throws -> String {
        let access = src.startAccessingSecurityScopedResource()
        defer { if access { src.stopAccessingSecurityScopedResource() } }
        var dest = root.appendingPathComponent(src.lastPathComponent)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            let ext = src.pathExtension
            let stem = src.deletingPathExtension().lastPathComponent
            dest = root.appendingPathComponent(ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)")
            n += 1
        }
        try FileManager.default.copyItem(at: src, to: dest)
        touch()
        return relative(dest)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }
}
