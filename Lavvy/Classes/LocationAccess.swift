//
//  CameraAccess.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import CoreLocation

actor LocationAccess {
    var authorised: Bool = false
    var status: CLAuthorizationStatus = .notDetermined
    
    var manager: CLLocationManager = CLLocationManager()
    
    init() {
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }
    
    func checkAuthorisationStatus() async {
        await withCheckedContinuation { continuation in
            status = manager.authorizationStatus
            authorised = status == .authorizedAlways || status == .authorizedWhenInUse
            continuation.resume()
        }
    }
    
    func authorise() async {
        await withCheckedContinuation { continuation in
            manager.requestWhenInUseAuthorization()
            manager.requestAlwaysAuthorization()
            authorised = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
            continuation.resume()
        }
    }
}
