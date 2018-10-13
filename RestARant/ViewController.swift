//
//  ViewController.swift
//  RestARant
//
//  Created by Maxwell Hubbard on 10/12/18.
//  Copyright © 2018 Maxwell Hubbard. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import FirebaseStorage

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

protocol PropertyStoring {
    associatedtype T
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T
}
extension PropertyStoring {
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T {
        guard let value = objc_getAssociatedObject(self, key) as? T else {
            return defaultValue
        }
        return value
    }
}

extension UIView : PropertyStoring{
    typealias T = UIView
    private struct CustomProperties {
        static var toggleState = UIView()
    }
    
    var container: UIView {
        get {
            return getAssociatedObject(&CustomProperties.toggleState, defaultValue: CustomProperties.toggleState)
        }
        set {
            return objc_setAssociatedObject(self, &CustomProperties.toggleState, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func showActivityIndicatory() {
        if container != nil {
            container.removeFromSuperview()
        }
        container = UIView()
        container.frame = frame
        container.center = center
        
        
        container.backgroundColor = UIColor(rgb: 0xffffff).withAlphaComponent(0.3)
        
        let loadingView: UIView = UIView()
        loadingView.frame = CGRect(x:0, y:0, width:80, height:80)
        loadingView.center = center
        loadingView.backgroundColor = UIColor(rgb: 0x444444).withAlphaComponent(0.7)
        loadingView.clipsToBounds = true
        loadingView.layer.cornerRadius = 10
        
        let actInd: UIActivityIndicatorView = UIActivityIndicatorView()
        actInd.frame = CGRect(x:0.0, y:0.0, width:40.0, height:40.0);
        actInd.style =
            UIActivityIndicatorView.Style.whiteLarge
        actInd.center = CGPoint(x:loadingView.frame.size.width / 2,
                                y:loadingView.frame.size.height / 2);
        loadingView.addSubview(actInd)
        container.addSubview(loadingView)
        addSubview(container)
        actInd.startAnimating()
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var foodVisualView: UIVisualEffectView!
    @IBOutlet weak var foodLabel: UILabel!
    @IBOutlet weak var closeVisualView: UIVisualEffectView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var calorieVisualView: UIVisualEffectView!
    @IBOutlet weak var calorieLabel: UILabel!
    @IBOutlet weak var ingredientVisualView: UIVisualEffectView!
    @IBOutlet weak var ingredientScroller: UIScrollView!
    
    
    var requests = [VNRequest]()
    
    var looking: Bool = false
    var info: Information = Information()
    
    func startDetection() {
        let request = VNDetectBarcodesRequest(completionHandler: self.detectHandler)
        request.symbologies = [VNBarcodeSymbology.QR]
        self.requests = [request]
    }
    
    func detectHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            //print("no result")
            return
        }
        
        let results = observations.map({$0 as? VNBarcodeObservation})
        if results.count == 1 && !looking {
            for result in results {
                
                self.view.showActivityIndicatory()
                
                if (result!.payloadStringValue!.contains(" | ")) {
                    
                    print(result!.payloadStringValue!)
                    let res = result!.payloadStringValue!.components(separatedBy: " | ")[0]
                    let dataSearch = result!.payloadStringValue!.components(separatedBy: " | ")[1]
                    
                    let storage = Storage.storage()
                    let storageRef = storage.reference()
                    let modelReference = storageRef.child("Models/" + res + ".scn")
                    let textureReference = storageRef.child("Textures/" + res + "/Color.png")
                    let ingredientsReference = storageRef.child("Information/" + res + ".json")
                    
                    
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let modelURL = documentsURL.appendingPathComponent(res + "/" + res + ".scn")
                    let texURL = documentsURL.appendingPathComponent(res + "/Color.png")
                    
                    self.looking = true
                    
                    textureReference.write(toFile: texURL) { url, error in
                        if let error = error {
                            // Uh-oh, an error occurred!
                            print("ERROR: ",error.localizedDescription)
                            
                            self.view.container.removeFromSuperview()
                            
                            let alert = UIAlertController(title: "Invalid", message: "Sorry! This QR code is invalid!", preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            
                            self.present(alert, animated: true)
                            
                            self.looking = false
                        } else {
                            // Download to the local filesystem
                            modelReference.write(toFile: modelURL) { url, error in
                                if let error = error {
                                    // Uh-oh, an error occurred!
                                    print("Here's the error", error.localizedDescription)
                                    self.looking = false
                                } else {
                                    
                                    
                                    
                                    self.view.container.removeFromSuperview()
                                    
                                    
                                    self.foodLabel.text = res
                                    
                                    
                                    self.foodVisualView.isHidden = false
                                    self.foodLabel.isHidden = false
                                    self.closeVisualView.isHidden = false
                                    self.closeButton.isHidden = false
                                    
                                    
                                    USDA.search(s: res, ds: dataSearch) { item in
                                        
                                        let ndbno = (item["ndbno"] as! NSString)
                                        
                                        USDA.getNutrients(id: ndbno as String) { (nutrients) in
                                            
                                            for nut in nutrients {
                                                
                                                if ((nut["nutrient_id"]!) as AnyObject).isKind(of: NSNumber.self) {
                                                    
                                                    if nut["nutrient_id"] as! Int == 208 {
                                                        
                                                        self.info.calories = nut["value"] as! Double
                                                        
                                                        DispatchQueue.main.async {
                                                            self.calorieLabel.text = String(describing: self.info.calories) + " Calories"
                                                            self.calorieVisualView.isHidden = false
                                                            self.calorieLabel.isHidden = false
                                                        }
                                                    } else {
                                                        
                                                        let name = nut["name"] as! String
                                                        let unit = nut["unit"] as! String
                                                        
                                                        var value = 0.0;
                                                        
                                                        if ((nut["value"]!) as AnyObject).isKind(of: NSNumber.self) {
                                                            value = nut["value"] as! Double
                                                        } else {
                                                            value = (nut["value"] as! NSString).doubleValue
                                                        }
                                                        
                                                        
                                                        let regex = try! NSRegularExpression(pattern: "[a-zA-Z, \\s]+", options: [])
                                                        
                                                        let range = regex.rangeOfFirstMatch(in: name, options: [], range: NSRange(location: 0, length: name.characters.count))
                                                        
                                                        if range.length == name.characters.count {
                                                            self.info.nutrients[name] = String(describing: value) + unit
                                                        }
                                                        
                                                        
                                                    }
                                                } else if nut["nutrient_id"] as! String == "208" {
                                                    
                                                    self.info.calories = (nut["value"] as! NSString).doubleValue
                                                    
                                                    DispatchQueue.main.async {
                                                        self.calorieLabel.text = String(describing: self.info.calories) + " Calories"
                                                        self.calorieVisualView.isHidden = false
                                                        self.calorieLabel.isHidden = false
                                                    }
                                                } else {
                                                    
                                                    let name = nut["name"] as! String
                                                    let unit = nut["unit"] as! String
                                                    
                                                    var value = 0.0;
                                                    
                                                    if ((nut["value"]!) as AnyObject).isKind(of: NSNumber.self) {
                                                        value = nut["value"] as! Double
                                                    } else {
                                                        value = (nut["value"] as! NSString).doubleValue
                                                    }
                                                    
                                                    
                                                    let regex = try! NSRegularExpression(pattern: "[a-zA-Z, \\s]+", options: [])
                                                    
                                                    let range = regex.rangeOfFirstMatch(in: name, options: [], range: NSRange(location: 0, length: name.characters.count))
                                                    
                                                    if range.length == name.characters.count {
                                                        self.info.nutrients[name] = String(describing: value) + unit
                                                    }
                                                    
                                                    
                                                }
                                                    
                                                
                                            }
                                            
                                            
                                            
                                        }
                                        
                                    }
                                    
                                    
                                    ingredientsReference.getData(maxSize: 1 * 1024 * 1024) { data, error in
                                        if let error = error {
                                            // Uh-oh, an error occurred!
                                            print(error.localizedDescription)
                                        } else {
                                            // Data for "images/island.jpg" is returned
                                            
                                            
                                            let json = try? JSONSerialization.jsonObject(with: data!, options: [])
                                            
                                            if let dictionary = json as? [String: Any] {
                                                
                                                self.info.calories = dictionary["Calories"] as! Double
                                                
                                                if let ingredients = dictionary["Ingredients"] as? [String] {
                                                    self.info.ingredients = ingredients
                                                    
                                                    for c in self.ingredientScroller.subviews {
                                                        c.removeFromSuperview()
                                                    }
                                                    let contentView = self.ingredientVisualView.contentView
                                                    for i in 0...self.info.ingredients.count - 1 {
                                                        let label = UILabel()
                                                        label.text = self.info.ingredients[i]
                                                        
                                                        label.frame = CGRect(x: 0, y: i * 40, width: Int(contentView.frame.width), height: 35)
                                                        label.textAlignment = .center
                                                        label.adjustsFontSizeToFitWidth = true
                                                        label.adjustsFontForContentSizeCategory = true
                                                        label.isUserInteractionEnabled = true
                                                        label.numberOfLines = 0
                                                        label.textColor = .white
                                                        
                                                        self.ingredientScroller.addSubview(label)
                                                    }
                                                    
                                                    self.ingredientScroller.contentSize = CGSize(width: contentView.frame.width, height: CGFloat(self.info.ingredients.count * 40))
                                                    
                                                }
                                                
                                                if let scale = dictionary["Scale"] as? [CGFloat] {
                                                    self.info.scale = SCNVector3(scale[0], scale[1], scale[2])
                                                    
                                                    do {
                                                        try self.sceneView.scene = SCNScene(url: url!, options: nil)
                                                        
                                                        let root = self.sceneView.scene.rootNode
                                                        if root.childNodes.count > 0 {
                                                            root.childNodes[0].scale = self.info.scale
                                                        }
                                                        
//                                                        var rect = result!.boundingBox
//                                                        // Flip coordinates
//                                                        rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
//                                                        rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
//                                                        // Get center
//                                                        let center = CGPoint(x: rect.midX, y: rect.midY)
                                                        
//                                                        DispatchQueue.main.async {
//                                                            self.hitTestQrCode(center: center)
//                                                        }
                                                        
                                                    } catch{}
                                                    
                                                    
                                                    
                                                    
                                                }
                                                
                                                
                                                self.ingredientVisualView.isHidden = false
                                                self.ingredientScroller.isHidden = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    var detectedDataAnchor: ARAnchor?
    
    func hitTestQrCode(center: CGPoint) {
        let hitTestResults = self.sceneView.hitTest(center, types: [.featurePoint] )
        let hitTestResult = hitTestResults.first
        if hitTestResult != nil {
            if let detectedDataAnchor = self.detectedDataAnchor,
                let node = self.sceneView.node(for: detectedDataAnchor) {
                let previousQrPosition = node.position
                node.transform = SCNMatrix4(hitTestResult!.worldTransform)
                
            } else {
                // Create an anchor. The node will be created in delegate methods
                self.detectedDataAnchor = ARAnchor(transform: hitTestResult!.worldTransform)
                self.sceneView.session.add(anchor: self.detectedDataAnchor!)
            }
        }
    }
    
    @IBAction func nutrientsChange(_ sender: UIButton) {
        
        if sender.titleLabel!.text == "Nutrients" {
            // Add Nutrients
            sender.setTitle("Ingredients", for: .normal)
            
            for c in self.ingredientScroller.subviews {
                c.removeFromSuperview()
            }
            let contentView = self.ingredientVisualView.contentView
            var j = 0
            for i in self.info.nutrients {
                let label = UILabel()
                label.text = i.key + ": " + i.value
                
                label.frame = CGRect(x: 0, y: j * 40, width: Int(contentView.frame.width), height: 35)
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.adjustsFontForContentSizeCategory = true
                label.isUserInteractionEnabled = true
                label.numberOfLines = 0
                label.textColor = .white
                
                self.ingredientScroller.addSubview(label)
                j += 1
            }
            
            self.ingredientScroller.contentSize = CGSize(width: contentView.frame.width, height: CGFloat(self.info.nutrients.count * 40))
            
        } else {
            // Add Ingredients
            sender.setTitle("Nutrients", for: .normal)
            
            for c in self.ingredientScroller.subviews {
                c.removeFromSuperview()
            }
            let contentView = self.ingredientVisualView.contentView
            for i in 0...self.info.ingredients.count - 1 {
                let label = UILabel()
                label.text = self.info.ingredients[i]
                
                label.frame = CGRect(x: 0, y: i * 40, width: Int(contentView.frame.width), height: 35)
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.adjustsFontForContentSizeCategory = true
                label.isUserInteractionEnabled = true
                label.numberOfLines = 0
                label.textColor = .white
                
                self.ingredientScroller.addSubview(label)
            }
            
            self.ingredientScroller.contentSize = CGSize(width: contentView.frame.width, height: CGFloat(self.info.ingredients.count * 40))
            
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        foodVisualView.layer.cornerRadius = 5
        foodVisualView.layer.masksToBounds = true
        
        closeVisualView.layer.cornerRadius = 5
        closeVisualView.layer.masksToBounds = true
        
        ingredientVisualView.layer.cornerRadius = 5
        ingredientVisualView.layer.masksToBounds = true
        
        calorieVisualView.layer.cornerRadius = 5
        calorieVisualView.layer.masksToBounds = true
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // Create a new scene
        
        let scene = SCNScene()
                
        
        // Set the scene to the view
        sceneView.scene = scene
        
        foodVisualView.isHidden = true
        foodLabel.isHidden = true
        closeVisualView.isHidden = true
        closeButton.isHidden = true
        self.calorieVisualView.isHidden = true
        self.calorieLabel.isHidden = true
        self.ingredientVisualView.isHidden = true
        self.ingredientScroller.isHidden = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(moveNode(_:)))
        self.view.addGestureRecognizer(panGesture)
        
        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotateNode(_:)))
        self.view.addGestureRecognizer(rotateGesture)
        
        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleNode(_:)))
        self.view.addGestureRecognizer(scaleGesture)
        
        startDetection()
        startCapture()
    }
    
    
    @IBAction func closeHit(_ sender: UIButton) {
        
        let root = sceneView.scene.rootNode
        root.childNodes[0].removeAllAnimations()
        root.childNodes[0].removeAllActions()
        root.childNodes[0].removeFromParentNode()
        
        foodVisualView.isHidden = true
        foodLabel.isHidden = true
        closeVisualView.isHidden = true
        closeButton.isHidden = true
        self.calorieVisualView.isHidden = true
        self.calorieLabel.isHidden = true
        self.ingredientVisualView.isHidden = true
        self.ingredientScroller.isHidden = true
        
        looking = false
    }
    
    
    
    
    
    var capTimer: Timer!
    
    func startCapture() {
        capTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(capture), userInfo: nil, repeats: true)
        capTimer.fire()
    }
    
    @objc func capture() {
        
        if (sceneView.session.currentFrame != nil) {
            
            let buff = sceneView.session.currentFrame!.capturedImage
            
            
            var requestOptions:[VNImageOption:Any] = [:]
            if let camData = CMGetAttachment(buff, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
                requestOptions = [.cameraIntrinsics:camData]
            }
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: buff, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
            do {
                try imageRequestHandler.perform(self.requests)
            } catch {
                print(error)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // If this is our anchor, create a node
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            let root = sceneView.scene.rootNode
            root.childNodes[0].transform = SCNMatrix4(anchor.transform)
            root.childNodes[0].scale = info.scale
            
            DispatchQueue.main.async {
                if self.calorieLabel.isHidden {
                    self.calorieLabel.text = String(describing: self.info.calories) + " Calories"
                    self.calorieVisualView.isHidden = false
                    self.calorieLabel.isHidden = false
                }
            }
            
            return nil
        }
        return nil
    }

    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    // Rotate & Pan Node
    var currentAngleY: Float = 0.0
    var isRotating = false
    
    @objc func scaleNode(_ gesture: UIPinchGestureRecognizer) {
        
        let root = sceneView.scene.rootNode
        
        if (root.childNodes.count > 0 && !isRotating) {
            
            let nodeToScale = root.childNodes[0]
            
            
            
            if gesture.state == .changed {
                
                let pinchScaleX: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.x))
                let pinchScaleY: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.y))
                let pinchScaleZ: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.z))
                nodeToScale.scale = SCNVector3Make(Float(pinchScaleX), Float(pinchScaleY), Float(pinchScaleZ))
                gesture.scale = 1
                
            }
            if gesture.state == .ended { }
        }
        
    }
    
    @objc func moveNode(_ gesture: UIPanGestureRecognizer) {
        
        print("HERE!")
        
        if !isRotating{
            
            
            
            let root = sceneView.scene.rootNode
            
            if (root.childNodes.count > 0) {
                
                //1. Get The Current Touch Point
                let currentTouchPoint = gesture.location(in: self.sceneView)
                
                //2. Get The Next Feature Point Etc
                guard let hitTest = self.sceneView.hitTest(currentTouchPoint, types: .existingPlane).first else { return }
                
                //3. Convert To World Coordinates
                let worldTransform = hitTest.worldTransform
                
                //4. Set The New Position
                let newPosition = SCNVector3(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
                
                //5. Apply To The Node
                root.simdPosition = float3(newPosition.x, newPosition.y, newPosition.z)
            }
        }
    }
    
    @objc func rotateNode(_ gesture: UIRotationGestureRecognizer){
        
        let root = sceneView.scene.rootNode
        
        if (root.childNodes.count > 0) {
            
            let currentNode = root.childNodes[0]
            
            //1. Get The Current Rotation From The Gesture
            let rotation = Float(gesture.rotation)
            
            //2. If The Gesture State Has Changed Set The Nodes EulerAngles.y
            if gesture.state == .changed{
                isRotating = true
                currentNode.eulerAngles.y = currentAngleY + rotation
            }
            
            //3. If The Gesture Has Ended Store The Last Angle Of The Cube
            if(gesture.state == .ended) {
                currentAngleY = currentNode.eulerAngles.y
                isRotating = false
            }
        }
    }
    
    
    
}
