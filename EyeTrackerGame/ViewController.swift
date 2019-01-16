//
//  ViewController.swift
//  EyeTrackerGame
//
//  Created by Alex Lopez on 15/01/2019.
//  Copyright © 2019 Alex Lopez. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var imageViewAim: UIImageView!
    
    let face = SCNNode()
    let leftEye = Eye(color: .green)
    let rightEye = Eye(color: .blue)
    let phonePlane = SCNNode(geometry: SCNPlane(width: 1, height: 1))
    let targetNames = ["alienBlue", "alienGreen", "alienOrange", "alienRed"]
    let numberOfSmoothUpdates = 25
    
    var targets = [UIImageView]()
    var eyeGazeHistory = ArraySlice<CGPoint>() //Average of aim
    var currentTraget = 0
    var laserShoot : AVAudioPlayer?
    var startTime = CACurrentMediaTime()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Adding eyes nodes to face
        sceneView.scene.rootNode.addChildNode(face)
        face.addChildNode(leftEye)
        face.addChildNode(rightEye)
        
        sceneView.scene.rootNode.addChildNode(phonePlane)
        
        //let leftHitTest = phonePlane.hitTestWithSegment(from: leftEye.target.worldPosition, to: leftEye.position)
        //let leftScreenPosition = leftHitTest.first?.screenPosition
        
        createEnemies()
        perform(#selector(createTraget), with: nil, afterDelay: 3.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard  ARFaceTrackingConfiguration.isSupported else {
            print("Unsupported device")
            return
        }
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSessionDelegate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        DispatchQueue.main.async {
            self.face.simdTransform = node.simdTransform
            self.update(using: faceAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = sceneView.pointOfView?.simdTransform else { return }
        
        self.phonePlane.simdTransform = pointOfView
    }
    
    // MARK: - Custom functions
    func shoot() {
        let aimFrame = imageViewAim.superview!.convert(imageViewAim.frame, to: nil)
        
        let hitTragets = self.targets.filter { iv -> Bool in
            if iv.alpha == 0 { return false }
            
            let targetFrame = iv.superview!.convert(iv.frame, to: nil)
            
            return targetFrame.intersects(aimFrame)
        }
        
        guard let selectedTarget = hitTragets.first else {
            return
        }
        
        selectedTarget.alpha = 0
        
        if let url = Bundle.main.url(forResource: "SoundLaser", withExtension: "wav") {
            laserShoot = try?AVAudioPlayer(contentsOf: url)
            laserShoot?.play()
        }
        
        perform(#selector(createTraget), with: nil, afterDelay: 1.5)
    }
    
    @objc func createTraget() {
        guard currentTraget < self.targets.count else {
            endGame()
            return
        }
        
        let target = self.targets[self.currentTraget]
        target.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        
        UIView.animate(withDuration: 0.5) {
            target.transform = .identity
            target.alpha = 1
        }
        currentTraget += 1
    }
    
    func update(using anchor: ARFaceAnchor) {
        if let leftBlink = anchor.blendShapes[.eyeBlinkLeft] as? Float,
            let rightBlink = anchor.blendShapes[.eyeBlinkRight] as? Float {
            
            if leftBlink > 0.2 && rightBlink > 0.2 {
                shoot()
                return
            }
        }
        
        leftEye.simdTransform = anchor.leftEyeTransform
        rightEye.simdTransform = anchor.rightEyeTransform
        
        let intersectPoints = [leftEye, rightEye].compactMap { eye -> CGPoint? in
            let hitTest = self.phonePlane.hitTestWithSegment(from: eye.target.worldPosition, to: eye.worldPosition)
            
            return hitTest.first?.screenPosition
        }
        
        guard let leftPoint = intersectPoints.first, let rightPoint = intersectPoints.last else { return }
        
        let centerPoint = CGPoint(x: (leftPoint.x + rightPoint.x)/2, y: -(leftPoint.y + rightPoint.y)/2)
        
        eyeGazeHistory.append(centerPoint)
        eyeGazeHistory = eyeGazeHistory.suffix(numberOfSmoothUpdates)
        
        imageViewAim.transform = eyeGazeHistory.averageAffineTransform
    }
    
    func createEnemies() {
        let rowStackView = UIStackView()
        rowStackView.translatesAutoresizingMaskIntoConstraints = false //Disable autolayout
        rowStackView.distribution = .fillEqually
        rowStackView.axis = .vertical
        rowStackView.spacing = 20
        
        for _ in 1...8 {
            let colStackView = UIStackView()
            colStackView.translatesAutoresizingMaskIntoConstraints = false
            colStackView.distribution = .fillEqually
            colStackView.axis = .horizontal
            colStackView.spacing = 20
            
            rowStackView.addArrangedSubview(colStackView)
            
            for imageName in targetNames{
                let imageView = UIImageView(image: UIImage(named: imageName))
                imageView.contentMode = .scaleAspectFit
                imageView.alpha = 0
                targets.append(imageView)
                
                colStackView.addArrangedSubview(imageView)
            }
            
        }
        self.view.addSubview(rowStackView)
        
        NSLayoutConstraint.activate([
            rowStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            rowStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            rowStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            rowStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 20)
            ])
        
        self.view.bringSubviewToFront(imageViewAim)
        targets.shuffle()
    }
    
    func endGame() {
        let gameTime = Int(CACurrentMediaTime() - startTime)
        let alertController = UIAlertController(title: "End game", message: "Time: \(gameTime)", preferredStyle: .alert)
        present(alertController, animated: true)
        perform(#selector(backToMainMenu), with: nil, afterDelay: 4.0)
    }
    
    @objc func backToMainMenu() {
        dismiss(animated: true) {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

extension SCNHitTestResult {
    var screenPosition : CGPoint {
        // Collition calculation
        
        var physicallIphoneXSize = CGSize(width: 0.062/2, height: 0.135/2)
        
        let sizeResolution = UIScreen.main.bounds.size
        
        let screenX = CGFloat(localCoordinates.x) / physicallIphoneXSize.width * sizeResolution.width
        let screenY = CGFloat(localCoordinates.y) / physicallIphoneXSize.height * sizeResolution.height
        
        return CGPoint(x: screenX, y: screenY)
    }
}

extension Collection where Element == CGPoint {
    var averageAffineTransform : CGAffineTransform {
        var x : CGFloat = 0
        var y : CGFloat = 0
        
        for item in self {
            x += item.x
            y += item.y
        }
        let elementCount = CGFloat(self.count) //Average
        return CGAffineTransform(translationX: x/elementCount, y: y/elementCount)
    }
}
