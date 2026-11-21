#if DEBUG
import SwiftUI

/// Presents the output preference separately from the demo's enable controls.
struct ASLFixtureOutputPicker: View {
    let fixture: ASLFixtureConversation

    var body: some View {
        Menu {
            Picker("Conversation Output", selection: Binding(
                get: { fixture.outputMode },
                set: fixture.selectOutput
            )) {
                ForEach(ASLFixtureOutputMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Label("Conversation Output", systemImage: "rectangle.split.2x1")
                .frame(minHeight: 44)
        }
        .accessibilityValue(Text(fixture.outputMode.title))
        .accessibilityIdentifier("asl.demo.output")
    }
}
#endif
