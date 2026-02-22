//
//  MKMapView.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import MapKit

extension MKMapView {
    func addAnnotations(for facilities: [Facility], using location: CLLocation) {
        let annotations: [FacilityAnnotation] = facilities.map { facility in
            let facilityLocation: CLLocation = CLLocation(latitude: facility.geographyPoints.latitude, longitude: facility.geographyPoints.longitude)
            let distance: CLLocationDistance = facilityLocation.distance(from: location)
            let measurement: Measurement = Measurement(value: distance, unit: UnitLength.meters)
            
            let string: String = if distance >= 1000 {
                String(format: "%.0lf km away", measurement.converted(to: .kilometers).value)
            } else {
                String(format: "%.0lf m away", measurement.value)
            }
            
            return FacilityAnnotation(coordinate: facility.geographyPoints.coordinate,
                                      title: facility.name.capitalized,
                                      subtitle: string,
                                      distanceInMeters: distance,
                                      facility: facility)
        }
        
        addAnnotations(annotations)
    }
}

/*
 the numbers below are a speed test between for-in and map when generating the annotations,
 the test used `ContinuousClock` to measure the time with the exact same code within `.measure {}`
 
 map was faster
 */
// forin:   0.037031291
// map:     0.03470025
