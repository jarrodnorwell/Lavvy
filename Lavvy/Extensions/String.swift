//
//  String.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 28/1/2026.
//

import CryptoKit
import Foundation

extension String {
    var bool: Bool {
        lowercased() == "true"
    }
    
    static func nonce(with length: Int = 32) -> Self {
        precondition(length > 0)
        
        var bytes: [UInt8] = Array(repeating: 0, count: length)
        let errorCode: Int32 = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = bytes.map { byte in charset[Int(byte) % charset.count] }
        return String(nonce)
    }
    
    static func sha256(from input: String) -> Self {
        let data: Data = .init(input.utf8)
        let hash: SHA256Digest = SHA256.hash(data: data)
        return hash.map { number in String(format: "%02x", number) }.joined()
    }
}
