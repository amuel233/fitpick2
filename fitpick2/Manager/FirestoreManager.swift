//
//  FirestoreManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/15/26.
//

import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import SwiftUI

class FirestoreManager: ObservableObject {
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    @Published var users = [User]()
    @Published var posts: [SocialsPost] = []
    @Published var followersList: [User] = []
    @Published var followingList: [User] = []
    
    @Published var currentEmail: String? = Auth.auth().currentUser?.email
    @Published var currentUserData: User?
    
    init() {
        fetchSocialPosts()
        if let email = currentEmail {
            startCurrentUserListener(email: email)
            fetchFollowers() // Fetch followers list on startup
            fetchFollowing() // Fetch following list on startup
        }
    }
    
    func startCurrentUserListener(email: String) {
        db.collection("users").document(email).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            self.currentUserData = User(
                id: email,
                username: data["username"] as? String ?? "",
                selfie: data["selfie"] as? String ?? "",
                following: data["following"] as? [String] ?? []
            )
        }
    }
    
    
    // Create
    func addUser(documentID: String, email: String, selfie: String) {
        
        let newUser = [
            "email":email,
            "selfie":selfie,
        ]
        
        db.collection("users").document(documentID).setData(newUser) { error in
               if let error = error {
                   print("Error creating document: \(error)")
               } else {
                   print("Document with custom ID: \(documentID) successfully created")
               }
           }
    }

    // Fetch today's hero outfit image name or url from `recommendations/today`
    func fetchHeroImageName(completion: @escaping (String?) -> Void) {
        let docRef = db.collection("recommendations").document("today")
        docRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let imageName = data["imageName"] as? String {
                completion(imageName)
            } else {
                completion(nil)
            }
        }
    }

    // Fetch wardrobe counts (e.g., shoes by subCategory) to help gap detection
    func fetchWardrobeCounts(completion: @escaping ([String: Int]) -> Void) {
        db.collection("clothes").getDocuments { snapshot, error in
            var counts: [String: Int] = [:]
            guard let docs = snapshot?.documents else {
                completion(counts)
                return
            }

            for doc in docs {
                let data = doc.data()
                let category = data["category"] as? String ?? ""
                let subCategory = data["subCategory"] as? String ?? ""

                if category == "Shoes" {
                    counts[subCategory, default: 0] += 1
                }
            }
            completion(counts)
        }
    }

    // Fetch number of clothes uploaded in the last 7 days and how many of those were specifically tagged in socials posts during that same period.
    func fetchWardrobePulse(lastDays: Int = 7, completion: @escaping (_ totalUploaded: Int, _ usedCount: Int) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else { completion(0,0); return }
        let since = Date().addingTimeInterval(TimeInterval(-lastDays * 24 * 60 * 60))

        // Get the Document IDs of clothes uploaded in the last 7 days
        db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .whereField("createdat", isGreaterThan: Timestamp(date: since))
            .getDocuments { clothesSnap, _ in
                let docs = clothesSnap?.documents ?? []
                let uploadedCount = docs.count
                
                // Collect the Document IDs (doc.documentID)
                let newClothesIDs = Set(docs.map { $0.documentID })

                print("Pulse Debug: Found \(uploadedCount) new clothes.")
                
                // Get social posts from the last 7 days
                self.db.collection("socials")
                    .whereField("userEmail", isEqualTo: userEmail)
                    .whereField("timestamp", isGreaterThan: Timestamp(date: since))
                    .getDocuments { postsSnap, _ in
                        var uniqueUsedIDs = Set<String>()
                        
                        postsSnap?.documents.forEach { doc in
                            // 3. Check the array of IDs tagged in this post
                            if let taggedIDs = doc.data()["taggedClothesIds"] as? [String] {
                                for idFromPost in taggedIDs {
                                    // 4. Match the Post's Tagged ID against our New Clothes IDs
                                    if newClothesIDs.contains(idFromPost) {
                                        uniqueUsedIDs.insert(idFromPost)
                                    }
                                }
                            }
                        }
                        print("Pulse Debug: Found \(uniqueUsedIDs.count) tagged items matching new clothes.")
                        completion(uploadedCount, uniqueUsedIDs.count)
                    }
            }
    }
    
    func fetchUserMeasurements(email: String, completion: @escaping ([String: Double]?) -> Void) {
            let db = Firestore.firestore()
            
            db.collection("users").document(email).getDocument { document, error in
                if let document = document, document.exists {
                    // Get the 'measurements' map from the document
                    let data = document.data()
                    let measurements = data?["measurements"] as? [String: Any]
                    print(measurements ?? "")
                    
                    // Convert [String: Any] to [String: Double]
                    var result: [String: Double] = [:]
                    measurements?.forEach { key, value in
                        if let doubleValue = value as? Double {
                            result[key] = doubleValue
                        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                            result[key] = doubleValue
                        }
                    }
                    completion(result)
                } else {
                    print("Document does not exist")
                    completion(nil)
                }
            }
        }

    /// Fetch the current user's gender string (e.g., "Male", "Female") from the users document.
    func fetchUserGender(completion: @escaping (String?) -> Void) {
        guard let email = Auth.auth().currentUser?.email else { completion(nil); return }
        db.collection("users").document(email).getDocument { snapshot, error in
            guard let data = snapshot?.data() else { completion(nil); return }
            if let gender = data["gender"] as? String {
                completion(gender)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Socials Feed Listener
    
    func updateUsernameEverywhere(email: String, oldUsername: String, newUsername: String) {
        let socialsRef = db.collection("socials")
        
        // Query posts authored by the user
        socialsRef.whereField("userEmail", isEqualTo: email).getDocuments { snapshot, _ in
            let batch = self.db.batch()
            
            snapshot?.documents.forEach { doc in
                batch.updateData(["username": newUsername], forDocument: doc.reference)
            }
            
            // Query posts liked by the user
            socialsRef.whereField("likedBy", arrayContains: email).getDocuments { likedSnapshot, _ in
                
                likedSnapshot?.documents.forEach { doc in
                    // In Firestore, you can't "update" a specific index in an array easily.
                    // We remove the old name and add the new one.
                    batch.updateData([
                        "likedByNames": FieldValue.arrayRemove([oldUsername])
                    ], forDocument: doc.reference)
                    
                    batch.updateData([
                        "likedByNames": FieldValue.arrayUnion([newUsername])
                    ], forDocument: doc.reference)
                }
                
                // Commit all changes at once
                batch.commit { error in
                    if let error = error {
                        print("Batch update failed: \(error.localizedDescription)")
                    } else {
                        print("Username updated in posts and likes successfully!")
                    }
                }
            }
        }
    }
        
    func fetchSocialPosts() {
        db.collection("socials")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.posts = documents.compactMap { doc in
                        do {
                            return try doc.data(as: SocialsPost.self)
                        } catch {
                            print("Error decoding post \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                }
            }
    }
    
    func deletePost(post: SocialsPost) {
        // 1. Delete the image from Firebase Storage first
        let storageRef = Storage.storage().reference(forURL: post.imageUrl)
        
        storageRef.delete { [weak self] error in
            if let error = error {
                print("Error deleting image from storage: \(error.localizedDescription)")
                // Even if storage fails (e.g. image already gone), we usually proceed to delete the doc
            }
            
            // 2. Delete the document from Firestore
            self?.db.collection("social_posts").document(post.id).delete() { error in
                if let error = error {
                    print("Error removing document: \(error.localizedDescription)")
                } else {
                    print("Post and storage successfully deleted!")
                }
            }
        }
    }

    func toggleLike(post: SocialsPost, userEmail: String, username: String) {
        let postRef = db.collection("socials").document(post.id)
        
        // Check using the email (unique ID)
        if post.safeLikedBy.contains(userEmail) {
            // UNLIKE: Both email and the exact username must be removed
            postRef.updateData([
                "likedBy": FieldValue.arrayRemove([userEmail]),
                "likedByNames": FieldValue.arrayRemove([username]),
                "likes": FieldValue.increment(Int64(-1))
            ])
        } else {
            // LIKE: Add both to the database
            postRef.updateData([
                "likedBy": FieldValue.arrayUnion([userEmail]),
                "likedByNames": FieldValue.arrayUnion([username]),
                "likes": FieldValue.increment(Int64(1))
            ])
        }
    }
    
    // MARK: - Follow Logic
    func toggleFollow(currentEmail: String, targetEmail: String, isFollowing: Bool) {
        let currentUserRef = db.collection("users").document(currentEmail)
        
        if isFollowing {
            // UNFOLLOW: Remove target email from my following list
            currentUserRef.updateData(["following": FieldValue.arrayRemove([targetEmail])])
        } else {
            // FOLLOW: Add target email to my following list
            currentUserRef.updateData(["following": FieldValue.arrayUnion([targetEmail])])
        }
    }
    
    func fetchFollowers() {
        guard let currentEmail = Auth.auth().currentUser?.email else { return }
        
        // We search for all users whose 'following' array contains the current user's email
        db.collection("users")
            .whereField("following", arrayContains: currentEmail)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching followers: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.followersList = documents.compactMap { doc in
                        let data = doc.data()
                        return User(
                            id: doc.documentID,
                            username: data["username"] as? String ?? "",
                            selfie: data["selfie"] as? String ?? "",
                            following: data["following"] as? [String] ?? []
                        )
                    }
                }
            }
    }
    
    func fetchFollowing() {
        // Get the list of emails from the current user's data
        guard let followingEmails = currentUserData?.following, !followingEmails.isEmpty else {
            self.followingList = []
            return
        }
        
        // Fetch user documents where the document ID (email) is in the following list
        db.collection("users")
            .whereField(FieldPath.documentID(), in: followingEmails)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching following: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.followingList = documents.compactMap { doc in
                        let data = doc.data()
                        return User(
                            id: doc.documentID,
                            username: data["username"] as? String ?? "",
                            selfie: data["selfie"] as? String ?? "",
                            following: data["following"] as? [String] ?? []
                        )
                    }
                }
            }
    }
    
    func removeFollower(followerEmail: String) {
        guard let currentEmail = currentEmail else { return }
        
        // We go to the FOLLOWER'S document and remove OUR email from their 'following' list
        db.collection("users").document(followerEmail).updateData([
            "following": FieldValue.arrayRemove([currentEmail])
        ]) { error in
            if let error = error {
                print("Error removing follower: \(error.localizedDescription)")
            } else {
                print("Follower successfully removed.")
                // The snapshot listener in fetchFollowers() will automatically update the UI
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
    }
}
