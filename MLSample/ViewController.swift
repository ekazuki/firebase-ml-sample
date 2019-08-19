import Firebase
import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    let captureSession = AVCaptureSession()
    let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
    var englishJapaneseTranslator: Translator?
    var mainCamera: AVCaptureDevice?
    var innerCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice?
    var photoOutput : AVCapturePhotoOutput?
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var translateLabelView: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        initialize()
    }
    
    func initialize()
    {
        setupTranslator()
        setupCamera()
        setupCaptureButton()
        setupBackButton()
        enableCamera();
    }
    
    func setupTranslator() {
        englishJapaneseTranslator = NaturalLanguage.naturalLanguage().translator(options: TranslatorOptions(sourceLanguage: .en, targetLanguage: .ja))
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: false,
            allowsBackgroundDownloading: true
        )
        if englishJapaneseTranslator != nil {
            englishJapaneseTranslator!.downloadModelIfNeeded(with: conditions) { error in
                guard error == nil else { return }
                self.indicator.stopAnimating()
                self.indicator.isHidden = true
            }
        }
    }
    
    func setupCamera() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                mainCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                innerCamera = device
            }
        }
        currentDevice = mainCamera
        
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
        } catch {
            print(error)
        }
        
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        cameraPreviewLayer?.frame = view.frame
        view.layer.insertSublayer(self.cameraPreviewLayer!, at: 0)
    }
    
    func setupCaptureButton() {
        captureButton.layer.borderColor = UIColor.gray.cgColor
        captureButton.layer.borderWidth = 5
        captureButton.clipsToBounds = true
        captureButton.backgroundColor = UIColor.white;
        captureButton.layer.cornerRadius = min(captureButton.frame.width, captureButton.frame.height) / 2
    }
    
    func setupBackButton() {
        backButton.layer.borderColor = UIColor.white.cgColor
        backButton.layer.borderWidth = 5
        backButton.clipsToBounds = true
        backButton.layer.cornerRadius = min(captureButton.frame.width, captureButton.frame.height) / 2
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let uiImage = UIImage(data: imageData) {
            disableCamera()
            processText(image: uiImage)
        }
    }
    
    func processText(image: UIImage) {
        let vision = Vision.vision()
        let textRecognizer = vision.onDeviceTextRecognizer()
        let visionImage = VisionImage(image: image)
        textRecognizer.process(visionImage) { result, error in
            guard error == nil, let result = result else {
                print("[ERROR]: " + error.debugDescription)
                return
            }

            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            let previewFrame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: self.view.frame.width * aspectRatio, height: self.view.frame.height)
            let xOffSet = (self.view.frame.width - previewFrame.width) * 0.5
            let widthRate = previewFrame.width / imageSize.height;
            let heightRate = previewFrame.height / imageSize.width;

            for block in result.blocks {
                let blockText = block.text
                let frame = block.frame;
                if frame.width < 100 || frame.height < 100 {
                    continue;
                }
                if self.englishJapaneseTranslator != nil {
                    self.englishJapaneseTranslator!.translate(blockText) { translatedText, error in
                        guard error == nil, let translatedText = translatedText else {
                            print("[ERROR]: " + error.debugDescription)
                            return
                        }
                        DispatchQueue.main.async {
                            let label = UILabel(frame: CGRect(x: xOffSet + frame.origin.x * widthRate, y: frame.origin.y * heightRate, width: frame.width * widthRate, height: frame.height * heightRate))
                            label.text = translatedText
                            label.textColor = UIColor.white
                            label.backgroundColor = UIColor.red
                            label.numberOfLines = 0
                            label.adjustsFontSizeToFitWidth = true
                            self.translateLabelView.addSubview(label)
                        }
                    }
                }
            }
        }
    }
    
    func disableCamera() {
        captureSession.stopRunning()
        captureButton.isHidden = true
        backButton.isHidden = false
    }

    func enableCamera() {
        captureSession.startRunning()
        captureButton.isHidden = false
        backButton.isHidden = true
    }

    @IBAction func captureButton_TouchUpInside(_ sender: Any) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        settings.isAutoStillImageStabilizationEnabled = true
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func backButton_TouchUpInside(_ sender: Any) {
        enableCamera()
        for view in translateLabelView.subviews {
            view.removeFromSuperview()
        }
    }
}
