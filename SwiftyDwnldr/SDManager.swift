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
    var startDate : Date!
    var downloadTask : URLSessionDownloadTask!
    var progressClosure : ((_ progress: CGFloat) -> Void)?
    var remainingTimeClosure : ((_ seconds: Int) -> Void)?
    var completionClosure : ((_ completed: Bool) -> Void)?
    init(fileName: String,
                  friendlyName: String,
                  directoryName: String,
                  downloadTask: URLSessionDownloadTask,
                  progressClosure : ((_ progress: CGFloat) -> Void)?,
                  remainingTimeClosure : ((_ seconds: Int) -> Void)?,
                  completionClosure : ((_ completed: Bool) -> Void)?) {
        self.fileName = fileName
        self.friendlyName = friendlyName
        self.directoryName = directoryName
        self.startDate = Date()
        self.downloadTask = downloadTask
        self.progressClosure = progressClosure
        self.remainingTimeClosure = remainingTimeClosure
        self.completionClosure = completionClosure
    }
    
}

open class SDManager: NSObject, URLSessionDelegate, URLSessionDownloadDelegate, UIApplicationDelegate {
    //front session
    fileprivate var session : Foundation.URLSession!
    //background session
    fileprivate var backgroundSession : Foundation.URLSession!
    fileprivate var downloads = [String : DownloadObject]()
    
    fileprivate override init() {
        super.init()
        session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        var backgroundConfiguration : URLSessionConfiguration!
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
            backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: Bundle.main.bundleIdentifier!)
        }
        else {
            backgroundConfiguration = URLSessionConfiguration.backgroundSessionConfiguration("ru.wearemad.SwiftyDwnldr")
        }
        self.backgroundSession = Foundation.URLSession(configuration: backgroundConfiguration, delegate: self, delegateQueue: nil)
    }
    fileprivate func cachesDirectoryPath () -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory = paths[0]
        let cachesDirectoryURL = URL(fileURLWithPath: cachesDirectory)
        return cachesDirectoryURL
    }
    
    /**
     Singleton manager.
     */
    open static let sharedInstance = SDManager()
    
    /**
     Current Downloads.
     */
    open func currentDownloads () -> [URL] {
        return downloads.map { ($0.1.downloadTask.originalRequest?.url)! }
    }
    /**
     Background completion
     */
    open var backgroundCompletion : (() -> Void)?
    /**
     Background completion notification string
     */
    open var backgroundCompletionNotificationString : String?
    /**
     Starts a file download
     
     - Parameter url:   File URL to download.
     - Parameter fileName:   Filename to save.
     - Parameter directory:   Directory to save.
     - Parameter backgroundMode:  Enabled backgroundDownload.
     */
    open func downloadFile (_ url : URL,
                              fileName: String?,
                              friendlyName: String?,
                              directoryName: String,
                              progress: ((_ progress: CGFloat) -> Void)?,
                              remainingTime: ((_ seconds: Int) -> Void)?,
                              completion: ((_ completed: Bool) -> Void)?,
                              backgroundMode: Bool) {
        //check whether file is already downloading
        if (self.isFileDownloadingForURL(url)) {
            print("File " + url.absoluteString + " is already downloading")
            return
        }
        //creating download task
        var downloadTask : URLSessionDownloadTask!
        let urlRequest = URLRequest(url: url)
        if (backgroundMode) {
            downloadTask = self.backgroundSession.downloadTask(with: urlRequest)
        }
        else {
            downloadTask = self.session.downloadTask(with: urlRequest)
        }
        let actualFileName = fileName != nil ? fileName! : url.lastPathComponent
        let actualFriendlyName = friendlyName != nil ? friendlyName! : actualFileName
        
        //download object init
        let downloadObject = DownloadObject.init(fileName: actualFileName, friendlyName: actualFriendlyName, directoryName: directoryName, downloadTask: downloadTask, progressClosure: progress, remainingTimeClosure: remainingTime, completionClosure: completion)
        self.downloads[url.absoluteString] = downloadObject
        downloadTask.resume()
    }
    /**
     Cancels all downloads
     */
    open func cancellAllDownloads () {
        for (_, item) in self.downloads {
            if let completion = item.completionClosure {
                completion(false)
            }
            item.downloadTask.cancel()
        }
        self.downloads.removeAll()
    }
    /**
     Cancel download for a specific file
     
     - Parameter url:   File URL to cancel.
     */
    open func cancelDownloadForURL (_ url: URL) {
        self.downloads.removeValue(forKey: url.absoluteString)
    }
    /**
     Returns whether file is downloading
     
     - Parameter url:   File URL to check.
     */
    open func isFileDownloadingForURL (_ url: URL) -> Bool {
        return self.downloads[url.absoluteString] != nil
    }
    
    // MARK: URLSessionDelegate
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fileURLString = downloadTask.originalRequest?.url?.absoluteString
        if let downloadObject = self.downloads[fileURLString!] {
            //progress
            if let progressClosure = downloadObject.progressClosure {
                let progress = CGFloat(totalBytesWritten) / CGFloat(totalBytesExpectedToWrite)
                progressClosure(progress)
            }
            //remainingtime
            if let remainingTimeClosure = downloadObject.remainingTimeClosure {
                let timeInterval = Date().timeIntervalSince(downloadObject.startDate)
                let speed = CGFloat(totalBytesWritten) / CGFloat(timeInterval)
                let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
                let remainingTime = CGFloat(remainingBytes) / speed
                remainingTimeClosure(Int(remainingTime))
            }
        }

    }
    
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileURLString = downloadTask.originalRequest?.url?.absoluteString
        if let downloadObject = self.downloads[fileURLString!] {
            var success = true
            
            //response code (maybe there is an error?)
            if let response = downloadTask.response as? HTTPURLResponse {
                let statusCode = response.statusCode
                if (statusCode >= 400) {
                    print("ERROR: HTTP Status Code " + String(statusCode))
                    success = false
                }
            }
            if (success == true) {
                //move file to destintaion
                let directory = self.cachesDirectoryPath()
                let path = directory.appendingPathComponent(downloadObject.directoryName)
                do {
                    if (!FileManager.default.fileExists(atPath: path.absoluteString)) {
                        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
                    }
                    let destinationLocation = path.appendingPathComponent(downloadObject.fileName)
                    try FileManager.default.moveItem(at: location, to: destinationLocation)
                } catch {
                    print("Error while moving file!")
                    success = false
                }

            }
            if let completionClosure = downloadObject.completionClosure {
                completionClosure(success)
            }
            
            self.downloads.removeValue(forKey: fileURLString!)
        }
        
    }
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print(error.localizedDescription)

            do {
                let fileURLString = task.originalRequest?.url?.absoluteString
                let downloadObject = self.downloads[fileURLString!]
                
                if let completionClosure = downloadObject?.completionClosure {
                    completionClosure(false)
                }
                self.downloads.removeValue(forKey: fileURLString!)
            }
        }
    }
    
    // MARK: Background download
    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            if (downloadTasks.count == 0) {
                if let backgroundCompletionClosure = self.backgroundCompletion {
                    DispatchQueue.main.async(execute: { 
                        backgroundCompletionClosure()
                        if let bgNotifString = self.backgroundCompletionNotificationString {
                            let localNotification = UILocalNotification()
                            localNotification.alertBody = bgNotifString
                            UIApplication.shared.presentLocalNotificationNow(localNotification)
                        }
                        self.backgroundCompletion = nil
                    })
                }
            }
        }
    }
    
    
}
