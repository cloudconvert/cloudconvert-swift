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

private var managerInstance: Alamofire.Manager?
private var manager: Alamofire.Manager {
    if((managerInstance) != nil) {
        return managerInstance!;
    }
    //let configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.cloudconvert.background")
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    configuration.HTTPAdditionalHeaders = [
        "Authorization": "Bearer " + apiKey
    ]
    managerInstance = Alamofire.Manager(configuration: configuration)
    return managerInstance!;
}


/**

Creates a NSURLRequest for API Requests

:param: URLString   The URL String, can be relative to api Host
:param: parameters  Dictionary of Query String (GET) or JSON Body (POST) parameters

:returns: NSURLRequest

*/
private func URLRequest(method: Alamofire.Method, var URLString: Alamofire.URLStringConvertible) -> NSURLRequest {
    
    if let url = URLString as? String {
        if url.hasPrefix("//") {
            URLString =  apiProtocol + ":" + url;
        } else if !url.hasPrefix("http") {
            URLString =  apiProtocol + "://" + apiHost + url;
        }
    }
    
    let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URLString.URLString)!)
    mutableURLRequest.HTTPMethod = method.rawValue
    
    return mutableURLRequest
}


/**

Wrapper for Alamofire.request()

:param: method      HTTP Method (.GET, .POST...)
:param: URLString   The URL String, can be relative to api Host
:param: parameters  Dictionary of Query String (GET) or JSON Body (POST) parameters

:returns: Alamofire.Request

*/
public func req(method: Alamofire.Method, URLString: Alamofire.URLStringConvertible, parameters: [String: AnyObject]? = nil) -> Alamofire.Request {
    
    var encoding: Alamofire.ParameterEncoding = .URL
    if(method == .POST) {
        encoding = .JSON
    }
    
    return manager.request(encoding.encode(URLRequest(method, URLString: URLString), parameters: parameters).0)

}

/**

Wrapper for Alamofire.upload()

:param: URLString   The URL String, can be relative to api Host
:param: parameters  Dictionary of Query String parameters
:param: file        The NSURL to the local file to upload

:returns: Alamofire.Request

*/

public func upload(URLString: Alamofire.URLStringConvertible, parameters: [String: AnyObject]? = nil, file: NSURL) -> Alamofire.Request {
    
    let encoding: Alamofire.ParameterEncoding = .URL
    
    let request: NSMutableURLRequest = (encoding.encode(URLRequest(Alamofire.Method.GET, URLString: URLString), parameters: parameters).0).mutableCopy() as! NSMutableURLRequest
    // set method to GET first to let Alamofire encode it as query parameters
    request.HTTPMethod = "POST"

    
    let boundary = "NET-POST-boundary-\(arc4random())-\(arc4random())"
  
    request.setValue("multipart/form-data;boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    
    let postdata = NSMutableData()
    for s in ["\r\n--\(boundary)\r\n",
        "Content-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent!)\"\r\n",
        "Content-Type: application/octet-stream\r\n\r\n"] {
            postdata.appendData(s.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    postdata.appendData(NSData(contentsOfURL: file)!)
    postdata.appendData("\r\n--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

    
    return manager.upload(request, data: postdata)
    

    
}

/**

Wrapper for Alamofire.download()

:param: URLString   The URL String, can be relative to api Host
:param: parameters  Dictionary of Query String parameters
:param: destination Closure to generate the destination NSURL

:returns: Alamofire.Request

*/
public func download(URLString: Alamofire.URLStringConvertible, parameters: [String: AnyObject]? = nil, destination: Alamofire.Request.DownloadFileDestination) -> Alamofire.Request {

    let encoding: Alamofire.ParameterEncoding = .URL
    let request = encoding.encode(URLRequest(Alamofire.Method.GET, URLString: URLString), parameters: parameters).0

    return manager.download(request, destination: destination)
}




/**

Response Serializer for the CloudConvert API

*/

extension Request {
    
    /**
    
    Parse Response from the CloudConvert API
    
    :param: completionHandler   The code to be executed once the request has finished.
    
    :returns: Alamofire.Request
    
    */
    
    

    public static func CloudConvertSerializer() -> ResponseSerializer<AnyObject, NSError> {
        return  ResponseSerializer  { request, response, data, error in
            guard error == nil else { return .Failure(error!) }
            
            
            let JSONSerializer = Request.JSONResponseSerializer(options: .AllowFragments)
            let result = JSONSerializer.serializeResponse(request, response, data, error)
            
            
            switch result {
            case .Success(let value):
                if let response = response {
                    if(!(200..<300).contains(response.statusCode) ) {
                        let message: String? = (value["error"] as? String != nil ? value["error"] as? String : value["message"] as? String)
                        let error = Error.errorWithCode(response.statusCode, failureReason: message != nil ? message! : "Unknown error")
                        return .Failure(error)
                    } else {
                        return .Success(value)
                    }
                } else {
                    let failureReason = "Response collection could not be serialized due to nil response"
                    let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                    return .Failure(error)
                }
            case .Failure(let error):
                return .Failure(error)
            }
            
            
            
        }
    }
        
    
    public func responseCloudConvertApi(completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        
        return response(responseSerializer: Request.CloudConvertSerializer(), completionHandler: { res in
            
            switch res.result {
            case .Success(let value):
                completionHandler(self.request!, self.response, value, nil)
            case .Failure(let error):
                completionHandler(self.request!, self.response, nil, error)
                
            }
            
            
        })

        
        
 
    }
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
    func conversionProgress(process: Process, step: String?, percent: Float?, message: String?)
    
    /**
    
    Conversion completed on server side. This happens before the output file was downloaded!
    
    :param: process     The CloudConvert.Process
    :param: error       NSError object if the conversion failed
    
    */
    func conversionCompleted(process: Process?, error: NSError?)
    
    
    /**
    
    Conversion output file was downloaded to local path
    
    :param: process     The CloudConvert.Process
    :param: path        NSURL of the downloaded output file
    
    */
    func conversionFileDownloaded(process: Process?, path: NSURL)
}


public class Process: NSObject {
    
    public var delegate: ProcessDelegate? = nil
    public var url: String?

    private var data: AnyObject? = [:] {
        didSet {
            if let url = data?["url"] as? String {
                self.url = url
            }
        }
    }
    
    private var currentRequest: Alamofire.Request? = nil
    private var waitCompletionHandler: ((NSError?) -> Void)? = nil
    private var progressHandler: ((step: String?, percent: Float?, message: String?) -> Void)? = nil
    private var refreshTimer: NSTimer? = nil

    
    subscript(name: String) -> AnyObject?
        {
            return data?[name]
        }

    override init() {
        
    }
    
    init(url: String) {
        self.url = url
    }
    
    
    /**
    
    Create Process on the CloudConvert API
    
    :param: parameters          Dictionary of parameters. See: https://cloudconvert.com/apidoc#create
    :param: completionHandler   The code to be executed once the request has finished.
    
    :returns: CloudConvert.Process
    
    */
    public func create(var parameters: [String: AnyObject], completionHandler: (NSError?) -> Void) -> Self {
        
        parameters.removeValueForKey("file")
        parameters.removeValueForKey("download")
        
        req(.POST, URLString: "/process", parameters: parameters).responseCloudConvertApi { (_, _, data, error) -> Void in
            if(error != nil) {
                completionHandler(error)
            } else if let url = data?["url"] as? String  {
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
    public func refresh(parameters: [String: AnyObject]? = nil, completionHandler: ((NSError?) -> Void)? = nil ) -> Self {
        
        if(self.currentRequest != nil) {
            // if there is a active refresh request, cancel it
            self.currentRequest!.cancel()
        }
        
        if(self.url == nil) {
            completionHandler?(NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "No Process URL!"] ))
            return self
        }
        
        self.currentRequest = CloudConvert.req(.GET, URLString: self.url!, parameters: parameters).responseCloudConvertApi { (_, _, data, error) -> Void in
            
       
            self.currentRequest = nil;
            if(error != nil) {
                completionHandler?(error)
            } else {
                self.data = data
                completionHandler?(nil)
            }
            
            self.progressHandler?(step: self.data?["step"] as? String, percent: self.data?["percent"] as? Float, message: self.data?["message"] as? String)
            self.delegate?.conversionProgress(self, step: self.data?["step"] as? String, percent: self.data?["percent"] as? Float, message: self.data?["message"] as? String)
            
            if(error != nil || self.data?["step"] as? String == "finished") {
                
                // conversion finished
                
                dispatch_async(dispatch_get_main_queue(),{
                self.refreshTimer?.invalidate()
                self.refreshTimer = nil
                })
                
                self.waitCompletionHandler?(error)
                self.waitCompletionHandler = nil
                
                self.delegate?.conversionCompleted(self, error: error)
                
                
    
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
    public func start(var parameters: [String: AnyObject], completionHandler: ((NSError?) -> Void)?) -> Self {
        
        
        if(self.url == nil) {
            completionHandler?(NSError(domain: errorDomain, code: -1, userInfo: ["localizedDescription" : "No Process URL!"] ))
            return self
        }
        
        
        let startRequestComplete : (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void = { (_, _, data, error) -> Void in
            self.currentRequest = nil;
            if(error != nil) {
                completionHandler?(error)
            } else {
                self.data = data
                completionHandler?(nil)
            }
        }
        

        parameters.removeValueForKey("download")
        
        let file: NSURL? = parameters["file"] as? NSURL
        
        if (file != nil && (parameters["input"] as? String) == "upload") {
            parameters.removeValueForKey("file")
            
            let formatter = NSByteCountFormatter()
            formatter.allowsNonnumericFormatting = false
            
            self.currentRequest = CloudConvert.upload(self.url!, parameters: parameters, file: file!).progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                let percent: Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * 100
                let message = "Uploading (" + formatter.stringFromByteCount(totalBytesWritten) + " / " + formatter.stringFromByteCount(totalBytesExpectedToWrite) + ") ..."
                self.delegate?.conversionProgress(self, step: "upload", percent: percent, message: message)
                self.progressHandler?(step: "upload", percent: percent, message: message)
            }.responseCloudConvertApi(startRequestComplete)
        } else {
            if(file != nil) {
                parameters["file"] = file!.absoluteString
            }
            self.currentRequest = CloudConvert.req(.POST, URLString: self.url!, parameters: parameters).responseCloudConvertApi(startRequestComplete)
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
    public func download(var downloadPath: NSURL? = nil, completionHandler: ((NSURL?, NSError?) -> Void)?) -> Self {
        
        
        if let output = self.data?["output"] as? NSDictionary, let url = output["url"] as? String  {
            
            let formatter = NSByteCountFormatter()
            formatter.allowsNonnumericFormatting = false
            
            self.currentRequest = CloudConvert.download(url, parameters: nil, destination:  { (temporaryURL, response) in
                
                var isDirectory: ObjCBool = false
                
                if (downloadPath != nil && isDirectory) {
                    // downloadPath is a directory
                    let downloadName = response.suggestedFilename!
                    downloadPath = downloadPath!.URLByAppendingPathComponent(downloadName)
                    do {
                        try NSFileManager.defaultManager().removeItemAtURL(downloadPath!)
                    } catch _ {
                    }
                    return downloadPath!
                } else if(downloadPath != nil) {
                    // downloadPath is a file
                    let exists =  NSFileManager.defaultManager().fileExistsAtPath(downloadPath!.path!, isDirectory: &isDirectory)
                    if(exists) {
                        do {
                            try NSFileManager.defaultManager().removeItemAtURL(downloadPath!)
                        } catch _ {
                        }
                    }
                    return downloadPath!
                } else {
                    // downloadPath not set
                    if let directoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first   {
                        let downloadName = response.suggestedFilename!
                        downloadPath = directoryURL.URLByAppendingPathComponent(downloadName)
                        do {
                            try NSFileManager.defaultManager().removeItemAtURL(downloadPath!)
                        } catch _ {
                        }
                        return downloadPath!
                    }
                }
                
                return temporaryURL
            }) .progress { (bytesWritten, totalBytesWritten, totalBytesExpectedToWrite) in
                
                let percent: Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * 100
                let message = "Downloading (" + formatter.stringFromByteCount(totalBytesWritten) + " / " + formatter.stringFromByteCount(totalBytesExpectedToWrite) + ") ..."
                self.delegate?.conversionProgress(self, step: "download", percent: percent, message: message)
                self.progressHandler?(step: "download", percent: percent, message: message)
                
            }.response { (request, response, data, error) in
                
                self.progressHandler?(step: "finished", percent: 100, message: "Conversion finished!")
                self.delegate?.conversionProgress(self, step: "finished", percent: 100, message: "Conversion finished!")
                
                completionHandler?(downloadPath, error)
                self.delegate?.conversionFileDownloaded(self, path: downloadPath!)
            }

        
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
    public func wait(completionHandler: ((NSError?) -> Void)?) -> Self {

        self.waitCompletionHandler = completionHandler
        dispatch_async(dispatch_get_main_queue(),{
            self.refreshTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self as Process, selector: Selector("refreshTimerTick"), userInfo: nil, repeats: true)
        })
        
        return self
    }
    
    
    public func refreshTimerTick() {
        self.refresh()
    }
    
    
    /**
    
    Cancels the conversion, including any running upload or download.
    Also deletes the process from the CloudConvert API.
    
    :returns: CloudConvert.Process
    
    */
    public func cancel() -> Self {
        
        self.currentRequest?.cancel()
        self.currentRequest = nil;
        
        dispatch_async(dispatch_get_main_queue(),{
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
        })
        
        if(self.url != nil) {
            CloudConvert.req(.DELETE, URLString: self.url!, parameters: nil)
        }

        return self
    }
    
    // Printable
    public override var description: String {
        return "Process " + (self.url != nil ? self.url! : "") + " " + ( data != nil ? data!.description : "")
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
                            error:      NSError if the conversion failed
                            
:returns: A CloudConvert.Porcess object, which can be used to cancel the conversion.

*/
public func convert(parameters: [String: AnyObject], progressHandler: ((step: String?, percent: Float?, message: String?) -> Void)? = nil ,  completionHandler: ((NSURL?, NSError?) -> Void)? = nil) -> Process {
    
    let process = Process()
    process.progressHandler = progressHandler
    
    process.create(parameters, completionHandler: { (error) -> Void in
        if(error != nil) {
            completionHandler?(nil, error)
        } else {
            process.start(parameters, completionHandler: { (error) -> Void in
                if(error != nil) {
                    completionHandler?(nil, error)
                } else {
                    process.wait({ (error) -> Void in
                        if(error != nil) {
                            completionHandler?(nil, error)
                        } else {
                            if let download = parameters["download"] as? NSURL  {
                                process.download(download, completionHandler: completionHandler)
                            } else if let download = parameters["download"] as? String where download != "false" {
                                process.download(completionHandler: completionHandler)
                            } else if let download = parameters["download"] as? Bool where download != false {
                                process.download(completionHandler: completionHandler)
                            } else {
                                completionHandler?(nil, nil)
                            }
                        }
                    })
                }
            })
            
        }
    })
    
    
    return process
}

/**

Find possible conversion types. 

:param: parameters          Find conversion types for a specific inputformat and/or outputformat.
                            For example: ["inputformat" : "png"]
                            See https://cloudconvert.com/apidoc#types
:param: completionHandler   The code to be executed once the request has finished.

*/
public func conversionTypes( parameters: [String: AnyObject], completionHandler: (Array<[String: AnyObject]>?, NSError?) -> Void) -> Void {
    req(.GET, URLString: "/conversiontypes", parameters: parameters).responseCloudConvertApi { (_, _, data, error) -> Void in
        if let types = data as? Array<[String: AnyObject]> {
            completionHandler(types, nil)
        } else {
            completionHandler(nil, error)
        }
    }
}



