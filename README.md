# Emotion Video Analyzer

An iOS app that analyzes emotions in videos by extracting and processing their audio using Apple's SoundAnalysis framework.

## Features

- Detects emotions from video audio in real time
- Supports videos from the Photos library or a bundled demo video
- Displays the current detected emotion during playback

## How It Works

1. User selects a video from the Photos library (or uses a bundled test video)
2. The app extracts and converts the audio to a `.m4a` format (for compatibility)
3. Apple's SoundAnalysis API analyzes the audio stream
4. Emotions are synced and displayed as the video plays

## APIs Used

- `SoundAnalysis`
- `AVFoundation`
- PhotosUI
- SwiftUI
