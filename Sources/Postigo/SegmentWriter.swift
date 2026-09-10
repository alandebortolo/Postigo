import AVFoundation
import CoreVideo
import Foundation

final class SegmentWriter {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStarted = false
    private(set) var url: URL?

    func start(url: URL, width: Int, height: Int, fps: Int32, bitrate: Int) throws {
        finishSync()
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        func settings(_ codec: AVVideoCodecType) -> [String: Any] {
            [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoExpectedSourceFrameRateKey: fps,
                    AVVideoMaxKeyFrameIntervalKey: fps * 2,
                ],
            ]
        }

        var outputSettings = settings(.hevc)
        if !writer.canApply(outputSettings: outputSettings, forMediaType: .video) {
            outputSettings = settings(.h264)
        }
        guard writer.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw NSError(domain: "Postigo", code: 10, userInfo: [NSLocalizedDescriptionKey: "Encoder HEVC/H.264 indisponível"])
        }

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw NSError(domain: "Postigo", code: 11, userInfo: [NSLocalizedDescriptionKey: "Não deu para criar a trilha de vídeo"])
        }
        writer.add(input)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "Postigo", code: 12, userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter recusou start"])
        }

        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        self.sessionStarted = false
        self.url = url
    }

    @discardableResult
    func append(pixelBuffer: CVPixelBuffer, time: CMTime) -> Bool {
        guard let writer, let input, let adaptor, writer.status == .writing else { return false }
        if !sessionStarted {
            writer.startSession(atSourceTime: time)
            sessionStarted = true
        }
        guard input.isReadyForMoreMediaData else { return false }
        return adaptor.append(pixelBuffer, withPresentationTime: time)
    }

    func finish(completion: @escaping () -> Void) {
        guard let writer, let input else {
            completion()
            return
        }
        if writer.status == .writing {
            input.markAsFinished()
            writer.finishWriting {
                completion()
            }
        } else {
            completion()
        }
        self.writer = nil
        self.input = nil
        self.adaptor = nil
        self.sessionStarted = false
    }

    private func finishSync() {
        guard writer != nil else { return }
        let group = DispatchGroup()
        group.enter()
        finish { group.leave() }
        _ = group.wait(timeout: .now() + 5)
    }
}
