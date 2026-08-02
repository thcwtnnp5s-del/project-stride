// RootPlaceholderView.swift
// Project Stride — app target
//
// A placeholder that proves the app launches and links StrideCore.
//
// This is deliberately plain. It is not a design, not a draft of the Adventure
// screen, and not a preview of the visual identity — that work is P-01 and P-02,
// and starting it here would put UI decisions ahead of the design review that
// owns them.

import SwiftUI
import StrideCore

struct RootPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Project Stride")
                .font(.title2.weight(.semibold))

            Text("Foundation skeleton — F-01")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Reading a value from StrideCore proves the app target actually
            // links the package rather than merely declaring it.
            Text("StrideCore \(StrideCore.version)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootPlaceholderView()
}
