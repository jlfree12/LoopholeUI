import SwiftUI

extension View {
    func overlax<Overlay: View>(_ overlay: Overlay) -> some View {
        self.overlay(overlay)
    }
}
