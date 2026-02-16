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
    @State private var isEditing = false
    
    // Alert States
    @State private var showCancelAlert = false
    @State private var showSaveSuccessAlert = false
    
    @EnvironmentObject var session: UserSession
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var storageManager = StorageManager()
    
    @State private var focusedPart: String? = nil
    let fitPickGold = Color("fitPickGold")
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let screenHeight = geo.size.height
                
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // --- 1. USERNAME SECTION ---
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USERNAME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            TextField("Enter username", text: $viewModel.username)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .disabled(!isEditing)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 8)
                        
                        // --- 2. GENDER PICKER ---
                        Picker("Gender", selection: $viewModel.gender) {
                            Text("Male").tag("Male")
                            Text("Female").tag("Female")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .disabled(!isEditing)
                        
                        Spacer(minLength: 8)
                        
                        // --- 3. AUTO MEASURE BUTTON ---
                        Button(action: { if isEditing { showAutoMeasure = true } }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Auto-Measure")
                            }
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isEditing ? fitPickGold : Color.gray.opacity(0.3))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(!isEditing)
                        
                        Spacer(minLength: 12)
                        
                        // --- 4. BODY IMAGE SECTION ---
                        bodyAvatarSection(geo: geo, screenHeight: screenHeight)
                        
                        Spacer(minLength: 12)
                        
                        // --- 5. WEIGHT & SHOE SIZE ---
                        HStack(spacing: 12) {
                            StatBox(label: "Weight", value: $viewModel.bodyWeight, unit: "kg", icon: "scalemass.fill")
                                .disabled(!isEditing)
                            StatBox(label: "Shoes", value: $viewModel.shoeSize, unit: "US", icon: "shoeprints.fill")
                                .disabled(!isEditing)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 10)
                        
                        // --- 6. SELFIE BUTTON ---
                        Button(action: { if isEditing { showImagePicker = true } }) {
                            Label(selectedSelfie == nil ? "Take Selfie" : "Selfie Ready", systemImage: "camera.fill")
                                .font(.subheadline).bold()
                                .foregroundColor(isEditing ? (selectedSelfie == nil ? .primary : .green) : .secondary.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(!isEditing)
                        
                        Spacer(minLength: 10)
                        
                        // --- 7. SAVE BUTTON ---
                        if isEditing {
                            Button(action: {
                                saveProfile()
                                // Logic: saveProfile handles Firebase, then we show success
                                showSaveSuccessAlert = true
                            }) {
                                Text("Save Changes")
                                    .font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(viewModel.username.isEmpty ? Color.gray : Color.black)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 15)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Spacer().frame(height: 15)
                        }
                    }
                }
            }
            // --- UPDATED TOOLBAR ---
            .toolbar {
                // Move to Trailing (Upper Right)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Cancel") {
                            showCancelAlert = true
                        }
                        .font(.subheadline).bold()
                        .foregroundColor(.red)
                        .id("cancel")
                    } else {
                        Button(action: {
                            withAnimation(.spring()) { isEditing = true }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.circle.fill") // Using a filled icon for better visibility
                                    .foregroundColor(fitPickGold)
                                Text("Edit Profile")
                                    .foregroundColor(.primary)
                            }
                            .font(.subheadline).bold()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(fitPickGold.opacity(0.1)) // Subtle background makes it look like a button
                            .cornerRadius(8)
                        }
                        .id("edit")
                    }
                }
            }
            // --- ALERTS ---
            .alert("Discard Changes?", isPresented: $showCancelAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    withAnimation {
                        isEditing = false
                        focusedPart = nil
                        viewModel.fetchUserData() // Revert changes by fetching original data
                    }
                }
            } message: {
                Text("Are you sure you want to discard your unsaved changes?")
            }
            .alert("Profile Updated", isPresented: $showSaveSuccessAlert) {
                Button("OK") {
                    withAnimation { isEditing = false }
                }
            } message: {
                Text("Your measurements and profile details have been saved successfully.")
            }
            // --- FULL SCREEN COVERS & SHEETS ---
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
        .onAppear { viewModel.fetchUserData() }
    }
    // (Avatar Section & saveProfile logic remain unchanged)
    @ViewBuilder
        private func bodyAvatarSection(geo: GeometryProxy, screenHeight: CGFloat) -> some View {
            ZStack {
                // --- CLEAN ANCHOR EFFECT ---
                // Instead of a gray box, we use a very soft circular gradient
                // to provide a visual base for the avatar.
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [fitPickGold.opacity(0.12), .clear]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    ))
                    .frame(width: geo.size.width)
                    .offset(y: -10)
                
                // --- THE AVATAR ---
                // Removed the RoundedRectangle. Added a subtle shadow.
                Image(viewModel.gender ?? "Male")
                    .resizable()
                    .scaledToFit()
                    .frame(height: screenHeight * 0.35)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .overlay(
                        Group {
                            if let part = focusedPart {
                                MeasurementGuide(focusedPart: part, geo: geo)
                            }
                        }
                    )
            
            HStack {
                VStack(alignment: .leading, spacing: screenHeight * 0.04) {
                    MeasurementCallout(label: "Height", value: $viewModel.height, unit: "cm", alignment: .leading, isFocused: focusedPart == "Height", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Height") ? nil : "Height"
                    }
                    MeasurementCallout(label: "Arm", value: $viewModel.armLength, unit: "cm", alignment: .leading, isFocused: focusedPart == "Arm", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Arm") ? nil : "Arm"
                    }
                    MeasurementCallout(label: "Inseam", value: $viewModel.inseam, unit: "cm", alignment: .leading, isFocused: focusedPart == "Inseam", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Inseam") ? nil : "Inseam"
                    }
                }
                Spacer().frame(width: 180)
                VStack(alignment: .trailing, spacing: screenHeight * 0.03) {
                    MeasurementCallout(label: "Shoulder", value: $viewModel.shoulderWidth, unit: "cm", alignment: .trailing, isFocused: focusedPart == "Shoulder", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Shoulder") ? nil : "Shoulder"
                    }
                    MeasurementCallout(label: "Chest", value: $viewModel.chest, unit: "cm", alignment: .trailing, isFocused: focusedPart == "Chest", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Chest") ? nil : "Chest"
                    }
                    MeasurementCallout(label: "Waist", value: $viewModel.waist, unit: "cm", alignment: .trailing, isFocused: focusedPart == "Waist", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Waist") ? nil : "Waist"
                    }
                    MeasurementCallout(label: "Hips", value: $viewModel.hips, unit: "cm", alignment: .trailing, isFocused: focusedPart == "Hips", isLocked: !isEditing) {
                        focusedPart = (focusedPart == "Hips") ? nil : "Hips"
                    }
                }
            }
        }
        .frame(height: screenHeight * 0.38)
    }
    
    private func saveProfile() {
        guard let userEmail = session.email, !userEmail.isEmpty else { return }
        let db = Firestore.firestore()
        
        // Handle image upload if exists
        if let selfie = selectedSelfie {
            storageManager.uploadSelfie(email: userEmail, selfie: selfie) { url in
                db.collection("users").document(userEmail).updateData(["selfie": url])
            }
        }
        
        // Save the rest of the data
        db.collection("users").document(userEmail).updateData([
            "gender": viewModel.gender ?? "Male",
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
        ])
    }
}
// MARK: - Subcomponents (Internalized Logic)
struct MeasurementCallout: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let alignment: HorizontalAlignment
    let isFocused: Bool
    let isLocked: Bool // To disable the Menu
    let toggleFocus: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            if alignment == .trailing {
                guideLine
                tooltipButton
            }
            VStack(alignment: alignment, spacing: 2) {
                Text(label.uppercased()).font(.system(size: 8, weight: .black))
                    .foregroundColor(isFocused ? Color("fitPickGold") : .secondary)
                
                // Clicking the value only opens the picker if NOT locked
                Menu {
                    Picker(label, selection: $value) {
                        ForEach(1...250, id: \.self) { num in
                            Text("\(num) \(unit)").tag(Double(num))
                        }
                    }
                } label: {
                    Text("\(Int(value))\(unit)").font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isFocused ? Color("fitPickGold") : .primary)
                }
                .disabled(isLocked) // Disable picker interaction
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2))
            if alignment == .leading {
                tooltipButton
                guideLine
            }
        }
    }
    private var tooltipButton: some View {
        Button(action: toggleFocus) {
            Image(systemName: isFocused ? "eye.fill" : "eye")
                .font(.system(size: 8))
                .foregroundColor(isFocused ? Color("fitPickGold") : .secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .disabled(isLocked) // Prevent clicking eye icons unless in Edit mode
    }
    private var guideLine: some View {
        Rectangle().fill(isFocused ? Color("fitPickGold") : Color.gray.opacity(0.2))
            .frame(width: 10, height: 1)
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
                Image(systemName: icon).foregroundColor(Color("fitPickGold")).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                    Text("\(Int(value))\(unit)").font(.footnote).bold().foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(10).background(Color(.secondarySystemBackground)).cornerRadius(10)
        }
    }
}
struct MeasurementGuide: View {
    let focusedPart: String
    let geo: GeometryProxy
    
    var body: some View {
        // Use the middle of the available width
        let centerX = geo.size.width / 2
        
        // We match the height used in the frame of the image
        let avatarHeight = geo.size.height
        
        // No vertical offset needed if the ZStack is perfectly contained,
        // but we'll anchor everything to the top of the avatar's head.
        
        ZStack {
            switch focusedPart {
            case "Height":
                // Top of head to bottom of feet
                makeLine(from: CGPoint(x: centerX - 88, y: avatarHeight * 0.33),
                         to: CGPoint(x: centerX - 88, y: avatarHeight * 0.025))
            case "Shoulder":
                // Wider horizontal line across the upper torso
                makeLine(from: CGPoint(x: centerX - 116, y: avatarHeight * 0.08),
                         to: CGPoint(x: centerX - 57, y: avatarHeight * 0.08))
            case "Chest":
                // Slightly higher than center torso
                makeLine(from: CGPoint(x: centerX - 105, y: avatarHeight * 0.1),
                         to: CGPoint(x: centerX - 70, y: avatarHeight * 0.1))
            case "Waist":
                // Narrowest part of the torso
                makeLine(from: CGPoint(x: centerX - 106, y: avatarHeight * 0.135),
                         to: CGPoint(x: centerX - 67, y: avatarHeight * 0.135))
            case "Hips":
                // Wider line below the waist
                makeLine(from: CGPoint(x: centerX - 108, y: avatarHeight * 0.17),
                         to: CGPoint(x: centerX - 67, y: avatarHeight * 0.17))
            case "Arm":
                // Diagonal line following the arm angle
                makeLine(from: CGPoint(x: centerX - 110, y: avatarHeight * 0.08),
                         to: CGPoint(x: centerX - 120, y: avatarHeight * 0.175))
            case "Inseam":
                // Vertical line from crotch to ankle
                makeLine(from: CGPoint(x: centerX - 95, y: avatarHeight * 0.2),
                         to: CGPoint(x: centerX - 95, y: avatarHeight * 0.31))
            default: EmptyView()
            }
        }
    }
    
    private func makeLine(from: CGPoint, to: CGPoint) -> some View {
        DashedLineShape(from: from, to: to)
            .stroke(Color("fitPickGold"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 4]))
            .shadow(color: .black.opacity(0.1), radius: 1) // Makes the line "pop" against the avatar
    }
}
struct DashedLineShape: Shape {
    var from: CGPoint
    var to: CGPoint
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: from); path.addLine(to: to); return path
    }
}
#Preview {
    BodyMeasurementView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
