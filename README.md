SwiftyDwnldr
=================
<img width="374" alt="swiftydwnldr" src="https://cloud.githubusercontent.com/assets/5983656/23771033/8274482a-0526-11e7-8bec-e9b6c01bcace.png">
## Description

A modern download manager for iOS (Swift) based on NSURLSession to deal with asynchronous downloading of multiple files. 

SwiftyDwnldr uses the power of `NSURLSession` and `NSURLSessionDownloadTask` to make downloading of files and keeping track of their progress a breeze.

## Installing the library

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate SwiftyDwnldr into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "maximality/swiftydwnldr"
```

Run `carthage update` to build the framework and drag the built `SwiftyDwnldr.framework` into your Xcode project.

## Usage

`SwiftyDwnldr` provides facilities for the following task:

- downloading files;
- persisting downloaded files and saving them to disk;
- keeping track of download progress via closures syntax;
- being notified of the download completion via closures syntax;
- check the time that system need to download the file

All the following instance methods can be called directly on `
SDManager.sharedManager()`.

### Downloading files

```swift 
public func downloadFile (url : NSURL,
                              fileName: String?,
                              friendlyName: String?,
                              directoryName: String,
                              progress: ((progress: CGFloat) -> Void)?,
                              remainingTime: ((seconds: Int) -> Void)?,
                              completion: ((completed: Bool) -> Void)?,
                              backgroundMode: Bool)
```

If a directory name is provided, a new sub-directory will be created in the Cached directory.

Once the file is finished downloading, if a name was provided by the user, it will be used to store the file in its final destination. If no name was provided the manager will use by default the last path component of the URL string (e.g. for `http://www.example.com/files/my_file.zip`, the final file name would be `my_file.zip`).

### Checking for current downloads 

To check if a file is being downloaded, you can use following method:

```swift
  public func isFileDownloadingForURL (url: NSURL) -> Bool
  
```

To retrieve a list of current files being downloaded, you can use the following:

```swift 
  public func currentDownloads () -> [NSURL]
```

This method returns an array of `NSURL` objects with the URLs of the current downloads being performed.

### Canceling downloads

The downloads, which are uniquely referenced by the download manager by the provided URL, can either be canceled singularly or all together with a single call via one of the two following methods:

```swift
  public func cancellAllDownloads ()
  public func cancelDownloadForURL (url: NSURL)
```
### Background Mode

To enable background downloads in iOS 7+, you should conform to the following steps:

- enable background modes in your project. Select the project in the Project Navigator in Xcode, select your target, then select the `Capabilities` tab and finally enable Background Modes:

![Enable Background modes](http://cocoahunter-blog.s3.amazonaws.com/TWRDownloadManager/bg_modes.png)

- add the following method to your AppDelegate

```swift
public func application(application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: () -> Void) {
        SDManager.sharedInstance.backgroundCompletion = completionHandler
    }
```

- register for local notifications in your `application:didFinishLaunchingWithOptions:` so that you can display a message to the user when the download completes

## Requirements

`SwiftyDwnldr` requires iOS 7.x or greater.

## Contributions

All contributions are welcome. Please fork the project to add functionalities and open a pull request to have them merged into the master branch in the next releases.
Inspired by https://github.com/chasseurmic/TWRDownloadManager
