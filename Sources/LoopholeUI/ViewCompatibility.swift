import SwiftUI

extension View {
    @ViewBuilder
    func overlax<Overlay: View>(@ViewBuilder _ overlay: () -> Overlay) -> some View {
        self.overlay(overlay())
    }
}
