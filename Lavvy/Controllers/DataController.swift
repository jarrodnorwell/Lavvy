//
//  DataController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 28/1/2026.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import MapKit
import OnboardingKit
import UIKit

nonisolated enum DataHeaders : String, CaseIterable, Comparable {
    static func < (lhs: DataHeaders, rhs: DataHeaders) -> Bool {
        lhs.string.localizedCaseInsensitiveCompare(rhs.string) == .orderedAscending
    }
    
    case directionDistance = "Direction & Distance",
         location = "Location",
         genderSex = "Gender & Sex",
         accessibilty = "Accessibility",
         parenting = "Parenting",
         ameneties = "Amenities",
         parking = "Parking",
         miscellaneous = "Miscellaneous",
         reviews = "Reviews"
    
    case warning = "Warning"
    
    var int: Int {
        DataHeaders.allCases.firstIndex(of: self) ?? 0
    }
    
    var string: String {
        rawValue
    }
    
    static var allCases: [DataHeaders] {
        var cases: [DataHeaders] = [
            .location,
            .genderSex,
            .accessibilty,
            .parenting,
            .ameneties,
            .parking,
            .miscellaneous
        ].sorted(by: <)
        cases.insert(.directionDistance, at: 0)
        cases.append(.reviews)
        return cases
    }
}

nonisolated class HashableSendable : Hashable, @unchecked Sendable {
    static func == (lhs: HashableSendable, rhs: HashableSendable) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: UUID = UUID()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated class BlankSendable : HashableSendable, @unchecked Sendable {}

nonisolated class BoolSendable : HashableSendable, @unchecked Sendable {
    var image: UIImage? = nil
    var text: String
    var secondaryText: String? = nil
    var value: Bool = false
    
    init(image: UIImage? = nil, text: String, secondaryText: String? = nil, value: Bool = false) {
        self.image = image
        self.text = text
        self.secondaryText = secondaryText
        self.value = value
    }
}

nonisolated class DistanceSendable : HashableSendable, @unchecked Sendable {
    var text: String
    var value: CGFloat = 0
    
    init(text: String, value: CGFloat = 0) {
        self.text = text
    }
}

nonisolated class StringSendable : HashableSendable, @unchecked Sendable {
    var image: UIImage? = nil
    var text: String
    var secondaryText: String? = nil
    
    init(image: UIImage? = nil, text: String, secondaryText: String? = nil) {
        self.image = image
        self.text = text
        self.secondaryText = secondaryText
    }
}

nonisolated class WarningStringSendable : HashableSendable, @unchecked Sendable {
    var image: UIImage? = nil
    var text: String
    var secondaryText: String? = nil
    
    init(image: UIImage? = nil, text: String, secondaryText: String? = nil) {
        self.image = image
        self.text = text
        self.secondaryText = secondaryText
    }
}

nonisolated class FacilityReviewSendable : HashableSendable, @unchecked Sendable {
    var image: UIImage? = nil
    var text: String
    var secondaryText: String? = nil
    
    var facilityID: String
    var index: Int
    
    init(image: UIImage? = nil, text: String, secondaryText: String? = nil, facilityID: String, index: Int) {
        self.image = image
        self.text = text
        self.secondaryText = secondaryText
        self.facilityID = facilityID
        self.index = index
    }
}

class DistanceCell : UICollectionViewCell {
    var imageView: UIImageView? = nil
    var textLabel: UILabel? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView = UIImageView(image: UIImage(systemName: "arrow.up.circle"))
        guard let imageView else {
            return
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .systemBlue
        addSubview(imageView)
        
        imageView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor).isActive = true
        imageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        imageView.widthAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, multiplier:  1 / 2).isActive = true
        imageView.heightAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.widthAnchor).isActive = true
        
        textLabel = UILabel()
        guard let textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = .bold(.extraLargeTitle)
        textLabel.textAlignment = .center
        textLabel.textColor = .label
        addSubview(textLabel)
        
        textLabel.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor).isActive = true
        // textLabel.centerYAnchor.constraint(equalTo: visualEffectView.contentView.safeAreaLayoutGuide.centerYAnchor).isActive = true
        textLabel.topAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.bottomAnchor, constant: 20).isActive = true
        textLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        
        // heightAnchor.constraint(equalTo: safeAreaLayoutGuide.widthAnchor, multiplier: 2 / 3).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DataController : UICollectionViewController {
    var dataSource: UICollectionViewDiffableDataSource<DataHeaders, HashableSendable>? = nil
    var snapshot: NSDiffableDataSourceSnapshot<DataHeaders, HashableSendable>? = nil
    
    let auth: Auth = .auth()
    let firestore: Firestore = .firestore()
    
    var facility: Facility
    init(_ facility: Facility, collectionViewLayout: UICollectionViewLayout) {
        self.facility = facility
        super.init(collectionViewLayout: collectionViewLayout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), primaryAction: UIAction { action in
            self.dismiss(animated: true)
        })
        
        navigationItem.trailingItemGroups = [
            UIBarButtonItemGroup(barButtonItems: [
                UIBarButtonItem(image: UIImage(systemName: "safari"), primaryAction: UIAction { action in
                    let directionalController: UINavigationController = UINavigationController(rootViewController: DirectionalController(facility: self.facility))
                    directionalController.modalPresentationStyle = .fullScreen
                    if let navigationController: UINavigationController = self.presentingViewController as? UINavigationController,
                       let mapController: MapController  = navigationController.topViewController as? MapController,
                       let currentLocation = mapController.currentLocation,
                       let mapView: MKMapView  = mapController.view as? MKMapView {
                        self.present(directionalController, animated: true) {
                            mapController.directions(currentLocation, CLLocation(latitude: self.facility.geographyPoints.latitude,
                                                                                 longitude: self.facility.geographyPoints.longitude),
                                                     with: mapView)
                            
                            mapController.monitor(self.facility, for: mapView)
                        }
                    }
                }),
                UIBarButtonItem(image: UIImage(systemName: "dot.arrowtriangles.up.right.down.left.circle"), primaryAction: UIAction { action in
                    if let navigationController: UINavigationController = self.presentingViewController as? UINavigationController,
                       let mapController: MapController  = navigationController.topViewController as? MapController,
                       let currentLocation = mapController.currentLocation,
                       let mapView: MKMapView  = mapController.view as? MKMapView {
                        self.dismiss(animated: true) {
                            mapController.directions(currentLocation, CLLocation(latitude: self.facility.geographyPoints.latitude,
                                                                                 longitude: self.facility.geographyPoints.longitude),
                                                     with: mapView)
                            
                            mapController.monitor(self.facility, for: mapView)
                        }
                    }
                }),
                UIBarButtonItem(image: UIImage(systemName: "map.circle"), primaryAction: UIAction { action in
                    let item: MKMapItem = MKMapItem(location: CLLocation(latitude: self.facility.geographyPoints.latitude,
                                                                         longitude: self.facility.geographyPoints.longitude),
                                                    address: nil)
                    item.name = self.facility.pointOfInterestName ?? self.facility.name
                    item.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDefault
                    ])
                })
            ], representativeItem: nil)
        ]
        
        /*
        let rightBarButtonItem: UIBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(preferredElementSize: .medium, children: [
            UIAction(title: "Compass", image: UIImage(systemName: "arrow.up.forward.circle")) { action in
                let directionalController: UINavigationController = UINavigationController(rootViewController: DirectionalController(facility: self.facility))
                directionalController.modalPresentationStyle = .fullScreen
                self.present(directionalController, animated: true)
            },
            UIAction(title: "Directions", image: UIImage(systemName: "point.bottomleft.forward.to.arrow.triangle.scurvepath")) { action in
                if let navigationController: UINavigationController = self.presentingViewController as? UINavigationController,
                   let mapController: MapController  = navigationController.topViewController as? MapController,
                   let currentLocation = mapController.currentLocation,
                   let mapView: MKMapView  = mapController.view as? MKMapView {
                    self.dismiss(animated: true) {
                        mapController.directions(currentLocation, CLLocation(latitude: self.facility.geographyPoints.latitude, longitude: self.facility.geographyPoints.longitude),
                                                 with: mapView)
                        
                        mapController.monitor(self.facility, for: mapView)
                    }
                }
            },
            UIAction(title: "Maps", image: UIImage(systemName: "map")) { action in
                let item: MKMapItem = MKMapItem(location: CLLocation(latitude: self.facility.geographyPoints.latitude,
                                                                     longitude: self.facility.geographyPoints.longitude),
                                                address: nil)
                item.name = self.facility.pointOfInterestName ?? self.facility.name
                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving
                ])
            }
        ]))
        rightBarButtonItem.style = .prominent
        navigationItem.rightBarButtonItem = rightBarButtonItem
         */
        
        let backgroundView: UIVisualEffectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        backgroundView.cornerConfiguration = .corners(radius: .containerConcentric())
        
        collectionView.backgroundColor = .clear
        collectionView.backgroundView = backgroundView
        view.backgroundColor = .clear
        
        let blankCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, BlankSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            let contentConfiguration: UIListContentConfiguration = UIListContentConfiguration.cell()
            cell.contentConfiguration = contentConfiguration
        }
        
        let boolCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, BoolSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            var backgroundConfiguration: UIBackgroundConfiguration = .clear()
            
            let visualEffectView: UIVisualEffectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            visualEffectView.cornerConfiguration = .corners(topLeftRadius: .fixed(cell.effectiveRadius(corner: .topLeft)),
                                                            topRightRadius: .fixed(cell.effectiveRadius(corner: .topRight)),
                                                            bottomLeftRadius: .fixed(cell.effectiveRadius(corner: .bottomLeft)),
                                                            bottomRightRadius: .fixed(cell.effectiveRadius(corner: .bottomRight)))
            backgroundConfiguration.customView = visualEffectView
            cell.backgroundConfiguration = backgroundConfiguration
            
            var contentConfiguration: UIListContentConfiguration = if itemIdentifier.secondaryText == nil {
                UIListContentConfiguration.cell()
            } else {
                UIListContentConfiguration.valueCell()
            }
            contentConfiguration.image = itemIdentifier.image
            contentConfiguration.text = itemIdentifier.text
            contentConfiguration.secondaryText = itemIdentifier.secondaryText
            cell.contentConfiguration = contentConfiguration
            
            cell.accessories = if itemIdentifier.value {
                [
                    UICellAccessory.customView(configuration: UICellAccessory.CustomViewConfiguration(customView: UIImageView(image: UIImage(systemName: "checkmark.circle.fill")?
                        .applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [.systemBlue]))?
                        .applyingSymbolConfiguration(UIImage.SymbolConfiguration(scale: .large))), placement: .trailing()))
                ]
            } else {
                []
            }
        }
        
        let distanceCellRegistration: UICollectionView.CellRegistration<DistanceCell, DistanceSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            var backgroundConfiguration: UIBackgroundConfiguration = .clear()
            
            let visualEffectView: UIVisualEffectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            visualEffectView.cornerConfiguration = .corners(topLeftRadius: .fixed(cell.effectiveRadius(corner: .topLeft)),
                                                            topRightRadius: .fixed(cell.effectiveRadius(corner: .topRight)),
                                                            bottomLeftRadius: .fixed(cell.effectiveRadius(corner: .bottomLeft)),
                                                            bottomRightRadius: .fixed(cell.effectiveRadius(corner: .bottomRight)))
            backgroundConfiguration.customView = visualEffectView
            cell.backgroundConfiguration = backgroundConfiguration
            
            if let textLabel: UILabel = cell.textLabel, let imageView: UIImageView = cell.imageView {
                textLabel.text = itemIdentifier.text
                
                imageView.transform = CGAffineTransform(rotationAngle: itemIdentifier.value)
            }
        }
        
        let stringCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StringSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            var backgroundConfiguration: UIBackgroundConfiguration = .clear()
            
            let visualEffectView: UIVisualEffectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            visualEffectView.cornerConfiguration = .corners(topLeftRadius: .fixed(cell.effectiveRadius(corner: .topLeft)),
                                                            topRightRadius: .fixed(cell.effectiveRadius(corner: .topRight)),
                                                            bottomLeftRadius: .fixed(cell.effectiveRadius(corner: .bottomLeft)),
                                                            bottomRightRadius: .fixed(cell.effectiveRadius(corner: .bottomRight)))
            backgroundConfiguration.customView = visualEffectView
            cell.backgroundConfiguration = backgroundConfiguration
            
            var contentConfiguration: UIListContentConfiguration = if itemIdentifier.secondaryText == nil {
                UIListContentConfiguration.cell()
            } else {
                UIListContentConfiguration.valueCell()
            }
            contentConfiguration.image = itemIdentifier.image
            contentConfiguration.text = itemIdentifier.text
            contentConfiguration.secondaryText = itemIdentifier.secondaryText
            cell.contentConfiguration = contentConfiguration
        }
        
        let warningStringCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, WarningStringSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
            var backgroundConfiguration: UIBackgroundConfiguration = .clear()
            
            let effect: UIGlassEffect = UIGlassEffect(style: .regular)
            effect.tintColor = .systemOrange
            
            let visualEffectView: UIVisualEffectView = UIVisualEffectView(effect: effect)
            visualEffectView.cornerConfiguration = .corners(topLeftRadius: .fixed(cell.effectiveRadius(corner: .topLeft)),
                                                            topRightRadius: .fixed(cell.effectiveRadius(corner: .topRight)),
                                                            bottomLeftRadius: .fixed(cell.effectiveRadius(corner: .bottomLeft)),
                                                            bottomRightRadius: .fixed(cell.effectiveRadius(corner: .bottomRight)))
            backgroundConfiguration.customView = visualEffectView
            cell.backgroundConfiguration = backgroundConfiguration
            
            var contentConfiguration: UIListContentConfiguration = if itemIdentifier.secondaryText == nil {
                UIListContentConfiguration.cell()
            } else {
                UIListContentConfiguration.valueCell()
            }
            contentConfiguration.image = itemIdentifier.image
            contentConfiguration.text = itemIdentifier.text
            contentConfiguration.textProperties.color = .white
            contentConfiguration.textProperties.font = .bold(.title1)
            contentConfiguration.secondaryText = itemIdentifier.secondaryText
            contentConfiguration.secondaryTextProperties.color = .white.withProminence(.secondary)
            // contentConfiguration.secondaryTextProperties.font = .preferredFont(forTextStyle: .title3)
            cell.contentConfiguration = contentConfiguration
        }
        
        let supplementaryRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell> = UICollectionView.SupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, elementKind, indexPath in
            var contentConfiguration: UIListContentConfiguration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            if let dataSource = self.dataSource, let header: DataHeaders = dataSource.sectionIdentifier(for: indexPath.section) {
                contentConfiguration.text = header.string
            }
            supplementaryView.contentConfiguration = contentConfiguration
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let blankSendable as BlankSendable:
                collectionView.dequeueConfiguredReusableCell(using: blankCellRegistration, for: indexPath, item: blankSendable)
            case let boolSendable as BoolSendable:
                collectionView.dequeueConfiguredReusableCell(using: boolCellRegistration, for: indexPath, item: boolSendable)
            case let distanceSendable as DistanceSendable:
                collectionView.dequeueConfiguredReusableCell(using: distanceCellRegistration, for: indexPath, item: distanceSendable)
            case let stringSendable as StringSendable:
                collectionView.dequeueConfiguredReusableCell(using: stringCellRegistration, for: indexPath, item: stringSendable)
            case let warningStringSendable as WarningStringSendable:
                collectionView.dequeueConfiguredReusableCell(using: warningStringCellRegistration, for: indexPath, item: warningStringSendable)
            default:
                nil
            }
        }
        
        guard let dataSource else {
            return
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            if indexPath.section == 0 {
                nil
            } else {
                collectionView.dequeueConfiguredReusableSupplementary(using: supplementaryRegistration, for: indexPath)
            }
        }
        
        snapshot = NSDiffableDataSourceSnapshot()
        guard var snapshot else {
            return
        }
        snapshot.appendSections(DataHeaders.allCases)
        snapshot.appendItems([
            DistanceSendable(text: "Awaiting Update", value: 0)
        ], toSection: DataHeaders.directionDistance)
        snapshot.appendItems([
            // StringSendable(text: "Name", secondaryText: facility.pointOfInterestName?.capitalized ?? "Unknown Name"),
            StringSendable(text: "State", secondaryText: facility.state?.uppercased() ?? "Unknown State"),
            StringSendable(text: "Street", secondaryText: facility.pointOfInterestStreet?.capitalized ?? "Unknown Street"),
            StringSendable(text: "Suburb", secondaryText: facility.pointOfInterestSuburb?.capitalized ?? "Unknown Suburb")
        ], toSection: DataHeaders.location)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "figure.stand"), text: "Male", value: facility.male.bool),
            BoolSendable(image: UIImage(systemName: "figure.stand.dress"), text: "Female", value: facility.female.bool),
            BoolSendable(image: UIImage(systemName: "figure.stand.dress.line.vertical.figure"), text: "Unisex", value: facility.unisex.bool),
            BoolSendable(image: UIImage(systemName: "figure"), text: "All Gender", value: facility.allgender.bool)
        ], toSection: DataHeaders.genderSex)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "cross.case"), text: "Ambulant", value: facility.ambulant.bool),
            BoolSendable(image: UIImage(systemName: "wheelchair"), text: "Accessible", value: facility.accessible.bool),
            
            BoolSendable(image: UIImage(systemName: "left"), text: "Left Hand Transfer", value: facility.leftHandTransfer?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "right"), text: "Right Hand Transfer", value: facility.rightHandTransfer?.bool ?? false)
        ], toSection: DataHeaders.accessibilty)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "figure.seated.side.right.child.lap"), text: "Baby Change Room", value: facility.babyChange?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "figure.child"), text: "Baby Care Room", value: facility.babyCareRoom?.bool ?? false)
        ], toSection: DataHeaders.parenting)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "shower"), text: "Shower", value: facility.shower?.bool ?? false)
        ], toSection: DataHeaders.ameneties)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "parkingsign"), text: "Parking", value: facility.parking?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "figure.walk"), text: "Parking Accessible", value: facility.parkingAccessible?.bool ?? false)
        ], toSection: DataHeaders.parking)
        snapshot.appendItems([
            BoolSendable(image: UIImage(systemName: "syringe"), text: "Sharps Disposal", value: facility.sharpsDisposal?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "waterbottle"), text: "Drinking Water", value: facility.drinkingWater?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "xmark.bin"), text: "Sanitary Disposal", value: facility.sanitaryDisposal?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "trash"), text: "Men's Pad Disposal", secondaryText: "Provided by BINS4Blokes", value: facility.mensPadDisposal?.bool ?? false),
            BoolSendable(image: UIImage(systemName: "cart"), text: "Payment Required", value: facility.paymentRequired?.bool ?? false)
        ], toSection: DataHeaders.miscellaneous)
        
        
        let task = Task {
            if let _: User = auth.currentUser {
                let fReviews: LavvyFacility = try await firestore.collection("facilities").document(facility.id).getDocument(as: LavvyFacility.self)
                if fReviews.reviews.isEmpty {
                    snapshot.appendItems([
                        StringSendable(text: "No Reviews")
                    ], toSection: DataHeaders.reviews)
                } else {
                    if fReviews.ratio <= 0.3 {
                        snapshot.insertSections([.warning], beforeSection: .directionDistance)
                        
                        snapshot.appendItems([
                            WarningStringSendable(text: "Warning",
                                                  secondaryText: "Other users have overwhelmingly reported this facility as non-existent\n\nWe recommend trying another facility")
                        ], toSection: .warning)
                    }
                    
                    snapshot.appendItems(fReviews.reviews.map { review in
                        StringSendable(text: review.user.name ?? "Anonymous", secondaryText: review.text)
                    }, toSection: DataHeaders.reviews)
                }
            }
            
            await dataSource.apply(snapshot)
        }
        
        Task {
            switch await task.result {
            case .success():
                break
            case .failure(_):
                snapshot.appendItems([
                    StringSendable(text: "No Reviews")
                ], toSection: DataHeaders.reviews)
                
                await dataSource.apply(snapshot)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
    
    func update(_ type: Int, for location: CLLocation? = nil, with heading: CLHeading? = nil) {
        guard let dataSource else {
            return
        }
        
        func updateDirection(for item: DistanceSendable) {
            guard let location, let heading else {
                return
            }
            
            let bearing: Double = location.coordinate.bearing(to: .init(latitude: facility.geographyPoints.latitude, longitude: facility.geographyPoints.longitude))
            let deviceHeading: CLLocationDirection = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
            
            let relativeBearing: Double = (bearing - deviceHeading).normalizedDegrees
            
            let radians: CGFloat = .init(relativeBearing * .pi / 180)
            
            item.value = radians
        }
        
        func updateDistance(for item: DistanceSendable) {
            guard let location else {
                return
            }
            
            let destination: CLLocation = .init(latitude: facility.geographyPoints.latitude, longitude: facility.geographyPoints.longitude)
            
            let mapPoint1: MKMapPoint = .init(location.coordinate)
            let mapPoint2: MKMapPoint = .init(destination.coordinate)
            
            let distance = mapPoint1.distance(to: mapPoint2)
            
            let measurement: Measurement = Measurement(value: distance, unit: UnitLength.meters)
            
            let string: String = if distance >= 1000 {
                String(format: "%.0lf km away", measurement.converted(to: .kilometers).value)
            } else {
                String(format: "%.0lf m away", measurement.value)
            }
            
            item.text = string
        }
        
        var snapshot = dataSource.snapshot()
        if snapshot.indexOfSection(.directionDistance) != nil,  let item = snapshot.itemIdentifiers(inSection: .directionDistance)[0] as? DistanceSendable {
            if type == 1 {
                updateDirection(for: item)
            }
            
            if type == 0 {
                updateDistance(for: item)
            }
            
            snapshot.reconfigureItems([item])
            
            Task {
                await dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }
}
