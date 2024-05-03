import ARKit
import Flutter

class LidarManager: NSObject, ARSessionDelegate {
    private let session = ARSession()
    private var methodChannel: FlutterMethodChannel?

    override init() {
        super.init()

        let flutterViewController =
            (UIApplication.shared.delegate as! AppDelegate).window.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "lidar_channel", binaryMessenger: flutterViewController.binaryMessenger)
        methodChannel!.setMethodCallHandler({
          (call: FlutterMethodCall, result: FlutterResult) -> Void in
          // This method is invoked on the UI thread.
          guard call.method == "captureLidar" else {
            result(FlutterMethodNotImplemented)
            return
          }
          self.captureLidar()
        })


        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics.insert(.sceneDepth)
        session.delegate = self
        session.run(configuration)
        
        print("start")
    }

//    func captureLidar(result: FlutterResult) {
//        print("invoke")
//        guard let depthMap = arSession.currentFrame?.sceneDepth?.depthMap else {
//            print("error get depth")
//            return
//        }
//        print("capture")
//        sendDepthDataAsList(depthMap: depthMap, result: result)
//        print("send")
//    }
    func captureLidar() {
        print("begin send")
        guard let frame = session.currentFrame else {
            print("No frame")
            return
        }
        
        let sceneDepth = frame.sceneDepth
        let depthMap = sceneDepth!.depthMap
        let imageBuffer = frame.capturedImage

        // Convert depth data to list
        let depthArray = convertDepthDataToList(depthMap: depthMap)
        print("converted depth")
        // Convert image data (CVPixelBuffer) to a transferable format
        let imageData = convertImageToData(imageBuffer: imageBuffer)
        print("converted image")
        // Send data to Flutter
        methodChannel!.invokeMethod("onFrameUpdate", arguments: [
            "depthData": depthArray,
            "imageData": imageData // Assuming imageData is in a Flutter-compatible format
        ])
        print("sent")
    }
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        // Handle AR session failure here
//        print("AR session failed with error: \(error.localizedDescription)")
//        // You can take appropriate actions based on the error, like informing the user or attempting to recover
//    }
//    
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        print("begin send")
//        let sceneDepth = frame.sceneDepth
//        let depthMap = sceneDepth!.depthMap
//        let imageBuffer = frame.capturedImage
//
//        // Convert depth data to list
//        let depthArray = convertDepthDataToList(depthMap: depthMap)
//        print("converted depth")
//        // Convert image data (CVPixelBuffer) to a transferable format
//        let imageData = convertImageToData(imageBuffer: imageBuffer)
//        print("converted image")
//        // Send data to Flutter
//        methodChannel?.invokeMethod("onFrameUpdate", arguments: [
//            "depthData": depthArray,
//            "imageData": imageData // Assuming imageData is in a Flutter-compatible format
//        ])
//        print("sent")
//    }
    
    private func convertImageToData(imageBuffer: CVPixelBuffer) -> Data { // Or another suitable format
        // 1. Lock pixel buffer for access
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 1.0) ?? Data()
        }
        return Data()
    }

    private func convertDepthDataToList(depthMap: CVPixelBuffer) -> [[Float32]] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly) // Lock for reading
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)

        var depthArray = [[Float32]]()
        
        print("converting")
        // Assuming depth data is stored as Float32
        if let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self) {
            for row in 0..<height {
                var depthRow = [Float32]()
                for col in 0..<width {
                    let depthValue = floatBuffer[row * width + col]
                    depthRow.append(depthValue)
                }
                depthArray.append(depthRow)
            }
        }

        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

        return depthArray
    }
}
