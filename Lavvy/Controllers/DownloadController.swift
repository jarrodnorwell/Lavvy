//
//  DownloadController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 27/1/2026.
//

import Foundation
import OnboardingKit
import UIKit

class DownloadController : UIViewController {
    override func loadView() {
        view = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        view.cornerConfiguration = .corners(radius: .containerConcentric())
    }
    
    var textLabel: UILabel? = nil,
        secondaryTextLabel: UILabel? = nil
    
    var downloadCompletionHandler: ((URL) -> Void)? = nil
    var downloadFailureHandler: ((Error) -> Void)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let view: UIVisualEffectView = view as? UIVisualEffectView else {
            return
        }
        
        textLabel = UILabel()
        guard let textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = .bold(.extraLargeTitle)
        textLabel.text = "0%"
        textLabel.textAlignment = .center
        textLabel.textColor = .label
        view.contentView.addSubview(textLabel)
        
        textLabel.centerXAnchor.constraint(equalTo: view.contentView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        textLabel.centerYAnchor.constraint(equalTo: view.contentView.safeAreaLayoutGuide.centerYAnchor).isActive = true
        
        secondaryTextLabel = UILabel()
        guard let secondaryTextLabel else {
            return
        }
        secondaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryTextLabel.font = .preferredFont(forTextStyle: .body)
        secondaryTextLabel.text = "Downloading Database"
        secondaryTextLabel.textAlignment = .center
        secondaryTextLabel.textColor = .secondaryLabel
        view.contentView.addSubview(secondaryTextLabel)
        
        secondaryTextLabel.centerXAnchor.constraint(equalTo: view.contentView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        secondaryTextLabel.topAnchor.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottomAnchor,
                                                constant: 8).isActive = true
        
        downloadDatabaseFile()
    }
}

extension DownloadController : URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        
        let date: Date = Date()
        
        if let documentDirectoryURL, let downloadCompletionHandler, let downloadFailureHandler {
            let finalURL: URL = documentDirectoryURL.appending(component: "toilets.json")
            
            do {
                try FileManager.default.moveItem(at: location, to: finalURL)
                
                UserDefaults.standard.set(formatter.string(from: date), forKey: "dateOfLastDownload")
                
                downloadCompletionHandler(finalURL)
            } catch {
                downloadFailureHandler(error)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB]
        
        if let textLabel {
            DispatchQueue.main.async {
                textLabel.text = formatter.string(fromByteCount: totalBytesWritten)
            }
        }
    }
}

extension DownloadController {
    var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func downloadDatabaseFile() {
        guard let url: URL = URL(string: Strings.download) else {
            return
        }
        
        let request: URLRequest = URLRequest(url: url)
        
        let session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        session.downloadTask(with: request).resume()
    }
}
