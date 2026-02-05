//
//  BodyMeasurementView.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

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
            // Using GeometryReader to calculate relative positions for measurement lines
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // --- 1. User Info Header ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("User Information")
                                .font(.system(size: 34, weight: .bold))
                                .padding(.top, 10)
                            
                            TextField("Username", text: $viewModel.username)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            
                            Picker("Gender", selection: $viewModel.gender) {
                                Text("Male").tag("Male")
                                Text("Female").tag("Female")
                            }
                            .pickerStyle(.segmented)
                            
                            // CENTERED AUTO-MEASURE BUTTON
                            HStack {
                                Spacer()
                                Button(action: { showAutoMeasure = true }) {
                                    Text("Auto-Measure")
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 140)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)

                        // --- 2. Body Visualizer ---
                        // We use a ZStack with a responsive frame based on device width
                        ZStack {
                            Image(viewModel.gender)
                                .resizable()
                                .scaledToFit()
                                .frame(height: geo.size.height * 0.5) // 50% of screen height
                                .opacity(0.8)
                                .padding(.vertical, 20)
                            
                            // Positioning lines relative to the image size
                            // Note: Adjusted offsets to be more standard across screens
                            MeasurementLine(label: "Height", value: $viewModel.height, unit: "cm", isVertical: true)
                                .frame(height: geo.size.height * 0.35).offset(x: -geo.size.width * 0.4, y: -10)
                            
                            MeasurementLine(label: "Arm", value: $viewModel.armLength, unit: "cm", isVertical: true)
                                .frame(height: 140).offset(x: -70, y: -60)
                            
                            MeasurementLine(label: "Inseam", value: $viewModel.inseam, unit: "cm", isVertical: true)
                                .frame(height: 160).offset(x: 0, y: 80)
                            
                            MeasurementLine(label: "Shoulder", value: $viewModel.shoulderWidth, unit: "cm", isVertical: false)
                                .frame(width: 100).offset(y: -130)
                            
                            MeasurementLine(label: "Chest", value: $viewModel.chest, unit: "cm", isVertical: false)
                                .frame(width: 60).offset(y: -95)
                            
                            MeasurementLine(label: "Waist", value: $viewModel.waist, unit: "cm", isVertical: false)
                                .frame(width: 50).offset(y: -60)
                            
                            MeasurementLine(label: "Hips", value: $viewModel.hips, unit: "cm", isVertical: false)
                                .frame(width: 75).offset(y: -25)
                        }
                        
                        // --- 3. Stat Boxes (Weight & Shoes) ---
                        HStack(spacing: 20) {
                            StatBox(label: "Body", value: $viewModel.bodyWeight, unit: "kg")
                            StatBox(label: "Shoe Size", value: $viewModel.shoeSize, unit: "")
                        }
                        .padding(.horizontal)

                        // --- 4. Action Buttons ---
                        VStack(spacing: 12) {
                            Button(action: { showImagePicker = true }) {
                                Text(selectedSelfie == nil ? "Take Selfie" : "Retake Selfie")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundColor(fitPickGold)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(fitPickGold.opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(fitPickGold, lineWidth: 1))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: { saveProfile() }) {
                                Text("Save")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(viewModel.username.isEmpty ? Color.gray.opacity(0.5) : Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                            }
                            .disabled(viewModel.username.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30) // Extra padding so it doesn't hit the bottom bar
                    }
                }
            }
        }
        .onAppear { viewModel.fetchUserData() }
        .fullScreenCover(isPresented: $showAutoMeasure) {
            AutoMeasureView(onCapture: { h, w, i, a, s, c, hi in
                viewModel.height = h
                viewModel.waist = w
                viewModel.inseam = i
                viewModel.armLength = a
                viewModel.shoulderWidth = s
                viewModel.chest = c
                viewModel.hips = hi
                showAutoMeasure = false
            })
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
            Task { await viewModel.generateAndSaveAvatar() }
        }
    }
}
// MARK: - Subcomponents (The ones that were missing)
struct MeasurementLine: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let isVertical: Bool
    var body: some View {
        VStack(spacing: 4) {
            Menu {
                Picker(label, selection: $value) {
                    ForEach(Array(stride(from: 1, through: 250, by: 1)), id: \.self) { num in
                        Text("\(num) \(unit)").tag(Double(num))
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.secondary).textCase(.uppercase)
                    Text("\(Int(value))").font(.system(size: 12, weight: .bold)).foregroundColor(.blue)
                }
                .padding(4).background(Color.white.opacity(0.9)).cornerRadius(6)
            }
            if isVertical {
                VStack(spacing: 0) {
                    Rectangle().frame(width: 8, height: 1.5)
                    Rectangle().frame(width: 1.5, height: .infinity)
                    Rectangle().frame(width: 8, height: 1.5)
                }
                .foregroundColor(.blue.opacity(0.5))
            } else {
                HStack(spacing: 0) {
                    Rectangle().frame(width: 1.5, height: 8)
                    Rectangle().frame(width: .infinity, height: 1.5)
                    Rectangle().frame(width: 1.5, height: 8)
                }
                .foregroundColor(.blue.opacity(0.5))
            }
        }
    }
}
struct StatBox: View {
    let label: String
    @Binding var value: Double
    let unit: String
    
    var body: some View {
        Menu {
            Picker(label, selection: $value) {
                ForEach(1...200, id: \.self) { num in
                    Text("\(num) \(unit)").tag(Double(num))
                }
            }
        } label: {
            VStack(alignment: .leading) {
                Text(label).font(.caption2).bold().foregroundColor(.secondary)
                Text("\(Int(value))\(unit)").font(.subheadline).bold().foregroundColor(.primary)
            }
            .padding(10).frame(width: 80).background(BlurView(style: .systemUltraThinMaterial)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2)))
        }
    }
}
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}



