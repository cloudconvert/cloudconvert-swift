cloudconvert-swift
=======================

This is a lightweight wrapper for the [CloudConvert](https://cloudconvert.com) API, written in Swift. It is compatible with iOS 9.0+ / Mac OS X 10.9+ and requires Xcode 9.0.

Feel free to use, improve or modify this wrapper! If you have questions contact us or open an issue on GitHub.




## Quickstart

```Swift
import CloudConvert

CloudConvert.apiKey = "your_api_key"

let inputURL = NSBundle.mainBundle().URLForResource("file",withExtension: "png")!
let outputURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as? NSURL

CloudConvert.convert([
                    "inputformat": "png",
                    "outputformat" : "pdf",
                    "input" : "upload",
                    "file": inputURL,
                    "download": outputURL
                ],
                progressHandler: { (step, percent, message) -> Void in
                    print(step! + " " + percent!.description + "%: " + message!)
                },
                completionHandler: { (path, error) -> Void in
                    if(error != nil) {
                        print("failed: " + error!.description)
                    } else {
                        println("done! output file saved to: " + path!.description)
                    }   
            })
```

You can use the [CloudConvert API Console](https://cloudconvert.com/apiconsole) to generate ready-to-use Swift code snippets using this wrapper.


## Installation


### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects.

CocoaPods 0.36 adds supports for Swift and embedded frameworks. You can install it with the following command:

```bash
gem install cocoapods
```

To integrate CloudConvert into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
use_frameworks!

pod 'CloudConvert', '~> 1.0'
```

Then, run the following command:

```bash
pod install
```

### Manually
If you prefer not to use CocoaPods, you can integrate CloudConvert into your project manually.
As CloudConvert depends on [Alamofire](https://github.com/Alamofire/Alamofire), you need to add [Alamofire.swift](https://github.com/Alamofire/Alamofire/blob/master/Source/Alamofire.swift) to your Xcode Project first. Afterwards you can add the [CloudConvert.swift](https://github.com/cloudconvert/cloudconvert-swift/blob/master/Source/CloudConvert.swift) Source file.

Note that any calling conventions described in this README with the CloudConvert prefix would instead omit it (for example, ``CloudConvert.convert`` becomes ``convert``), since this functionality is incorporated into the top-level namespace.


## Example Project

It is a good starting point to have a look at the CloudConvert Example project in this repository. It shows how to find possible conversion types, start and monitor a conversions and how to cancel a conversion.

To open the project:

* Checkout (or download) this repository
* Execute ``pod install`` in the CloudConvertExample folder
* Open CloudConvertExample***.xcworkspace*** in the CloudConvertExample folder with Xcode

## Resources

* [API Documentation](https://cloudconvert.com/apidoc)
* [Conversion Types](https://cloudconvert.com/formats)
* [CloudConvert Blog](https://cloudconvert.com/blog)
