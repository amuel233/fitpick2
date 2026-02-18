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
    
    // Luxe Theme alignment
    let fitPickGold = Color.luxeEcru
    let fitPickBlack = Color.luxeDeepOnyx
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let screenHeight = geo.size.height
                
                ZStack {
                    // Background: Spotlight Gradient
                    Color.luxeSpotlightGradient.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // --- 1. USERNAME SECTION ---
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USERNAME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.luxeFlax)
                            
                            TextField("Enter username", text: $viewModel.username)
                                .padding(12)
                                .background(Color.luxeRichCharcoal.opacity(0.8))
                                .cornerRadius(10)
                                .foregroundColor(.luxeBeige)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.usernameError != nil ? Color.red : Color.luxeEcru.opacity(0.3), lineWidth: 1)
                                )
                                .disabled(!isEditing)
                                .autocapitalization(.none)
                            
                            if let error = viewModel.usernameError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 8)
                        
                        // --- 2. GENDER PICKER ---
                        Picker("Gender", selection: $viewModel.gender) {
                            Text("Male").tag("Male_luxe_1")
                            Text("Female").tag("Female_luxe_1")
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
                            .foregroundColor(.luxeBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isEditing ? Color.luxeGoldGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(10)
                            .shadow(color: isEditing ? Color.luxeEcru.opacity(0.3) : .clear, radius: 5)
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
                                .foregroundColor(isEditing ? (selectedSelfie == nil ? .luxeBeige : .green) : .luxeBeige.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.luxeRichCharcoal)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(!isEditing)
                        
                        Spacer(minLength: 10)
                        
                        // --- 7. SAVE BUTTON ---
                        if isEditing {
                            Button(action: {
                                Task {
                                    if await viewModel.isUsernameUnique() {
                                        saveProfile()
                                        withAnimation { showSaveSuccessAlert = true }
                                    }
                                }
                            }) {
                                Group {
                                    if viewModel.isCheckingUsername {
                                        ProgressView().tint(.luxeBlack)
                                    } else {
                                        Text("Save Changes")
                                            .font(.headline).foregroundColor(.luxeBlack)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.luxeFlax)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 15)
                            .disabled(viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isCheckingUsername)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            Spacer().frame(height: 15)
                        }
                    }
                }
                // --- CUSTOM LUXE ALERTS ---
                .luxeAlert(
                    isPresented: $showCancelAlert,
                    title: "DISCARD CHANGES?",
                    message: "Are you sure you want to discard your unsaved changes?",
                    confirmTitle: "DISCARD",
                    cancelTitle: "KEEP EDITING"
                ) {
                    withAnimation {
                        isEditing = false
                        focusedPart = nil
                        viewModel.fetchUserData()
                        showCancelAlert = false
                    }
                }
                .luxeAlert(
                    isPresented: $showSaveSuccessAlert,
                    title: "PROFILE UPDATED",
                    message: "Your measurements and profile details have been saved successfully.",
                    confirmTitle: "OK",
                    cancelTitle: "" // Leaving this empty removes the extra button and centers "OK"
                ) {
                    withAnimation {
                        isEditing = false
                        showSaveSuccessAlert = false
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        // Minimalist Cancel Button in Luxe Palette
                        Button("Cancel") {
                            withAnimation { showCancelAlert = true }
                        }
                        .font(.subheadline).bold()
                        .foregroundColor(.luxeBeige.opacity(0.7))
                    } else {
                        // Clean Edit Profile Button (No background shape)
                        Button(action: {
                            withAnimation(.spring()) { isEditing = true }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(Color.luxeFlax)
                                Text("Edit Profile")
                                    .foregroundColor(.luxeBeige)
                            }
                            .font(.subheadline).bold()
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        .onAppear {
            viewModel.fetchUserData()
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.luxeEcru)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.luxeBeige)], for: .normal)
        }
    }
    
    @ViewBuilder
    private func bodyAvatarSection(geo: GeometryProxy, screenHeight: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color.luxeEcru.opacity(0.12), .clear]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 180
                ))
                .frame(width: geo.size.width)
                .offset(y: -10)
            
            Image(viewModel.gender ?? "Male")
                .resizable()
                .scaledToFit()
                .frame(height: screenHeight * 0.35)
                .shadow(color: Color.luxeEcru.opacity(0.15), radius: 10)
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
        
        if let selfie = selectedSelfie {
            storageManager.uploadSelfie(email: userEmail, selfie: selfie) { url in
                db.collection("users").document(userEmail).updateData(["selfie": url])
            }
        }
        
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





// MARK: - Subcomponents
struct MeasurementCallout: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let alignment: HorizontalAlignment
    let isFocused: Bool
    let isLocked: Bool
    let toggleFocus: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            if alignment == .trailing {
                guideLine
                tooltipButton
            }
            VStack(alignment: alignment, spacing: 2) {
                Text(label.uppercased()).font(.system(size: 8, weight: .black))
                    .foregroundColor(isFocused ? Color.luxeFlax : Color.luxeBeige.opacity(0.5))
                
                Menu {
                    Picker(label, selection: $value) {
                        ForEach(1...250, id: \.self) { num in
                            Text("\(num) \(unit)").tag(Double(num))
                        }
                    }
                } label: {
                    Text("\(Int(value))\(unit)").font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isFocused ? Color.luxeFlax : Color.luxeBeige)
                }
                .disabled(isLocked)
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.luxeRichCharcoal)
                .shadow(color: isFocused ? Color.luxeEcru.opacity(0.3) : .black.opacity(0.2), radius: 2))
            
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
                .foregroundColor(isFocused ? Color.luxeFlax : Color.luxeBeige.opacity(0.4))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.luxeBlack))
        }
        .disabled(isLocked)
    }
    
    private var guideLine: some View {
        Rectangle().fill(isFocused ? Color.luxeFlax : Color.luxeEcru.opacity(0.2))
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
                Image(systemName: icon).foregroundColor(Color.luxeEcru).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(Color.luxeBeige.opacity(0.6))
                    Text("\(Int(value))\(unit)").font(.footnote).bold().foregroundColor(Color.luxeBeige)
                }
                Spacer()
            }
            .padding(10).background(Color.luxeRichCharcoal).cornerRadius(10)
        }
    }
}


struct MeasurementGuide: View {
    let focusedPart: String
    let geo: GeometryProxy
    
    // Proportional scaling
    private var avatarHeight: CGFloat { geo.size.height * 0.35 }
    private var avatarWidth: CGFloat { avatarHeight * 0.42 }
    
    private var centerX: CGFloat { geo.size.width / 2 }
    private var centerY: CGFloat { geo.size.height / 2 }

    var body: some View {
        ZStack {
            switch focusedPart {
            case "Height":
                // Shifted further left (-45) and slightly UP
                heightVerticalGuide()
                
            case "Shoulder":
                guideLine(yOffset: -avatarHeight * 0.32, width: avatarWidth * 0.55)
                
            case "Chest":
                guideLine(yOffset: -avatarHeight * 0.20, width: avatarWidth * 0.50)
                
            case "Waist":
                guideLine(yOffset: -avatarHeight * 0.04, width: avatarWidth * 0.45)
                
            case "Hips":
                guideLine(yOffset: avatarHeight * 0.08, width: avatarWidth * 0.55)
                
            case "Arm":
                // Shifted UP and to the LEFT
                armPath()
                
            case "Inseam":
                // Shifted UP and to the LEFT
                inseamPath()
                
            default:
                EmptyView()
            }
        }
    }
    
    // --- Vertical Height Guide ---
    @ViewBuilder
    private func heightVerticalGuide() -> some View {
        // Moved to -45 to clear the shoulder silhouette entirely
        let heightX = centerX - 220
        let topY = centerY - (avatarHeight * 1.4) // Higher top point
        let bottomY = centerY - (avatarHeight * 0.42) // Slightly raised floor point
        
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: heightX, y: topY))
                path.addLine(to: CGPoint(x: heightX, y: bottomY))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundColor(.luxeEcru)

            // T-Bar Caps
            Path { path in
                path.move(to: CGPoint(x: heightX - 10, y: topY))
                path.addLine(to: CGPoint(x: heightX + 10, y: topY))
                path.move(to: CGPoint(x: heightX - 10, y: bottomY))
                path.addLine(to: CGPoint(x: heightX + 10, y: bottomY))
            }
            .stroke(lineWidth: 2)
            .foregroundColor(.luxeEcru)
        }
    }

    // --- Arm Guide ---
    @ViewBuilder
        private func armPath() -> some View {
            Path { path in
                // Adjusted: start moved UP (multiplier -0.45) and further LEFT (multiplier 0.40)
                let start = CGPoint(x: centerX - (avatarWidth * 1.8), y: centerY - (avatarHeight * 1.25))
                // Adjusted: end moved UP (multiplier 0.05) and further LEFT (multiplier 0.65)
                let end = CGPoint(x: centerX - (avatarWidth * 2), y: centerY - (avatarHeight * 0.95))
                
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .foregroundColor(.luxeEcru)
        }
        
        // --- Inseam Guide ---
        @ViewBuilder
        private func inseamPath() -> some View {
            Path { path in
                // Adjusted: start moved UP (multiplier -0.10) and further LEFT (multiplier 0.15)
                let start = CGPoint(x: centerX - (avatarWidth * 1.3), y: centerY - (avatarHeight * 0.88))
                // Adjusted: end moved UP (multiplier 0.35) and further LEFT (multiplier 0.22)
                let end = CGPoint(x: centerX - (avatarWidth * 1.3), y: centerY - (avatarHeight * 0.5))
                
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            .foregroundColor(.luxeEcru)
        }

    @ViewBuilder
    private func guideLine(yOffset: CGFloat, width: CGFloat) -> some View {
        ZStack {
            DashedLineShape()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundColor(.luxeEcru.opacity(0.9))
                .frame(width: width, height: 1)
            
            HStack {
                Circle().fill(Color.luxeEcru).frame(width: 3, height: 3)
                Spacer()
                Circle().fill(Color.luxeEcru).frame(width: 3, height: 3)
            }
            .frame(width: width)
        }
        .offset(y: yOffset)
    }

    
    // Vertical/Angled measurement for Arm
    @ViewBuilder
    private func armGuide() -> some View {
        Path { path in
            path.move(to: CGPoint(x: geo.size.width/2 - avatarWidth * 0.4, y: geo.size.height/2 - avatarHeight * 0.28))
            path.addLine(to: CGPoint(x: geo.size.width/2 - avatarWidth * 0.55, y: geo.size.height/2 + avatarHeight * 0.1))
        }
        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundColor(.luxeEcru.opacity(0.8))
    }
    
    // Vertical measurement for Inseam
    @ViewBuilder
    private func inseamGuide() -> some View {
        Path { path in
            path.move(to: CGPoint(x: geo.size.width/2 - avatarWidth * 0.1, y: geo.size.height/2 + avatarHeight * 0.12))
            path.addLine(to: CGPoint(x: geo.size.width/2 - avatarWidth * 0.15, y: geo.size.height/2 + avatarHeight * 0.45))
        }
        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundColor(.luxeEcru.opacity(0.8))
    }
}

// MARK: - Refined Dashed Line Shape
struct DashedLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
