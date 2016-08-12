//
//  SDManager.swift
//  SwiftyDwnldr
//
//  Created by Maxim Mamedov on 12.08.16.
//  Copyright © 2016 Maxim Mamedov. All rights reserved.
//

import Foundation

/**
 Downloadable object structure, for convenience
 */
struct DownloadObject {
    var fileName : String!
    var friendlyName : String!
    var directoryName : String!
    var startDate : NSDate!
    var downloadTask : NSURLSessionDownloadTask!
    var progressClosure : ((progress: CGFloat) -> Void)?
    var remainingTimeClosure : ((seconds: Int) -> Void)?
    var completionClosure : ((completed: Bool) -> Void)?
    init(fileName: String,
                  friendlyName: String,
                  directoryName: String,
                  downloadTask: NSURLSessionDownloadTask,
                  progressClosure : ((progress: CGFloat) -> Void)?,
                  remainingTimeClosure : ((seconds: Int) -> Void)?,
                  completionClosure : ((completed: Bool) -> Void)?) {
        self.fileName = fileName
        self.friendlyName = friendlyName
        self.directoryName = directoryName
        self.startDate = NSDate()
        self.downloadTask = downloadTask
        self.progressClosure = progressClosure
        self.remainingTimeClosure = remainingTimeClosure
        self.completionClosure = completionClosure
    }
    
}

public class SDManager: NSObject, NSURLSessionDelegate, NSURLSessionDownloadDelegate, UIApplicationDelegate {
    //front session
    private var session : NSURLSession!
    //background session
    private var backgroundSession : NSURLSession!
    private var downloads = [String : DownloadObject]()
    
    private override init() {
        super.init()
        session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: nil)
        var backgroundConfiguration : NSURLSessionConfiguration!
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
            backgroundConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(NSBundle.mainBundle().bundleIdentifier!)
        }
        else {
            backgroundConfiguration = NSURLSessionConfiguration.backgroundSessionConfiguration("ru.wearemad.SwiftyDwnldr")
        }
        self.backgroundSession = NSURLSession(configuration: backgroundConfiguration, delegate: self, delegateQueue: nil)
    }
    private func cachesDirectoryPath () -> NSURL {
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
        let cachesDirectory = paths[0]
        let cachesDirectoryURL = NSURL(fileURLWithPath: cachesDirectory)
        return cachesDirectoryURL
    }
    
    /**
     Singleton manager.
     */
    public static let sharedInstance = SDManager()
    
    /**
     Current Downloads.
     */
    public func currentDownloads () -> [NSURL] {
        return downloads.map { ($0.1.downloadTask.originalRequest?.URL)! }
    }
    /**
     Background completion
     */
    public var backgroundCompletion : (() -> Void)?
    /**
     Background completion notification string
     */
    public var backgroundCompletionNotificationString : String?
    /**
     Starts a file download
     
     - Parameter url:   File URL to download.
     - Parameter fileName:   Filename to save.
     - Parameter directory:   Directory to save.
     - Parameter backgroundMode:  Enabled backgroundDownload.
     */
    public func downloadFile (url : NSURL,
                              fileName: String?,
                              friendlyName: String?,
                              directoryName: String,
                              progress: ((progress: CGFloat) -> Void)?,
                              remainingTime: ((seconds: Int) -> Void)?,
                              completion: ((completed: Bool) -> Void)?,
                              backgroundMode: Bool) {
        //check whether file is already downloading
        if (self.isFileDownloadingForURL(url)) {
            print("File " + url.absoluteString + " is already downloading")
            return
        }
        //creating download task
        var downloadTask : NSURLSessionDownloadTask!
        let urlRequest = NSURLRequest(URL: url)
        if (backgroundMode) {
            downloadTask = self.backgroundSession.downloadTaskWithRequest(urlRequest)
        }
        else {
            downloadTask = self.session.downloadTaskWithRequest(urlRequest)
        }
        let actualFileName = fileName != nil ? fileName! : url.lastPathComponent!
        let actualFriendlyName = friendlyName != nil ? friendlyName! : actualFileName
        
        //download object init
        let downloadObject = DownloadObject.init(fileName: actualFileName, friendlyName: actualFriendlyName, directoryName: directoryName, downloadTask: downloadTask, progressClosure: progress, remainingTimeClosure: remainingTime, completionClosure: completion)
        self.downloads[url.absoluteString] = downloadObject
        downloadTask.resume()
    }
    /**
     Cancels all downloads
     */
    public func cancellAllDownloads () {
        for (_, item) in self.downloads {
            if let completion = item.completionClosure {
                completion(completed: false)
            }
            item.downloadTask.cancel()
        }
        self.downloads.removeAll()
    }
    /**
     Cancel download for a specific file
     
     - Parameter url:   File URL to cancel.
     */
    public func cancelDownloadForURL (url: NSURL) {
        self.downloads.removeValueForKey(url.absoluteString)
    }
    /**
     Returns whether file is downloading
     
     - Parameter url:   File URL to check.
     */
    public func isFileDownloadingForURL (url: NSURL) -> Bool {
        return self.downloads[url.absoluteString] != nil
    }
    
    // MARK: URLSessionDelegate
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fileURLString = downloadTask.originalRequest?.URL?.absoluteString
        if let downloadObject = self.downloads[fileURLString!] {
            //progress
            if let progressClosure = downloadObject.progressClosure {
                let progress = CGFloat(totalBytesWritten) / CGFloat(totalBytesExpectedToWrite)
                progressClosure(progress: progress)
            }
            //remainingtime
            if let remainingTimeClosure = downloadObject.remainingTimeClosure {
                let timeInterval = NSDate().timeIntervalSinceDate(downloadObject.startDate)
                let speed = CGFloat(totalBytesWritten) / CGFloat(timeInterval)
                let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
                let remainingTime = CGFloat(remainingBytes) / speed
                remainingTimeClosure(seconds: Int(remainingTime))
            }
        }

    }
    
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        let fileURLString = downloadTask.originalRequest?.URL?.absoluteString
        if let downloadObject = self.downloads[fileURLString!] {
            var success = true
            
            //response code (maybe there is an error?)
            if let response = downloadTask.response as? NSHTTPURLResponse {
                let statusCode = response.statusCode
                if (statusCode >= 400) {
                    print("ERROR: HTTP Status Code " + String(statusCode))
                    success = false
                }
            }
            if (success == true) {
                //move file to destintaion
                let directory = self.cachesDirectoryPath()
                let path = directory.URLByAppendingPathComponent(downloadObject.directoryName)
                do {
                    if (!NSFileManager.defaultManager().fileExistsAtPath(path.absoluteString)) {
                        try NSFileManager.defaultManager().createDirectoryAtURL(path, withIntermediateDirectories: true, attributes: nil)
                    }
                    let destinationLocation = path.URLByAppendingPathComponent(downloadObject.fileName)
                    try NSFileManager.defaultManager().moveItemAtURL(location, toURL: destinationLocation)
                } catch {
                    print("Error while moving file!")
                    success = false
                }

            }
            if let completionClosure = downloadObject.completionClosure {
                completionClosure(completed: success)
            }
            
            self.downloads.removeValueForKey(fileURLString!)
        }
        
    }
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let error = error {
            print(error.localizedDescription)

            do {
                let fileURLString = task.originalRequest?.URL?.absoluteString
                let downloadObject = self.downloads[fileURLString!]
                
                if let completionClosure = downloadObject?.completionClosure {
                    completionClosure(completed: false)
                }
                self.downloads.removeValueForKey(fileURLString!)
            }
        }
    }
    
    // MARK: Background download
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            if (downloadTasks.count == 0) {
                if let backgroundCompletionClosure = self.backgroundCompletion {
                    dispatch_async(dispatch_get_main_queue(), { 
                        backgroundCompletionClosure()
                        if let bgNotifString = self.backgroundCompletionNotificationString {
                            let localNotification = UILocalNotification()
                            localNotification.alertBody = bgNotifString
                            UIApplication.sharedApplication().presentLocalNotificationNow(localNotification)
                        }
                        self.backgroundCompletion = nil
                    })
                }
            }
        }
    }
    
    
}
