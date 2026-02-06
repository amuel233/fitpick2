import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

struct BodyMeasurementView: View {
    @StateObject private var viewModel = BodyMeasurementViewModel()
    @State private var showAutoMeasure = false
    @State private var showImagePicker = false
    @State private var selectedSelfie: UIImage? = nil
    
    @EnvironmentObject var session: UserSession
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var storageManager = StorageManager()
    
    let fitPickGold = Color("fitPickGold")

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            // --- 1. Top Header Section (Username & Auto-Measure) ---
                            VStack(alignment: .leading, spacing: 15) {
                                Text("User Information")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("USERNAME")
                                        .font(.caption2).bold().foregroundColor(.secondary)
                                    TextField("Enter username", text: $viewModel.username)
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                }

                                Picker("Gender", selection: $viewModel.gender) {
                                    Text("Male").tag("Male")
                                    Text("Female").tag("Female")
                                }
                                .pickerStyle(.segmented)
                                
                                Button(action: { showAutoMeasure = true }) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Auto-Measure")
                                    }
                                    .font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(fitPickGold)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)

                            // --- 2. HERO Body Visualizer (Scrolling & Interactive) ---
                            ZStack {
                                // Large Avatar Image
                                Image(viewModel.gender ?? "Male")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: geo.size.height * 0.7)
                                    .shadow(color: .black.opacity(0.1), radius: 15)
                                
                                // Measurement Lines & Interactive Callouts
                                HStack(alignment: .center, spacing: 0) {
                                    // Left Side (Lengths)
                                    VStack(alignment: .leading, spacing: geo.size.height * 0.1) {
                                        MeasurementCallout(label: "Height", value: $viewModel.height, unit: "cm", alignment: .leading)
                                        MeasurementCallout(label: "Arm", value: $viewModel.armLength, unit: "cm", alignment: .leading)
                                        MeasurementCallout(label: "Inseam", value: $viewModel.inseam, unit: "cm", alignment: .leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    // Right Side (Widths)
                                    VStack(alignment: .trailing, spacing: geo.size.height * 0.07) {
                                        MeasurementCallout(label: "Shoulder", value: $viewModel.shoulderWidth, unit: "cm", alignment: .trailing)
                                        MeasurementCallout(label: "Chest", value: $viewModel.chest, unit: "cm", alignment: .trailing)
                                        MeasurementCallout(label: "Waist", value: $viewModel.waist, unit: "cm", alignment: .trailing)
                                        MeasurementCallout(label: "Hips", value: $viewModel.hips, unit: "cm", alignment: .trailing)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 15)
                            }
                            .frame(height: geo.size.height * 0.75)
                            .padding(.vertical, 30)

                            // --- 3. Bottom Profile Form ---
                            VStack(spacing: 20) {
                                HStack(spacing: 15) {
                                    StatBox(label: "Weight", value: $viewModel.bodyWeight, unit: "kg", icon: "scalemass.fill")
                                    StatBox(label: "Shoes", value: $viewModel.shoeSize, unit: "US", icon: "shoeprints.fill")
                                }

                                Button(action: { showImagePicker = true }) {
                                    Label(selectedSelfie == nil ? "Selfie" : "Selfie Ready", systemImage: "camera.fill")
                                        .font(.subheadline).bold()
                                        .foregroundColor(selectedSelfie == nil ? .primary : .green)
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                }

                                Button(action: { saveProfile() }) {
                                    Text("Save Changes")
                                        .font(.headline).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                                        .background(viewModel.username.isEmpty ? Color.gray : Color.black)
                                        .cornerRadius(15)
                                }
                                .disabled(viewModel.username.isEmpty)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 60)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchUserData() }
        .fullScreenCover(isPresented: $showAutoMeasure) {
            AutoMeasureView { h, w, i, a, s, c, hi in
                viewModel.height = h; viewModel.waist = w; viewModel.inseam = i
                viewModel.armLength = a; viewModel.shoulderWidth = s; viewModel.chest = c; viewModel.hips = hi
                showAutoMeasure = false
            }
        }
        .sheet(isPresented: $showImagePicker) {
            FaceCaptureView(selectedImage: $selectedSelfie)
        }
    }

    private func saveProfile() {
        guard let userEmail = session.email, !userEmail.isEmpty else { return }
        let oldUsername = firestoreManager.currentUserData?.username ?? ""
        let db = Firestore.firestore()
        
        if let selfie = selectedSelfie {
            storageManager.uploadSelfie(email: userEmail, selfie: selfie) { url in
                db.collection("users").document(userEmail).updateData(["selfie": url])
            }
        }
        
        db.collection("users").document(userEmail).updateData([
            "gender": viewModel.gender,
            "username": viewModel.username,
            "measurements.height": viewModel.height,
            "measurements.bodyWeight": viewModel.bodyWeight,
            "measurements.chest": viewModel.chest,
            "measurements.shoulderWidth": viewModel.shoulderWidth,
            "measurements.armLength": viewModel.armLength,
            "measurements.waist": viewModel.waist,
            "measurements.hips": viewModel.hips,
            "measurements.inseam": viewModel.inseam,
            "measurements.shoeSize": viewModel.shoeSize,
        ]) { _ in
            if oldUsername != viewModel.username && !oldUsername.isEmpty {
                firestoreManager.updateUsernameEverywhere(email: userEmail, oldUsername: oldUsername, newUsername: viewModel.username)
            }
            print("Profile saved. Avatar generation must be triggered from Closet.")
        }
    }
}

// MARK: - Subcomponents

struct MeasurementCallout: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let alignment: HorizontalAlignment
    
    var body: some View {
        // WRAPPED IN MENU TO MAKE IT CLICKABLE
        Menu {
            Picker(label, selection: $value) {
                ForEach(Array(stride(from: 1, through: 250, by: 1)), id: \.self) { num in
                    Text("\(num) \(unit)").tag(Double(num))
                }
            }
        } label: {
            HStack(spacing: 0) {
                if alignment == .trailing {
                    Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 35, height: 1)
                }
                
                VStack(alignment: alignment, spacing: 2) {
                    Text(label.uppercased()).font(.system(size: 8, weight: .black)).foregroundColor(.secondary)
                    Text("\(Int(value))\(unit)").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.1), radius: 3))

                if alignment == .leading {
                    Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 35, height: 1)
                }
            }
        }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

struct StatBox: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let icon: String
    
    var body: some View {
        Menu {
            Picker(label, selection: $value) {
                ForEach(1...250, id: \.self) { num in
                    Text("\(num) \(unit)").tag(Double(num))
                }
            }
        } label: {
            HStack {
                Image(systemName: icon).foregroundColor(Color("fitPickGold"))
                VStack(alignment: .leading) {
                    Text(label).font(.caption2).bold().foregroundColor(.secondary)
                    Text("\(Int(value))\(unit)").font(.subheadline).bold().foregroundColor(.primary)
                }
                Spacer()
            }
            .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
        }
    }
}
