# Native captions

Issue #17 adds the first captions flow to the native app. Start Conversation prepares an English recognition request and asks for microphone and speech access in context. The app shares one caption session across windows. Continue Captions starts another recognition request in the same conversation after a request ends. End Conversation stops capture and clears the transcript.

Each recognition request updates one stable caption row until its final result. The latest row appears above earlier rows. Updates leave the reader's scroll position under their control, with Return to Live available during the conversation. Caption text size is adjustable per window and follows Dynamic Type.

The backend requires on-device recognition. ASL is unavailable in this build while provider access, timing and pose playback are unresolved. The app hides the transcript in inactive windows and ends the conversation when all windows enter the background. The session prunes expired captions even when no new speech arrives. Audio route changes and system interruptions need additional validation under #21.

Use `swift test --package-path Packages/SRayKit` for the controlled-backend integration tests. Run `python3 scripts/apple_ci.py ios` and `python3 scripts/apple_ci.py visionos` for device SDK compilation. Verify microphone permission, real audio capture, offline assets, thermal behavior and assistive technology on physical devices before claiming platform support.
