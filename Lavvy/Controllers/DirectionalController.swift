//
//  DirectionalController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 29/1/2026.
//

import CoreLocation
import Foundation
import MapKit
import OnboardingKit
import UIKit

class DirectionalController : UIViewController, CLLocationManagerDelegate {
    var distance: CLLocationDistance? = nil
    var manager: CLLocationManager = .init()
    
    var imageView: UIImageView? = nil
    var containerView: UIView? = nil
    var label: UILabel? = nil,
        secondaryLabel: UILabel? = nil
    
    var facility: Facility
    init(facility: Facility) {
        self.facility = facility
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        if let navigationController {
            navigationController.navigationBar.prefersLargeTitles = true
            navigationController.overrideUserInterfaceStyle = .dark
        }
        if let pointOfInterestName = facility.pointOfInterestName, let pointOfInterestStreet = facility.pointOfInterestStreet {
            navigationItem.largeTitle = pointOfInterestStreet.capitalized
            navigationItem.largeSubtitle = pointOfInterestName.capitalized
        } else {
            if let address = facility.address {
                navigationItem.largeTitle = address.capitalized
            } else {
                navigationItem.largeTitle = "Unknown Address"
            }
            navigationItem.largeSubtitle = facility.name.capitalized
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), primaryAction: UIAction { action in
            self.dismiss(animated: true)
        })
        navigationItem.style = .browser
        view.backgroundColor = .tintColor
        
        imageView = .init(image: .init(systemName: "arrow.up.circle"))
        guard let imageView else {
            return
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .white
        view.addSubview(imageView)
        
        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        imageView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 4 / 5).isActive = true
        imageView.heightAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.widthAnchor).isActive = true
        
        containerView = .init()
        guard let containerView else {
            return
        }
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        containerView.topAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.bottomAnchor, constant: 20).isActive = true
        containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20).isActive = true
        containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20).isActive = true
        
        label = .init()
        guard let label else {
            return
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .bold(.extraLargeTitle)
        label.text = "Unknown Cardinal"
        label.textAlignment = .center
        label.textColor = .white
        containerView.addSubview(label)
        
        label.centerXAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.centerYAnchor).isActive = true
        label.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 20).isActive = true
        label.trailingAnchor.constraint(lessThanOrEqualTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -20).isActive = true
        
        secondaryLabel = .init()
        guard let secondaryLabel else {
            return
        }
        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.font = .bold(.headline)
        secondaryLabel.text = "Unknown Distance"
        secondaryLabel.textAlignment = .center
        secondaryLabel.textColor = .lightText
        containerView.addSubview(secondaryLabel)
        
        secondaryLabel.centerXAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        secondaryLabel.topAnchor.constraint(equalTo: label.safeAreaLayoutGuide.bottomAnchor, constant: 8).isActive = true
        secondaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 20).isActive = true
        secondaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -20).isActive = true
        
        manager.delegate = self
        manager.headingFilter = 0
        manager.distanceFilter = 0
        manager.startUpdatingHeading()
        manager.startUpdatingLocation()
    }
    
    override var prefersStatusBarHidden: Bool { true }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let imageView, let label, let location = manager.location else {
            return
        }
        
        let bearing: Double = location.coordinate.bearing(to: .init(latitude: facility.geographyPoints.latitude, longitude: facility.geographyPoints.longitude))
        let deviceHeading: CLLocationDirection = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        let relativeBearing: Double = (bearing - deviceHeading).normalizedDegrees
        
        let radians: CGFloat = .init(relativeBearing * .pi / 180)
        
        label.text = location.coordinate.cardinal(from: relativeBearing)
        if let secondaryLabel, let distance {
            let measurement: Measurement = Measurement(value: distance, unit: UnitLength.meters)
            
            let string: String = if distance >= 1000 {
                String(format: "%.0lf km away", measurement.converted(to: .kilometers).value)
            } else {
                String(format: "%.0lf m away", measurement.value)
            }
            
            secondaryLabel.text = string
        }
        
        imageView.transform = .init(rotationAngle: radians)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        let destination: CLLocation = .init(latitude: facility.geographyPoints.latitude, longitude: facility.geographyPoints.longitude)
        
        let mapPoint1: MKMapPoint = .init(location.coordinate)
        let mapPoint2: MKMapPoint = .init(destination.coordinate)
        
        distance = mapPoint1.distance(to: mapPoint2)
    }
}
