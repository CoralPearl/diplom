import SwiftUI

extension Binding where Value == String {
    /// Creates a Binding that applies a transform to every new value (useful for input masks).
    func filtered(_ transform: @escaping (String) -> String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue },
            set: { newValue in
                let transformed = transform(newValue)
                if transformed != self.wrappedValue {
                    self.wrappedValue = transformed
                }
            }
        )
    }
}
