//
//  URL.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 27/1/2026.
//

import Foundation

extension URL {
    func read(progressHandler: @escaping (Double, Data?) -> Void, errorHandler: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                guard let fileSize = attrs[.size] as? NSNumber else {
                    DispatchQueue.main.async {
                        errorHandler(NSError(domain: "FileError", code: 1))
                    }
                    return
                }
                
                let total = fileSize.intValue
                if total == 0 {
                    DispatchQueue.main.async {
                        progressHandler(1.0, Data())
                    }
                    return
                }
                
                let fileHandle = try FileHandle(forReadingFrom: self)
                defer {
                    try? fileHandle.close()
                }
                
                var buffer = Data(capacity: total)
                var lastProgress: Double = 0.0
                
                while let chunk = try fileHandle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                    buffer.append(chunk)
                    
                    let offset = fileHandle.offsetInFile
                    let progress = min(Double(offset) / Double(total), 1.0)
                    
                    if progress - lastProgress >= 0.001 || progress == 1.0 {
                        lastProgress = progress
                        DispatchQueue.main.async {
                            progressHandler(progress, progress < 1.0 ? nil : buffer)
                        }
                    }
                    
                    if progress >= 1.0 {
                        break
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorHandler(error)
                }
            }
        }
    }
}
