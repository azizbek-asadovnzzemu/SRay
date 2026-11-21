#if DEBUG
import SwiftUI

/// Presents the output preference separately from the demo's enable controls.
struct ASLFixtureOutputPicker: View {
    let fixture: ASLFixtureConversation

    var body: some View {
        Menu {
            ForEach(ASLFixtureOutputMode.allCases, id: \.self) { mode in
                let selected = fixture.outputMode == mode
                Button {
                    fixture.selectOutput(mode)
                } label: {
                    if selected {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
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
