//
//  Login.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

import SwiftUI

struct BodyMeasurementView: View {
    
    @State private var gender = "Male"
    @State private var selectedHeight = 100 // Default value
    @State private var selectedWeight = 100 // Default value
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 50){
                Picker("Gender", selection: $gender) {
                                    Text("Male").tag("Male")
                                    Text("Female").tag("Female")
                                }
                                .pickerStyle(.segmented)
                Text("Body Measurements")
                    .font(.largeTitle)
                    .navigationTitle("User Information")
            ZStack {
                    if gender == "Male" {
                        Image("Male")
                            .resizable()
                            .frame(maxWidth: .infinity)
                            .position(x:240, y:200)
                            .scaledToFill()
                    } else {
                        Image("Female")
                            .resizable()
                            .frame(maxWidth: .infinity)
                            .position(x:240, y:200)
                            .scaledToFill()
                    }
                
                Picker("Weight", selection: $selectedWeight) {
                    ForEach(1...150, id: \.self) { number in
                        Text("\(number) kg").tag(number)
                    }
                }
                // This modifier makes it look like a dropdown menu
                .pickerStyle(.menu)
                .position(x:280, y:-110)
                
                Picker("Height", selection: $selectedHeight) {
                    ForEach(1...150, id: \.self) { number in
                        Text("\(number) cm").tag(number)
                    }
                }
                // This modifier makes it look like a dropdown menu
                .pickerStyle(.menu)
                .position(x:110, y:70)
                
                Text("Shoulder Width") // Custom label above the wheel
                        .font(.headline)
                        .position(x:110, y:45)
                Text("Weight") // Custom label above the wheel
                        .font(.headline)
                        .position(x:200, y:-110)
                
                Button("Save") {
                    print("Button was tapped!")
                    // Add your logic here, like resetting the height to 100:
                    // selectedHeight = 100
                }.position(x:380, y:420)
                
            }
            }
            .padding()
            .navigationTitle("Body Measurement")
        }
    }
}
