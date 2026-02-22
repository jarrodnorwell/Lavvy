//
//  ReviewsController.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 4/2/2026.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import UIKit

class ReviewsController : UIViewController {
    var dataSource: UICollectionViewDiffableDataSource<String, HashableSendable>? = nil
    var snapshot: NSDiffableDataSourceSnapshot<String, HashableSendable>? = nil
    
    let auth: Auth = .auth()
    let firestore: Firestore = .firestore()
    
    var collectionView: UICollectionView? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let navigationController {
            navigationController.navigationBar.prefersLargeTitles = true
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), primaryAction: UIAction { action in
            self.dismiss(animated: true)
        })
        navigationItem.largeTitle = "My Reviews"
        navigationItem.title = navigationItem.largeTitle
        navigationItem.style = .browser
        
        let collectionViewLayout: UICollectionViewCompositionalLayout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var configuration: UICollectionLayoutListConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = .supplementary
            configuration.trailingSwipeActionsConfigurationProvider = { indexPath in
                let removeAction: UIContextualAction = UIContextualAction(style: .destructive, title: nil) { action, sourceView, actionPerformed in
                    Task {
                        guard let user: User = self.auth.currentUser,
                              let dataSource: UICollectionViewDiffableDataSource<String, HashableSendable> = self.dataSource,
                              let itemIdentifier: FacilityReviewSendable = dataSource.itemIdentifier(for: indexPath) as? FacilityReviewSendable else {
                            return
                        }
                        
                        func deleteFromFacility() async throws {
                            let document: DocumentReference = await self.firestore.collection("facilities").document(itemIdentifier.facilityID)
                            let snapshot: DocumentSnapshot = try await document.getDocument()
                            if snapshot.exists {
                                var old: LavvyFacility = try snapshot.data(as: LavvyFacility.self)
                                old.reviews.remove(at: itemIdentifier.index)
                                try document.setData(from: old)
                            }
                        }
                        
                        func deleteFromUser() async throws {
                            let document: DocumentReference = await self.firestore.collection("users").document(user.uid)
                            let snapshot: DocumentSnapshot = try await document.getDocument()
                            if snapshot.exists {
                                var old: LavvyUser = try snapshot.data(as: LavvyUser.self)
                                if let index = old.reviews.firstIndex(where: { $0.facilityID == itemIdentifier.facilityID }) {
                                    old.reviews[index].indexes.removeAll(where: { $0 == itemIdentifier.index })
                                }
                                try document.setData(from: old)
                            }
                        }
                        
                        try await deleteFromFacility()
                        try await deleteFromUser()
                        
                        var snapshot = dataSource.snapshot()
                        snapshot.deleteItems([itemIdentifier])
                        if let indexPath = dataSource.indexPath(for: itemIdentifier), let section = dataSource.sectionIdentifier(for: indexPath.section) {
                            if snapshot.numberOfItems(inSection: section) == 0 {
                                snapshot.deleteSections([section])
                            }
                        }
                        await dataSource.apply(snapshot)
                        
                        self.navigationItem.largeSubtitle = "\(snapshot.numberOfItems) review\(snapshot.numberOfItems == 1 ? "" : "s")"
                        self.navigationItem.subtitle = self.navigationItem.largeSubtitle
                        
                        actionPerformed(true)
                    }
                }
                removeAction.image = .init(systemName: "trash")
                
                return UISwipeActionsConfiguration(actions: [removeAction])
            }
            
            let section: NSCollectionLayoutSection = .list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
        
        collectionView = .init(frame: .zero, collectionViewLayout: collectionViewLayout)
        guard let collectionView else {
            return
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        let facilityReviewCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, FacilityReviewSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
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
        
        let stringCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, StringSendable> = UICollectionView.CellRegistration { cell, indexPath, itemIdentifier in
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
        
        let supplementaryRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell> = UICollectionView.SupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, elementKind, indexPath in
            var contentConfiguration: UIListContentConfiguration = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            if let dataSource = self.dataSource, let header: String = dataSource.sectionIdentifier(for: indexPath.section) {
                contentConfiguration.text = header
            }
            supplementaryView.contentConfiguration = contentConfiguration
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let facilityReviewSendable as FacilityReviewSendable:
                collectionView.dequeueConfiguredReusableCell(using: facilityReviewCellRegistration, for: indexPath, item: facilityReviewSendable)
            case let stringSendable as StringSendable:
                collectionView.dequeueConfiguredReusableCell(using: stringCellRegistration, for: indexPath, item: stringSendable)
            default:
                nil
            }
        }
        
        guard let dataSource else {
            return
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: supplementaryRegistration, for: indexPath)
        }
        
        snapshot = NSDiffableDataSourceSnapshot()
        guard var snapshot else {
            return
        }
        
        func populateForNoReviews() async {
            snapshot.appendSections(["No Reviews"])
            snapshot.appendItems([
                StringSendable(text: "Get started by leaving a review for any facility visited using Lavvy")
            ], toSection: "No Reviews")
            
            await dataSource.apply(snapshot)
        }
        
        let task = Task {
            if let user: User = auth.currentUser {
                let document: DocumentReference = firestore.collection("users").document(user.uid)
                let documentSnapshot: DocumentSnapshot = try await document.getDocument()
                if documentSnapshot.exists {
                    let lavvyUser: LavvyUser = try documentSnapshot.data(as: LavvyUser.self)
                    dump(lavvyUser)
                    
                    let indexes = lavvyUser.reviews.flatMap(\.indexes)
                    if lavvyUser.reviews.isEmpty || indexes.isEmpty {
                        await populateForNoReviews()
                    } else {
                        for userReview in lavvyUser.reviews {
                            let facilityDocument: DocumentReference = firestore.collection("facilities").document(userReview.facilityID)
                            let facilitySnapshot: DocumentSnapshot = try await facilityDocument.getDocument()
                            
                            let lavvyFacility: LavvyFacility = try facilitySnapshot.data(as: LavvyFacility.self)
                            
                            let filtered: [LavvyFacility.FacilityReview] = lavvyFacility.reviews.filter { facilityReview in
                                userReview.indexes.contains(facilityReview.index)
                            }
                            
                            let formatter = DateFormatter()
                            formatter.dateStyle = .long
                            formatter.timeStyle = .none
                            
                            let datesAsStrings: [String] = Array(Set(filtered.map { review in formatter.string(from: review.date) }))
                            snapshot.appendSections(datesAsStrings)
                            
                            formatter.dateStyle = .none
                            formatter.timeStyle = .short
                            
                            datesAsStrings.forEach { string in
                                snapshot.appendItems(filtered.sorted(by: { $0.date.compare($1.date) == .orderedDescending }).map { review in
                                    FacilityReviewSendable(text: review.text,
                                                           secondaryText: formatter.string(from: review.date),
                                                           facilityID: review.facilityID,
                                                           index: review.index)
                                }, toSection: string)
                            }
                        }
                        
                        navigationItem.largeSubtitle = "\(snapshot.numberOfItems) review\(snapshot.numberOfItems == 1 ? "" : "s")"
                        navigationItem.subtitle = navigationItem.largeSubtitle
                        
                        await dataSource.apply(snapshot)
                    }
                } else {
                    await populateForNoReviews()
                }
            } else {
                await populateForNoReviews()
            }
        }
        
        Task {
            switch await task.result {
            case .success(_):
                break
            case .failure(let error):
                print(error, error.localizedDescription)
            }
        }
    }
}

extension ReviewsController : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
