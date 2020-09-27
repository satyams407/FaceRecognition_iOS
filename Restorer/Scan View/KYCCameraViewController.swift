import UIKit
import CoreMedia
import Firebase
import AVFoundation

protocol KYCFacePhotoDelegate {
    func didCapturedFacePhoto(_ image:UIImage)
}

//Camera Page for FacePhoto
class KYCCameraViewController: UIViewController {

    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var drawingView: DrawingView!
    
    var delegate:KYCFacePhotoDelegate?
    
    private var eyeOpenTiming: Int = 0
    private var eyeCloseTiming: Int = 0
    private var count = 0
    
    // MARK - Performance Measurement Property
    private var isBeingCaptured:Bool = false
    private var shouldCaptureSelfie:  Bool = true
    private let messure = Measure()
    
    @IBOutlet weak var cameraOrientationButton: UIButton!
    
    @IBOutlet weak var captureButton: UIButton!{
        didSet{
            captureButton.backgroundColor = BaseConstant.Colors.themeButtonBlue
            captureButton.layer.cornerRadius = 8.0
        }
    }
    
    // MARK: - ML Kit Vision Property
    
    var imageLabler: VisionImageLabeler?
    let remoteModel = AutoMLRemoteModel(
        name: "faces_big_data_base"
    )
    let downloadConditions = ModelDownloadConditions(
      allowsCellularAccess: true,
      allowsBackgroundDownloading: true
    )
    
    lazy var vision = Vision.vision()
    lazy var faceDetector: VisionFaceDetector = { () -> VisionFaceDetector in
        // Real-time contour detection of multiple faces
        let options = VisionFaceDetectorOptions()
        options.contourMode = .all
        options.classificationMode = .all
        
        return vision.faceDetector(options: options)
    }()
    var isInference = false
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCamera()
        drawingView.setUp()
        messure.delegate = self
        self.getRemoteModel()
        
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if KYCCaptureViewModel.enableDetectionBoxes == true {
            drawingView.overlayView?.layoutSubviews()
            drawingView.overlayView?.setNeedsDisplay()
        }

    }
    
    private func getRemoteModel() {
        _ = ModelManager.modelManager().download (
          remoteModel,
          conditions: downloadConditions
        )
        if (ModelManager.modelManager().isModelDownloaded(remoteModel)) {
            ModelManager.modelManager().getLatestModelFilePath(remoteModel) { (data, error) in
                self.configureModel()
            }
        }
        
        
        NotificationCenter.default.addObserver(
            forName: .firebaseMLModelDownloadDidSucceed,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let strongSelf = self
                else { return }
            strongSelf.configureModel()
        }

        NotificationCenter.default.addObserver(
            forName: .firebaseMLModelDownloadDidFail,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let strongSelf = self,
                let userInfo = notification.userInfo
                else { return }
//            let error = userInfo[ModelDownloadUserInfoKey.error.rawValue]
    
//            strongSelf.showAlert(title: "Error", message: "Failed")
            strongSelf.configureModel()
        }
    }
    
    @objc func configureModel() {
           guard let menifestPath =  Bundle.main.path(forResource: "manifest", ofType: "json") else {
            self.showAlert(title: "Error", message: "Not able to find menifest file")
               return
           }
         let localModel = AutoMLLocalModel(manifestPath: menifestPath)
           var options: VisionOnDeviceAutoMLImageLabelerOptions?
           if (ModelManager.modelManager().isModelDownloaded(remoteModel)) {
             options = VisionOnDeviceAutoMLImageLabelerOptions(remoteModel: remoteModel)
           } else {
                    options = VisionOnDeviceAutoMLImageLabelerOptions(localModel: localModel)
            
        }
           options?.confidenceThreshold = 0.5
           if let visionOptions = options {
               imageLabler = Vision.vision().onDeviceAutoMLImageLabeler(options: visionOptions)
           }
       }
    private func validateImage(_ image: VisionImage, completion: @escaping (String?) -> Void) {
        imageLabler?.process(image, completion: { [weak self] (visioinlbls, error) in
            if let processError = error {
                self?.showAlert(title: "Error", message: processError.localizedDescription)
                return
            }
            if let responselbls = visioinlbls {
                if responselbls.count > 0  {
                     for visionlabel in responselbls {
                        let confidenceString = String(format: "%0.2f", (visionlabel.confidence ?? 0).doubleValue * 100)
                        completion(confidenceString)
                        return
                    }
                }
            }
            completion(nil)
        })
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        AVCaptureDevice.authorizeVideo { (status) in
            if status == .alreadyAuthorized || status == .justAuthorized {
                 self.startVideoCapture()
            }
            else {
                AVCaptureDevice.cameraDisabledWarnAlert(self)
            }
        }
    }
    
    private func startVideoCapture(){
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(self.shouldCaptureSelfie, sessionPreset: .high) { success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    @IBAction func changeCameraOrientation(_ sender: Any) {
        self.shouldCaptureSelfie = !self.shouldCaptureSelfie
        self.isBeingCaptured = false
        self.videoCapture.stop()
        self.setUpCamera()
    }
    
    @IBAction func capture(_ sender: Any) {
        DispatchQueue.main.async {
            self.takePicture()
        }
    }
    private func takePicture() {
        let isAllowedCapture = KYCCaptureViewModel.enableDetectionBoxes == true ? self.drawingView.allwedCapture  : true
        if isAllowedCapture && !self.isInference {
            self.videoCapture.capture()
        } else {
            WPUtility.showToast("Try again ! Face is not within frame.")
        }
    }
    
    func getCurDuration()-> Int {
        let date = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: date)
        return seconds
    }
}

extension KYCCameraViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if !self.isInference, let pixelBuffer = pixelBuffer {
            // start of measure
            self.messure.start()
            self.isInference = true
            
            // predict!
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
    
    func capturePhoto(_ pixelBuffer: CVPixelBuffer?) {
        if  let pixelBuffer = pixelBuffer {
            self.isBeingCaptured = true
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension KYCCameraViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        let ciimage: CIImage = CIImage(cvImageBuffer: pixelBuffer)
          // crop found word
        let ciContext = CIContext()
        guard let cgImage: CGImage = ciContext.createCGImage(ciimage, from: ciimage.extent) else {
            self.isInference = false
            // end of measure
            self.messure.stop()
            return
        }
        let uiImage: UIImage = UIImage(cgImage: cgImage)
        let visionImage = VisionImage(image: uiImage)
        faceDetector.process(visionImage) { (features, error) in
            self.messure.label(with: "endInference")
            // this closure is called on main thread
            if error == nil, let faces: [VisionFace] = features {
                if !self.isBeingCaptured {
                    self.drawingView.imageSize = uiImage.size
                    self.drawingView.faces = faces
                    
                    DispatchQueue.main.async {
                        if faces.count < 2 , let face = faces.first { // only one face is required
                            self.validateForBlinking(face)
                        }
                    }
                    
                } else {
                    // image already captured review image
                    if let face = faces.first {
                        if face.leftEyeOpenProbability < 0.6 || face.rightEyeOpenProbability < 0.6 {
                             WPUtility.showToast("Keep eyes open for 1 sec") //key: capturing
                            self.reCapture()
                        } else {
                            self.validateImage(visionImage) { (confidenceLabel) in
                                
                                if let confidence = Double(confidenceLabel ?? "0.0") {
                                    if confidence < 60.0 {
                                        WPUtility.showToast("No face detected yet")
                                        self.reCapture()
                                        return
                                    }
                                }
                                
                                
                                self.delegate?.didCapturedFacePhoto(uiImage)
                            }
                        }
                    }
                    self.removeFaceDetectores()
                }
                
            } else {
                self.removeFaceDetectores()
            }
            
             self.isInference = false
            // end of measure
            self.messure.stop()
        }
    }
    private func reCapture(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.isBeingCaptured = false
            self.videoCapture.stop()
            self.setUpCamera()
        })
    }
    private func validateForBlinking(_ face: VisionFace) {
        let leftEyeOpenProbability = face.leftEyeOpenProbability
        let rightEyeOpenProbability = face.rightEyeOpenProbability
        
        
        if leftEyeOpenProbability < 0.1 && rightEyeOpenProbability < 0.1 {
            self.eyeCloseTiming = self.getCurDuration()
            
        }
        else if leftEyeOpenProbability > 0.6 && rightEyeOpenProbability > 0.6 {
            self.eyeOpenTiming = self.getCurDuration()
        }
        
        if self.eyeOpenTiming - self.eyeCloseTiming == 2 {
            if self.count == 2 {
                DispatchQueue.main.async {
                    self.takePicture()
                }
            } else {
                if self.count > 2 {
                    self.count = 0
                }
                self.count += 1
            }
        }
    }
    
    private func removeFaceDetectores() {
        self.drawingView.imageSize = .zero
        self.drawingView.faces = []
    }
    
    override func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: LocalizationConstant.ok.localized(), style: .cancel, handler: { (_) in
            self.isBeingCaptured = false
            self.messure.start()
            self.videoCapture.start()
        }))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - (Performance Measurement) Delegate
extension KYCCameraViewController: MeasureDelegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        //print(executionTime, fps)
//        self.inferenceLabel.text = "inference: \(Int(inferenceTime*1000.0)) mm"
//        self.etimeLabel.text = "execution: \(Int(executionTime*1000.0)) mm"
//        self.fpsLabel.text = "fps: \(fps)"
    }
}

