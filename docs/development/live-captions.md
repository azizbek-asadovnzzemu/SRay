# Native captions

Issue #17 adds the first captions flow to the native app. Start Conversation prepares an English recognition request and asks for microphone and speech access in context. The app shares one caption session across windows. Continue Captions starts another recognition request in the same conversation after a request ends. End Conversation stops capture and clears the transcript.

Each recognition request updates one stable caption row until its final result. The latest row appears above earlier rows. Updates leave the reader's scroll position under their control, with Return to Live available during the conversation. Caption text size is adjustable per window and follows Dynamic Type.

The backend requires on-device recognition. ASL is unavailable in this build while provider access, timing and pose playback are unresolved. The app hides the transcript in inactive windows and ends the conversation when all windows enter the background. The session prunes expired captions even when no new speech arrives. Audio interruption, media-services reset, relevant route changes, and closure of the last visible conversation window stop capture and clear the transcript. A new conversation requires an explicit start. Audio routes and window lifecycle need physical validation under #21.

The local pose demo also exercises app backgrounding with a completed pose ready for replay. After returning, the prior caption and replay are cleared. Starting a new conversation restores captions and requires explicit enable before accepting another pose request. The iPhone and iPad simulator scenario verifies this flow with generated content.

Use `swift test --package-path Packages/SRayKit` for the controlled-backend integration tests. Run `python3 scripts/apple_ci.py ios` and `python3 scripts/apple_ci.py visionos` for device SDK compilation. Verify microphone permission, real audio capture, offline assets, thermal behavior and assistive technology on physical devices before claiming platform support.

A controlled Swift test also covers a result that arrives after the last window closes. One connected window keeps the original conversation and request alive. Closing the last window clears the caption and cancels that request. A fresh window must start and enable a new conversation, and the previous result cannot show or displace the new request.

The simulator background checks wait for the restart control to accept input after foregrounding. Its accessibility element can become available while the Home Screen return animation is still finishing.
