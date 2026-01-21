import SwiftUI

struct BodyMeasurementView: View {

    @State private var username: String = ""
    @State private var gender: String = "Male"
    
    @State private var height: Double = 175
    @State private var bodyWeight: Double = 70
    @State private var chest: Double = 90
    @State private var shoulderWidth: Double = 45
    @State private var armLength: Double = 60
    @State private var waist: Double = 80
    @State private var hips: Double = 95
    @State private var inseam: Double = 80
    @State private var shoeSize: Double = 9

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("User Information")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top, 10)

                    TextField("Username", text: $username)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                ZStack {
                    Image(gender)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 40)
                        .opacity(0.8)
                    
                    MeasurementLine(label: "Height", value: $height, unit: "cm", isVertical: true)
                        .frame(height: 380)
                        .offset(x: -165, y: -17)

                    MeasurementLine(label: "Arm", value: $armLength, unit: "cm", isVertical: true)
                        .frame(height: 160)
                        .offset(x: -70, y: -70)

                    MeasurementLine(label: "Inseam", value: $inseam, unit: "cm", isVertical: true)
                        .frame(height: 190)
                        .offset(x: 0, y: 80)

                    
                    MeasurementLine(label: "Shoulder", value: $shoulderWidth, unit: "cm", isVertical: false)
                        .frame(width: 100)
                        .offset(y: -130)
                    
                    MeasurementLine(label: "Chest", value: $chest, unit: "cm", isVertical: false)
                        .frame(width: 60)
                        .offset(y: -100)
                    
                    MeasurementLine(label: "Waist", value: $waist, unit: "cm", isVertical: false)
                        .frame(width: 50)
                        .offset(y: -65)

                    MeasurementLine(label: "Hips", value: $hips, unit: "cm", isVertical: false)
                        .frame(width: 75)
                        .offset(y: -30)

                    VStack {
                        Spacer()
                        HStack {
                            StatBox(label: "Body", value: $bodyWeight, unit: "kg")
                            Spacer()
                            StatBox(label: "Shoe Size", value: $shoeSize, unit: "")
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 15)
                    }
                }
                
                VStack(spacing: 12) {
                    Button(action: { print("Selfie tapped") }) {
                        Text("Selfie")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }

                    Button(action: { print("Saved Profile: \(username)") }) {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(username.isEmpty ? Color.gray.opacity(0.5) : Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .disabled(username.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

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
                .padding(4)
                .background(Color.white.opacity(0.9))
                .cornerRadius(6)
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
            .padding(10)
            .frame(width: 80)
            .background(BlurView(style: .systemUltraThinMaterial))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2)))
        }
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    BodyMeasurementView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
