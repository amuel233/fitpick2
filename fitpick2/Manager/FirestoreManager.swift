//
//  FirestoreManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/15/26.
//

import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class FirestoreManager: ObservableObject {
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    @Published var users = [User]()
    @Published var posts: [SocialsPost] = []
    
    @Published var currentEmail: String? = Auth.auth().currentUser?.email
    @Published var currentUserData: User?
    
    init() {
        fetchSocialPosts()
        if let email = currentEmail {
            startCurrentUserListener(email: email)
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

    /// Fetch number of clothes uploaded in the last `days` and how many of those were used in socials posts in the same period.
    func fetchWardrobePulse(lastDays: Int = 7, completion: @escaping (_ totalUploaded: Int, _ usedCount: Int) -> Void) {
        guard let userEmail = Auth.auth().currentUser?.email else { completion(0,0); return }

        let since = Date().addingTimeInterval(TimeInterval(-lastDays * 24 * 60 * 60))

        // 1) fetch clothes uploaded in the last `lastDays`
        db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .whereField("createdat", isGreaterThan: Timestamp(date: since))
            .getDocuments { clothesSnap, err in
                guard let clothesDocs = clothesSnap?.documents else {
                    completion(0,0); return
                }

                let uploaded = clothesDocs.count
                // collect image URLs from clothes
                let imageURLs: Set<String> = Set(clothesDocs.compactMap { $0.data()["imageURL"] as? String })

                // 2) fetch socials by user in same timeframe
                self.db.collection("socials")
                    .whereField("userEmail", isEqualTo: userEmail)
                    .whereField("timestamp", isGreaterThan: Timestamp(date: since))
                    .getDocuments { postsSnap, _ in
                        var used = 0
                        if let posts = postsSnap?.documents {
                            let postUrls = posts.compactMap { $0.data()["imageUrl"] as? String }
                            for u in imageURLs {
                                if postUrls.contains(u) { used += 1 }
                            }
                        }
                        completion(uploaded, used)
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
    
    // MARK: - Socials Feed Listener
        
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

    func uploadPost(email: String, username: String, caption: String, imageUrl: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uniqueID = "\(email)_\(timestamp)"
        
        let postData: [String: Any] = [
            "id": uniqueID,
            "userEmail": email,
            "username": username,
            "caption": caption,
            "imageUrl": imageUrl,
            "likes": 0,
            "likedBy": [], // Initialize with empty array
            "comments": 0,
            "timestamp": FieldValue.serverTimestamp()
        ]
        db.collection("socials").document(uniqueID).setData(postData)
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
    
    func stopListening() {
        listener?.remove()
    }
}
