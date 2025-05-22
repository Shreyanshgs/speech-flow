//
//  EmotionAnalyzer.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/13/25.
//

import AVFoundation
import SoundAnalysis

class EmotionFileAnalyzer: NSObject, SNResultsObserving {
    private var analyzer: SNAudioFileAnalyzer!
    private var request: SNClassifySoundRequest?
    private var onEmotionUpdate: (String, TimeInterval) -> Void
    
    init(onEmotionUpdate: @escaping (String, TimeInterval) -> Void) {
        self.onEmotionUpdate = onEmotionUpdate
        super.init()
        
        do {
            let model = try EmotionClassifierFinal().model
            request = try SNClassifySoundRequest(mlModel: model)
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    func analyzeVideoAudio(from url: URL) async {
        do {
            analyzer = try SNAudioFileAnalyzer(url: url)

            if let request = request {
                try analyzer.add(request, withObserver: self)
                await analyzer.analyze()
            }
        } catch {
            print("Analysis failed: \(error)")
        }
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        if let classificationResult = result as? SNClassificationResult,
           let top = classificationResult.classifications.first {
            let timestamp = classificationResult.timeRange.start.seconds
            onEmotionUpdate(top.identifier, timestamp)
        }
    }
}

