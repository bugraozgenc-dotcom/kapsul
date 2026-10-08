import SwiftUI

struct SidebarTint: View {
    @AppStorage("sidebarRed") private var red = 0.0
    @AppStorage("sidebarGreen") private var green = 0.0
    @AppStorage("sidebarBlue") private var blue = 0.0
    @AppStorage("sidebarTransparency") private var transparency = 82.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Color(red: red, green: green, blue: blue)
            .opacity(reduceTransparency ? 1 : 1 - min(max(transparency, 0), 100) / 100)
    }
}

struct SidebarAppearanceSettings: View {
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("sidebarRed") private var red = 0.0
    @AppStorage("sidebarGreen") private var green = 0.0
    @AppStorage("sidebarBlue") private var blue = 0.0
    @AppStorage("sidebarTransparency") private var transparency = 82.0

    private var color: Binding<Color> {
        Binding(get: { Color(red: red, green: green, blue: blue) }, set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
            red = rgb.redComponent
            green = rgb.greenComponent
            blue = rgb.blueComponent
        })
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(localization.text("Sol menü"), systemImage: "sidebar.left").font(.headline)
                ColorPicker(localization.text("Sol menü rengi"), selection: color, supportsOpacity: false)
                HStack {
                    Text(localization.text("Sol menü şeffaflığı"))
                    Spacer()
                    Text("\(Int(transparency))%").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $transparency, in: 0...100, step: 1) {
                    Text(localization.text("Sol menü şeffaflığı"))
                }.labelsHidden().frame(maxWidth: .infinity).disabled(reduceTransparency)
                HStack {
                    Text(localization.text("Opak"))
                    Spacer()
                    Text(localization.text("Daha şeffaf"))
                }.font(.caption).foregroundStyle(.secondary)
                Text(localization.text("Değişiklik hemen uygulanır. Kartlar ve yazılar net kalır."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(localization.text("Varsayılana dön")) {
                    red = 0; green = 0; blue = 0; transparency = 82
                }.buttonStyle(.borderless)
            }
        }
    }
}
