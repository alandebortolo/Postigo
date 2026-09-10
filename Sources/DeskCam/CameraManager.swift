import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

struct CameraInfo: Equatable {
    var uniqueID: String
    var name: String
}

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(label: "br.com.designmaster.deskcam.capture")
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var running = false

    func listCameras() -> [CameraInfo] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { CameraInfo(uniqueID: $0.uniqueID, name: $0.localizedName) }
    }

    func authorization() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        let status = authorization()
        if status == .authorized {
            completion(true)
            return
        }
        if status == .denied || status == .restricted {
            completion(false)
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func start(cameraID: String?, width: Int, height: Int, fps: Int32) throws {
        if running { stop() }

        session.beginConfiguration()
        session.sessionPreset = width >= 1920 ? .hd1920x1080 : .hd1280x720

        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }
        for existing in session.outputs {
            session.removeOutput(existing)
        }

        guard let device = Self.device(cameraID: cameraID) else {
            session.commitConfiguration()
            throw NSError(domain: "DeskCam", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nenhuma câmera encontrada"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw NSError(domain: "DeskCam", code: 2, userInfo: [NSLocalizedDescriptionKey: "Não deu para abrir a câmera"])
        }
        session.addInput(input)
        currentInput = input

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw NSError(domain: "DeskCam", code: 3, userInfo: [NSLocalizedDescriptionKey: "Não deu para ligar a saída de vídeo"])
        }
        session.addOutput(output)

        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: fps)
            let range = device.activeFormat.videoSupportedFrameRateRanges
            let ok = range.contains { $0.minFrameDuration <= duration && duration <= $0.maxFrameDuration }
            if ok {
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }

        session.commitConfiguration()
        session.startRunning()
        running = session.isRunning
        if !running {
            throw NSError(domain: "DeskCam", code: 4, userInfo: [NSLocalizedDescriptionKey: "A sessão da câmera não iniciou"])
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        running = false
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        onFrame?(pixel, time)
    }

    private static func device(cameraID: String?) -> AVCaptureDevice? {
        if let cameraID, let match = AVCaptureDevice(uniqueID: cameraID) {
            return match
        }
        return AVCaptureDevice.default(for: .video)
    }
}
