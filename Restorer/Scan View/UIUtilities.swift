
import Foundation
import UIKit
//
/// Defines UI-related utilitiy methods for vision detection.
public class UIUtilities {
    
    // MARK: - Public
    
    public static func addCircle(
        atPoint point: CGPoint,
        to view: UIView,
        color: UIColor,
        radius: CGFloat
    ) {
        let divisor: CGFloat = 2.0
        let xCoord = point.x - radius / divisor
        let yCoord = point.y - radius / divisor
        let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
        let circleView = UIView(frame: circleRect)
        circleView.layer.cornerRadius = radius / divisor
        circleView.alpha = BaseConstant.circleViewAlpha
        circleView.backgroundColor = color
        view.addSubview(circleView)
    }
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = BaseConstant.rectangleViewCornerRadius
        rectangleView.alpha = BaseConstant.rectangleViewAlpha
        rectangleView.backgroundColor = color
        view.addSubview(rectangleView)
    }
    
    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
        guard let points = points else { return }
        let path = UIBezierPath()
        for (index, value) in points.enumerated() {
            let point = value.cgPointValue
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            if index == points.count - 1 {
                path.close()
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        let shapeView = UIView(frame: rect)
        shapeView.alpha = BaseConstant.shapeViewAlpha
        shapeView.layer.addSublayer(shapeLayer)
        view.addSubview(shapeView)
    }
    
    public static func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp
            || deviceOrientation
            == .unknown
        {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    
    // MARK: - Private
    
    private static func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}

// MARK: - BaseConstant
extension BaseConstant {
    static let circleViewAlpha: CGFloat = 0.7
    static let rectangleViewAlpha: CGFloat = 0.3
    static let shapeViewAlpha: CGFloat = 0.3
    static let rectangleViewCornerRadius: CGFloat = 10.0
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let originalScale: CGFloat = 1.0
    
}


public enum Detector: String {
    case onDeviceBarcode = "On-Device Barcode Scanner"
    case onDeviceFace = "On-Device Face Detection"
    case onDeviceText = "On-Device Text Recognition"
    case onDeviceObjectProminentNoClassifier = "ODT, single, no labeling"
    case onDeviceObjectProminentWithClassifier = "ODT, single, labeling"
    case onDeviceObjectMultipleNoClassifier = "ODT, multiple, no labeling"
    case onDeviceObjectMultipleWithClassifier = "ODT, multiple, labeling"
    case onDeviceObjectCustomProminentNoClassifier = "ODT, custom, single, no labeling"
    case onDeviceObjectCustomProminentWithClassifier = "ODT, custom, single, labeling"
    case onDeviceObjectCustomMultipleNoClassifier = "ODT, custom, multiple, no labeling"
    case onDeviceObjectCustomMultipleWithClassifier = "ODT, custom, multiple, labeling"
}
