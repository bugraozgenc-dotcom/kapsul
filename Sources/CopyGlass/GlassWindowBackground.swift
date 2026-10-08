import AppKit
import SwiftUI

/// A native backdrop that blurs the desktop behind the window, rather than
/// fading the window's text and controls together with its background.
struct GlassWindowSurface: View {
    @AppStorage("backgroundTransparency") private var transparency = 75.0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var amount: Double { reduceTransparency ? 0 : min(max(transparency, 0), 100) / 100 }

    var body: some View {
        ZStack {
            GlassWindowBackground(transparency: amount)
            Color(nsColor: .windowBackgroundColor).opacity(1 - amount)
        }.allowsHitTesting(false)
    }
}

struct GlassWindowBackground: NSViewRepresentable {
    let transparency: Double
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> WindowBackdrop {
        let view = WindowBackdrop()
        view.blendingMode = .behindWindow
        view.material = .sidebar
        view.state = .active
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: WindowBackdrop, context: Context) {
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        view.reduceTransparency = transparency == 0
        view.isHidden = transparency == 0
        // Sidebar material is intentionally dense. Fade only the backdrop at
        // the clear end of the slider so desktop colors and shapes show through.
        // Keep a little native blur instead of fading any foreground content.
        view.alphaValue = 1 - 0.78 * pow(transparency, 2)
        view.configureWindow()
    }

    final class WindowBackdrop: NSVisualEffectView {
        var reduceTransparency = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        func configureWindow() {
            guard let window else { return }
            window.isOpaque = reduceTransparency
            window.backgroundColor = reduceTransparency ? .windowBackgroundColor : .clear
        }
    }
}
