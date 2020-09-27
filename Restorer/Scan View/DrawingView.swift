import UIKit
import Firebase

class DrawingView: UIView {
    
    var imageSize: CGSize = .zero
    var faces: [VisionFace] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var overlayView: UIView?
    var allwedCapture: Bool = false
    
    func setUp() {
        overlayView = UIView()
        overlayView?.backgroundColor = UIColor.clear
        overlayView?.layer.borderWidth = 3.5
        if let overlayView = overlayView {
            addSubview(overlayView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
      
        if KYCCaptureViewModel.enableDetectionBoxes == true {
            overlayView?.frame = CGRect(x: 50.0, y: 100.0, width: self.bounds.size.width - 100, height: self.bounds.size.width - 100)
        }
        else{
            overlayView?.frame = .zero
        }
    }
    
    
    override func draw(_ rect: CGRect) {
        
        if KYCCaptureViewModel.enableDetectionBoxes == true {
            if let ctx = UIGraphicsGetCurrentContext() {
                       
                       ctx.clear(rect);
                       
                       let frameSize = self.bounds.size
                       let frameRateSize = frameSize / imageSize
                       for face in faces {
                           let faceFrame = (face.frame * frameRateSize).flipX(fullSize: frameSize)
                           
                           drawRectangle(ctx: ctx, frame: faceFrame, color: UIColor.red.cgColor)
                           let faceheight = faceFrame.height
                           let faceWidth = faceFrame.width
                           if faceFrame.origin.y < overlayView?.frame.origin.y ?? 0 || faceFrame.origin.y + faceheight > (overlayView?.frame.origin.y ?? 0) + (overlayView?.frame.size.height ?? 0) || faceFrame.origin.x < overlayView?.frame.origin.x ?? 0 || faceFrame.origin.x + faceWidth > (overlayView?.frame.origin.x ?? 0) + (overlayView?.frame.size.width ?? 0) {
                               overlayView?.layer.borderColor = UIColor.red.cgColor
                               allwedCapture = false
                           } else {
                               overlayView?.layer.borderColor = UIColor.green.cgColor
                               allwedCapture = true
                           }
                       }
                        
                   }
            
        }
       
    }
    
    private func drawRectangle(ctx: CGContext, frame: CGRect, color: CGColor, fill: Bool = false)  {
        let topLeft = frame.origin
        let topRight = CGPoint(x: frame.origin.x + frame.width, y: frame.origin.y)
        let bottomRight = CGPoint(x: frame.origin.x + frame.width, y: frame.origin.y + frame.height)
        let bottomLeft = CGPoint(x: frame.origin.x, y: frame.origin.y + frame.height)
        
        drawPolygon(ctx: ctx,
                    points: [topLeft, topRight, bottomRight, bottomLeft],
                    color: color,
                    fill: fill)
    }
    
    private func drawPolygon(ctx: CGContext, points: [CGPoint], color: CGColor, fill: Bool = false) {
        if fill {
            ctx.setStrokeColor(UIColor.clear.cgColor)
            ctx.setFillColor(color)
            ctx.setLineWidth(0.0)
        } else {
            ctx.setStrokeColor(color)
            ctx.setLineWidth(2.0)
        }
        
        
        for i in 0..<points.count {
            if i == 0 {
                ctx.move(to: points[i])
            } else {
                ctx.addLine(to: points[i])
            }
        }
        if let firstPoint = points.first {
            ctx.addLine(to: firstPoint)
        }
        
        if fill {
            ctx.fillPath()
        } else {
            ctx.strokePath();
        }
    }
}

func * (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width * right.width, height: left.height * right.height)
}
func / (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width / right.width, height: left.height / right.height)
}

func * (left: CGRect, right: CGSize) -> CGRect {
    return CGRect(x: left.origin.x*right.width,
                  y: left.origin.y*right.height,
                  width: left.width*right.width,
                  height: left.height*right.height)
}

extension CGRect {
    func flipX(fullSize: CGSize) -> CGRect {
        return CGRect(x: fullSize.width - origin.x - size.width, y: origin.y, width: size.width, height: size.height)
    }
}

class KYCCaptureViewModel {
    static let enableDetectionBoxes = true
}
