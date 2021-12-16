//
//  ViewController.swift
//  CameraDemo
//
//  Created by unthinkable-mac-0025 on 15/12/21.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    //1. Camera Session
    var session : AVCaptureSession?
    
    //2.Photo Output
    let output = AVCapturePhotoOutput()
    
    //3.Video Preview
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    //4.Shutter Button
    private let shutterButton : UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        button.layer.cornerRadius = 40
        button.layer.borderWidth = 10
        button.layer.borderColor = UIColor.white.cgColor
        
        return button
    }()
    
    // MARK:  Private Data Members
    //Zoom
    private let minimumZoom: CGFloat = 1.0
    private var maximumZoom: CGFloat = 5.0
    private var beginZoomScale : CGFloat?
    private var zoomScale : CGFloat = 1.0
    
    //Tap to Focus
    var previousPointOfFocus: CGPoint = .zero
    let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    

}

// MARK:  Lifecyle Methods
extension ViewController{
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        view.addSubview(shutterButton)
        
        checkCameraPermission()
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
        
        self.view.addGestureRecognizer(self.setupPinchGesture())
        self.view.addGestureRecognizer(self.setupTapGesture())
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        shutterButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 80)
    }
    
    override public var shouldAutorotate: Bool {
        return false
      }
      override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
      }
      override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
      }
}

// MARK:  Private Methods For Camera
private extension ViewController{
    
    func checkCameraPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .notDetermined:
            //Request
            AVCaptureDevice.requestAccess(for: .video) { [weak self]granted in
                guard granted else{
                    return
                }
                DispatchQueue.main.async {
                    self?.setUpCamera()
                }
            }
        case.restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        default:
            break
        }
    }
    
    func setUpCamera(){
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video){
            do{
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input){
                    session.addInput(input)
                }
                
                if session.canAddOutput(output){
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
            }catch{
                print(error)
            }
        }
    }
    
    @objc func didTapTakePhoto(){
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}


// MARK: Private Methods To Manage Zoom With Pinch Gesture
private extension ViewController{
    /// Method to register pinch gesture to zoom
    func setupPinchGesture() ->  UIPinchGestureRecognizer {
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(pinch(_:)))
        pinchRecognizer.delegate = self
        return pinchRecognizer
    }
    
    /// Method to perform pinch gesture
    /// - Parameter pinch: Instance of UIPinchGestureRecognizer
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        update(scale: pinch.scale)
    }
    
    /// Method to perform zoom operation
    /// - Parameter factor: CGFloat value specifying current zoom factor
    func update(scale factor: CGFloat) {
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                try device.lockForConfiguration()
                print("Factor -> \(factor)")
                zoomScale = min(maximumZoom, max(minimumZoom, min(beginZoomScale! * factor, device.activeFormat.videoMaxZoomFactor)))
                device.videoZoomFactor = zoomScale
                
                print("Zoom Scale -> \(zoomScale)")
                device.unlockForConfiguration()
                
            } catch {
                print("[SwiftyCam]: Error locking configuration")
            }
        }
    }
}

// MARK: Private Methods To Manage Focus With Tap Gesture
private extension ViewController{
    /// Method to register tap gesture to focus
    func setupTapGesture() -> UITapGestureRecognizer {
        let tapGesture = UITapGestureRecognizer(target: self, action:#selector(focusAndExposeTap(_:)))
        tapGesture.delegate = self
        return tapGesture
    }
    
    /// Method called when user tap on camera view to get focus
    /// - Parameter gestureRecognizer: instance of UIGestureRecognizer
    @objc func focusAndExposeTap(_ gestureRecognizer: UIGestureRecognizer) {
    
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        let screenSize = previewLayer.bounds.size
        let tapPoint = gestureRecognizer.location(in: view)
        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let convertedPoint = CGPoint(x: x, y: y)
        self.previousPointOfFocus = convertedPoint
        if device.isFocusPointOfInterestSupported {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = convertedPoint
                    device.focusMode = .autoFocus
                }
                device.unlockForConfiguration()
                focusAnimationAt(tapPoint)
            } catch {
                print("unable to focus")
            }
        }
        if let device = AVCaptureDevice.default(for: .video) {
                   do {
                       try device.lockForConfiguration()
                       if device.isAutoFocusRangeRestrictionSupported{
                       }
                       device.unlockForConfiguration()
                   } catch {
                       print("unable to focus")
                   }
               }
    }
    
    func focusAnimationAt(_ point: CGPoint) {
        
        focusView.layer.borderColor = UIColor(hex: 0xF9A23D).cgColor
        focusView.layer.borderWidth = 1
        focusView.center = point
        focusView.alpha = 0.0

        self.view.addSubview(focusView)
        focusView.transform = CGAffineTransform(scaleX: 2.2, y: 2.2)
        UIView.animate(withDuration: 0.40, delay: 0.0, options: .curveEaseInOut, animations: {
            self.focusView.alpha = 1.0
            self.focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            
        }) { (success) in
        }
    }
    
}

// MARK:  Methods to manage Photo Capture
extension ViewController : AVCapturePhotoCaptureDelegate{
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else{
            return
        }
        let image = UIImage(data: data)
        
        session?.stopRunning()
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.frame = view.bounds
        view.addSubview(imageView)
    }
}


extension ViewController : UIGestureRecognizerDelegate {

    /// Set beginZoomScale when pinch begins
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale;
        }
        return true
    }
}

// MARK:  UIColor Extension Methods
extension UIColor {

    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
    
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(hex: Int) {
        self.init(
            red: (hex >> 16) & 0xFF,
            green: (hex >> 8) & 0xFF,
            blue: hex & 0xFF
        )
    }
}


