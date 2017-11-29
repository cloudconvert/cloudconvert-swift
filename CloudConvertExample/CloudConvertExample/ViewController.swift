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
    
    private var conversionTypes: Array<[String: Any]>? = []
    private var convertTo: String = "bmp"
    private var process: CloudConvert.Process?
    private var outputFile: URL?
    
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
        
        CloudConvert.conversionTypes(parameters: ["inputformat" : "png"], completionHandler: { [weak self] (conversionTypes, error) -> Void in
            
            if let error = error {
                let alert = UIAlertController(title: "Failed to get conversion types for .png", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            } else {
                self?.conversionTypes = conversionTypes
                self?.convertToPickerView.reloadAllComponents()
            }
        })
    }
    
    @IBAction func convert(_ sender: AnyObject) {
        
        if process != nil {
            // conversion already running. cancel it.
            process?.cancel()
            process = nil
            convertButton.setTitle("Convert", for: .normal)
            
        } else {
            // start a conversion
            convertButton.setTitle("Cancel", for: .normal)
            
            let imageURL = Bundle.main.url(forResource: "file",withExtension: "png")!
            let parameters: [String: Any] = [
                "inputformat": "png",
                "outputformat" : self.convertTo,
                "input" : "upload",
                "file": imageURL,
                "download": true]
            
            process = CloudConvert.convert(
                parameters: parameters,
                progressHandler: { [weak self] (step, percent, message) -> Void in
                    DispatchQueue.main.async {
                        guard let `self` = self else { return }
                        self.statusLabel.text = message
                        if let percent = percent {
                            self.statusProgress.setProgress(Float(percent) / 100, animated: false)
                        }
                    }
                },
                completionHandler: { [weak self] (path, error) -> Void in
                    guard let `self` = self else { return }
                    self.process = nil
                    self.convertButton.setTitle("Convert", for: .normal)
                    
                    if let error = error {
                        print("failed: " + error.localizedDescription)
                        
                        let alert = UIAlertController(title: "Failed to convert file", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    } else if let path = path  {
                        print("done! output file saved to: " + path.description)
                        
                        // preview output file
                        self.outputFile = path
                        let preview = QLPreviewController()
                        preview.dataSource = self
                        preview.currentPreviewItemIndex = 0
                        self.present(preview, animated: true, completion: nil)
                    }
            })
        }
    }
    
    
    //MARK:  UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return conversionTypes?.count ?? 0
    }
    
    
    //MARK: UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return conversionTypes?[row]["outputformat"] as? String
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        convertTo = conversionTypes?[row]["outputformat"] as! String
    }
    
    
    //MARK: QLPreviewControllerDataSource
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return outputFile! as QLPreviewItem
    }
}
