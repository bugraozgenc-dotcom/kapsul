import SwiftUI

struct BrandHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text("Kapsül")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(colorScheme == .dark ? Color(red: 0.84, green: 0.95, blue: 1) : Color.blue)
            .frame(width: 184, height: 62, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kapsül")
            .accessibilityAddTraits(.isHeader)
    }
}
