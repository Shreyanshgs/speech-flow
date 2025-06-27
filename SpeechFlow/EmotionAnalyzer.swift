//
//  EmotionAnalyzer.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/13/25.
//

import AVFoundation
import SoundAnalysis

// This class uses SoundAnalysis and a CoreML model to analyze emotions from an audio file
class EmotionFileAnalyzer: NSObject, SNResultsObserving {
    
    // The analyzer that processes audio files frame by frame
    private var analyzer: SNAudioFileAnalyzer!
    
    // The request that performs classification using the CoreML model
    private var request: SNClassifySoundRequest?
    
    // A callback function that gets called with each predicted emotion and its timestamp
    private var onEmotionUpdate: (String, TimeInterval) -> Void
    
    // Initializer takes a closure to report each emotion classification result
    init(onEmotionUpdate: @escaping (String, TimeInterval) -> Void) {
        self.onEmotionUpdate = onEmotionUpdate
        super.init()
        
        do {
            // Load the compiled CoreML model
            let model = try EmotionClassifierFinal().model
            
            // Create a classification request with the model
            request = try SNClassifySoundRequest(mlModel: model)
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    // Asynchronously analyze the audio from the given URL
    func analyzeVideoAudio(from url: URL) async {
        do {
            // Initialize the audio analyzer with the file URL
            analyzer = try SNAudioFileAnalyzer(url: url)
            
            // Add the classification request and start analysis
            if let request = request {
                try analyzer.add(request, withObserver: self)
                await analyzer.analyze() // Begin analysis and wait for it to finish
            }
        } catch {
            print("Analysis failed: \(error)")
        }
    }
    
    // Called every time the analyzer produces a classification result
    func request(_ request: SNRequest, didProduce result: SNResult) {
        // Convert the result to a classification result and get the top prediction
        if let classificationResult = result as? SNClassificationResult,
           let top = classificationResult.classifications.first {
            
            // Extract the timestamp of the classification
            let timestamp = classificationResult.timeRange.start.seconds
            
            // Pass the result back through the callback
            onEmotionUpdate(top.identifier, timestamp)
        }
    }
}
