//
//  ViewController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import AuthenticationServices
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import MapKit
import UIKit

nonisolated class FacilityAnnotation : NSObject, MKAnnotation, Comparable {
    static func < (lhs: FacilityAnnotation, rhs: FacilityAnnotation) -> Bool {
        lhs.distanceInMeters < rhs.distanceInMeters
    }
    
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? = nil
    dynamic var subtitle: String? = nil
    
    dynamic var distanceInMeters: CLLocationDistance = 0
    
    dynamic var facility: Facility
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil,
         distanceInMeters: CLLocationDistance, facility: Facility) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.distanceInMeters = distanceInMeters
        self.facility = facility
        super.init()
    }
}

extension UISheetPresentationController.Detent {
    static func full() -> UISheetPresentationController.Detent {
        value(forKey: "_fullDetent") as! UISheetPresentationController.Detent
    }
}

class MapController : UIViewController {
    var manager: CLLocationManager = CLLocationManager()
    var foundInitialUserLocation: Bool = false,
        decodedFacilities: Bool = false
    
    var currentHeading: CLHeading? = nil
    var currentLocation: CLLocation? = nil
    var facilities: [Facility] = []
    
    var monitor: CLMonitor? = nil
    
    var nonce: String? = nil
    
    var leadingItemGroups: [UIBarButtonItemGroup] {
        let signOutBarButtonItem: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.forward.circle"),
                                                                    primaryAction: UIAction { action in
            func signout() {
                do {
                    try self.auth.signOut()
                    self.navigationItem.leadingItemGroups = self.leadingItemGroups
                } catch {}
            }
            
            let alertController: UIAlertController = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?\n\nYou can sign in again at any time using your Apple Account", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alertController.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { action in
                signout()
            })
            alertController.preferredAction = alertController.actions.last
            self.present(alertController, animated: true)
        })
        signOutBarButtonItem.tintColor = .systemRed
        
        return if let _: User = auth.currentUser {
            [
                UIBarButtonItemGroup(barButtonItems: [
                    UIBarButtonItem(image: UIImage(systemName: "person.crop.circle"), menu: UIMenu(preferredElementSize: .medium, children: [
                        UIAction(title: "Reviews", image: UIImage(systemName: "star.hexagon")) { action in
                            let reviewController: UINavigationController = UINavigationController(rootViewController: ReviewsController())
                            reviewController.modalPresentationStyle = .fullScreen
                            self.present(reviewController, animated: true)
                        }
                    ])),
                    signOutBarButtonItem
                ], representativeItem: nil)
            ]
        } else {
            [
                UIBarButtonItemGroup(barButtonItems: [
                    UIBarButtonItem(image: UIImage(systemName: "person.crop.circle"), primaryAction: UIAction { action in
                        let nonce: String = .nonce()
                        self.nonce = nonce
                        
                        let appleIDProvider: ASAuthorizationAppleIDProvider = ASAuthorizationAppleIDProvider()
                        
                        let request: ASAuthorizationAppleIDRequest = appleIDProvider.createRequest()
                        request.nonce = .sha256(from: nonce)
                        request.requestedScopes = [.email, .fullName]
                        
                        let authorizationController: ASAuthorizationController = ASAuthorizationController(authorizationRequests: [request])
                        authorizationController.delegate = self
                        authorizationController.presentationContextProvider = self
                        authorizationController.performRequests()
                    })
                ], representativeItem: nil)
            ]
        }
    }
    
    let auth: Auth = .auth()
    let firestore: Firestore = .firestore()
    
    var locationOfInitialLaunch: CLLocation? = nil
    init(_ locationOfInitialLaunch: CLLocation? = nil) {
        self.locationOfInitialLaunch = locationOfInitialLaunch
        super.init(nibName: nil, bundle: nil)
        Task {
            monitor = await CLMonitor("lavvyMonitor")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let mapView: MKMapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        view = mapView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        becomeFirstResponder()
        navigationItem.leadingItemGroups = leadingItemGroups
        
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.headingFilter = kCLHeadingFilterNone
        manager.startUpdatingHeading()
        manager.startUpdatingLocation()
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, let view: MKMapView = view as? MKMapView {
            view.removeOverlays(view.overlays)
        }
    }
}

extension MapController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading
        
        DispatchQueue.main.async {
            if let presentedViewController: UINavigationController = self.presentedViewController as? UINavigationController,
               let dataController: DataController = presentedViewController.topViewController as? DataController {
                dataController.update(1, for: self.currentLocation, with: self.currentHeading)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !foundInitialUserLocation, let view: MKMapView = view as? MKMapView, let first: CLLocation = locations.first {
            view.setRegion(MKCoordinateRegion(center: first.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
                           animated: true)
            
            foundInitialUserLocation = true
            
            detectDatabaseFile { result in
                switch result {
                case false:
                    let downloadController: DownloadController = DownloadController()
                    downloadController.modalPresentationStyle = .overCurrentContext
                    downloadController.downloadCompletionHandler = { url in
                        downloadController.dismiss(animated: true) {
                            let decodeController: DecodeController = DecodeController(first)
                            decodeController.modalPresentationStyle = .overCurrentContext
                            decodeController.decodeCompletionHandler = { facilities in
                                self.decodedFacilities = true
                                self.facilities = facilities
                                decodeController.dismiss(animated: true) {
                                    DispatchQueue.main.async {
                                        view.addAnnotations(for: facilities, using: first)
                                    }
                                }
                            }
                            decodeController.decodeFailureHandler = { error in
                                decodeController.dismiss(animated: true)
                            }
                            self.present(decodeController, animated: true)
                        }
                    }
                    downloadController.downloadFailureHandler = { error in
                        downloadController.dismiss(animated: true)
                    }
                    self.present(downloadController, animated: true)
                case true:
                    let formatter: DateFormatter = DateFormatter()
                    formatter.dateStyle = .full
                    formatter.timeStyle = .full
                    
                    let date: Date = Date()
                    
                    if let dateOfLastDownloadString: String = UserDefaults.standard.string(forKey: "dateOfLastDownload") {
                        if let dateOfLastDownload: Date = formatter.date(from: dateOfLastDownloadString) {
                            let daysSinceLastDownload: Int = Calendar.current.dateComponents([.day], from: dateOfLastDownload, to: date).day ?? 0
                            if daysSinceLastDownload > 7 {
                                let downloadController: DownloadController = DownloadController()
                                downloadController.modalPresentationStyle = .overCurrentContext
                                downloadController.downloadCompletionHandler = { url in
                                    downloadController.dismiss(animated: true) {
                                        let decodeController: DecodeController = DecodeController(first)
                                        decodeController.modalPresentationStyle = .overCurrentContext
                                        decodeController.decodeCompletionHandler = { facilities in
                                            self.decodedFacilities = true
                                            self.facilities = facilities
                                            decodeController.dismiss(animated: true) {
                                                DispatchQueue.main.async {
                                                    view.addAnnotations(for: facilities, using: first)
                                                }
                                            }
                                        }
                                        decodeController.decodeFailureHandler = { error in
                                            decodeController.dismiss(animated: true)
                                        }
                                        self.present(decodeController, animated: true)
                                    }
                                }
                                downloadController.downloadFailureHandler = { error in
                                    downloadController.dismiss(animated: true)
                                }
                                self.present(downloadController, animated: true)
                            } else {
                                let decodeController: DecodeController = DecodeController(first)
                                decodeController.modalPresentationStyle = .overCurrentContext
                                decodeController.decodeCompletionHandler = { facilities in
                                    self.decodedFacilities = true
                                    self.facilities = facilities
                                    decodeController.dismiss(animated: true) {
                                        DispatchQueue.main.async {
                                            view.addAnnotations(for: facilities, using: first)
                                        }
                                    }
                                }
                                decodeController.decodeFailureHandler = { error in
                                    decodeController.dismiss(animated: true)
                                }
                                self.present(decodeController, animated: true)
                            }
                        }
                    }
                }
            }
        }
        
        if let last = locations.last {
            currentLocation = last
            DispatchQueue.main.async {
                if let presentedViewController: UINavigationController = self.presentedViewController as? UINavigationController,
                   let dataController: DataController = presentedViewController.topViewController as? DataController {
                    dataController.update(0, for: self.currentLocation, with: self.currentHeading)
                }
            }
        }
    }
}

extension MapController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let annotation: FacilityAnnotation = view.annotation as? FacilityAnnotation {
            print(annotation.facility.id)
            
            let collectionViewLayout: UICollectionViewCompositionalLayout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
                var configuration: UICollectionLayoutListConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                configuration.backgroundColor = .clear
                if sectionIndex > 0 {
                    configuration.headerMode = .supplementary
                }
                configuration.showsSeparators = false
                
                let section: NSCollectionLayoutSection = .list(using: configuration, layoutEnvironment: layoutEnvironment)
                return section
            }
            
            let dataController: UINavigationController = UINavigationController(rootViewController: DataController(annotation.facility,
                                                                                                                   collectionViewLayout: collectionViewLayout))
            dataController.view.backgroundColor = .clear
            
            dataController.modalPresentationStyle = .overFullScreen
            present(dataController, animated: true) {
                mapView.deselectAnnotation(view.annotation, animated: true)
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        let renderer: MKPolylineRenderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 8
        renderer.strokeColor = .tintColor.withProminence(.secondary)
        return renderer
    }
}

extension MapController : ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce: String = nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            guard let appleIDToken: Data = appleIDCredential.identityToken else {
                return
            }
            
            guard let idTokenString: String = .init(data: appleIDToken, encoding: .utf8) else {
                return
            }
            
            let credential: OAuthCredential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                                            rawNonce: nonce,
                                                                            fullName: appleIDCredential.fullName)
            
            let task = Task {
                try await auth.signIn(with: credential)
            }
            
            Task {
                switch await task.result {
                case .success(_):
                    navigationItem.leadingItemGroups = leadingItemGroups
                case .failure(_):
                    break
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {}
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window: UIWindow = view.window {
            window
        } else {
            UIWindow()
        }
    }
}

extension MapController {
    var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    func detectDatabaseFile(_ result: @escaping (Bool) -> Void) {
        if let documentDirectoryURL {
            result(FileManager.default.fileExists(atPath: documentDirectoryURL.appending(component: "toilets.json").path))
        } else {
            result(false)
        }
    }
    
    func directions(_ from: CLLocation, _ to: CLLocation, with mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(location: from, address: nil)
        request.destination = MKMapItem(location: to, address: nil)
        
        MKDirections(request: request).calculate { response, error in
            guard let response, let route = response.routes.first else {
                return
            }

            mapView.addOverlay(route.polyline)
        }
    }
    
    func monitor(_ facility: Facility, for mapView: MKMapView) {
        guard let monitor, let user: User = auth.currentUser else {
            return
        }
        
        func submit(for alertController: UIAlertController, existance: Bool, facility: Facility) async throws {
            let calendar: Calendar = Calendar.current
            let year: Year = calendar.component(.year, from: Date())
            let month: Month = calendar.component(.month, from: Date())
            
            let status: LavvyFacility.FacilityReview.ReviewStatus = .init(year: year, month: month, existance: existance)
            
            
            if let textFields: [UITextField] = alertController.textFields, let textField: UITextField = textFields.first,
               let text: String = textField.text, !text.isEmpty {
                let document: DocumentReference = self.firestore.collection("facilities").document(facility.id)
                let snapshot: DocumentSnapshot = try await document.getDocument()
                
                if snapshot.exists {
                    var old: LavvyFacility = try snapshot.data(as: LavvyFacility.self)
                    old.reviews.append(LavvyFacility.FacilityReview(date: Date(),
                                                                    status: status,
                                                                    text: text,
                                                                    user: LavvyFacility.FacilityReview.ReviewUser(name: user.displayName,
                                                                                                                  uid: user.uid),
                                                                    facilityID: facility.id,
                                                                    index: old.reviews.count))
                    try document.setData(from: old)
                } else {
                    try document.setData(from: LavvyFacility(reviews: [
                        LavvyFacility.FacilityReview(date: Date(),
                                                     status: status,
                                                     text: text,
                                                     user: LavvyFacility.FacilityReview.ReviewUser(name: user.displayName,
                                                                                                   uid: user.uid),
                                                     facilityID: facility.id,
                                                     index: 0)
                    ]))
                }
                
                let userDocument: DocumentReference = self.firestore.collection("users").document(user.uid)
                let userSnapshot: DocumentSnapshot = try await userDocument.getDocument()
                if userSnapshot.exists {
                    var old: LavvyUser = try userSnapshot.data(as: LavvyUser.self)
                    if let index: Int = old.reviews.firstIndex(where: { $0.facilityID == facility.id }) {
                        var indexes: [Int] = old.reviews[index].indexes
                        indexes.append(indexes.count)
                        old.reviews[index].indexes = indexes
                    } else {
                        old.reviews.append(LavvyUser.UserReview(facilityID: facility.id, indexes: [0]))
                    }
                    try userDocument.setData(from: old)
                } else {
                    try userDocument.setData(from: LavvyUser(reviews: [
                        LavvyUser.UserReview(facilityID: facility.id, indexes: [0])
                    ]))
                }
            }
        }
        
        Task {
            await monitor.remove("10_meter_region")
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("sceneDidDisconnect"), object: nil, queue: .main) { _ in
                Task {
                    await monitor.remove("10_meter_region")
                }
            }
            
            let condition: CLMonitor.CircularGeographicCondition = CLMonitor.CircularGeographicCondition(center: facility.geographyPoints.coordinate,
                                                                                                         radius: 10)
            
            await monitor.add(condition, identifier: "10_meter_region")
            
            for try await event in await monitor.events {
                switch event.state {
                case .satisfied:
                    let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
                        mapView.removeOverlays(mapView.overlays)
                        Task {
                            await monitor.remove("10_meter_region")
                        }
                    }
                    
                    let noAction: UIAlertAction = UIAlertAction(title: "No", style: .default) { action in
                        let alertController: UIAlertController = UIAlertController(title: "Review",
                                                                                   message: "Please take a moment to write a review for this facility to help other users",
                                                                                   preferredStyle: .alert)
                        
                        let submitAction: UIAlertAction = UIAlertAction(title: "Submit", style: .default) { action in
                            mapView.removeOverlays(mapView.overlays)
                            Task {
                                await monitor.remove("10_meter_region")
                                try await submit(for: alertController, existance: false, facility: facility)
                            }
                        }
                        
                        alertController.addAction(cancelAction)
                        alertController.addAction(submitAction)
                        alertController.preferredAction = submitAction
                        
                        alertController.addTextField { textField in
                            textField.placeholder = "Write a review here..."
                        }
                        
                        self.present(alertController, animated: true)
                    }
                    
                    let yesAction: UIAlertAction = UIAlertAction(title: "Yes", style: .default) { action in
                        let alertController: UIAlertController = UIAlertController(title: "Review",
                                                                                   message: "Please take a moment to write a review for this facility to help other users",
                                                                                   preferredStyle: .alert)
                        
                        let submitAction: UIAlertAction = UIAlertAction(title: "Submit", style: .default) { action in
                            mapView.removeOverlays(mapView.overlays)
                            Task {
                                await monitor.remove("10_meter_region")
                                try await submit(for: alertController, existance: true, facility: facility)
                            }
                        }
                        
                        alertController.addAction(cancelAction)
                        alertController.addAction(submitAction)
                        alertController.preferredAction = submitAction
                        
                        alertController.addTextField { textField in
                            textField.placeholder = "Write a review here..."
                        }
                        
                        self.present(alertController, animated: true)
                    }
                    
                    let alertController: UIAlertController = UIAlertController(title: "Arrival",
                                                                               message: "Did you arrive at the correct location given to you by Lavvy?",
                                                                               preferredStyle: .alert)
                    
                    alertController.addAction(noAction)
                    alertController.addAction(yesAction)
                    alertController.preferredAction = yesAction
                    
                    present(alertController, animated: true)
                default:
                    break
                }
            }
        }
    }
}
