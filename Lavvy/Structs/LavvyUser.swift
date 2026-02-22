//
//  LavvyUser.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 2/2/2026.
//

import Foundation

nonisolated struct LavvyUser : Codable {
    nonisolated struct UserReview : Codable {
        var facilityID: String
        var indexes: [Int]
    }
    
    var reviews: [UserReview]
}
