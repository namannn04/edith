import Foundation

public struct CompanionScanResult: Equatable, Sendable {
    public let files: [CompanionIngestFile]
    public let skipped: [String]

    public init(files: [CompanionIngestFile], skipped: [String]) {
        self.files = files
        self.skipped = skipped
    }
}

public enum CompanionScan {
    public static func markdownFiles(
        at url: URL, limit maximumByteSize: Int = 2 * 1024 * 1024
    ) throws -> CompanionScanResult {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isRegularFile == true {
            guard url.pathExtension.lowercased() == "md" else {
                return CompanionScanResult(files: [], skipped: [])
            }
            return try scan(urls: [url], relativeTo: nil, maximumByteSize: maximumByteSize)
        }
        guard values.isDirectory == true else {
            return CompanionScanResult(files: [], skipped: [])
        }
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
        ]
        guard
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        else {
            return CompanionScanResult(files: [], skipped: [])
        }
        let markdown = enumerator.compactMap { item -> URL? in
            guard let item = item as? URL, item.pathExtension.lowercased() == "md" else {
                return nil
            }
            let itemValues = try? item.resourceValues(forKeys: [.isRegularFileKey])
            return itemValues?.isRegularFile == true ? item : nil
        }
        return try scan(urls: markdown, relativeTo: url, maximumByteSize: maximumByteSize)
    }

    private static func scan(
        urls: [URL], relativeTo root: URL?, maximumByteSize: Int
    ) throws -> CompanionScanResult {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var files: [CompanionIngestFile] = []
        var skipped: [String] = []
        for url in urls {
            let name = relativeName(for: url, root: root)
            let values = try url.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard values.fileSize.map({ $0 <= maximumByteSize }) ?? true else {
                skipped.append(name)
                continue
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= maximumByteSize else {
                skipped.append(name)
                continue
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            files.append(
                CompanionIngestFile(
                    name: name, text: text,
                    mtime: values.contentModificationDate.map { formatter.string(from: $0) }))
        }
        return CompanionScanResult(
            files: files.sorted { $0.name < $1.name }, skipped: skipped.sorted())
    }

    private static func relativeName(for url: URL, root: URL?) -> String {
        guard let root else { return url.lastPathComponent }
        let prefix = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(prefix) else { return url.lastPathComponent }
        return String(path.dropFirst(prefix.count))
    }
}
