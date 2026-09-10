import Foundation

public enum Brand {
    public static let name = "Postigo"
    public static let folderName = "Postigo"
    public static let bundleID = "br.com.designmaster.postigo"

    public static func defaultRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/\(folderName)", isDirectory: true)
    }
}
