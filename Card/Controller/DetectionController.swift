
import UIKit

class DetectionController: UIViewController {
    
    // MARK: Storyboards Connections
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var resumeButton: UIButton!
    @IBOutlet weak var cameraUnavailableLabel: UILabel!
    @IBOutlet weak var modeChangeBtn: UIButton!
    @IBOutlet weak var guideLabel: UILabel!
    
    // MARK: Constants
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -30.0
    private let expandTransitionThreshold: CGFloat = 30.0
    private let delayBetweenInferencesMs: Double = 200
    
    // MARK: Instance Variables
    private var initialBottomSpace: CGFloat = 0.0
    
    // Holds the results at any time
    private var result: Result?
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
    
    // MARK: Controllers that manage functionality
    private lazy var cameraFeedManager = CameraFeedManager(previewView: previewView)
    private var modelDataHandler: ModelDataHandler? =
    ModelDataHandler(modelFileInfo: tflite.modelInfo, labelsFileInfo: tflite.labelsInfo)
    
    var cardResult: Card!
    var errorCount = 0
    var checkCount = 0
    var cardNumDic: [String: Int]! = [:]
    var cardMonthDic: [String: Int]! = [:]
    var cardYearDic: [String: Int]! = [:]
    var sendCheck = false
    var verticalMode: Bool = true
    var cropRect: CGRect!
    
    // MARK: View Handling Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 촬영 모드 설정 및 버튼 적용
        setupCardGuide(mode: "horizontal")
        modeChangeBtn.setTitle("세로카드 스캔", for: .normal)
        modeChangeBtn.setImage(#imageLiteral(resourceName: "bt_ic_card"), for: .normal)
        modeChangeBtn.setTitleColor(.black, for: .normal)
        modeChangeBtn.imageView?.contentMode = .scaleAspectFit
        modeChangeBtn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        modeChangeBtn.contentHorizontalAlignment = .center
        modeChangeBtn.semanticContentAttribute = .forceLeftToRight
        modeChangeBtn.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        
        
        guard modelDataHandler != nil else {
            fatalError("Failed to load model")
        }
        cameraFeedManager.delegate = self
        overlayView.clearsContextBeforeDrawing = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedManager.checkCameraConfigurationAndStartSession()
        cardResult = nil
        sendCheck = false
        checkCount = 0
        errorCount = 0
        cardNumDic = [:]
        cardMonthDic = [:]
        cardYearDic = [:]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cardResult = nil
        sendCheck = false
        checkCount = 0
        errorCount = 0
        cardNumDic = [:]
        cardMonthDic = [:]
        cardYearDic = [:]
        cameraFeedManager.stopSession()
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: Button Actions
    @IBAction func onClickResumeButton(_ sender: Any) {
        
        cameraFeedManager.resumeInterruptedSession { (complete) in
            
            if complete {
                self.resumeButton.isHidden = true
                self.cameraUnavailableLabel.isHidden = true
            }
            else {
                self.presentUnableToResumeSessionAlert()
            }
        }
    }
    
    func presentUnableToResumeSessionAlert() {
        let alert = UIAlertController(
            title: "Unable to Resume Session",
            message: "There was an error while attempting to resume session.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    // 세로모드 카드 가이드 설정
    func setupCardGuide(mode: String) {
        //뒷배경 색깔 및 투명도
        let frameColor : UIColor = UIColor.red
        let maskLayerColor: UIColor = UIColor.white
        let maskLayerAlpha: CGFloat = 1.0
        var cardBoxLocationX: CGFloat!
        var cardBoxLocationY: CGFloat!
        var cardBoxWidthSize: CGFloat!
        var cardBoxheightSize: CGFloat!
        
        ////////////// 영역 설정
        if mode == "horizontal" {
            // 카드 가이드 박스 가로 사이즈 = 전체 영역 94%
            cardBoxWidthSize = view.bounds.width * 0.94
            // 카드 가이드 박스 세로 사이즈 = 전체 영역 40%
            cardBoxheightSize = cardBoxWidthSize / 1.58
            // 카드 가이드 박스 시작 X 좌표 = 전체 뷰 영역의 3% 위치
            cardBoxLocationX = view.bounds.width * 0.03
            // 카드 가이드 박스 시작 Y 좌표 = 전체 뷰 영역의 25% 위치
            cardBoxLocationY = view.bounds.height * 0.25
        }
        else {
            // 카드 가이드 박스 세로 사이즈 = 전체 영역 40%
            cardBoxheightSize = modeChangeBtn.frame.minY - guideLabel.frame.maxY - 60
            // 카드 가이드 박스 가로 사이즈 = 전체 영역 94%
            cardBoxWidthSize = cardBoxheightSize / 1.58
            // 카드 가이드 박스 시작 X 좌표 = 전체 뷰 영역의 3% 위치
            cardBoxLocationX = (view.bounds.width - cardBoxWidthSize) / 2
            // 카드 가이드 박스 시작 Y 좌표 = 전체 뷰 영역의 25% 위치
            cardBoxLocationY = guideLabel.frame.maxY + 30
        }
        
        let cardRect = CGRect(x: cardBoxLocationX,
                                y: cardBoxLocationY,
                                width: cardBoxWidthSize,
                                height: cardBoxheightSize)
        cropRect = cardRect

        // 카드 가이드 백그라운드 설정
        let backLayer = CALayer()
        backLayer.frame = view.bounds
        backLayer.backgroundColor = maskLayerColor.withAlphaComponent(maskLayerAlpha).cgColor

        // 카드 가이드 구역 설정
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 10.0)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        backLayer.mask = maskLayer
        self.previewView.layer.addSublayer(backLayer)
        
        let frameLayer = CAShapeLayer()
        frameLayer.lineWidth = 2.0
        frameLayer.strokeColor = frameColor.cgColor
        frameLayer.path = UIBezierPath(roundedRect: cardRect, cornerRadius: 10.0).cgPath
        frameLayer.fillColor = nil
        self.previewView.layer.addSublayer(frameLayer)
        
        self.previewView.bringSubviewToFront(modeChangeBtn)
        self.previewView.bringSubviewToFront(guideLabel)
    }

    // 가로 세로 모드 변경
    @IBAction func change(_ sender: Any) {
        previewView.layer.sublayers?.remove(at: previewView.layer.sublayers!.count - 1)
        previewView.layer.sublayers?.remove(at: previewView.layer.sublayers!.count - 1)
        cardResult = nil
        sendCheck = false
        checkCount = 0
        errorCount = 0
        cardNumDic = [:]
        cardMonthDic = [:]
        cardYearDic = [:]
        
        // 세로로 변경
        if verticalMode == true {
            verticalMode=false
            setupCardGuide(mode: "vertical")
            modeChangeBtn.setTitle("가로카드 스캔", for: .normal)
            
        }
        // 가로로 변경
        else {
            verticalMode=true
            setupCardGuide(mode: "horizontal")
            modeChangeBtn.setTitle("세로카드 스캔", for: .normal)
    
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.destination is ResultController{
            let resultController = segue.destination as? ResultController
            resultController?.card = self.cardResult
        }
    }
}

// MARK: CameraFeedManagerDelegate Methods
extension DetectionController: CameraFeedManagerDelegate {
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        runModel(onPixelBuffer: pixelBuffer)
    }
    
    // MARK: Session Handling Alerts
    func sessionRunTimeErrorOccurred() {
        
        // Handles session run time error by updating the UI and providing a button if session can be manually resumed.
        self.resumeButton.isHidden = false
    }
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        
        // Updates the UI when session is interrupted.
        if resumeManually {
            self.resumeButton.isHidden = false
        }
        else {
            self.cameraUnavailableLabel.isHidden = false
        }
    }
    
    func sessionInterruptionEnded() {
        
        // Updates UI once session interruption has ended.
        if !self.cameraUnavailableLabel.isHidden {
            self.cameraUnavailableLabel.isHidden = true
        }
        
        if !self.resumeButton.isHidden {
            self.resumeButton.isHidden = true
        }
    }
    
    func presentVideoConfigurationErrorAlert() {
        
        let alertController = UIAlertController(title: "Configuration Failed", message: "Configuration of camera has failed.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func presentCameraPermissionsDeniedAlert() {
        
        let alertController = UIAlertController(title: "Camera Permissions Denied", message: "Camera permissions have been denied for this app. You can change this by going to Settings", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true, completion: nil)
        
    }
    
    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {

        let postProcessor = PostProcessor()
        
        // image preprocessing
        let imageScale = CGFloat(1080) / previewView.frame.width
        let w: CGFloat!
        let h: CGFloat!
        let x: CGFloat!
        let y: CGFloat!
        
        if cropRect.width > cropRect.height {
            w = cropRect.width * imageScale
            h = cropRect.width * imageScale
            x = cropRect.minX * imageScale
            y = cropRect.minY * imageScale - (cropRect.width * imageScale - cropRect.height * imageScale) / 2
        }
        else {
            w = cropRect.height * imageScale
            h = cropRect.height * imageScale
            x = cropRect.minX * imageScale  - (cropRect.height * imageScale - cropRect.width * imageScale) / 2
            y = cropRect.minY * imageScale
        }
     
        let new_buffer = pixelBuffer.crop(to: CGRect(x: x, y: y, width: w, height: h))
        
        //        var image = UIUtilities.createUIImage(from: pixelBuffer, orientation: UIImage.Orientation.up)
        //        image = UIUtilities.makeSquareGrayImage(image: image!)
        //        let new_buffer = UIUtilities.createImageBuffer(from: image!)

    
        // Run the live camera pixelBuffer through tensorFlow to get the result
        
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        
        guard  (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else {
            return
        }
        
        previousInferenceTimeMs = currentTimeMs
        result = self.modelDataHandler?.runModel(onFrame: new_buffer!)
        let card = postProcessor.card(result: result!)

        
        if card.errcode == 99 {
             errorCount += 1
            
            if errorCount == 7 && cardNumDic.isEmpty {
                print("실패 토스트")
                let message = "유효하지 않은 카드번호입니다."
                DispatchQueue.main.async {
                    self.view.makeToast(message, duration: 1.0, position: .center)
                }
                cardResult = nil
                sendCheck = false
                checkCount = 0
                errorCount = 0
                cardNumDic = [:]
                cardMonthDic = [:]
                cardYearDic = [:]
            }
        }
        
        if cardNumDic.isEmpty && card.cardNumber != "" {
            cardNumDic[card.cardNumber] = 1
            
            if card.cardYear != "" {
                cardYearDic[card.cardYear] = 1
            }
            if card.cardMonth != "" {
                cardMonthDic[card.cardMonth] = 1
            }
            checkCount += 1
        }
        else if cardNumDic.isEmpty == false {
            if card.cardNumber != "" {
                if let _ = cardNumDic[card.cardNumber] {
                    cardNumDic[card.cardNumber]! += 1
                }
                else {
                    cardNumDic[card.cardNumber] = 1
                }
            }
            if card.cardYear != "" {
                if let _ = cardYearDic[card.cardYear] {
                    cardYearDic[card.cardYear]! += 1
                }
                else {
                    cardYearDic[card.cardYear] = 1
                }
            }
            if card.cardMonth != "" {
                if let _ = cardMonthDic[card.cardMonth] {
                    cardMonthDic[card.cardMonth]! += 1
                }
                else {
                    cardMonthDic[card.cardMonth] = 1
                }
            }
            checkCount += 1
            
            if checkCount >= 3 {
                var newCard = Card()
                let sortedNumDitionary = cardNumDic.sorted { $0.1 > $1.1 }
                let sortedYearDitionary = cardYearDic.sorted { $0.1 > $1.1 }
                let sortedMonthDitionary = cardMonthDic.sorted { $0.1 > $1.1 }
                
                if sortedNumDitionary.isEmpty == false {
                    newCard.cardNumber = sortedNumDitionary[0].key
                }
                if sortedYearDitionary.isEmpty == false && sortedMonthDitionary.isEmpty == false {
                    newCard.cardYear = sortedYearDitionary[0].key
                    newCard.cardMonth = sortedMonthDitionary[0].key
                }
                
                if newCard.cardNumber.count == 16 { newCard.cardType = 1 }
                else if newCard.cardNumber.count == 15 { newCard.cardType = 2 }
                else if newCard.cardNumber.count == 14 { newCard.cardType = 3 }
                
                if sendCheck == false {
                    if newCard.cardType == 2 {
                        DispatchQueue.main.async {
                            self.cardResult = newCard
                            self.performSegue(withIdentifier: "showResult", sender: self)
                            self.sendCheck = true
                        }
                    }
                    else if (newCard.cardType == 1 || newCard.cardType == 3)
                                && newCard.cardNumber != "" && newCard.cardYear != "" && newCard.cardMonth != "" {
                        DispatchQueue.main.async {
                            self.cardResult = newCard
                            self.performSegue(withIdentifier: "showResult", sender: self)
                            self.sendCheck = true
                        }
                    }
                }
            }
        }
        // 그리기 코드
//        guard let displayResult = result else {
//            return
//        }
//
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//
//        DispatchQueue.main.async {
//            // Draws the bounding boxes and displays class names and confidence scores.
//            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
//        }
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {
        
        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()
        
        guard !inferences.isEmpty else {
            return
        }
        
        var objectOverlays: [ObjectOverlay] = []
        
        for inference in inferences {
            
            // Translates bounding box rect to current view.
            var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))
            
            if convertedRect.origin.x < 0 {
                convertedRect.origin.x = self.edgeOffset
            }
            
            if convertedRect.origin.y < 0 {
                convertedRect.origin.y = self.edgeOffset
            }
            
            if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
            }
            
            if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
            }
            
            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(inference.className)  (\(confidenceValue)%)"
            
            let size = string.size(usingFont: self.displayFont)
            
            let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)
            
            objectOverlays.append(objectOverlay)
        }
        
        // Hands off drawing to the OverlayView
        self.draw(objectOverlays: objectOverlays)
        
    }
    
    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {
        
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
    }
    
}
