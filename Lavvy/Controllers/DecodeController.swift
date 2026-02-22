//
//  DecodeController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 28/1/2026.
//

import CoreLocation
import Foundation
import MapKit
import OnboardingKit
import UIKit

class DecodeController : UIViewController {
    override func loadView() {
        view = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        view.cornerConfiguration = .corners(radius: .containerConcentric())
    }
    
    var textLabel: UILabel? = nil,
        secondaryTextLabel: UILabel? = nil
    
    var decodeCompletionHandler: (([Facility]) -> Void)? = nil
    var decodeFailureHandler: ((Error) -> Void)? = nil
    
    var currentLocation: CLLocation? = nil
    init(_ currentLocation: CLLocation? = nil) {
        self.currentLocation = currentLocation
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        textLabel.text = "Please Wait"
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
        secondaryTextLabel.text = "Decoding Database"
        secondaryTextLabel.textAlignment = .center
        secondaryTextLabel.textColor = .secondaryLabel
        view.contentView.addSubview(secondaryTextLabel)
        
        secondaryTextLabel.centerXAnchor.constraint(equalTo: view.contentView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        secondaryTextLabel.topAnchor.constraint(equalTo: textLabel.safeAreaLayoutGuide.bottomAnchor,
                                                constant: 8).isActive = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        decodeDatabaseFile()
    }
}

extension DecodeController {
    var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func decodeDatabaseFile() {
        Task {
            if let currentLocation, let documentDirectoryURL, let decodeCompletionHandler, let decodeFailureHandler {
                let request = MKReverseGeocodingRequest(location: currentLocation)
                guard let request else {
                    return
                }
                
                var state: String?
                var town: String?
                
                let mapItems = try await request.mapItems
                if let item = mapItems.first(where: { $0.addressRepresentations != nil }), let rep = item.addressRepresentations {
                    if let context = rep.cityWithContext, let comp = context.components(separatedBy: " ").last {
                        state = comp
                    } else {
                        town = rep.cityName
                    }
                }
                
                let databaseFileURL: URL = documentDirectoryURL.appending(component: "toilets.json")
                databaseFileURL.read { progress, data in
                    if progress == 1.0 {
                        if let data {
                            do {
                                let decoder: JSONDecoder = JSONDecoder()
                                let facilities: [Facility] = try decoder.decode([Facility].self, from: data)
                                decodeCompletionHandler(facilities.filter { facility in facility.state == state || facility.town == town && facility.state != nil && facility.town != nil })
                            } catch {
                                decodeCompletionHandler([])
                            }
                        }
                    }
                } errorHandler: { error in
                    decodeFailureHandler(error)
                }
            }
        }
    }
}
