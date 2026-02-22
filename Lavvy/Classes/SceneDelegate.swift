//
//  SceneDelegate.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import ColourKit
import CoreLocation
import FirebaseCore
import OnboardingKit
import SwiftUI
import UIKit

class SceneDelegate : UIResponder, UIWindowSceneDelegate {
    var window: UIWindow? = nil
    
    var onboardingModel: OnboardingModel = OnboardingModel()
    
    var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        FirebaseApp.configure()
        guard let windowScene: UIWindowScene = scene as? UIWindowScene else {
            return
        }
        
        Task {
            await onboardingModel.locationAccess.checkAuthorisationStatus()
            UserDefaults.standard.set(await onboardingModel.locationAccess.authorised, forKey: "lavvy.1.0.locationAccessGranted")
        }
        
        let locationAccessGranted: Bool = UserDefaults.standard.bool(forKey: "lavvy.1.0.locationAccessGranted")
        let onboardingComplete: Bool = UserDefaults.standard.bool(forKey: "lavvy.1.0.onboardingComplete")
        
        window = UIWindow(windowScene: windowScene)
        guard let window else {
            return
        }
        window.rootViewController = if locationAccessGranted && onboardingComplete {
            UINavigationController(rootViewController: MapController())
        } else {
            viewController(locationAccessGranted, onboardingComplete)
        }
        window.tintColor = .systemBlue
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        NotificationCenter.default.post(name: NSNotification.Name("sceneDidDisconnect"), object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}
    
    func viewController(_ locationAccessGranted: Bool, _ onboardingComplete: Bool) -> UIViewController {
        if !locationAccessGranted && onboardingComplete {
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
            return viewController
        } else {
            let buttons: [OBButtonConfiguration] = [
                OBButtonConfiguration(text: "Continue") { button, controller in
                    await self.onboardingModel.location(controller: controller)
                }
            ]
            
            let image: UIImage? = UIImage(systemName: "toilet.fill")
            let text: String = "Lavvy"
            let secondaryText: String = "Browse a map of public toilets all across Australia"
            
            let viewController: OnboardingController = onboardingController(buttons, Colour.vibrantBlues, image, text, secondaryText)
            return viewController
        }
    }
}
