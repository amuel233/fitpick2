//
//  BodyMeasurementViewModel.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/23/26.
//

import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAILogic

class BodyMeasurementViewModel: ObservableObject {
    
        @Published var isGenerating: Bool = false
        @Published var isProcessing: Bool = true
        @Published var generatedImage: UIImage? = nil
    
    
        func generateAvatar() async {
            let generativeModel = FirebaseAI.firebaseAI(backend: .vertexAI(location: "global")).generativeModel(
                modelName: "gemini-2.5-flash-image",
                generationConfig: GenerationConfig(responseModalities: [.text, .image])
            )
            let prompt = "Generate an image of car."
            do {
                let response = try await generativeModel.generateContent(prompt)
                
                guard let inlineDataPart = response.inlineDataParts.first else {
                    return
                }
                
                if let uiImage = UIImage(data: inlineDataPart.data) {
                    self.generatedImage = uiImage
                    print("Image successfully created")
                }
                
            } catch {
                print("Error: \(error.localizedDescription)")
            }
            // 3. And used here to stop the loading spinner
            isProcessing = false
        }

}
