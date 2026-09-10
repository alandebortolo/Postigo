import CoreImage
import CoreVideo
import Foundation

enum SnapshotWriter {
    private static let ci = CIContext(options: [.useSoftwareRenderer: false])

    static func writeJPEG(buffer: CVPixelBuffer, to url: URL) throws {
        let image = CIImage(cvPixelBuffer: buffer)
        let space = CGColorSpaceCreateDeviceRGB()
        try ci.writeJPEGRepresentation(
            of: image,
            to: url,
            colorSpace: space,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.72]
        )
    }
}
