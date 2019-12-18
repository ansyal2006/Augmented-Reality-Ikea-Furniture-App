//
//  ViewController.swift
//  Ikea
//
//  Created by Anshul Goyal on 27/10/19.
//  Copyright © 2019 Anshul Goyal. All rights reserved.
//

import UIKit
import ARKit

// to access delegate functions for a Collection View, we need the ViewController to inherit from
class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, ARSCNViewDelegate {

    @IBOutlet weak var planeDetectedLabel: UILabel!
    
    var itemsList : [String] = ["boxing", "table", "vase", "cup"]
    var selectedIndexPath: IndexPath?
    @IBOutlet weak var itemsCollectionView: UICollectionView!
    @IBOutlet weak var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.itemsCollectionView.delegate = self
        self.itemsCollectionView.dataSource = self
        self.sceneView.delegate = self
        self.sceneView.autoenablesDefaultLighting = true
        self.registerGestureRecognizers()
        // Do any additional setup after loading the view.
    }

    func registerGestureRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture))
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGestureRecognizer.minimumPressDuration = 0.1
        self.sceneView.addGestureRecognizer(longPressGestureRecognizer)
        self.sceneView.addGestureRecognizer(pinchGestureRecognizer)
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleLongPress (sender : UILongPressGestureRecognizer) {
        let sceneView = sender.view as! ARSCNView
        let longPressLocation = sender.location(in: sceneView)
        let hitTest = sceneView.hitTest(longPressLocation)
        if !hitTest.isEmpty {
            let result = hitTest.first!
            let node = result.node
            // began sender state is activated when the user begins the long press on the screen
            if sender.state == .began {
                let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(360.degreesToRadians), z: 0, duration: 1)
                let foreverAction = SCNAction.repeatForever(rotateAction)
                node.runAction(foreverAction)
            }
            // ended sender state is activated when the user RELEASES or ends the long press on the screen
            else if sender.state == .ended {
                node.removeAllActions()
            }
        }
    }
    
    @objc func handlePinchGesture (sender : UIPinchGestureRecognizer) {
        let sceneView = sender.view as! ARSCNView
        let pinchLocation = sender.location(in: sceneView)
        let hitTest = sceneView.hitTest(pinchLocation)
        if !hitTest.isEmpty {
            let result = hitTest.first!
            let node = result.node
            let pinchAction = SCNAction.scale(by: sender.scale, duration: 0)
            node.runAction(pinchAction)
            sender.scale = 1.0
        }
    }
    
    @objc func handleTapGesture (sender : UITapGestureRecognizer){
        let sceneView = sender.view as! ARSCNView
        let tapLocation = sender.location(in: sceneView)
        let hitTest = sceneView.hitTest(tapLocation, types: [.existingPlaneUsingExtent])
        if !hitTest.isEmpty {
            self.addItem(hitTestResult: hitTest.first!)
        }
    }
    
    func addItem ( hitTestResult : ARHitTestResult) {
        // if this statement is valid
        if let selectedItemPath = selectedIndexPath {
            // use .item to extract index from selectedItemPath if it exists
            let scene = SCNScene(named: "Models.scnassets/\(itemsList[selectedItemPath.item]).scn")
            // (recursively : false) : only the direct descendants of rootNode are searched. If true, all the subtrees are searched for the node
            let node = scene?.rootNode.childNode(withName: itemsList[selectedItemPath.item], recursively: false)
            let transform = hitTestResult.worldTransform
            node?.position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            // note that the table's pivot needs to be centered so that rotation doesn't cause revolution instead
            self.centerPivot(for: node!)
            self.sceneView.scene.rootNode.addChildNode(node!)
        }
    }
    
    //to notify each time we detect a horizontal plane. Note that didAdd function is called everytime a new anchor is added to the scene
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // if a new anchor is added to the session but is not an ARPlaneAnchor, the function gets returned
        guard anchor is ARPlaneAnchor else {return}
        // the following statements have to be run on the main thread and NOT in the background
        DispatchQueue.main.async {
            self.planeDetectedLabel.isHidden = false
            // the asyncAfter function is used to delay the execution of the code inside it asynchronously. Here we are hiding the label after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3){
                self.planeDetectedLabel.isHidden = true
            }
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = itemsCollectionView.dequeueReusableCell(withReuseIdentifier: "itemID", for: indexPath) as! CollectionViewCell
        // indexPath.item and indexPath.row have the same functionality
        cell.myLabel.text = itemsList[indexPath.item]
        
        if indexPath == selectedIndexPath {
            cell.backgroundColor = UIColor.green
        }
        else {
            cell.backgroundColor = UIColor.orange
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let cell = collectionView.cellForItem(at: indexPath)
//        cell?.backgroundColor = UIColor(red: 0, green: 102, blue: 204, alpha: 1)
        // the path of the selected index, it's true index can be extracted by using .item or .row attribute
        selectedIndexPath = indexPath
        // see the REASON below of calling collectionView.reloadData() and removing didDeselectItemAt
        collectionView.reloadData()
    }
    
    // REASON : Commented out didDeselectItemAt because it was NOT serving our purpose of changing the deselected cells color back to their original color. This is because the cells are always been reused in a CollectionView to save Memory which doesn't play well with deselecting when the selected cell to be deselected is not in our screen view. So we call reloadData() instead
    
//    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
//        let cell = collectionView.cellForItem(at: indexPath)
//        cell?.backgroundColor = UIColor(red: 0, green: 250, blue: 146, alpha: 1)
//    }
    
    // "for" is the argument label : used when calling the function, "node" is parameter name : used when referencing inside the defined function, "SCNNode" is the argument type
    func centerPivot(for node : SCNNode) {
        let min = node.boundingBox.min
        let max = node.boundingBox.max
        // translating the pivot/hinge point of the node to the center of the node. Note that table.scn has a pivot point away from its geometrical center. Since Xcode doesn't allow us to change the pivot point in the interface, we do it through code.
        node.pivot = SCNMatrix4MakeTranslation(
            min.x + (max.x - min.x)/2,
            min.y + (max.y - min.y)/2,
            min.z + (max.z - min.z)/2
        )
    }
}

extension Int {
    var degreesToRadians : Double {return Double(self) * .pi/180 }
}
