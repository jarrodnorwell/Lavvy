//
//  Review.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 2/2/2026.
//

import Foundation

typealias Year = Int
typealias Month = Int

nonisolated struct LavvyFacility : Codable {
    nonisolated struct FacilityReview : Codable {
        nonisolated struct ReviewUser : Codable {
            var name: String? = nil
            var uid: String
        }
        
        nonisolated struct ReviewStatus : Codable {
            var year: Year = Calendar.current.component(.year, from: Date())
            var month: Month = Calendar.current.component(.month, from: Date())
            
            var existance: Bool = true
        }
        
        var date: Date
        var status: ReviewStatus
        var text: String
        var user: ReviewUser
        
        var facilityID: String
        var index: Int
    }
    
    var reviews: [FacilityReview]
    
    var trues: Int {
        reviews.map(\.status.existance).filter { $0 == true }.count
    }
    
    var falses: Int {
        reviews.map(\.status.existance).filter { $0 == false }.count
    }
    
    var ratio: Double {
        let trues: Int = trues
        let count: Int = reviews.count
        return Double(trues) / Double(count)
    }
}
