# Live Presentation Coach

An iOS app that gives real-time feedback on public speaking. Built to help users improve their delivery through speech emotion detection, pacing analysis, filler word detection, and visual posture cues.

(#NOTE: Need to create your own folder called "Resources" after fetching repo, then add your own video titled "test_video.mp4" in order to analyze bundled videos)

## Features

- **Speech Emotion Recognition**  
  Uses models trained on Apple's Create ML platform to classify emotions (e.g., happy, angry, sad) from your voice.

- **Pacing & Filler Word Detection** *(coming soon)*  
  Detects speaking speed and overused filler words like “um” or “like”.

- **Posture & Head Movement Analysis** *(coming soon)*  
  Uses Vision APIs to provide visual feedback on eye contact and posture.

## Tech Stack / APIs Used

- `AVFoundation` – for audio/video capture
- `SoundAnalysis` – for real-time audio classification
- `Create ML` – for emotion recognition model training
- `Vision` – for facial and gesture analysis (planned)
- `SwiftUI` – for building the iOS UI
