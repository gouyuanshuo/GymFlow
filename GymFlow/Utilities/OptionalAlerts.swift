import SwiftUI

extension Binding {
    /// A `Bool` binding that is `true` while an optional value is present, and clears the value
    /// when set to `false`.
    ///
    /// SwiftUI's `alert`/`sheet` presentation takes `isPresented: Binding<Bool>`, while state that
    /// drives a presentation is usually modelled as an optional ("the error to show", "the item
    /// pending deletion"). This bridges the two so views do not hand-roll a `Binding(get:set:)`
    /// at every call site.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { isPresented in
                if !isPresented { wrappedValue = nil }
            }
        )
    }
}

extension View {
    /// Presents a single-button alert whenever `message` holds a value, clearing it on dismiss.
    ///
    /// Every screen in GymFlow surfaces recoverable failures the same way, so the wording of the
    /// dismiss button and the fallback message live here rather than being restated per screen.
    func errorAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(title, isPresented: message.isPresent()) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message.wrappedValue ?? "An unknown error occurred.")
        }
    }
}
