//
//  ViewController.swift
//  CloudConvertExample
//
//  Created by Josias Montag on 03.04.15.
//  Copyright (c) 2015 Lunaweb Ltd. All rights reserved.
//

import UIKit
import QuickLook

import CloudConvert



class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, QLPreviewControllerDataSource {
    
    private var conversionTypes: Array<[String: AnyObject]> = []
    private var convertTo: String = "pdf"
    private var process: CloudConvert.Process?
    private var outputFile: NSURL?
    
    @IBOutlet weak var convertToPickerView: UIPickerView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var statusProgress: UIProgressView!
    @IBOutlet weak var convertButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        // Set your API Key here.
        
        CloudConvert.apiKey = ""
    
        
        // Find all possible conversion types for input format .png and display it in UIPickerView
        
        convertToPickerView.dataSource = self
        convertToPickerView.delegate = self
        
        CloudConvert.conversionTypes(["inputformat" : "png"], { (conversionTypes, error) -> Void in
            
            if(error != nil) {
                let alert = UIAlertView()
                alert.title = "Failed to get conversion types for .png"
                alert.message = error!.description
                alert.addButtonWithTitle("OK")
                alert.show()
            } else {
                self.conversionTypes = conversionTypes!
                self.convertToPickerView.reloadAllComponents()
            }
            
        })


    }
    


    @IBAction func convert(sender: AnyObject) {
        
        if(self.process != nil) {
            // conversion already running. cancel it.
            self.process!.cancel()
            self.process = nil
            self.convertButton.setTitle("Convert", forState: .Normal)
            
        } else {
            // start a conversion
            self.convertButton.setTitle("Cancel", forState: .Normal)
            
            let imageURL = NSBundle.mainBundle().URLForResource("file",withExtension: "png")!
            
            self.process = CloudConvert.convert([
                    "inputformat": "png",
                    "outputformat" : self.convertTo,
                    "input" : "upload",
                    "file": imageURL,
                    "download": true
                ],
                progressHandler: { (step, percent, message) -> Void in
                    println(step! + " " + percent!.description + "%: " + message!)
                    dispatch_async(dispatch_get_main_queue(),{
                        self.statusLabel.text = message
                        self.statusProgress.setProgress(percent! / 100, animated: false)
                    })
                },
                completionHandler: { (path, error) -> Void in
                    self.process = nil
                    self.convertButton.setTitle("Convert", forState: .Normal)
                    
                    if(error != nil) {
                        println("failed: " + error!.description)
                        let alert = UIAlertView()
                        alert.title = "Failed to convert file"
                        println(error)
                        alert.message = error!.localizedDescription
                        alert.addButtonWithTitle("OK")
                        alert.show()
                    } else {
                        println("done! output file saved to: " + path!.description)
                        // preview output file
                        self.outputFile = path!
                        let preview =  QLPreviewController()
                        preview.dataSource = self
                        preview.currentPreviewItemIndex = 0
                        self.presentViewController(preview, animated: true, completion: nil)
                    }
                    
            })
            
        }
        
    }
    
    
    //MARK:  UIPickerViewDataSource
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return conversionTypes.count
    }
    
    
    //MARK: UIPickerViewDelegate
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return conversionTypes[row]["outputformat"] as? String
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.convertTo = conversionTypes[row]["outputformat"] as! String
    }
    
    
    //MARK: QLPreviewControllerDataSource
    func numberOfPreviewItemsInPreviewController(controller: QLPreviewController!) -> Int {
        return 1
    }
    
    func previewController(controller: QLPreviewController!, previewItemAtIndex index: Int) -> QLPreviewItem! {
        return self.outputFile!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

