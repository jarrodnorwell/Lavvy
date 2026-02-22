//
//  OnboardingModel.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import CoreLocation
import ColourKit
import OnboardingKit
import SwiftUI
import UIKit

typealias OBButtonConfiguration = OnboardingController.Onboarding.Button.Configuration
typealias OBConfiguration = OnboardingController.Onboarding.Configuration

func onboardingController(_ buttons: [OBButtonConfiguration], _ colours: [Colour], _ image: UIImage? = nil,
                          _ text: String, _ secondaryText: String, _ tertiaryText: String? = nil) -> OnboardingController {
    OnboardingController(configuration: OBConfiguration(buttons: buttons,
                                                        colours: colours,
                                                        image: image,
                                                        text: text,
                                                        secondaryText: secondaryText,
                                                        tertiaryText: tertiaryText))
}

class OnboardingModel : NSObject {
    var controller: UIViewController? = nil
    var result: Bool = false
    
    var locationAccess: LocationAccess = LocationAccess()
    
    func location(controller: UIViewController) async {
        let buttons: [OBButtonConfiguration] = [
            OBButtonConfiguration(text: "Continue") { button, controller in
                self.controller = controller
                
                button.configuration?.showsActivityIndicator = true
                button.configuration?.title = nil
                
                await self.locationAccess.manager.delegate = self
                await self.locationAccess.authorise()
            }
        ]
        
        let image: UIImage? = UIImage(systemName: "location.fill.viewfinder")?
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(hierarchicalColor: .systemBackground))
        let text: String = "Location"
        let secondaryText: String = "Lavvy requires access to Location to provide locations of public toilets in relation to yourself based on your current location"
        let tertiaryText: String = "You can change this option later in the Settings app"
        
        let viewController: OnboardingController = onboardingController(buttons, Colour.vibrantBlues, image, text, secondaryText, tertiaryText)
        viewController.modalPresentationStyle = .fullScreen
        controller.present(viewController, animated: true)
    }
    
    func settings(controller: UIViewController) async {
        let buttons: [OBButtonConfiguration] = [
            OBButtonConfiguration(text: "Open Settings") { button, controller in
                guard let url: URL = URL(string: UIApplication.openSettingsURLString),
                      UIApplication.shared.canOpenURL(url) else {
                    return
                }
                
                UIApplication.shared.open(url)
            }
        ]
        
        let image: UIImage? = UIImage(systemName: "gearshape.fill")
        let text: String = "Access Denied"
        let secondaryText: String = "Access to Location has been denied and Lavvy cannot function without it. Please go to the Settings app to allow access"
        
        let viewController: OnboardingController = onboardingController(buttons, Colour.vibrantOranges, image, text, secondaryText)
        viewController.modalPresentationStyle = .fullScreen
        controller.present(viewController, animated: true)
    }
}

extension OnboardingModel : CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        result = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
        
        UserDefaults.standard.set(result, forKey: "lavvy.1.0.locationAccessGranted")
        UserDefaults.standard.set(true, forKey: "lavvy.1.0.onboardingComplete")
        
        Task {
            await locationAccess.manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let controller, let location: CLLocation = locations.last else {
            return
        }
        
        if result {
            let viewController: UINavigationController = UINavigationController(rootViewController: MapController(location))
            viewController.modalPresentationStyle = .fullScreen
            controller.present(viewController, animated: true)
        } else {
            Task {
                await settings(controller: controller)
            }
        }
    }
}
