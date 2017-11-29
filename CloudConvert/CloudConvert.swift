//
//  CloudConvert.swift
//
//  Copyright (c) 2015 CloudConvert (https://cloudconvert.com/)
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in
//    all copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//    THE SOFTWARE.
//
//
//  Created by Josias Montag on 03.04.15.
//

import Foundation
import Alamofire

public let apiProtocol = "https"
public let apiHost = "api.cloudconvert.com"
public var apiKey: String = "" {
    didSet {
        // reset manager instance because we need a new auth header
        managerInstance = nil;
    }
}

public let errorDomain = "com.cloudconvert.error"



// MARK: - Request

private var managerInstance: Alamofire.SessionManager?

private var manager: Alamofire.SessionManager {

    if (managerInstance != nil) {
        return managerInstance!
    }

    let configuration = URLSessionConfiguration.default
    configuration.httpAdditionalHeaders = [
        "Authorization": "Bearer " + apiKey
    ]

    managerInstance = SessionManager(configuration: configuration)
    return managerInstance!
}


/**

 */
private func stringURL(for endpoint: String) -> String {

    var url = endpoint
    if url.hasPrefix("//") {
        url =  apiProtocol + ":" + url;
    } else if !url.hasPrefix("http") {
        url =  apiProtocol + "://" + apiHost + url;
    }

    return url
}

/**

 Wrapper for Alamofire.request()

 :param: url         The URL String, can be relative to api Host
 :param: method      HTTP Method (.GET, .POST...)
 :param: parameters  Dictionary of Query String (GET) or JSON Body (POST) parameters

 :returns: Alamofire.Request

 */
public func req(url: String, method: Alamofire.HTTPMethod, parameters: Parameters? = nil) -> Alamofire.DataRequest {

    var encoding: Alamofire.ParameterEncoding = URLEncoding()
    if method == .post {
        encoding = JSONEncoding()
    }

    let strURL = stringURL(for: url)
    let request = manager.request(strURL, method: method, parameters: parameters, encoding: encoding)

    return request
}


/**

 Wrapper for Alamofire.upload()

 :param: url   The URL String, can be relative to api Host
 :param: file  The URL to the local file to upload

 :returns: Alamofire.Request

 */
public func ccUpload(url: String, file: URL) -> Alamofire.UploadRequest {

    let strURL = stringURL(for: url)
    let request = manager.upload(file, to: strURL, method: .put)

    return request
}


/**

 Wrapper for Alamofire.download()

 :param: url         The URL String, can be relative to api Host
 :param: parameters  Dictionary of Query String parameters
 :param: destination Closure to generate the destination NSURL

 :returns: Alamofire.Request

 */
public func ccDownload(url: String, parameters: Parameters? = nil, destination: @escaping Alamofire.DownloadRequest.DownloadFileDestination) -> Alamofire.DownloadRequest {

    let strURL = stringURL(for: url)
    let request = manager.download(strURL, method: .get, parameters: parameters, to: destination)

    return request
}


// MARK: - Process

public protocol ProcessDelegate {
    /**

     Monitor conversion progress

     :param: process     The CloudConvert.Process
     :param: step        Current step of the process; see https://cloudconvert.com/apidoc#status
     :param: percent     Percentage (0-100) of the current step as Float value
     :param: message     Description of the current progress

     */
    func conversionProgress(process: Process, step: String?, percent: CGFloat?, message: String?)

    /**

     Conversion completed on server side. This happens before the output file was downloaded!

     :param: process     The CloudConvert.Process
     :param: error       Error object if the conversion failed

     */
    func conversionCompleted(process: Process?, error: Error?)


    /**

     Conversion output file was downloaded to local path

     :param: process     The CloudConvert.Process
     :param: path        URL of the downloaded output file

     */
    func conversionFileDownloaded(process: Process?, path: URL)
}


public class Process: NSObject {

    public var delegate: ProcessDelegate? = nil
    public var url: String?

    private var data: [String: Any]? = [:] {
        didSet {
            if let url = data?["url"] as? String {
                self.url = url
            }
        }
    }

    private var currentRequest: Alamofire.Request? = nil
    private var waitCompletionHandler: ((Error?) -> Void)? = nil
    fileprivate var progressHandler: ((_ step: String?, _ percent: CGFloat?, _ message: String?) -> Void)? = nil
    private var refreshTimer: Timer? = nil

    subscript(name: String) -> Any? {
        return data?[name]
    }

    override init() { }

    init(url: String) {
        self.url = url
    }


    /**

     Create Process on the CloudConvert API

     :param: parameters          Dictionary of parameters. See: https://cloudconvert.com/apidoc#create
     :param: completionHandler   The code to be executed once the request has finished.

     :returns: CloudConvert.Process

     */
    public func create(parameters: [String: Any], completionHandler: @escaping (Error?) -> Void) -> Self {

        var parameters = parameters
        parameters.removeValue(forKey: "file")
        parameters.removeValue(forKey: "download")

        req(url: "/process", method: .post, parameters: parameters).responseJSON { (response: DataResponse<Any>) in
            if let error = response.error {

                completionHandler(error)
            } else if let dict = response.value as? [String : Any],
                let url = dict["url"] as? String {

                self.url = url
                completionHandler(nil)
            } else {

                completionHandler(NSError(domain: errorDomain, code: -1, userInfo: nil))
            }
        }
        return self
    }


    /**

     Refresh process data from API

     :param: parameters          Dictionary of Query String parameters
     :param: completionHandler   The code to be executed once the request has finished.

     :returns: CloudConvert.Process

     */
    public func refresh(parameters: Parameters? = nil, completionHandler: ((Error?) -> Void)? = nil) -> Self {

        if currentRequest != nil {
            // if there is a active refresh request, cancel it
            self.currentRequest?.cancel()
        }

        guard let url = url else {
            completionHandler?(NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "No Process URL!"] ))
            return self
        }

        currentRequest = req(url: url, method: .get, parameters: parameters).responseJSON { [weak self] response in

            self?.currentRequest = nil
            let currentValue = response.value as? [String : Any]
            if let error = response.error {
                completionHandler?(error)
            } else if let value = currentValue {
                self?.data = value
                completionHandler?(nil)
            }

            self?.progressHandler?(currentValue?["step"] as? String, currentValue?["percent"] as? CGFloat, currentValue?["message"] as? String)
            if let strongSelf = self {
                strongSelf.delegate?.conversionProgress(process: strongSelf, step: currentValue?["step"] as? String, percent: currentValue?["percent"] as? CGFloat, message: currentValue?["message"] as? String)
            }

            if response.error != nil || (currentValue?["step"] as? String) == "finished" {

                // Conversion finished
                DispatchQueue.main.async {
                    self?.refreshTimer?.invalidate()
                    self?.refreshTimer = nil
                }

                self?.waitCompletionHandler?(response.error)
                self?.waitCompletionHandler = nil

                self?.delegate?.conversionCompleted(process: self, error: response.error)
            }

        }
        return self
    }

    /**

     Starts the conversion on the CloudConvert API

     :param: parameters          Dictionary of parameters. See: https://cloudconvert.com/apidoc#start
     :param: completionHandler   The code to be executed once the request has finished.

     :returns: CloudConvert.Process

     */
    public func start(parameters: Parameters? = nil, completionHandler: ((Error?) -> Void)? = nil) -> Self {

        guard let url = url else {
            completionHandler?(NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "No Process URL!"] ))
            return self
        }

        var parameters = parameters
        let file: URL? = parameters?["file"] as? URL
        parameters?.removeValue(forKey: "download")

        if let file = file {
            parameters?["file"] = file.absoluteString
        }

        currentRequest = req(url: url, method: .post, parameters: parameters).responseJSON { [weak self] response in

            self?.currentRequest = nil
            let currentValue = response.value as? [String : Any]
            if let error = response.error {
                completionHandler?(error)
            } else {

                self?.data = currentValue
                if let file = file, (parameters?["input"] as? String) == "upload" {
                    // Upload
                    _ = self?.upload(uploadPath: file, completionHandler: completionHandler)
                } else {
                    completionHandler?(nil)
                }
            }
        }

        return self
    }


    /**

     Uploads an input file to the CloudConvert API

     :param: uploadPath        Local path of the input file.
     :param: completionHandler   The code to be executed once the upload has finished.

     :returns: CloudConvert.Process

     */
    public func upload(uploadPath: URL, completionHandler: ((Error?) -> Void)?) -> Self {

        if let upload = self.data?["upload"] as? [String: String], var url = upload["url"] {

            url += "/" + uploadPath.lastPathComponent

            let formatter = ByteCountFormatter()
            formatter.allowsNonnumericFormatting = false

            currentRequest = ccUpload(url: url, file: uploadPath).uploadProgress(closure: { [weak self] progress in

                let totalBytesExpectedToSend = progress.totalUnitCount
                let totalBytesSent = progress.completedUnitCount

                let percent = CGFloat(totalBytesSent) / CGFloat(totalBytesExpectedToSend)
                let message = "Uploading (" + formatter.string(fromByteCount: totalBytesSent) + " / " + formatter.string(fromByteCount: totalBytesExpectedToSend) + ") ..."

                if let strongSelf = self {
                    strongSelf.delegate?.conversionProgress(process: strongSelf, step: "upload", percent: percent, message: message)
                    strongSelf.progressHandler?("upload", percent, message)
                }
            }).responseJSON(completionHandler: { (response) in

                if let error = response.error {
                    completionHandler?(error)
                } else {
                    completionHandler?(nil)
                }
            })
        } else {
            completionHandler?(NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "File cannot be uploaded in this process state!"] ))
        }

        return self
    }

    /**

     Downloads the output file from the CloudConvert API

     :param: downloadPath        Local path for downloading the output file.
     If set to nil a temporary location will be choosen.
     Can be set to a directory or a file. Any existing file will be overwritten.
     :param: completionHandler   The code to be executed once the download has finished.

     :returns: CloudConvert.Process

     */
    public func download(downloadPath: URL? = nil, completionHandler: ((URL?, Error?) -> Void)?) -> Self {

        var downloadPath = downloadPath
        if let output = self.data?["output"] as? [String: Any], let url = output["url"] as? String {

            let formatter = ByteCountFormatter()
            formatter.allowsNonnumericFormatting = false

            let destination: DownloadRequest.DownloadFileDestination = { (temporaryURL, response) in

                if let downloadName = response.suggestedFilename {
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    downloadPath = documentsURL.appendingPathComponent(downloadName)

                    return (downloadPath!, [.removePreviousFile, .createIntermediateDirectories])
                } else {
                    return (temporaryURL, [.removePreviousFile, .createIntermediateDirectories])
                }
            }

            currentRequest = ccDownload(url: url, destination: destination).downloadProgress(closure: { [weak self] progress in

                let totalBytesExpectedToSend = progress.totalUnitCount
                let totalBytesSent = progress.completedUnitCount

                let percent = CGFloat(totalBytesSent) / CGFloat(totalBytesExpectedToSend)
                let message = "Uploading (" + formatter.string(fromByteCount: totalBytesSent) + " / " + formatter.string(fromByteCount: totalBytesExpectedToSend) + ") ..."

                if let strongSelf = self {
                    strongSelf.delegate?.conversionProgress(process: strongSelf, step: "download", percent: percent, message: message)
                    strongSelf.progressHandler?("download", percent, message)
                }
            }).response(completionHandler: { [weak self] response in

                if let strongSelf = self {
                    strongSelf.delegate?.conversionProgress(process: strongSelf, step: "finished", percent: 100, message: "Conversion finished!")
                }
                self?.progressHandler?("finished", 100, "Conversion finished!")
                completionHandler?(downloadPath, response.error)

                if let downloadPath = downloadPath {
                    self?.delegate?.conversionFileDownloaded(process: self, path: downloadPath)
                }
            })
        } else {
            completionHandler?(nil, NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "Output file not yet available!"] ))
        }
        return self
    }

    /**

     Waits until the conversion has finished

     :param: completionHandler   The code to be executed once the conversion has finished.

     :returns: CloudConvert.Process

     */
    public func wait(completionHandler: ((Error?) -> Void)?) -> Self {

        self.waitCompletionHandler = completionHandler
        DispatchQueue.main.async {
            self.refreshTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(Process.refreshTimerTick), userInfo: nil, repeats: true)
        }

        return self
    }

    @objc public func refreshTimerTick() {
        _ = self.refresh()
    }

    /**

     Cancels the conversion, including any running upload or download.
     Also deletes the process from the CloudConvert API.

     :returns: CloudConvert.Process

     */
    @discardableResult
    public func cancel() -> Self {

        self.currentRequest?.cancel()
        self.currentRequest = nil;

        DispatchQueue.main.async {
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
        }

        if let url = self.url {
            _ = req(url: url, method: .delete, parameters: nil)
        }

        return self
    }

    // Printable
    public override var description: String {
        return "Process " + (self.url ?? "") + " " + ( data?.description ?? "")
    }
}



// MARK: - Methods

/**

 Converts a file using the CloudConvert API.

 :param: parameters          Parameters for the conversion.
 Can be generated using the API Console: https://cloudconvert.com/apiconsole

 :param: progressHandler     Can be used to monitor the progress of the conversion.
 Parameters of the Handler:
 step:        Current step of the process; see https://cloudconvert.com/apidoc#status ;
 percent:     Percentage (0-100) of the current step as Float value;
 message:     Description of the current progress

 :param: completionHandler   The code to be executed once the conversion has finished.
 Parameters of the Handler:
 path:       local NSURL of the downloaded output file;
 error:      Error if the conversion failed

 :returns: A CloudConvert.Porcess object, which can be used to cancel the conversion.

 */
public func convert(parameters: [String: Any], progressHandler: ((_ step: String?, _ percent: CGFloat?, _ message: String?) -> Void)? = nil, completionHandler: ((URL?, Error?) -> Void)? = nil) -> Process {

    var process = Process()
    process.progressHandler = progressHandler

    process = process.create(parameters: parameters) { error in

        if let error = error {
            completionHandler?(nil, error)
        } else {

            process = process.start(parameters: parameters) { error in

                if let error = error {
                    completionHandler?(nil, error)
                } else {

                    process = process.wait { error in

                        if let error = error {
                            completionHandler?(nil, error)
                        } else {

                            if let download = parameters["download"] as? URL {
                                process = process.download(downloadPath: download, completionHandler: completionHandler)
                            } else if let download = parameters["download"] as? String, download != "false" {
                                process = process.download(completionHandler: completionHandler)
                            } else if let download = parameters["download"] as? Bool, download != false {
                                process = process.download(completionHandler: completionHandler)
                            } else {
                                completionHandler?(nil, nil)
                            }
                        }
                    }
                }
            }
        }
    }

    return process
}

/**

 Find possible conversion types.

 :param: parameters          Find conversion types for a specific inputformat and/or outputformat.
 For example: ["inputformat" : "png"]
 See https://cloudconvert.com/apidoc#types
 :param: completionHandler   The code to be executed once the request has finished.

 */
public func conversionTypes(parameters: [String: Any], completionHandler: @escaping (Array<[String: Any]>?, Error?) -> Void) -> Void {
    req(url: "/conversiontypes", method: .get, parameters: parameters).responseJSON { (response) in
        if let types = response.value as? Array<[String: Any]> {
            completionHandler(types, nil)
        } else {
            completionHandler(nil, response.error)
        }
    }
}
