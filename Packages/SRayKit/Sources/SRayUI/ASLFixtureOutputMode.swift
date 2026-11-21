#if DEBUG
import SwiftUI

/// Presentation options for the local pose demo.
enum ASLFixtureOutputMode: CaseIterable, Hashable {
    case captionsOnly
    case poseOnly
    case captionsAndPose

    var title: LocalizedStringKey {
        switch self {
        case .captionsOnly: "Captions Only"
        case .poseOnly: "Pose Only"
        case .captionsAndPose: "Captions and Pose"
        }
    }
}
#endif
