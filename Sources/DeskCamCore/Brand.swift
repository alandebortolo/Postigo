import Foundation

public enum Brand {
    public static let name = "Postigo"
    public static let folderName = "Postigo"
    public static let legacyFolderName = "DeskCam"

    public static func defaultRoot() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let postigo = home.appendingPathComponent("Movies/\(folderName)", isDirectory: true)
        let legacy = home.appendingPathComponent("Movies/\(legacyFolderName)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: postigo.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            return legacy
        }
        return postigo
    }
}
